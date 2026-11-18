import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ortodoctor/core/formatters.dart' as f;
import 'package:ortodoctor/core/validators.dart';
import 'package:ortodoctor/features/schedule/schedule_repository.dart';
import 'package:ortodoctor/shared/models/models.dart';

Company _company({int slot = 30, String open = '08:00', String close = '12:00'}) => Company(
      id: 'c',
      ownerId: 'o',
      name: 'Clínica',
      openingTime: open,
      closingTime: close,
      slotMinutes: slot,
    );

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Senha (RN.7)', () {
    test('exige 8 caracteres, número e caractere especial', () {
      expect(Validators.password('abc'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('abcdefg1'), isNotNull);
      expect(Validators.password('abcdef1!'), isNull);
    });
  });

  group('CPF', () {
    test('valida dígitos verificadores', () {
      expect(Validators.isValidCpf('52998224725'), isTrue);
      expect(Validators.isValidCpf('52998224724'), isFalse);
      expect(Validators.isValidCpf('11111111111'), isFalse);
      expect(Validators.cpfOptional(''), isNull);
      expect(Validators.cpfOptional('529.982.247-25'), isNull);
    });
  });

  group('Dinheiro', () {
    test('lê valores no formato brasileiro', () {
      expect(f.parseMoney('1.234,56'), 1234.56);
      expect(f.parseMoney('R\$ 99,90'), 99.90);
      expect(f.parseMoney('150'), 150);
      expect(f.parseMoney('150.5'), 150.5);
      expect(f.parseMoney(''), isNull);
    });
    test('formata em reais', () {
      expect(f.money(1234.5).replaceAll(' ', ' '), 'R\$ 1.234,50');
    });
  });

  group('Agenda', () {
    test('gera horários no intervalo da empresa', () {
      final slots = slotsFor(DateTime(2026, 11, 3), _company(), null);
      expect(slots.length, 8);
      expect(f.time(slots.first), '08:00');
      expect(f.time(slots.last), '11:30');
    });

    test('respeita o horário e a pausa do dia cadastrado', () {
      final day = ClinicDay(
        id: 'd',
        companyId: 'c',
        day: DateTime(2026, 11, 3),
        startTime: '09:00',
        endTime: '14:00',
        breakStart: '12:00',
        breakEnd: '13:00',
      );
      final times = slotsFor(DateTime(2026, 11, 3), _company(slot: 60), day).map(f.time).toList();
      expect(times, ['09:00', '10:00', '11:00', '13:00']);
    });
  });

  group('Produtos', () {
    Product p({bool promo = true, double? promoPrice = 80, DateTime? until, bool featured = false}) => Product(
          id: 'p',
          companyId: 'c',
          name: 'X',
          price: 100,
          promoPrice: promoPrice,
          isPromotion: promo,
          promoUntil: until,
          featured: featured,
        );

    test('promoção vencida deixa de valer', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(p(until: yesterday).onPromotion, isFalse);
      expect(p(until: yesterday).currentPrice, 100);
      expect(p().onPromotion, isTrue);
      expect(p().currentPrice, 80);
      expect(p().discountPercent, 20);
    });

    test('vitrine: fixados, depois promoções, depois o resto', () {
      final a = Product(id: '1', companyId: 'c', name: 'A');
      final b = Product(id: '2', companyId: 'c', name: 'B', isPromotion: true, promoPrice: 1, price: 2);
      final c = Product(id: '3', companyId: 'c', name: 'C', featured: true);
      final list = [a, b, c]..sort(Product.showcaseOrder);
      expect(list.map((e) => e.name), ['C', 'B', 'A']);
    });
  });

  group('Cobranças', () {
    Charge charge({required DateTime due, String status = 'open', String? received, String? approved}) =>
        Charge.fromMap({
          'id': 'x',
          'company_id': 'c',
          'patient_id': 'p',
          'description': 'Parcela',
          'amount': 100,
          'due_date': f.isoDate(due),
          'status': status,
          'received_by': received,
          'approved_by': approved,
        });

    test('vencida só se em aberto e antes de hoje', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(charge(due: yesterday).isOverdue, isTrue);
      expect(charge(due: DateTime.now()).isOverdue, isFalse);
      expect(charge(due: yesterday, status: 'paid').isOverdue, isFalse);
    });

    test('aprovação em duas etapas (RN.8)', () {
      final d = DateTime.now();
      expect(charge(due: d, status: 'paid', received: 'beta').pendingApproval, isTrue);
      expect(charge(due: d, status: 'paid', received: 'beta', approved: 'alfa').twoStepApproved, isTrue);
      expect(charge(due: d, status: 'paid', received: 'alfa', approved: 'alfa').twoStepApproved, isFalse);
    });
  });
}
