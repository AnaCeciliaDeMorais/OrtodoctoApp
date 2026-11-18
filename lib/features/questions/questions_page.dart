import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/supabase.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../home/company_switcher.dart';

class QuestionsRepository {
  Future<List<Question>> list({String? companyId}) async {
    var q = sb.from('questions').select('*, patients(full_name), companies(name)');
    if (companyId != null) q = q.eq('company_id', companyId);
    final rows = await q.order('created_at', ascending: false).limit(300);
    return rows.map(Question.fromMap).toList();
  }

  Future<void> ask(Patient patient, String message) => sb.from('questions').insert({
        'company_id': patient.companyId,
        'patient_id': patient.id,
        'message': message,
      });

  Future<void> answer(String id, String answer) =>
      sb.from('questions').update({'answer': answer}).eq('id', id);

  Future<void> delete(String id) => sb.from('questions').delete().eq('id', id);
}

/// Dúvidas (RF.16): cliente pergunta; funcionário e chefe respondem.
class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  final _repo = QuestionsRepository();
  final _loader = GlobalKey<AsyncLoaderState<List<Question>>>();
  bool _onlyOpen = true;

  Future<void> _ask(Patient patient) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova dúvida'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escreva a sua pergunta para a clínica'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Enviar')),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    if (await runGuarded(context, () => _repo.ask(patient, text), success: 'Pergunta enviada.')) {
      _loader.currentState?.reload();
    }
  }

  Future<void> _answer(Question q) async {
    final controller = TextEditingController(text: q.answer);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(q.patientName ?? 'Responder'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(q.message),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Resposta'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Responder')),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    if (await runGuarded(context, () => _repo.answer(q.id, text), success: 'Resposta enviada.')) {
      _loader.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final manager = session.isManager;
    final myPatient = session.myPatientInCurrent;
    return RequireCompany(
      title: 'Dúvidas',
      child: Scaffold(
        appBar: AppBar(title: CompanyTitle(manager ? 'Dúvidas dos clientes' : 'Tirar dúvidas')),
        floatingActionButton: !manager && myPatient != null
            ? FloatingActionButton.extended(
                onPressed: () => _ask(myPatient),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Perguntar'),
              )
            : null,
        body: ContentWidth(
          child: Column(children: [
            if (manager)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  FilterChip(
                    label: const Text('Só sem resposta'),
                    selected: _onlyOpen,
                    onSelected: (v) => setState(() => _onlyOpen = v),
                  ),
                ]),
              ),
            Expanded(
              child: AsyncLoader<List<Question>>(
                key: _loader,
                load: () => _repo.list(companyId: session.current?.id),
                builder: (context, all, reload) {
                  final items = manager && _onlyOpen ? all.where((q) => !q.answered).toList() : all;
                  if (items.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.forum_outlined,
                        message: manager ? 'Nenhuma dúvida pendente.' : 'Envie sua dúvida e a clínica responde aqui.',
                      ),
                    ]);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final q = items[i];
                      final scheme = Theme.of(context).colorScheme;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: manager ? () => _answer(q) : null,
                          onLongPress: !manager && !q.answered
                              ? () async {
                                  if (await confirm(context, 'Apagar pergunta', 'Apagar esta pergunta?',
                                          ok: 'Apagar', danger: true) &&
                                      context.mounted) {
                                    if (await runGuarded(context, () => _repo.delete(q.id))) reload();
                                  }
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(
                                  child: Text(manager ? (q.patientName ?? '') : 'Você perguntou',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Text(f.dateTime(q.createdAt), style: Theme.of(context).textTheme.bodySmall),
                              ]),
                              const SizedBox(height: 4),
                              Text(q.message),
                              const SizedBox(height: 8),
                              if (q.answered)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Resposta: ${q.answer}',
                                      style: TextStyle(color: scheme.onPrimaryContainer)),
                                )
                              else
                                StatusChip('Aguardando resposta', Colors.orange.shade800),
                            ]),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
