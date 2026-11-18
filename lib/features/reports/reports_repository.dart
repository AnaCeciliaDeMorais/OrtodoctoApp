import '../../core/formatters.dart';
import '../../core/supabase.dart';

class RevenueRow {
  RevenueRow(this.companyName, this.month, this.totalIn, this.totalOut, this.balance);
  final String companyName;
  final DateTime month;
  final double totalIn;
  final double totalOut;
  final double balance;
}

class OverdueRow {
  OverdueRow(this.companyName, this.patientName, this.phone, this.description, this.dueDate, this.amount, this.daysLate);
  final String companyName;
  final String patientName;
  final String? phone;
  final String description;
  final DateTime dueDate;
  final double amount;
  final int daysLate;
}

class AppointmentsRow {
  AppointmentsRow(this.companyName, this.status, this.total);
  final String companyName;
  final String status;
  final int total;
}

class StaffCashRow {
  StaffCashRow(this.companyName, this.staffName, this.totalIn, this.totalOut, this.balance, this.received,
      this.twoStep, this.pending);
  final String companyName;
  final String staffName;
  final double totalIn;
  final double totalOut;
  final double balance;
  final int received;
  final int twoStep;
  final int pending;
}

class ReportData {
  ReportData(this.revenue, this.overdue, this.appointments, this.staffCash);
  final List<RevenueRow> revenue;
  final List<OverdueRow> overdue;
  final List<AppointmentsRow> appointments;
  final List<StaffCashRow> staffCash;
}

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _i(dynamic v) => v == null ? 0 : (v as num).toInt();

/// Relatórios do chefe (funções report_* no banco). [companyId] null = todas.
class ReportsRepository {
  Future<ReportData> load({String? companyId, required DateTime from, required DateTime to}) async {
    final params = {'p_company': companyId, 'p_from': isoDate(from), 'p_to': isoDate(to)};
    final r = await Future.wait([
      sb.rpc('report_revenue_by_month', params: params),
      sb.rpc('report_overdue', params: {'p_company': companyId, 'p_ref': isoDate(DateTime.now())}),
      sb.rpc('report_appointments', params: params),
      sb.rpc('report_cash_by_staff', params: params),
    ]);
    List<Map<String, dynamic>> rows(dynamic v) => (v as List).cast<Map<String, dynamic>>();
    return ReportData(
      [
        for (final m in rows(r[0]))
          RevenueRow(m['company_name'] as String, DateTime.parse(m['month'] as String), _d(m['total_in']),
              _d(m['total_out']), _d(m['balance'])),
      ],
      [
        for (final m in rows(r[1]))
          OverdueRow(m['company_name'] as String, m['patient_name'] as String, m['patient_phone'] as String?,
              m['description'] as String, DateTime.parse(m['due_date'] as String), _d(m['amount']), _i(m['days_late'])),
      ],
      [
        for (final m in rows(r[2]))
          AppointmentsRow(m['company_name'] as String, m['status'] as String, _i(m['total'])),
      ],
      [
        for (final m in rows(r[3]))
          StaffCashRow(m['company_name'] as String, m['staff_name'] as String, _d(m['total_in']),
              _d(m['total_out']), _d(m['balance']), _i(m['received_count']), _i(m['approved_two_step']),
              _i(m['pending_approval'])),
      ],
    );
  }
}
