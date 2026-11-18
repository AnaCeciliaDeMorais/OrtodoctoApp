import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'companies_repository.dart';

Future<void> showCompanyForm(BuildContext context, {Company? company}) async {
  final saved = await showFormSheet<Company>(context, (_) => _CompanyForm(company: company));
  if (saved == null || !context.mounted) return;
  final session = SessionScope.read(context);
  await session.refreshCompanies();
  if (company == null) {
    session.selectCompany(session.companies.firstWhere((c) => c.id == saved.id));
  }
}

class _CompanyForm extends StatefulWidget {
  const _CompanyForm({this.company});
  final Company? company;

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.company?.name);
  late final _cnpj = TextEditingController(text: widget.company?.cnpj);
  late final _phone = TextEditingController(text: phone(widget.company?.phone));
  late final _email = TextEditingController(text: widget.company?.email);
  late final _address = TextEditingController(text: widget.company?.address);
  late String _open = widget.company?.openingTime ?? '08:00';
  late String _close = widget.company?.closingTime ?? '18:00';
  late int _slot = widget.company?.slotMinutes ?? 30;
  late int _max = widget.company?.maxPerSlot ?? 2;
  bool _saving = false;

  Future<void> _pickTime(bool opening) async {
    final current = parseTime(opening ? _open : _close);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.h, minute: current.m),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => opening ? _open = v : _close = v);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_close.compareTo(_open) <= 0) {
      showSnack(context, 'O fechamento precisa ser depois da abertura.', error: true);
      return;
    }
    setState(() => _saving = true);
    Company? saved;
    final ok = await runGuarded(context, () async {
      saved = await CompaniesRepository().save(widget.company?.id, {
        'name': _name.text.trim(),
        'cnpj': onlyDigits(_cnpj.text).isEmpty ? null : onlyDigits(_cnpj.text),
        'phone': onlyDigits(_phone.text).isEmpty ? null : onlyDigits(_phone.text),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'opening_time': _open,
        'closing_time': _close,
        'slot_minutes': _slot,
        'max_per_slot': _max,
      });
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormSheet(
        title: widget.company == null ? 'Nova empresa' : 'Editar empresa',
        saving: _saving,
        onSave: _save,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome da empresa'),
            validator: Validators.required,
          ),
          TextFormField(controller: _cnpj, decoration: const InputDecoration(labelText: 'CNPJ (opcional)')),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone'),
          ),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço')),
          const Text('Agenda padrão', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(true),
                child: Text('Abre às $_open'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickTime(false),
                child: Text('Fecha às $_close'),
              ),
            ),
          ]),
          DropdownButtonFormField<int>(
            initialValue: _slot,
            decoration: const InputDecoration(labelText: 'Intervalo entre horários'),
            items: [
              for (final m in [10, 15, 20, 30, 40, 45, 60])
                DropdownMenuItem(value: m, child: Text('$m minutos')),
            ],
            onChanged: (v) => setState(() => _slot = v ?? 30),
          ),
          DropdownButtonFormField<int>(
            initialValue: _max,
            decoration: const InputDecoration(labelText: 'Pacientes por horário'),
            items: [
              for (final m in [1, 2, 3, 4])
                DropdownMenuItem(value: m, child: Text('$m')),
            ],
            onChanged: (v) => setState(() => _max = v ?? 2),
          ),
        ],
      ),
    );
  }
}
