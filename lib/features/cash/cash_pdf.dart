import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/formatters.dart' as f;
import '../../shared/models/models.dart';

/// Exporta o caixa do período em PDF (abre imprimir / compartilhar).
Future<void> exportCashPdf({
  required String title,
  required String subtitle,
  required List<CashEntry> entries,
  required bool showCompany,
  required bool showStaff,
}) async {
  final doc = pw.Document();
  final totalIn = entries.where((e) => e.isIn).fold<double>(0, (a, e) => a + e.amount);
  final totalOut = entries.where((e) => !e.isIn).fold<double>(0, (a, e) => a + e.amount);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text(subtitle),
      pw.Text('Gerado em ${f.dateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 12),
    ]),
    build: (_) => [
      pw.Row(children: [
        _box('Entradas', f.money(totalIn)),
        pw.SizedBox(width: 8),
        _box('Saídas', f.money(totalOut)),
        pw.SizedBox(width: 8),
        _box('Saldo', f.money(totalIn - totalOut)),
      ]),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        headers: [
          'Data',
          'Descrição',
          if (showStaff) 'Caixa de',
          if (showCompany) 'Empresa',
          'Forma',
          'Entrada',
          'Saída',
        ],
        data: [
          for (final e in entries)
            [
              f.date(e.occurredOn),
              [e.description, if (e.patientName != null) '(${e.patientName})'].join(' '),
              if (showStaff) e.staffName ?? '',
              if (showCompany) e.companyName ?? '',
              e.paymentMethod ?? '',
              e.isIn ? f.money(e.amount) : '',
              e.isIn ? '' : f.money(e.amount),
            ],
        ],
      ),
    ],
  ));

  await Printing.sharePdf(bytes: await doc.save(), filename: 'caixa.pdf');
}

pw.Widget _box(String label, String value) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ]),
      ),
    );
