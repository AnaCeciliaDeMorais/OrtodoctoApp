import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/formatters.dart' as f;
import '../../core/supabase.dart';
import '../../core/xlsx.dart';

/// Relatório mensal de vendas e gastos (.xlsx), no modelo da Ana:
/// uma linha por recebimento, totais por forma de pagamento, atendimentos
/// e faltas, saídas pelo nome registrado e o total geral.
/// Gerado na tela Caixa. Chefe: uma empresa ou todas, de todos os caixas ou
/// de uma pessoa. Funcionário: só as entradas e saídas do próprio caixa
/// (o banco garante isso).

class SalesRow {
  SalesRow.fromMap(Map<String, dynamic> m)
      : companyName = m['company_name'] as String? ?? '',
        isIn = m['kind'] == 'in',
        occurredOn = DateTime.parse(m['occurred_on'] as String),
        description = m['description'] as String? ?? '',
        patientName = m['patient_name'] as String?,
        guardianName = m['guardian_name'] as String?,
        cpf = m['cpf_shown'] as String?,
        isMinor = m['is_minor'] as bool? ?? false,
        method = m['payment_method'] as String?,
        installments = (m['installments'] as int?) ?? 1,
        dueDate = f.parseDate(m['due_date']),
        interest = _n(m['interest']),
        amount = _n(m['amount']),
        staffName = m['staff_name'] as String?;

  final String companyName;
  final bool isIn;
  final DateTime occurredOn;
  final String description;
  final String? patientName;
  final String? guardianName;
  final String? cpf;
  final bool isMinor;
  final String? method;
  final int installments;
  final DateTime? dueDate;
  final double interest;
  final double amount;
  final String? staffName;

  static double _n(dynamic v) => v == null ? 0 : (v as num).toDouble();

  String get methodLabel {
    final m = (method == null || method!.trim().isEmpty) ? 'Não informada' : method!;
    return installments > 1 ? '$m ${installments}x' : m;
  }
}

class SalesReportData {
  SalesReportData(this.rows, this.attended, this.missed);
  final List<SalesRow> rows;
  final int attended;
  final int missed;

  List<SalesRow> get entries => rows.where((r) => r.isIn).toList();
  List<SalesRow> get exits => rows.where((r) => !r.isIn).toList();
}

/// [companyId] null = todas as empresas do chefe (geral).
/// [staffId] null = todos os caixas (só vale para o chefe).
Future<SalesReportData> loadSalesReport({String? companyId, String? staffId, required DateTime month}) async {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1, 0);
  final params = {'p_company': companyId, 'p_from': f.isoDate(from), 'p_to': f.isoDate(to)};
  final rows = await sb.rpc('report_sales', params: {...params, 'p_staff': staffId}) as List;
  final appts = await sb.rpc('report_sales_appointments', params: params) as List;
  final a = appts.isEmpty ? const <String, dynamic>{} : appts.first as Map<String, dynamic>;
  return SalesReportData(
    [for (final r in rows) SalesRow.fromMap(r as Map<String, dynamic>)],
    (a['attended'] as num?)?.toInt() ?? 0,
    (a['missed'] as num?)?.toInt() ?? 0,
  );
}

/// Linhas do bloco "total entradas", no modelo da Ana. Pix e transferência
/// contam como depósito; caixa é só dinheiro físico. Cartão de débito tem
/// linha própria, separado do crédito (pedido da Ana, 17/11/2026).
const salesBuckets = ['boletos', 'cartão de crédito', 'cartão de débito', 'depósito', 'caixa', 'outras'];

String bucketOf(String? method) {
  final m = (method ?? '').trim().toLowerCase();
  if (m.startsWith('boleto')) return 'boletos';
  if (m.startsWith('cartão de crédito') || m.startsWith('cartao de credito')) return 'cartão de crédito';
  if (m.startsWith('cartão de débito') || m.startsWith('cartao de debito')) return 'cartão de débito';
  if (m.startsWith('depósito') || m.startsWith('deposito') || m == 'pix' || m.startsWith('transfer')) {
    return 'depósito';
  }
  if (m == 'dinheiro') return 'caixa';
  return 'outras';
}

/// Soma das entradas em cada linha do modelo (sempre as quatro, mesmo zeradas).
List<(String, double)> totalsByMethod(List<SalesRow> entries) {
  final sums = {for (final k in salesBuckets) k: 0.0};
  for (final e in entries) {
    final k = bucketOf(e.method);
    sums[k] = sums[k]! + e.amount;
  }
  return [
    for (final k in salesBuckets)
      if (k != 'outras' || sums[k]! > 0) (k == 'outras' ? 'outras / não informada' : k, sums[k]!),
  ];
}

