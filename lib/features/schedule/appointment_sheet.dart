import 'package:flutter/material.dart';

import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../patients/patient_picker.dart';
import 'schedule_repository.dart';

/// Criar / editar agendamento (UC.4). Devolve true se algo mudou.
class AppointmentSheet extends StatefulWidget {
  const AppointmentSheet({
    super.key,
    required this.company,
    this.appointment,
    this.initialStart,
    this.patient,
  });
  final Company company;
  final Appointment? appointment;
  final DateTime? initialStart;

  /// Cliente já escolhido (quando aberto pela ficha do cliente).
  final Patient? patient;

  @override
  State<AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<AppointmentSheet> {
  final _repo = ScheduleRepository();
  late String? _patientId = widget.appointment?.patientId ?? widget.patient?.id;
  late String? _patientName = widget.appointment?.patientName ?? widget.patient?.fullName;
  late DateTime _start = widget.appointment?.startsAt ?? _defaultStart();
  late int _duration = widget.appointment?.durationMinutes ?? widget.company.slotMinutes;
  late AppointmentStatus _status = widget.appointment?.status ?? AppointmentStatus.scheduled;
  late String? _label = widget.appointment?.label ?? 'Consulta';
  late final _notes = TextEditingController(text: widget.appointment?.notes);
  bool _saving = false;

  bool get _isNew => widget.appointment == null;

  DateTime _defaultStart() {
    if (widget.initialStart == null) {
      // Próximo horário "redondo" a partir de agora.
      final now = DateTime.now();
      final step = widget.company.slotMinutes;
      final minutes = ((now.hour * 60 + now.minute) ~/ step + 1) * step;
      return DateTime(now.year, now.month, now.day).add(Duration(minutes: minutes));
    }
    final s = widget.initialStart!;
    if (s.hour == 0 && s.minute == 0) {
      final open = f.parseTime(widget.company.openingTime);
      return DateTime(s.year, s.month, s.day, open.h, open.m);
    }
    return s;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _start = DateTime(d.year, d.month, d.day, _start.hour, _start.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t != null) setState(() => _start = DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_patientId == null) {
      showSnack(context, 'Escolha o cliente.', error: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => _repo.save(
        id: widget.appointment?.id,
        companyId: widget.company.id,
        patientId: _patientId!,
        startsAt: _start,
        duration: _duration,
        status: _status,
        label: _label,
        notes: _notes.text,
      ),
      success: _isNew ? 'Agendamento criado.' : 'Agendamento salvo.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Excluir agendamento',
        'Para manter o histórico, prefira marcar como "Cancelado". Excluir mesmo assim?',
        ok: 'Excluir', danger: true);
    if (!ok || !mounted) return;
    if (await runGuarded(context, () => _repo.delete(widget.appointment!.id))) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: _isNew ? 'Novo agendamento' : 'Agendamento',
      saving: _saving,
      onSave: _save,
      extraActions: [
        if (!_isNew)
          IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ],
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.person_search),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(_patientName ?? 'Escolher cliente'),
          ),
          onPressed: widget.patient != null
              ? null
              : () async {
                  final p = await pickPatient(context, widget.company.id);
                  if (p != null) {
                    setState(() {
                      _patientId = p.id;
                      _patientName = p.fullName;
                    });
                  }
                },
        ),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(f.date(_start)),
              onPressed: _pickDate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(f.time(_start)),
              onPressed: _pickTime,
            ),
          ),
        ]),
        DropdownButtonFormField<int>(
          initialValue: _duration,
          decoration: const InputDecoration(labelText: 'Duração'),
          items: [
            for (final m in {10, 15, 20, 30, 40, 45, 60, 90, 120, _duration}.toList()..sort())
              DropdownMenuItem(value: m, child: Text('$m min')),
          ],
          onChanged: (v) => setState(() => _duration = v ?? _duration),
        ),
        const Text('Etiqueta'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in {...appointmentLabels, ?_label})
            ChoiceChip(
              label: Text(l),
              selected: _label == l,
              onSelected: (v) => setState(() => _label = v ? l : null),
            ),
        ]),
        const Text('Situação'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in AppointmentStatus.values)
            ChoiceChip(
              avatar: CircleAvatar(backgroundColor: s.color, radius: 6),
              label: Text(s.label),
              selected: _status == s,
              onSelected: (_) => setState(() => _status = s),
            ),
        ]),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Observação'),
        ),
        if (!_isNew && widget.appointment!.patientPhone != null)
          Text('Telefone do cliente: ${f.phone(widget.appointment!.patientPhone)}'),
      ],
    );
  }
}
