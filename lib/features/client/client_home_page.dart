import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../home/company_switcher.dart';
import '../patients/patients_repository.dart';
import '../products/product_card.dart';
import '../products/products_repository.dart';
import '../schedule/schedule_repository.dart';
import 'client_reminders.dart';

class _HomeData {
  _HomeData(this.appointments, this.charges, this.promos);
  final List<Appointment> appointments;
  final List<Charge> charges;
  final List<Product> promos;
}

/// Início do cliente: avisos (consulta em 1 hora, aniversário, promoções,
/// retorno de prevenção, vencimentos) e destaques.
class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Atualiza a tela a cada minuto para o aviso de "consulta em 1 hora"
    // aparecer na hora certa e a contagem de minutos andar.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<_HomeData> _load(Company? company) async {
    final r = await Future.wait([
      ScheduleRepository().mine(),
      ChargesRepository().mine(),
      company == null ? Future.value(<Product>[]) : ProductsRepository().list(company.id),
    ]);
    final products = (r[2] as List<Product>).where((p) => p.active && (p.onPromotion || p.featured)).toList();
    return _HomeData(r[0] as List<Appointment>, r[1] as List<Charge>, products);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.profile?.firstName ?? '';
    return Scaffold(
      appBar: AppBar(title: CompanyTitle('Olá, $name')),
      body: session.myPatients.isEmpty
          ? const EmptyState(
              icon: Icons.link_off,
              message: 'Seu acesso ainda não está ligado a uma ficha na clínica. Fale com a recepção.',
            )
          : ContentWidth(
              child: AsyncLoader<_HomeData>(
                load: () => _load(session.current),
                builder: (context, d, _) {
                  final now = DateTime.now();
                  final today = f.dayOnly(now);
                  final several = session.companies.length > 1;
                  final next = upcomingAppointments(d.appointments, now);
                  final soon = startingWithinAnHour(d.appointments, now);
                  final later = next.where((a) => !soon.contains(a)).toList();
                  final birthdays = birthdayToday(session.myPatients, now);
                  final prevention = preventionReturn(d.appointments);
                  final showPrevention = prevention != null && prevention.isDue && !prevention.scheduled;
                  final promos = d.promos.where((p) => p.onPromotion).toList();
                  final overdue = d.charges.where((c) => c.isOverdue).toList();
                  final dueSoon = d.charges
                      .where((c) =>
                          c.status == ChargeStatus.open &&
                          !c.isOverdue &&
                          c.dueDate.difference(today).inDays <= 7)
                      .toList();
                  final scheme = Theme.of(context).colorScheme;
                  String where(Appointment a) =>
                      several && a.companyName != null ? ' · ${a.companyName}' : '';

                  final notices = <Widget>[
                    for (final p in birthdays)
                      NoticeCard(
                        icon: Icons.cake,
                        color: Colors.pink,
                        highlight: true,
                        title: 'Feliz aniversário, ${p.fullName.split(' ').first}!',
                        subtitle: '${session.companies.where((c) => c.id == p.companyId).firstOrNull?.name ?? 'A clínica'}'
                            ' deseja um dia cheio de sorrisos.',
                      ),
                    for (final a in soon)
                      NoticeCard(
                        icon: Icons.alarm,
                        color: scheme.error,
                        highlight: true,
                        title: 'Sua consulta começa ${minutesUntil(a.startsAt)}',
                        subtitle: 'Hoje às ${f.time(a.startsAt)}'
                            '${a.label != null ? ' · ${a.label}' : ''}${where(a)}',
                      ),
                    if (later.isNotEmpty)
                      NoticeCard(
                        icon: Icons.event_available,
                        color: scheme.primary,
                        title: 'Próxima consulta: ${f.dayLong(later.first.startsAt)}',
                        subtitle: 'às ${f.time(later.first.startsAt)}${where(later.first)}',
                      ),
                    if (showPrevention)
                      NoticeCard(
                        icon: Icons.health_and_safety_outlined,
                        color: Colors.teal,
                        highlight: true,
                        title: 'Hora do seu retorno de prevenção',
                        subtitle: 'Sua última consulta foi em ${f.date(prevention.lastVisit)}. '
                            'Fale com a clínica para agendar.',
                      ),
                    for (final p in promos)
                      NoticeCard(
                        icon: Icons.local_offer,
                        color: AppTheme.promo,
                        title: 'Promoção: ${p.name}',
                        subtitle: [
                          p.promoPrice != null && p.promoPrice! < p.price
                              ? 'De ${f.money(p.price)} por ${f.money(p.promoPrice)}'
                              : f.money(p.currentPrice),
                          if (p.promoUntil != null) 'até ${f.date(p.promoUntil)}',
                        ].join(' · '),
                        onTap: () => showProductDetail(context, p),
                      ),
                    if (overdue.isNotEmpty)
                      NoticeCard(
                        icon: Icons.warning_amber,
                        color: scheme.error,
                        title: '${overdue.length} pagamento(s) vencido(s)',
                        subtitle: 'Total ${f.money(overdue.fold<double>(0, (a, c) => a + c.amount))}. Veja em Pagamentos.',
                      ),
                    if (dueSoon.isNotEmpty)
                      NoticeCard(
                        icon: Icons.schedule,
                        color: Colors.orange.shade800,
                        title: '${dueSoon.length} pagamento(s) vencem nos próximos 7 dias',
                        subtitle: 'Próximo: ${dueSoon.first.description} em ${f.date(dueSoon.first.dueDate)}',
                      ),
                  ];

                  return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                    const SectionTitle('Avisos'),
                    if (notices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Tudo em dia por aqui.'),
                      )
                    else
                      ...notices,
                    if (d.promos.isNotEmpty) ...[
                      const SectionTitle('Em destaque'),
                      PromoBanner(products: d.promos, onTap: (p) => showProductDetail(context, p)),
                    ],
                  ]);
                },
              ),
            ),
    );
  }
}