Uint8List buildSalesReportXlsx({
  required SalesReportData data,
  required DateTime month,
  required String companyLabel,
  required String generatedBy,
  required DateTime generatedAt,
  required bool showCompany,
}) {
  // Colunas na ordem do modelo (A a H). No relatório geral do chefe entra
  // a coluna "empresa" no fim.
  final headers = [
    'Nome paciente',
    'Responsável',
    'CPF paciente/\nresponsável',
    'Forma de pagamento',
    'Data de pagamento',
    'vencimento',
    'juros',
    'valor',
    if (showCompany) 'empresa',
  ];
  final lastCol = headers.length - 1;
  final s = XSheet('Relatório de vendas',
      columnWidths: [22, 22, 22, 22, 22, 22, 18, 14, if (showCompany) 22]);

  // Faixa verde: título e mês (com quem gerou e quando, à direita do mês).
  for (var r = 0; r < 2; r++) {
    for (var c = 0; c <= lastCol; c++) {
      s.set(r, c, XCell.empty(r == 0 ? XStyle.title : XStyle.band));
    }
  }
  s.set(0, 0, const XCell.text('Relatório de vendas', XStyle.title));
  s.height(0, 40);
  s.merge(0, 0, lastCol);
  s.set(1, 0, XCell.text(f.monthYear(month), XStyle.band));
  s.merge(1, 0, 2);
  s.set(1, 3, XCell.text('$companyLabel · gerado em ${f.dateTime(generatedAt)} por $generatedBy', XStyle.bandRight));
  s.merge(1, 3, lastCol);

  // Cabeçalho das colunas
  const h = 2;
  for (var c = 0; c <= lastCol; c++) {
    s.set(h, c, XCell.text(headers[c], XStyle.header));
  }
  s.height(h, 32);

  var r = h + 1;
  var stripe = 0;
  // Linha zebrada de ponta a ponta (como no modelo), com células vazias.
  void blankRow() {
    final alt = stripe.isOdd;
    for (var c = 0; c <= lastCol; c++) {
      s.set(r, c, XCell.empty(alt ? XStyle.textAlt : XStyle.text));
    }
  }

  void put(int c, XCell cell) => s.set(r, c, cell);
  XStyle t() => stripe.isOdd ? XStyle.textAlt : XStyle.text;
  XStyle m() => stripe.isOdd ? XStyle.moneyAlt : XStyle.money;
  XStyle d() => stripe.isOdd ? XStyle.dateAlt : XStyle.date;
  void next() {
    r++;
    stripe++;
  }

  // Entradas: uma linha por recebimento
  for (final e in data.entries) {
    blankRow();
    put(0, XCell.text(e.patientName ?? e.description, t()));
    put(1, XCell.text(e.guardianName ?? '', t()));
    put(2, XCell.text(f.cpf(e.cpf), t()));
    put(3, XCell.text(e.methodLabel, t()));
    put(4, XCell.date(e.occurredOn, d()));
    if (e.dueDate != null) put(5, XCell.date(e.dueDate!, d()));
    if (e.interest > 0) put(6, XCell.money(e.interest, m()));
    put(7, XCell.money(e.amount, m()));
    if (showCompany) put(8, XCell.text(e.companyName, t()));
    next();
  }
  if (data.entries.isEmpty) {
    blankRow();
    put(0, XCell.text('Nenhuma entrada no mês.', t()));
    next();
  }
  blankRow();
  next();

  // total entradas (coluna E) | total atendimentos e faltas (coluna G/H)
  blankRow();
  put(4, XCell.text('total entradas', t()));
  put(6, XCell.text('total atendimentos', t()));
  put(7, XCell.number(data.attended, stripe.isOdd ? XStyle.numberAlt : XStyle.numberRow));
  next();
  final totals = totalsByMethod(data.entries);
  for (var i = 0; i < totals.length; i++) {
    final (label, value) = totals[i];
    blankRow();
    put(4, XCell.text(label, t()));
    put(5, XCell.money(value, m()));
    if (i == 0) {
      put(6, XCell.text('faltas', t()));
      put(7, XCell.number(data.missed, stripe.isOdd ? XStyle.numberAlt : XStyle.numberRow));
    }
    next();
  }
  final totalIn = data.entries.fold<double>(0, (a, e) => a + e.amount);
  blankRow();
  put(4, XCell.text('total geral', t()));
  put(5, XCell.money(totalIn, m()));
  next();
  blankRow();
  next();

  // total saídas: nome registrado em cada saída e o total geral
  blankRow();
  put(4, XCell.text('total saídas', t()));
  next();
  for (final e in data.exits) {
    blankRow();
    put(4, XCell.text(e.description, t()));
    put(5, XCell.money(e.amount, m()));
    if (showCompany) put(6, XCell.text(e.companyName, t()));
    next();
  }
  if (data.exits.isEmpty) {
    blankRow();
    put(4, XCell.text('(nenhuma saída no mês)', t()));
    next();
  }
  final totalOut = data.exits.fold<double>(0, (a, e) => a + e.amount);
  blankRow();
  put(4, XCell.text('total geral', t()));
  put(5, XCell.money(totalOut, m()));
  next();

  return s.toBytes();
}

