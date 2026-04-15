import 'package:flutter/material.dart';

class RemindersSection extends StatelessWidget {
  final VoidCallback onAddReminder;

  const RemindersSection({
    super.key,
    required this.onAddReminder,
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: const [
              _ReminderCard(
                dateText: '14 maio, 2026',
                description: 'Conta de água',
              ),
              _ReminderCard(
                dateText: 'Junho, 2026',
                description: 'Retorno Cliente A.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final String dateText;
  final String description;

  const _ReminderCard({
    required this.dateText,
    required this.description,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {},
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Editar'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Excluir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}