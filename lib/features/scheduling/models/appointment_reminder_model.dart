class AppointmentReminderModel {
  final String id;
  final String appointmentId;
  final String reminderText;
  final DateTime showOnDate;
  final String createdBy;
  final DateTime? createdAt;

  AppointmentReminderModel({
    required this.id,
    required this.appointmentId,
    required this.reminderText,
    required this.showOnDate,
    required this.createdBy,
    this.createdAt,
  });

  factory AppointmentReminderModel.fromMap(Map<String, dynamic> map) {
    return AppointmentReminderModel(
      id: map['id'] as String,
      appointmentId: map['appointment_id'] as String,
      reminderText: map['reminder_text'] as String,
      showOnDate: DateTime.parse(map['show_on_date'] as String),
      createdBy: map['created_by'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'appointment_id': appointmentId,
      'reminder_text': reminderText,
      'show_on_date': showOnDate.toIso8601String().split('T').first,
      'created_by': createdBy,
    };
  }
}