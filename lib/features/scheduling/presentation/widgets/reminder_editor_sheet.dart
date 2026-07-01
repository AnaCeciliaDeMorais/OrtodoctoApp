import 'package:flutter/material.dart';

import '../../models/appointment_model.dart';

class ReminderEditorSheet extends StatefulWidget {
  final List<AppointmentModel> appointments;

  const ReminderEditorSheet({super.key, required this.appointments});

  @override
  State<ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<ReminderEditorSheet> {
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedReminderDate;
  String? _selectedAppointmentId;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'), // 👈 FORÇA português aqui também
      initialDate: _selectedReminderDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() => _selectedReminderDate = picked);
    }
  }

  void _saveReminder() {
    final reminderText = _notesController.text.trim();
    if (_selectedAppointmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um agendamento para o lembrete'),
        ),
      );
      return;
    }

    if (_selectedReminderDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a data do lembrete')),
      );
      return;
    }

    if (reminderText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição do lembrete')),
      );
      return;
    }

    Navigator.pop(context, {
      'appointmentId': _selectedAppointmentId!,
      'reminderText': reminderText,
      'showOnDate': _selectedReminderDate!,
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'Adicionar lembrete',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.appointments.isEmpty)
                const Text(
                  'Não há agendamentos disponíveis para associar o lembrete.',
                  style: TextStyle(color: Colors.black54),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedAppointmentId,
                  decoration: const InputDecoration(labelText: 'Agendamento'),
                  items: widget.appointments.map((appointment) {
                    final appointmentLabel =
                        '${appointment.patientName ?? 'Paciente'} • ${appointment.timeSlot} • ${_formatDate(appointment.clinicDate)}';
                    return DropdownMenuItem(
                      value: appointment.id,
                      child: Text(appointmentLabel),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAppointmentId = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedReminderDate == null
                              ? 'Selecione a data'
                              : _formatDate(_selectedReminderDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedReminderDate == null
                                ? Colors.grey.shade700
                                : Colors.black,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_month),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.appointments.isEmpty ? null : _saveReminder,
                child: const Text('Salvar lembrete'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
