import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dateShort = DateFormat('dd/MM', 'pt_BR');
final _time = DateFormat('HH:mm', 'pt_BR');
final _monthYear = DateFormat("MMMM 'de' yyyy", 'pt_BR');
final _weekday = DateFormat('EEE', 'pt_BR');
final _dayLong = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');

String money(num? value) => _money.format(value ?? 0);
String date(DateTime? d) => d == null ? '' : _date.format(d);
String dateShort(DateTime d) => _dateShort.format(d);
String time(DateTime d) => _time.format(d);
String dateTime(DateTime d) => '${date(d)} às ${time(d)}';
String monthYear(DateTime d) => capitalize(_monthYear.format(d));
String weekdayShort(DateTime d) => _weekday.format(d).replaceAll('.', '');
String dayLong(DateTime d) => capitalize(_dayLong.format(d));

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Data no formato do banco (AAAA-MM-DD), sem fuso.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "1.234,56", "1234.56" ou "1234" -> 1234.56
double? parseMoney(String text) {
  var t = text.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}

String moneyInput(num? value) =>
    value == null ? '' : value.toStringAsFixed(2).replaceAll('.', ',');

String onlyDigits(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');

String cpf(String? value) {
  final d = onlyDigits(value);
  if (d.length != 11) return value ?? '';
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

String phone(String? value) {
  final d = onlyDigits(value);
  if (d.length == 11) return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  if (d.length == 10) return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  return value ?? '';
}

/// "08:00:00" -> (8, 0)
({int h, int m}) parseTime(String v) {
  final p = v.split(':');
  return (h: int.parse(p[0]), m: int.parse(p[1]));
}

String timeOfDb(String v) => v.length >= 5 ? v.substring(0, 5) : v;
