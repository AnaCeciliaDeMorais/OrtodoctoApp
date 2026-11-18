import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../patients/charge_widgets.dart';
import '../patients/patient_files_widgets.dart';
import '../patients/patients_repository.dart';

/// Pagamentos do cliente: em aberto, vencidos e pagos, e a pasta com os
/// boletos e documentos que a clínica anexou.
/// O cliente não dá baixa no próprio pagamento (RN.10).
class ClientPaymentsPage extends StatelessWidget {
  const ClientPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final several = SessionScope.of(context).companies.length > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pagamentos')),
      body: ContentWidth(
        child: AsyncLoader<(List<Charge>, List<PatientFile>)>(
          load: () async {
            final r = await Future.wait([ChargesRepository().mine(), PatientFilesRepository().mine()]);
            return (r[0] as List<Charge>, r[1] as List<PatientFile>);
          },
          builder: (context, data, _) {
            final (items, files) = data;
            final open = items.where((c) => c.status == ChargeStatus.open).toList();
            final paid = items.where((c) => c.status == ChargeStatus.paid).toList().reversed.toList();
            final overdueSum = open.where((c) => c.isOverdue).fold<double>(0, (a, c) => a + c.remaining);
            final openSum = open.where((c) => !c.isOverdue).fold<double>(0, (a, c) => a + c.remaining);

            Widget tile(Charge c) => Column(children: [
                  ChargeTile(
                    charge: c,
                    forClient: true,
                    onTap: c.status == ChargeStatus.open && c.hasBoleto ? () => _boleto(context, c) : null,
                  ),
                  if (several && c.companyName != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 6),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(c.companyName!, style: Theme.of(context).textTheme.bodySmall)),
                    ),
                  if (c.status == ChargeStatus.open && c.hasBoleto)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.receipt_outlined),
                          label: const Text('Ver boleto'),
                          onPressed: () => _boleto(context, c),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                ]);

            return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: SummaryTile(label: 'A pagar', value: f.money(openSum))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryTile(
                        label: 'Vencido', value: f.money(overdueSum), color: Theme.of(context).colorScheme.error),
                  ),
                ]),
              ),
              const SectionTitle('Em aberto'),
              if (open.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Nada em aberto.'))
              else
                ...open.map(tile),
              if (paid.isNotEmpty) ...[
                const SectionTitle('Pagos'),
                ...paid.map(tile),
              ],
              const SectionTitle('Boletos e documentos'),
              if (files.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16), child: Text('A clínica ainda não anexou arquivos.'))
              else
                for (final file in files) PatientFileTile(file: file),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _boleto(BuildContext context, Charge c) async {
    if (c.files.length == 1) return openPatientFile(context, c.files.single);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(c.description), subtitle: Text('${f.money(c.amount)} · vence ${f.date(c.dueDate)}')),
          for (final file in c.files) PatientFileTile(file: file),
        ]),
      ),
    );
  }
}
