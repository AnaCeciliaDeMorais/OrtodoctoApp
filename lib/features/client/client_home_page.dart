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

class _HomeData {
  _HomeData(this.appointments, this.charges, this.promos);
  final List<Appointment> appointments;
  final List<Charge> charges;
  final List<Product> promos;
}

/// Início do cliente: avisos (consulta, vencimentos, promoções) e destaques.
class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

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
                  final next = d.appointments
                      .where((a) => a.startsAt.isAfter(now) &&
                          (a.status == AppointmentStatus.scheduled || a.status == AppointmentStatus.confirmed))
                      .toList()
                    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                  final overdue = d.charges.where((c) => c.isOverdue).toList();
                  final dueSoon = d.charges
                      .where((c) =>
                          c.status == ChargeStatus.open &&
                          !c.isOverdue &&
                          c.dueDate.difference(today).inDays <= 7)
                      .toList();
                  final scheme = Theme.of(context).colorScheme;

                  return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                    const SectionTitle('Avisos'),
                    if (next.isNotEmpty)
                      _Notice(
                        icon: Icons.event_available,
                        color: scheme.primary,
                        title: 'Próxima consulta: ${f.dayLong(next.first.startsAt)}',
                        subtitle: 'às ${f.time(next.first.startsAt)}'
                            '${next.first.companyName != null && session.companies.length > 1 ? ' · ${next.first.companyName}' : ''}',
                      ),
                    if (overdue.isNotEmpty)
                      _Notice(
                        icon: Icons.warning_amber,
                        color: scheme.error,
                        title: '${overdue.length} pagamento(s) vencido(s)',
                        subtitle: 'Total ${f.money(overdue.fold<double>(0, (a, c) => a + c.amount))}. Veja em Pagamentos.',
                      ),
                    if (dueSoon.isNotEmpty)
                      _Notice(
                        icon: Icons.schedule,
                        color: Colors.orange.shade800,
                        title: '${dueSoon.length} pagamento(s) vencem nos próximos 7 dias',
                        subtitle: 'Próximo: ${dueSoon.first.description} em ${f.date(dueSoon.first.dueDate)}',
                      ),
                    if (d.promos.any((p) => p.onPromotion))
                      _Notice(
                        icon: Icons.local_offer,
                        color: AppTheme.promo,
                        title: '${d.promos.where((p) => p.onPromotion).length} promoção(ões) para você',
                        subtitle: 'Confira em Produtos.',
                      ),
                    if (next.isEmpty && overdue.isEmpty && dueSoon.isEmpty && d.promos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Tudo em dia por aqui.'),
                      ),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.title, required this.subtitle});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}
