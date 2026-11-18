import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../schedule/appointment_sheet.dart';
import '../schedule/schedule_repository.dart';
import 'charge_widgets.dart';
import 'patient_files_widgets.dart';
import 'patient_form_sheet.dart';
import 'patients_repository.dart';

class _Data {
  _Data(this.patient, this.appointments, this.charges, this.files);
  final Patient patient;
  final List<Appointment> appointments;
  final List<Charge> charges;
  final List<PatientFile> files;
}

/// Ficha do cliente: dados, consultas, financeiro e pasta (boletos e documentos).
class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({super.key, required this.patientId});
  final String patientId;

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  final _patients = PatientsRepository();
  final _loader = GlobalKey<AsyncLoaderState<_Data>>();

  Future<_Data> _load() async {
    final r = await Future.wait([
      _patients.get(widget.patientId),
      ScheduleRepository().forPatient(widget.patientId),
      ChargesRepository().forPatient(widget.patientId),
      PatientFilesRepository().list(widget.patientId),
    ]);
    return _Data(r[0] as Patient, r[1] as List<Appointment>, r[2] as List<Charge>, r[3] as List<PatientFile>);
  }

  void _reload() => _loader.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AsyncLoader<_Data>(
        key: _loader,
        load: _load,
        builder: (context, data, _) {
          final p = data.patient;
          return Scaffold(
            appBar: AppBar(
              title: Text(p.fullName),
              actions: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final saved = await showFormSheet<Patient>(
                        context, (_) => PatientFormSheet(companyId: p.companyId, patient: p));
                    if (saved != null) _reload();
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final ok = await confirm(
                        context,
                        'Excluir cliente',
                        'Excluir ${p.fullName} apaga também os agendamentos, cobranças, arquivos da pasta e dúvidas dele. '
                            'Para guardar o histórico, prefira marcar como inativo.',
                        ok: 'Excluir',
                        danger: true,
                      );
                      if (!ok || !context.mounted) return;
                      if (await runGuarded(context, () => _patients.delete(p), success: 'Cliente excluído.')) {
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Excluir cliente'))],
                ),
              ],
              bottom: const TabBar(tabs: [
                Tab(text: 'Dados'),
                Tab(text: 'Consultas'),
                Tab(text: 'Financeiro'),
                Tab(text: 'Pasta'),
              ]),
            ),
            body: ContentWidth(
              child: TabBarView(children: [
                _DataTab(patient: p, onChanged: _reload),
                _AppointmentsTab(patient: p, items: data.appointments, onChanged: _reload),
                _FinanceTab(patient: p, charges: data.charges, onChanged: _reload),
                _FilesTab(patient: p, files: data.files, charges: data.charges, onChanged: _reload),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _DataTab extends StatelessWidget {
  const _DataTab({required this.patient, required this.onChanged});
  final Patient patient;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    Widget row(IconData icon, String label, String? value, {VoidCallback? onTap}) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : ListTile(leading: Icon(icon), title: Text(value), subtitle: Text(label), onTap: onTap);

    return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
      row(Icons.badge_outlined, 'CPF', p.cpf == null ? null : f.cpf(p.cpf)),
      row(Icons.cake_outlined, 'Nascimento', p.birthDate == null ? null : f.date(p.birthDate)),
      row(Icons.phone_outlined, 'Telefone', p.phone == null ? null : f.phone(p.phone),
          onTap: () => launchUrl(Uri.parse('tel:${f.onlyDigits(p.phone)}'))),
      if (p.phone != null)
        ListTile(
          leading: const Icon(Icons.chat_outlined),
          title: const Text('Conversar no WhatsApp'),
          onTap: () => launchUrl(Uri.parse('https://wa.me/55${f.onlyDigits(p.phone)}'),
              mode: LaunchMode.externalApplication),
        ),
      row(Icons.mail_outline, 'E-mail', p.email),
      row(Icons.family_restroom, 'Responsável',
          p.guardianName == null ? null : '${p.guardianName}${p.guardianCpf != null ? ' · CPF ${f.cpf(p.guardianCpf)}' : ''}'),
      row(Icons.home_outlined, 'Endereço', p.address),
      row(Icons.notes, 'Observações', p.notes),
      const Divider(),
      SectionTitle('Acesso ao app'),
      if (p.hasAccess)
        ListTile(
          leading: const Icon(Icons.phone_iphone),
          title: const Text('Cliente já tem acesso'),
          subtitle: const Text('Ele vê consultas, pagamentos, produtos e pode tirar dúvidas.'),
          trailing: TextButton(
            onPressed: () async {
              final ok = await confirm(context, 'Remover acesso',
                  'O cliente não conseguirá mais entrar no app (a ficha continua).',
                  ok: 'Remover', danger: true);
              if (!ok || !context.mounted) return;
              if (await runGuarded(context, () => PatientsRepository().removeAccess(p.id),
                  success: 'Acesso removido.')) {
                onChanged();
              }
            },
            child: const Text('Remover'),
          ),
        )
      else
        ListTile(
          leading: const Icon(Icons.lock_open),
          title: const Text('Criar acesso ao app'),
          subtitle: const Text('Cria login com e-mail e senha para o cliente.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (_) => _AccessDialog(patient: p));
            if (ok == true) onChanged();
          },
        ),
    ]);
  }
}

class _AccessDialog extends StatefulWidget {
  const _AccessDialog({required this.patient});
  final Patient patient;

  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.patient.email);
  final _password = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => PatientsRepository().createAccess(widget.patient.id, _email.text.trim(), _password.text),
      success: 'Acesso criado. Passe o e-mail e a senha ao cliente.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Criar acesso ao app'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail do cliente'),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(
                labelText: 'Senha inicial',
                helperText: '8+ caracteres, 1 número e 1 especial',
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 8),
            const Text(
              'Se o e-mail já tiver acesso (cliente de outra empresa), a senha atual dele é mantida.',
              style: TextStyle(fontSize: 12),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Criar acesso')),
        ],
      );
}

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab({required this.patient, required this.items, required this.onChanged});
  final Patient patient;
  final List<Appointment> items;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final company = SessionScope.of(context).companies.where((c) => c.id == patient.companyId).firstOrNull;
    Future<void> open([Appointment? a]) async {
      if (company == null) return;
      final saved = await showFormSheet<bool>(
          context, (_) => AppointmentSheet(company: company, appointment: a, patient: patient));
      if (saved == true) onChanged();
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-appointment',
        onPressed: open,
        icon: const Icon(Icons.add),
        label: const Text('Agendar'),
      ),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.event_note, message: 'Nenhuma consulta registrada.')
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = items[i];
                return ListTile(
                  leading: Icon(Icons.event, color: a.status.color),
                  title: Text(f.dateTime(a.startsAt)),
                  subtitle: Text([if (a.label != null) a.label!, if (a.notes != null) a.notes!].join(' · ')),
                  trailing: StatusChip(a.status.label, a.status.color),
                  onTap: () => open(a),
                );
              },
            ),
    );
  }
}

