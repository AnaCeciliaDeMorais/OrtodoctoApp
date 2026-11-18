import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'companies_repository.dart';

/// Cadastro (cria o login) ou edição de funcionário. Devolve true se salvou.
class StaffFormSheet extends StatefulWidget {
  const StaffFormSheet({super.key, required this.companyId, this.staff});
  final String companyId;
  final Profile? staff;

  @override
  State<StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<StaffFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.staff?.fullName);
  late final _phone = TextEditingController(text: phone(widget.staff?.phone));
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;

  bool get _isNew => widget.staff == null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = CompaniesRepository();
    final ok = await runGuarded(
      context,
      () => _isNew
          ? repo.createStaff(
              companyId: widget.companyId,
              fullName: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
              phone: onlyDigits(_phone.text),
            )
          : repo.updateStaff(widget.staff!.id,
              fullName: _name.text.trim(), phone: onlyDigits(_phone.text)),
      success: _isNew
          ? 'Funcionário criado. Passe o e-mail e a senha para ele entrar.'
          : 'Dados salvos.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormSheet(
        title: _isNew ? 'Novo funcionário' : 'Editar funcionário',
        saving: _saving,
        onSave: _save,
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome completo'),
            validator: Validators.required,
          ),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefone'),
          ),
          if (_isNew) ...[
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail de acesso'),
              validator: Validators.email,
            ),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(
                labelText: 'Senha inicial',
                helperText: 'Mínimo 8 caracteres, 1 número e 1 caractere especial',
              ),
              validator: Validators.password,
            ),
          ],
        ],
      ),
    );
  }
}
