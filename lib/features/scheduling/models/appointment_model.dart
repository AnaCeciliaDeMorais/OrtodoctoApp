import 'package:ortodoctor/features/scheduling/models/appointment_reminder_model.dart';

class AppointmentModel {
  final String id;
  final String patientId;
  final DateTime clinicDate;
  final String timeSlot;
  final String status;
  final String? labelId;
  final String? customLabel;
  final String? notes;
  final bool blocked;
  final String? blockedReason;
  final String? deletedReason;
  final String createdBy;
  final String? updatedBy;

  final String? patientName;
  final List<AppointmentReminderModel> reminders;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.clinicDate,
    required this.timeSlot,
    required this.status,
    this.labelId,
    this.customLabel,
    this.notes,
    required this.blocked,
    this.blockedReason,
    this.deletedReason,
    required this.createdBy,
    this.updatedBy,
    this.patientName,
    this.reminders = const [],
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    final remindersRaw = (map['appointment_reminders'] as List?) ?? [];

    return AppointmentModel(
      id: map['id'] as String,
      patientId: map['patient_id'] as String,
      clinicDate: DateTime.parse(map['clinic_date'] as String),
      timeSlot: map['time_slot'] as String,
      status: (map['status'] as String?) ?? 'Em Espera',
      labelId: map['label_id'] as String?,
      customLabel: map['custom_label'] as String?,
      notes: map['notes'] as String?,
      blocked: (map['blocked'] as bool?) ?? false,
      blockedReason: map['blocked_reason'] as String?,
      deletedReason: map['deleted_reason'] as String?,
      createdBy: map['created_by'] as String,
      updatedBy: map['updated_by'] as String?,
      patientName: map['patients']?['name'] as String?,
      reminders: remindersRaw
          .map((e) => AppointmentReminderModel.fromMap(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.showOnDate.compareTo(b.showOnDate)),
    );
  }
}