class _FinanceTab extends StatelessWidget {
  const _FinanceTab({required this.patient, required this.charges, required this.onChanged});
  final Patient patient;
  final List<Charge> charges;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    double sum(bool Function(Charge) t, double Function(Charge) v) => charges.where(t).fold(0, (a, c) => a + v(c));
    final open = sum((c) => c.status == ChargeStatus.open && !c.isOverdue, (c) => c.remaining);
    final overdue = sum((c) => c.isOverdue, (c) => c.remaining);
    final paid = sum((c) => c.status != ChargeStatus.canceled, (c) => c.paidAmount);
    final error = Theme.of(context).colorScheme.error;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-charge',
        onPressed: () async {
          final saved = await showFormSheet<bool>(context, (_) => NewChargeSheet(patientId: patient.id));
          if (saved == true) onChanged();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova cobrança'),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: SummaryTile(label: 'A vencer', value: f.money(open))),
            const SizedBox(width: 8),
            Expanded(child: SummaryTile(label: 'Vencido', value: f.money(overdue), color: error)),
            const SizedBox(width: 8),
            Expanded(child: SummaryTile(label: 'Pago', value: f.money(paid), color: Colors.green.shade700)),
          ]),
        ),
        if (charges.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, message: 'Nenhuma cobrança.')
        else
          for (final c in charges) ...[
            ChargeTile(
              charge: c,
              onTap: () async {
                if (await showChargeActions(context, c)) onChanged();
              },
            ),
            const Divider(height: 1),
          ],
      ]),
    );
  }
}

/// Pasta do paciente: boletos e documentos que ele vê e baixa no app.
class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.patient, required this.files, required this.charges, required this.onChanged});
  final Patient patient;
  final List<PatientFile> files;
  final List<Charge> charges;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-file',
        onPressed: () async {
          final saved = await showFormSheet<bool>(
            context,
            (_) => UploadPatientFileSheet(companyId: patient.companyId, patientId: patient.id, charges: charges),
          );
          if (saved == true) onChanged();
        },
        icon: const Icon(Icons.attach_file),
        label: const Text('Anexar arquivo'),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            patient.hasAccess
                ? 'O paciente vê e baixa estes arquivos na área dele do app.'
                : 'O paciente ainda não tem acesso ao app. Crie o acesso na aba Dados para ele ver estes arquivos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (files.isEmpty)
          const EmptyState(icon: Icons.folder_open_outlined, message: 'Nenhum boleto ou documento na pasta.')
        else
          for (final file in files) ...[
            PatientFileTile(
              file: file,
              onDelete: () async {
                if (await deletePatientFile(context, file)) onChanged();
              },
            ),
            const Divider(height: 1),
          ],
      ]),
    );
  }
}
