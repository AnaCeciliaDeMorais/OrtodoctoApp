import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ortodoctor/features/patients/charge_widgets.dart';
import 'package:ortodoctor/shared/models/models.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('dar baixa com duas formas e parcial cabe no celular', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final charge = Charge.fromMap({
      'id': 'c1',
      'company_id': 'e1',
      'patient_id': 'p1',
      'description': 'Profilaxia',
      'amount': 250,
      'due_date': '2026-11-17',
      'status': 'open',
      'charge_payments': [
        {'id': 'x', 'method': 'Pix', 'amount': 50, 'paid_on': '2026-11-10', 'installments': 1, 'interest': 0},
      ],
    });
    expect(charge.isPartial, isTrue);
    expect(charge.remaining, 200);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReceivePaymentDialog(charge: charge))));
    expect(find.text('Confirmar'), findsOneWidget);
    await tester.tap(find.text('Outra forma de pagamento'));
    await tester.pumpAndSettle();
    expect(find.text('Parcelas no cartão'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Valor').first, '100');
    await tester.pumpAndSettle();
    expect(find.textContaining('Pagamento parcial'), findsOneWidget);
  });
}
