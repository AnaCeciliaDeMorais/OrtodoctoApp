import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../patients/charge_widgets.dart';
import '../patients/patients_repository.dart';

/// Chefe: segunda etapa da aprovação financeira (RN.8).
class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final _repo = ChargesRepository();
  final _loader = GlobalKey<AsyncLoaderState<List<Charge>>>();
  String? _companyId;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Aprovações')),
      body: ContentWidth(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<String?>(
              initialValue: _companyId,
              decoration: const InputDecoration(labelText: 'Empresa'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final c in session.companies) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _companyId = v),
            ),
          ),
          Expanded(
            child: AsyncLoader<List<Charge>>(
              key: _loader,
              reloadKey: _companyId,
              load: () => _repo.pendingApproval(_companyId),
              builder: (context, items, reload) {
                if (items.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 60),
                    EmptyState(icon: Icons.verified, message: 'Nenhum pagamento aguardando aprovação.'),
                  ]);
                }
                final total = items.fold<double>(0, (a, c) => a + c.amount);
                return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(child: Text('${items.length} pagamento(s) · ${f.money(total)}')),
                      FilledButton.icon(
                        icon: const Icon(Icons.done_all),
                        label: const Text('Aprovar todos'),
                        onPressed: () async {
                          if (!await confirm(context, 'Aprovar todos',
                              'Aprovar ${items.length} pagamento(s) no total de ${f.money(total)}?')) {
                            return;
                          }
                          if (!context.mounted) return;
                          await runGuarded(context, () async {
                            for (final c in items) {
                              await _repo.approve(c.id);
                            }
                          }, success: 'Pagamentos aprovados.');
                          reload();
                        },
                      ),
                    ]),
                  ),
                  for (final c in items) ...[
                    ChargeTile(
                      charge: c,
                      showPatient: true,
                      onTap: () async {
                        if (await showChargeActions(context, c)) reload();
                      },
                    ),
                    if (_companyId == null && c.companyName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(c.companyName!, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const Divider(height: 1),
                  ],
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
