import 'package:flutter/material.dart';

import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'patients_repository.dart';

/// Cadastro / edição de cliente. Devolve o [Patient] salvo.
class PatientFormSheet extends StatefulWidget {
  const PatientFormSheet({super.key, required this.companyId, this.patient});
  final String companyId;
  final Patient? patient;

  @override
  State<PatientFormSheet> createState() => _PatientFormSheetState();
}

class _PatientFormSheetState extends State<PatientFormSheet> {
  final _form = GlobalKey<FormState>();
  late final p = widget.patient;
  late final _name = TextEditingController(text: p?.fullName);
  late final _cpf = TextEditingController(text: f.cpf(p?.cpf));
  late final _phone = TextEditingController(text: f.phone(p?.phone));
  late final _email = TextEditingController(text: p?.email);
  late final _guardian = TextEditingController(text: p?.guardianName);
  late final _guardianCpf = TextEditingController(text: f.cpf(p?.guardianCpf));
  late final _address = TextEditingController(text: p?.address);
  late final _notes = TextEditingController(text: p?.notes);
  late DateTime? _birth = p?.birthDate;
  late bool _active = p?.active ?? true;
  bool _saving = false;

  bool get _minor {
    if (_birth == null) return false;
    final now = DateTime.now();
    var age = now.year - _birth!.year;
    if (now.month < _birth!.month || (now.month == _birth!.month && now.day < _birth!.day)) age--;
    return age < 18;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    Patient? saved;
    final ok = await runGuarded(context, () async {
      saved = await PatientsRepository().save(
        p?.id,
        Patient(
          id: p?.id ?? '',
          companyId: widget.companyId,
          fullName: _name.text,
          cpf: _cpf.text,
          birthDate: _birth,
          phone: _phone.text,
          email: _email.text,
          guardianName: _guardian.text,
          guardianCpf: _guardianCpf.text,
          address: _address.text,
          notes: _notes.text,
          active: _active,
        ),
      );
    }, success: p == null ? 'Cliente cadastrado.' : 'Dados salvos.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormSheet(
        title: p == null ? 'Novo cliente' : 'Editar cliente',
        saving: _saving,
        onSave: _save,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome completo'),
            validator: Validators.required,
          ),
          TextFormField(
            controller: _cpf,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'CPF'),
            validator: Validators.cpfOptional,
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.cake_outlined),
            label: Text(_birth == null ? 'Data de nascimento' : 'Nascimento: ${f.date(_birth)}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _birth ?? DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                initialEntryMode: DatePickerEntryMode.input,
              );
              if (d != null) setState(() => _birth = d);
            },
          ),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone / WhatsApp'),
          ),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.email(v),
          ),
          if (_minor || _guardian.text.isNotEmpty) ...[
            TextFormField(
              controller: _guardian,
              decoration: InputDecoration(
                labelText: 'Responsável',
                helperText: _minor ? 'Cliente menor de idade' : null,
              ),
            ),
            TextFormField(
              controller: _guardianCpf,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'CPF do responsável'),
              validator: Validators.cpfOptional,
            ),
          ],
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço')),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
          if (p != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cliente ativo'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
        ],
      ),
    );
  }
}
