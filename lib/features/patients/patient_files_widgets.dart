import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors.dart';
import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'patients_repository.dart';

/// Abre o arquivo da pasta do paciente (link temporário do Storage).
Future<void> openPatientFile(BuildContext context, PatientFile file) async {
  try {
    final url = await PatientFilesRepository().signedUrl(file);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
  }
}

/// Linha de arquivo (boleto ou documento) usada na ficha e na área do cliente.
class PatientFileTile extends StatelessWidget {
  const PatientFileTile({super.key, required this.file, this.onDelete});
  final PatientFile file;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final lines = [
      if (file.isBoleto) 'Boleto' else 'Documento',
      if (file.dueDate != null) 'vence em ${f.date(file.dueDate)}',
      'enviado em ${f.date(file.createdAt)}',
    ];
    return ListTile(
      leading: Icon(file.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
      title: Text(file.title),
      subtitle: Text(lines.join(' · ')),
      onTap: () => openPatientFile(context, file),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Abrir / baixar',
          icon: const Icon(Icons.download_outlined),
          onPressed: () => openPatientFile(context, file),
        ),
        if (onDelete != null)
          IconButton(tooltip: 'Remover', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ]),
    );
  }
}

/// Pergunta e remove um arquivo da pasta. Devolve true se removeu.
Future<bool> deletePatientFile(BuildContext context, PatientFile file) async {
  if (!await confirm(context, 'Remover arquivo', 'Remover "${file.title}" da pasta do paciente?',
      ok: 'Remover', danger: true)) {
    return false;
  }
  if (!context.mounted) return false;
  return runGuarded(context, () => PatientFilesRepository().delete(file), success: 'Arquivo removido.');
}

/// Formulário para anexar um boleto/documento à pasta do paciente.
/// Se [charge] vier preenchida, o arquivo já fica ligado a ela.
class UploadPatientFileSheet extends StatefulWidget {
  const UploadPatientFileSheet({
    super.key,
    required this.companyId,
    required this.patientId,
    this.charge,
    this.charges = const [],
  });
  final String companyId;
  final String patientId;
  final Charge? charge;

  /// Cobranças do paciente para escolher a qual o boleto pertence (opcional).
  final List<Charge> charges;

  @override
  State<UploadPatientFileSheet> createState() => _UploadPatientFileSheetState();
}

class _UploadPatientFileSheetState extends State<UploadPatientFileSheet> {
  static const _maxBytes = 10 * 1024 * 1024;

  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.charge?.description ?? '');
  late String _kind = 'boleto';
  late String? _chargeId = widget.charge?.id;
  late DateTime? _due = widget.charge?.dueDate;
  String? _fileName;
  Uint8List? _bytes;
  bool _saving = false;

  List<Charge> get _choices => widget.charges.where((c) => c.status != ChargeStatus.canceled).toList();

  Future<void> _pick() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: PatientFilesRepository.allowedExtensions,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytes) {
      showSnack(context, 'Arquivo muito grande (máximo 10 MB).');
      return;
    }
    setState(() {
      _bytes = bytes;
      _fileName = picked.name;
      if (_title.text.trim().isEmpty) _title.text = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_bytes == null) {
      showSnack(context, 'Escolha o arquivo (PDF ou imagem).');
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => PatientFilesRepository().upload(
        companyId: widget.companyId,
        patientId: widget.patientId,
        bytes: _bytes!,
        fileName: _fileName!,
        title: _title.text,
        kind: _kind,
        chargeId: _kind == 'boleto' ? _chargeId : null,
        dueDate: _kind == 'boleto' ? _due : null,
      ),
      success: 'Arquivo anexado. O paciente já pode ver no app.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: FormSheet(
          title: widget.charge == null ? 'Anexar à pasta' : 'Anexar boleto',
          saveLabel: 'Anexar',
          saving: _saving,
          onSave: _save,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(_fileName ?? 'Escolher arquivo (PDF, JPG ou PNG)', overflow: TextOverflow.ellipsis),
              onPressed: _saving ? null : _pick,
            ),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título', hintText: 'Ex.: Boleto parcela 1/10'),
              validator: Validators.required,
            ),
            if (widget.charge == null) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'boleto', label: Text('Boleto'), icon: Icon(Icons.receipt_long_outlined)),
                  ButtonSegment(value: 'documento', label: Text('Documento'), icon: Icon(Icons.description_outlined)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              if (_kind == 'boleto' && _choices.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _chargeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cobrança (opcional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Nenhuma')),
                    for (final c in _choices)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text('${c.description} · ${f.money(c.amount)} · ${f.date(c.dueDate)}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _chargeId = v;
                    final c = _choices.where((c) => c.id == v).firstOrNull;
                    if (c != null) {
                      _due = c.dueDate;
                      if (_title.text.trim().isEmpty) _title.text = c.description;
                    }
                  }),
                ),
            ],
            if (_kind == 'boleto')
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_due == null ? 'Vencimento (opcional)' : 'Vencimento ${f.date(_due)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _due ?? f.dayOnly(DateTime.now()),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _due = d);
                },
              ),
            const Text('O paciente vê e baixa este arquivo na área dele do app.', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
}
