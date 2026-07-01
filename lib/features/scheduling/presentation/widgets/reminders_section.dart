import 'package:flutter/material.dart';
import '../../models/appointment_reminder_model.dart';

class RemindersSection extends StatelessWidget {
  final VoidCallback onAddReminder;
  final List<AppointmentReminderModel> reminders;
  final ValueChanged<String>? onDeleteReminder;

  const RemindersSection({
    super.key,
    required this.onAddReminder,
    required this.reminders,
    this.onDeleteReminder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onAddReminder,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar lembrete'),
            ),
          ),
        ),
        Expanded(
          child: reminders.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Nenhum lembrete encontrado.'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return _ReminderCard(
                      dateText:
                          '${reminder.showOnDate.day.toString().padLeft(2, '0')} ${_monthName(reminder.showOnDate.month)} ${reminder.showOnDate.year}',
                      description: reminder.reminderText,
                      onDelete: onDeleteReminder == null
                          ? null
                          : () => onDeleteReminder!(reminder.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month];
  }
}

class _ReminderCard extends StatelessWidget {
  final String dateText;
  final String description;
  final VoidCallback? onDelete;

  const _ReminderCard({
    required this.dateText,
    required this.description,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(description),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete' && onDelete != null) {
                onDelete!();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
    );
  }
}
