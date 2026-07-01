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
  String? _selectedPatientId; 
List<Map<String, dynamic>> _patients = [];
  final TextEditingController _notesController = TextEditingController();

  late DateTime _selectedClinicDate;
  late String _selectedTimeSlot;
  final List<String> _selectedTimeSlots = [];
  String _selectedStatus = 'Agendado';
  String? _selectedLabelId;

  bool _saving = false;

  List<AppointmentLabelModel> _labels = [];
  List<String> _availableSlots = [];

  String _normalizeTime(String time) {
    if (time.length >= 5) {
      return time.substring(0, 5);
    }
    return time;
  }

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
    _selectedTimeSlot = _normalizeTime(initial?.timeSlot ?? widget.initialTime);    _selectedStatus = initial?.status ?? 'Agendado';
    _selectedLabelId = initial?.labelId;
    _notesController.text = initial?.notes ?? '';
    _selectedPatientId = initial?.patientId;
    _selectedTimeSlots.add(_selectedTimeSlot);

    _loadSupportData();
  }

  @override
  void dispose() {
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

    final patients = await widget.repository.getPatients();

    final appointments =
      await widget.repository.getAppointmentsByDate(_selectedClinicDate);

    final appointmentsBySlot = <String, int>{};

    for (final appointment in appointments) {
      final slot = _normalizeTime(appointment.timeSlot);

      if (appointment.id == widget.initialAppointment?.id) {
        continue;
      }

      appointmentsBySlot[slot] = (appointmentsBySlot[slot] ?? 0) + 1;
    }

    final available = _buildTimeSlots()
        .where((slot) {
          final totalInSlot = appointmentsBySlot[slot] ?? 0;

          // permite até 2 pacientes no mesmo horário
          return totalInSlot < 2 || slot == _selectedTimeSlot;
        }) 
        .toList();
    if (!mounted) return;

    if (!available.contains(_selectedTimeSlot) && available.isNotEmpty) {
      _selectedTimeSlot = available.first;  
    }

    setState(() {
      _labels = labels;
      _patients = patients;
      _availableSlots = available;
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Erro ao carregar dados do formulário: $e',
        ),
      ),
    );
  }
}

  Future<void> _pickClinicDay() async {
  final allowedDates =
      widget.clinicDays.map((e) => _dateOnly(e.clinicDate)).toSet();

  final picked = await showDatePicker(
    context: context,
    initialDate: _selectedClinicDate,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    selectableDayPredicate: (day) {
      if (allowedDates.isEmpty) return true;
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
        if (_selectedTimeSlots.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecione pelo menos um horário')),
          );
          return;
        }

        for (final slot in _selectedTimeSlots) {
          await widget.repository.createAppointment(
            patientId: _selectedPatientId!,
            clinicDate: _selectedClinicDate,
            timeSlot: slot,
            labelId: _selectedLabelId,
            notes: _notesController.text.trim(),
          );
        }
      } else {
         await widget.repository.updateAppointment(
            appointmentId: widget.initialAppointment!.id,
            patientId: _selectedPatientId!,
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

  Future<void> _deleteAppointment() async {
  if (widget.initialAppointment == null) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Excluir agendamento'),
        content: const Text('Tem certeza que deseja excluir este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  try {
    await widget.repository.deleteAppointment(
      widget.initialAppointment!.id,
    );

    if (!mounted) return;
     Navigator.pop(context, true);
    } catch (e) {
    if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir: $e')),
      );
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

                Autocomplete<Map<String, dynamic>>(
                  initialValue: TextEditingValue(
                    text: _isEditing
                        ? (_patients.firstWhere(
                            (p) => p['id'] == _selectedPatientId,
                            orElse: () => {'name': ''},
                          )['name'] ?? '')
                        : '',
                  ),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.trim().isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }

                    return _patients.where((patient) {
                      final name = (patient['name'] ?? '').toString().toLowerCase();
                      final search = textEditingValue.text.toLowerCase();
                      return name.contains(search);
                    });
                  },
                  displayStringForOption: (patient) => patient['name'] ?? '',
                  onSelected: (patient) {
                    setState(() {
                      _selectedPatientId = patient['id'];
                    });
                  },
                  fieldViewBuilder: (
                    context,
                    controller,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Paciente',
                        border: OutlineInputBorder(),
                      ),
                      validator: (_) {
                        if (_selectedPatientId == null) {
                          return 'Selecione um paciente';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        setState(() {
                          _selectedPatientId = null;
                        });
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                InkWell(
                  onTap: _pickClinicDay,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dia do atendimento',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                    child: Text(_formatDate(_selectedClinicDate)),
                  ),
                ),

                const SizedBox(height: 8),

                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Horários',
                    border: OutlineInputBorder(),
                  ),
                  child: Column(
                    children: _availableSlots.map((slot) {
                      final selected = _selectedTimeSlots.contains(slot);

                      return CheckboxListTile(
                        value: selected,
                        title: Text(slot),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedTimeSlots.add(slot);
                            } else {
                              _selectedTimeSlots.remove(slot);
                            }

                            if (_selectedTimeSlots.isNotEmpty) {
                              _selectedTimeSlot = _selectedTimeSlots.first;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                if (_isEditing) ...[
                  DropdownButtonFormField<String>(
                    value: _statuses.contains(_selectedStatus) ? _selectedStatus : 'Agendado',
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
                  value: _labels.any((label) => label.id == _selectedLabelId)
                      ? _selectedLabelId
                      : null,
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

                if (_isEditing) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _deleteAppointment,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Excluir agendamento'),
                  ),
                ],

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