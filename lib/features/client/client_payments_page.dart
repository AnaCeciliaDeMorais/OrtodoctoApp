import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/session.dart';
import '../../core/formatters.dart' as f;
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../patients/charge_widgets.dart';
import '../patients/patients_repository.dart';

/// Pagamentos do cliente: em aberto, vencidos e pagos, com boleto.
/// O cliente não dá baixa no próprio pagamento (RN.10).
class ClientPaymentsPage extends StatelessWidget {
  const ClientPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final several = SessionScope.of(context).companies.length > 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pagamentos')),
      body: ContentWidth(
        child: AsyncLoader<List<Charge>>(
          load: () => ChargesRepository().mine(),
          builder: (context, items, _) {
            final open = items.where((c) => c.status == ChargeStatus.open).toList();
            final paid = items.where((c) => c.status == ChargeStatus.paid).toList().reversed.toList();
            final overdueSum = open.where((c) => c.isOverdue).fold<double>(0, (a, c) => a + c.amount);
            final openSum = open.where((c) => !c.isOverdue).fold<double>(0, (a, c) => a + c.amount);

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
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _boleto(BuildContext context, Charge c) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(c.description), subtitle: Text('${f.money(c.amount)} · vence ${f.date(c.dueDate)}')),
          if (c.boletoUrl != null)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Abrir boleto (PDF)'),
              onTap: () => launchUrl(Uri.parse(c.boletoUrl!), mode: LaunchMode.externalApplication),
            ),
          if (c.invoiceUrl != null)
            ListTile(
              leading: const Icon(Icons.pix),
              title: const Text('Pagar com Pix ou cartão'),
              onTap: () => launchUrl(Uri.parse(c.invoiceUrl!), mode: LaunchMode.externalApplication),
            ),
          if (c.boletoBarcode != null)
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar linha digitável'),
              subtitle: Text(c.boletoBarcode!),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: c.boletoBarcode!));
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) showSnack(context, 'Linha digitável copiada.');
              },
            ),
        ]),
      ),
    );
  }
}
