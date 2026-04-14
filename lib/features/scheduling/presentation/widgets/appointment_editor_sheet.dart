import 'package:flutter/material.dart';

import '../../data/scheduling_repository.dart';
import '../../models/appointment_label_model.dart';
import '../../models/appointment_model.dart';
import '../../models/appointment_reminder_model.dart';
import '../../models/clinic_day_model.dart';
import 'reminders_section.dart';

class AppointmentEditorSheet extends StatefulWidget {
  final DateTime selectedDate;
  final String initialTime;
  final AppointmentModel? initialAppointment;
  final List<ClinicDayModel> clinicDays;
  final SchedulingRepository repository;

  const AppointmentEditorSheet({
    super.key,
    required this.selectedDate,
    required this.initialTime,
    required this.clinicDays,
    required this.repository,
    this.initialAppointment,
  });

  @override
  State<AppointmentEditorSheet> createState() => _AppointmentEditorSheetState();
}

class _AppointmentEditorSheetState extends State<AppointmentEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _patientIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customLabelController = TextEditingController();
  final TextEditingController _reminderTextController = TextEditingController();

  late DateTime _selectedClinicDate;
  late String _selectedTimeSlot;
  String _selectedStatus = 'Em Espera';
  String? _selectedLabelId;
  DateTime? _selectedReminderDate;

  bool _saving = false;

  List<AppointmentLabelModel> _labels = [];
  List<AppointmentReminderModel> _reminders = [];
  List<String> _availableSlots = [];

  final List<String> _statuses = [
    'Em Espera',
    'Atendido',
    'Faltou',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAppointment;

    _selectedClinicDate = initial?.clinicDate ?? widget.selectedDate;
    _selectedTimeSlot = initial?.timeSlot ?? widget.initialTime;
    _selectedStatus = initial?.status ?? 'Em Espera';
    _selectedLabelId = initial?.labelId;
    _notesController.text = initial?.notes ?? '';
    _customLabelController.text = initial?.customLabel ?? '';
    _patientIdController.text = initial?.patientId ?? '';
    _reminders = [...(initial?.reminders ?? [])]
      ..sort((a, b) => a.showOnDate.compareTo(b.showOnDate));

    _loadSupportData();
  }

  List<String> _buildTimeSlots() {
    final List<String> slots = [];

    void addRange({
      required int startHour,
      required int startMinute,
      required int endHour,
      required int endMinute,
    }) {
      int current = startHour * 60 + startMinute;
      final int end = endHour * 60 + endMinute;

      while (current <= end) {
        final hour = (current ~/ 60).toString().padLeft(2, '0');
        final minute = (current % 60).toString().padLeft(2, '0');
        slots.add('$hour:$minute');
        current += 15;
      }
    }

    addRange(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0);
    addRange(startHour: 14, startMinute: 0, endHour: 18, endMinute: 30);

    return slots;
  }

  Future<void> _loadSupportData() async {
    final labels = await widget.repository.getLabels();
    final appointments = await widget.repository.getAppointmentsByDate(_selectedClinicDate);

    final occupied = appointments
        .where((a) => a.id != widget.initialAppointment?.id)
        .map((a) => a.timeSlot)
        .toSet();

    final available = _buildTimeSlots()
        .where((slot) => !occupied.contains(slot) || slot == _selectedTimeSlot)
        .toList();

    setState(() {
      _labels = labels;
      _availableSlots = available;
    });
  }

  Future<void> _openReminderSheet() async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const RemindersSection(),
  );
}

  Future<void> _pickClinicDay() async {
    final allowedDates = widget.clinicDays.map((e) => _dateOnly(e.clinicDate)).toSet();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedClinicDate,
      firstDate: widget.clinicDays.isNotEmpty
          ? widget.clinicDays.first.clinicDate
          : DateTime.now(),
      lastDate: widget.clinicDays.isNotEmpty
          ? widget.clinicDays.last.clinicDate
          : DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (day) {
        return allowedDates.contains(_dateOnly(day));
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedClinicDate = picked;
    });

    await _loadSupportData();

    if (!_availableSlots.contains(_selectedTimeSlot) && _availableSlots.isNotEmpty) {
      setState(() {
        _selectedTimeSlot = _availableSlots.first;
      });
    }
  }

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedReminderDate ?? _selectedClinicDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() => _selectedReminderDate = picked);
    }
  }

  void _addReminder() {
    final text = _reminderTextController.text.trim();

    if (text.isEmpty || _selectedReminderDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o texto e a data do lembrete.')),
      );
      return;
    }

    final userId = widget.repository.currentUser!.id;

    setState(() {
      _reminders.add(
        AppointmentReminderModel(
          id: '',
          appointmentId: widget.initialAppointment?.id ?? '',
          reminderText: text,
          showOnDate: _selectedReminderDate!,
          createdBy: userId,
        ),
      );
      _reminders.sort((a, b) => a.showOnDate.compareTo(b.showOnDate));
      _reminderTextController.clear();
      _selectedReminderDate = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (widget.initialAppointment == null) {
        await widget.repository.createAppointment(
          patientId: _patientIdController.text.trim(),
          clinicDate: _selectedClinicDate,
          timeSlot: _selectedTimeSlot,
          status: _selectedStatus,
          labelId: _selectedLabelId,
          customLabel: _customLabelController.text.trim().isEmpty
              ? null
              : _customLabelController.text.trim(),
          notes: _notesController.text.trim(),
          reminders: _reminders,
        );
      } else {
        await widget.repository.updateAppointment(
          appointmentId: widget.initialAppointment!.id,
          patientId: _patientIdController.text.trim(),
          clinicDate: _selectedClinicDate,
          timeSlot: _selectedTimeSlot,
          status: _selectedStatus,
          labelId: _selectedLabelId,
          customLabel: _customLabelController.text.trim().isEmpty
              ? null
              : _customLabelController.text.trim(),
          notes: _notesController.text.trim(),
          reminders: _reminders,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  widget.initialAppointment == null
                      ? 'Novo agendamento'
                      : 'Editar agendamento',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _patientIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID do paciente',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o paciente';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dia do atendimento'),
                  subtitle: Text(
                    '${_selectedClinicDate.day.toString().padLeft(2, '0')}/'
                    '${_selectedClinicDate.month.toString().padLeft(2, '0')}/'
                    '${_selectedClinicDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickClinicDay,
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  initialValue: _selectedTimeSlot,
                  items: _availableSlots
                      .map(
                        (slot) => DropdownMenuItem(
                          value: slot,
                          child: Text(slot),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTimeSlot = value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Horário',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  items: _statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Situação',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String?>(
                  initialValue: _selectedLabelId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem etiqueta'),
                    ),
                    ..._labels.map(
                      (label) => DropdownMenuItem<String?>(
                        value: label.id,
                        child: Text(label.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedLabelId = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta cadastrada',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 8),

                ..._reminders.map(
                  (reminder) => Card(
                    child: ListTile(
                      title: Text(reminder.reminderText),
                      subtitle: Text(
                        '${reminder.showOnDate.day.toString().padLeft(2, '0')}/'
                        '${reminder.showOnDate.month.toString().padLeft(2, '0')}/'
                        '${reminder.showOnDate.year}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _reminders.remove(reminder);
                          });
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando...' : 'Salvar'),
                ),

                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}