/// PDF com o mesmo layout da planilha (para imprimir ou compartilhar).
Future<Uint8List> buildSalesReportPdf({
  required SalesReportData data,
  required DateTime month,
  required String companyLabel,
  required String generatedBy,
  required DateTime generatedAt,
  required bool showCompany,
}) async {
  const green = PdfColor.fromInt(0xFF0F9D58);
  const zebra = PdfColor.fromInt(0xFFF3F3F3);
  const line = PdfColor.fromInt(0xFFC8C8C8);
  const small = pw.TextStyle(fontSize: 8);
  final headers = [
    'Nome paciente',
    'Responsável',
    'CPF paciente/\nresponsável',
    'Forma de pagamento',
    'Data de pagamento',
    'vencimento',
    'juros',
    'valor',
    if (showCompany) 'empresa',
  ];
  final n = headers.length;
  final rows = <List<String>>[];
  void add([Map<int, String> cells = const {}]) => rows.add([for (var c = 0; c < n; c++) cells[c] ?? '']);

  for (final e in data.entries) {
    add({
      0: e.patientName ?? e.description,
      1: e.guardianName ?? '',
      2: f.cpf(e.cpf),
      3: e.methodLabel,
      4: f.date(e.occurredOn),
      5: f.date(e.dueDate),
      6: e.interest > 0 ? f.money(e.interest) : '',
      7: f.money(e.amount),
      if (showCompany) 8: e.companyName,
    });
  }
  if (data.entries.isEmpty) add({0: 'Nenhuma entrada no mês.'});
  add();
  add({4: 'total entradas', 6: 'total atendimentos', 7: '${data.attended}'});
  final totals = totalsByMethod(data.entries);
  for (var i = 0; i < totals.length; i++) {
    add({4: totals[i].$1, 5: f.money(totals[i].$2), if (i == 0) 6: 'faltas', if (i == 0) 7: '${data.missed}'});
  }
  add({4: 'total geral', 5: f.money(data.entries.fold<double>(0, (a, e) => a + e.amount))});
  add();
  add({4: 'total saídas'});
  for (final e in data.exits) {
    add({4: e.description, 5: f.money(e.amount), if (showCompany) 6: e.companyName});
  }
  if (data.exits.isEmpty) add({4: '(nenhuma saída no mês)'});
  add({4: 'total geral', 5: f.money(data.exits.fold<double>(0, (a, e) => a + e.amount))});

  pw.Widget cell(String t, {bool right = false, pw.TextStyle style = small}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(t, style: style),
      );
  bool isMoney(String t) => t.startsWith('R\$');

  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(20),
    build: (_) => [
      pw.Container(
        color: green,
        padding: const pw.EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Relatório de vendas', style: const pw.TextStyle(fontSize: 20, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(f.monthYear(month),
                style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            pw.Text('$companyLabel · gerado em ${f.dateTime(generatedAt)} por $generatedBy',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
          ]),
        ]),
      ),
      pw.Table(
        border: const pw.TableBorder(verticalInside: pw.BorderSide(color: line, width: 0.5)),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8E8E8)),
            children: [for (final h in headers) cell(h, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))],
          ),
          for (var i = 0; i < rows.length; i++)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: i.isOdd ? zebra : PdfColors.white),
              children: [for (final t in rows[i]) cell(t, right: isMoney(t))],
            ),
        ],
      ),
    ],
  ));
  return doc.save();
}

String _fileName(String companyLabel, DateTime month, String ext) {
  final slug = companyLabel
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâã]'), 'a')
      .replaceAll(RegExp(r'[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp(r'[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return 'relatorio-vendas-${month.year}-${month.month.toString().padLeft(2, '0')}'
      '${slug.isEmpty ? '' : '-$slug'}.$ext';
}

/// Gera o relatório e salva/baixa (.xlsx) ou abre imprimir/compartilhar (PDF).
/// Devolve false se a pessoa cancelou.
Future<bool> exportSalesReport({
  String? companyId,
  String? staffId,
  required String companyLabel,
  required DateTime month,
  required String generatedBy,
  bool pdf = false,
}) async {
  final data = await loadSalesReport(companyId: companyId, staffId: staffId, month: month);
  final now = DateTime.now();
  if (pdf) {
    final bytes = await buildSalesReportPdf(
      data: data,
      month: month,
      companyLabel: companyLabel,
      generatedBy: generatedBy,
      generatedAt: now,
      showCompany: companyId == null,
    );
    return Printing.sharePdf(bytes: bytes, filename: _fileName(companyLabel, month, 'pdf'));
  }
  final bytes = buildSalesReportXlsx(
    data: data,
    month: month,
    companyLabel: companyLabel,
    generatedBy: generatedBy,
    generatedAt: now,
    showCompany: companyId == null,
  );
  final saved = await FilePicker.saveFile(
    fileName: _fileName(companyLabel, month, 'xlsx'),
    bytes: bytes,
    mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    dialogTitle: 'Salvar relatório de vendas',
  );
  // Na web o download começa direto e o retorno é null.
  return saved != null || kIsWeb;
}
