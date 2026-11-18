import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/formatters.dart' as f;
import '../../shared/models/models.dart';
import 'reports_repository.dart';

Future<void> exportReportsPdf({
  required ReportData data,
  required String companyLabel,
  required String period,
  required bool allCompanies,
}) async {
  final doc = pw.Document();
  final h = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9);
  const c = pw.TextStyle(fontSize: 9);
  const headerDecoration = pw.BoxDecoration(color: PdfColors.grey300);

  pw.Widget title(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) => rows.isEmpty
      ? pw.Text('Sem dados no período.', style: c)
      : pw.TableHelper.fromTextArray(
          headers: headers, data: rows, headerStyle: h, cellStyle: c, headerDecoration: headerDecoration);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Ortodoctor — Relatório gerencial', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('$companyLabel · $period'),
      pw.Text('Gerado em ${f.dateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
    ]),
    build: (_) => [
      title('Faturamento por mês'),
      table([
        'Mês',
        if (allCompanies) 'Empresa',
        'Entradas',
        'Saídas',
        'Saldo',
      ], [
        for (final r in data.revenue)
          [
            f.monthYear(r.month),
            if (allCompanies) r.companyName,
            f.money(r.totalIn),
            f.money(r.totalOut),
            f.money(r.balance),
          ],
      ]),
      title('Inadimplência (cobranças vencidas em aberto)'),
      table([
        'Cliente',
        if (allCompanies) 'Empresa',
        'Descrição',
        'Vencimento',
        'Dias',
        'Valor',
      ], [
        for (final r in data.overdue)
          [
            r.patientName,
            if (allCompanies) r.companyName,
            r.description,
            f.date(r.dueDate),
            '${r.daysLate}',
            f.money(r.amount),
          ],
      ]),
      title('Atendimentos no período'),
      table(['Empresa', 'Situação', 'Quantidade'], [
        for (final r in data.appointments)
          [r.companyName, AppointmentStatus.parse(r.status).label, '${r.total}'],
      ]),
      title('Caixa por funcionário'),
      table([
        'Funcionário',
        if (allCompanies) 'Empresa',
        'Entradas',
        'Saídas',
        'Saldo',
        'Receb.',
        'Aprov. 2 etapas',
        'Aguardando',
      ], [
        for (final r in data.staffCash)
          [
            r.staffName,
            if (allCompanies) r.companyName,
            f.money(r.totalIn),
            f.money(r.totalOut),
            f.money(r.balance),
            '${r.received}',
            '${r.twoStep}',
            '${r.pending}',
          ],
      ]),
    ],
  ));

  await Printing.sharePdf(bytes: await doc.save(), filename: 'relatorio-ortodoctor.pdf');
}
