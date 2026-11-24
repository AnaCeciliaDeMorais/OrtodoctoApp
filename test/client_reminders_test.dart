import 'package:flutter_test/flutter_test.dart';
import 'package:ortodoctor/features/client/client_reminders.dart';
import 'package:ortodoctor/shared/models/models.dart';

Appointment ap(String id, DateTime at, AppointmentStatus s) =>
    Appointment(id: id, companyId: 'c', patientId: 'p', startsAt: at, status: s);

void main() {
  test('6 meses sem estourar o mês', () {
    expect(addMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    expect(addMonths(DateTime(2026, 5, 18), 6), DateTime(2026, 11, 18));
  });

  test('retorno de prevenção usa a última consulta atendida', () {
    final now = DateTime.now();
    final items = [
      ap('a', now.subtract(const Duration(days: 400)), AppointmentStatus.done),
      ap('b', now.subtract(const Duration(days: 200)), AppointmentStatus.done),
      ap('c', now.subtract(const Duration(days: 10)), AppointmentStatus.canceled),
    ];
    final p = preventionReturn(items)!;
    expect(p.lastVisit.day, now.subtract(const Duration(days: 200)).day);
    expect(p.isDue, isTrue);
    expect(p.scheduled, isFalse);
    final withNext = [...items, ap('d', now.add(const Duration(days: 3)), AppointmentStatus.scheduled)];
    expect(preventionReturn(withNext)!.scheduled, isTrue);
    expect(preventionReturn([items[2]]), isNull);
  });

  test('consulta dentro de 1 hora', () {
    final now = DateTime(2026, 11, 18, 14, 0);
    final items = [
      ap('x', DateTime(2026, 11, 18, 14, 45), AppointmentStatus.confirmed),
      ap('y', DateTime(2026, 11, 18, 15, 30), AppointmentStatus.scheduled),
      ap('z', DateTime(2026, 11, 18, 14, 30), AppointmentStatus.canceled),
    ];
    expect(startingWithinAnHour(items, now).map((a) => a.id), ['x']);
  });

  test('aniversário', () {
    final p = Patient(id: '1', companyId: 'c', fullName: 'Ana', birthDate: DateTime(1990, 11, 18));
    final q = Patient(id: '2', companyId: 'c', fullName: 'Bia', birthDate: DateTime(2000, 2, 29));
    expect(birthdayToday([p, q], DateTime(2026, 11, 18)).map((e) => e.fullName), ['Ana']);
    expect(birthdayToday([p, q], DateTime(2027, 2, 28)).map((e) => e.fullName), ['Bia']);
    expect(birthdayToday([p, q], DateTime(2028, 2, 28)), isEmpty);
  });
}
