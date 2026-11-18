import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ortodoctor/features/reports/sales_report.dart';

Map<String, dynamic> _row({
  String kind = 'in',
  String day = '2026-11-05',
  String desc = 'Aparelho',
  String? patient,
  String? guardian,
  String? cpf,
  String? method,
  int inst = 1,
  String? due,
  num interest = 0,
  required num amount,
}) =>
    {
      'company_name': 'Clínica Centro',
      'kind': kind,
      'occurred_on': day,
      'description': desc,
      'patient_name': patient,
      'guardian_name': guardian,
      'cpf_shown': cpf,
      'is_minor': guardian != null,
      'payment_method': method,
      'installments': inst,
      'due_date': due,
      'interest': interest,
      'amount': amount,
      'staff_name': 'Beta',
    };

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final data = SalesReportData([
    SalesRow.fromMap(_row(patient: 'Ana Souza', cpf: '11122233344', method: 'Pix', due: '2026-11-05', amount: 300)),
    SalesRow.fromMap(_row(
        patient: 'Pedro Lima', guardian: 'Maria Lima', cpf: '55566677788', method: 'Cartão de crédito',
        inst: 3, due: '2026-11-01', amount: 700)),
    SalesRow.fromMap(_row(patient: 'Pedro Lima', guardian: 'Maria Lima', cpf: '55566677788', method: 'Boleto',
        due: '2026-10-10', interest: 12.5, amount: 212.5)),
    SalesRow.fromMap(_row(desc: 'Venda avulsa', method: 'Dinheiro', amount: 50)),
    SalesRow.fromMap(_row(kind: 'out', desc: 'Material de limpeza', method: 'Dinheiro', amount: 80)),
    SalesRow.fromMap(_row(kind: 'out', desc: 'Aluguel', method: 'Transferência', amount: 1500)),
  ], 42, 3);

  test('totais por forma de pagamento', () {
    final t = Map.fromEntries(totalsByMethod(data.entries).map((e) => MapEntry(e.$1, e.$2)));
    expect(t.keys.toList(), ['boletos', 'cartão de crédito', 'cartão de débito', 'depósito', 'caixa']);
    expect(t['boletos'], 212.5);
    expect(t['cartão de crédito'], 700);
    expect(t['depósito'], 300); // Pix conta como depósito
    expect(t['caixa'], 50);
    expect(t.values.fold<double>(0, (a, b) => a + b), 1262.5);
  });

  test('gera o .xlsx', () {
    final bytes = buildSalesReportXlsx(
      data: data,
      month: DateTime(2026, 11),
      companyLabel: 'Clínica Centro',
      generatedBy: 'Ana',
      generatedAt: DateTime(2026, 11, 17, 10, 30),
      showCompany: false,
    );
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['XLSX_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('gera o PDF no mesmo modelo', () async {
    final bytes = await buildSalesReportPdf(
      data: data,
      month: DateTime(2026, 11),
      companyLabel: 'Clínica Centro · Todos os caixas',
      generatedBy: 'Ana',
      generatedAt: DateTime(2026, 11, 17, 10, 30),
      showCompany: false,
    );
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
