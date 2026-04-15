import 'package:flutter/material.dart';

import '../../data/scheduling_repository.dart';
import '../../models/appointment_label_model.dart';
import '../../models/appointment_model.dart';
import '../../models/clinic_day_model.dart';

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

  late DateTime _selectedClinicDate;
  late String _selectedTimeSlot;
  String _selectedStatus = 'Agendado';
  String? _selectedLabelId;

  bool _saving = false;

  List<AppointmentLabelModel> _labels = [];
  List<String> _availableSlots = [];

  final List<String> _statuses = const [
    'Agendado',
    'Em Espera',
    'Atendido',
    'Faltou',
  ];

  bool get _isEditing => widget.initialAppointment != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAppointment;

    _selectedClinicDate = initial?.clinicDate ?? widget.selectedDate;
    _selectedTimeSlot = initial?.timeSlot ?? widget.initialTime;
    _selectedStatus = initial?.status ?? 'Agendado';
    _selectedLabelId = initial?.labelId;
    _notesController.text = initial?.notes ?? '';
    _patientIdController.text = initial?.patientId ?? '';

    _loadSupportData();
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _notesController.dispose();
    super.dispose();
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
    try {
      final labels = await widget.repository.getLabels();
      final appointments =
          await widget.repository.getAppointmentsByDate(_selectedClinicDate);

      final occupied = appointments
          .where((a) => a.id != widget.initialAppointment?.id)
          .map((a) => a.timeSlot)
          .toSet();

      final available = _buildTimeSlots()
          .where((slot) => !occupied.contains(slot) || slot == _selectedTimeSlot)
          .toList();

      if (!mounted) return;

      setState(() {
        _labels = labels;
        _availableSlots = available;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados do formulário: $e')),
      );
    }
  }

  Future<void> _pickClinicDay() async {
    final allowedDates =
        widget.clinicDays.map((e) => _dateOnly(e.clinicDate)).toSet();

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

    if (!_availableSlots.contains(_selectedTimeSlot) &&
        _availableSlots.isNotEmpty) {
      setState(() {
        _selectedTimeSlot = _availableSlots.first;
      });
    }
  }

  Future<AppointmentLabelModel?> _showCreateLabelDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<AppointmentLabelModel>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Nova etiqueta'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nome da etiqueta',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o nome da etiqueta';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final label = await widget.repository.createLabel(
                    controller.text.trim(),
                  );

                  if (!mounted) return;
                  Navigator.pop(context, label);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao criar etiqueta: $e')),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _onLabelChanged(String? value) async {
    if (value == '__new__') {
      final newLabel = await _showCreateLabelDialog();
      if (newLabel == null) return;

      await _loadSupportData();

      if (!mounted) return;
      setState(() {
        _selectedLabelId = newLabel.id;
      });
      return;
    }

    setState(() {
      _selectedLabelId = value;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há horários disponíveis para este dia.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (!_isEditing) {
        await widget.repository.createAppointment(
          patientId: _patientIdController.text.trim(),
          clinicDate: _selectedClinicDate,
          timeSlot: _selectedTimeSlot,
          status: 'Agendado',
          labelId: _selectedLabelId,
          notes: _notesController.text.trim(),
        );
      } else {
        await widget.repository.updateAppointment(
          appointmentId: widget.initialAppointment!.id,
          patientId: _patientIdController.text.trim(),
          clinicDate: _selectedClinicDate,
          timeSlot: _selectedTimeSlot,
          status: _selectedStatus,
          labelId: _selectedLabelId,
          notes: _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Editar agendamento' : 'Novo agendamento',
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
                  subtitle: Text(_formatDate(_selectedClinicDate)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickClinicDay,
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  initialValue: _selectedTimeSlot,
                  items: _availableSlots
                      .map(
                        (slot) => DropdownMenuItem<String>(
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

                if (_isEditing) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    items: _statuses
                        .map(
                          (status) => DropdownMenuItem<String>(
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
                ],

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
                    const DropdownMenuItem<String?>(
                      value: '__new__',
                      child: Text('+ Adicionar nova etiqueta'),
                    ),
                  ],
                  onChanged: _saving ? null : _onLabelChanged,
                  decoration: const InputDecoration(
                    labelText: 'Etiquetas cadastradas',
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

                const SizedBox(height: 24),

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