class ClinicDayModel {
  final String id;
  final DateTime clinicDate;
  final String createdBy;

  ClinicDayModel({
    required this.id,
    required this.clinicDate,
    required this.createdBy,
  });

  factory ClinicDayModel.fromMap(Map<String, dynamic> map) {
    return ClinicDayModel(
      id: map['id'] as String,
      clinicDate: DateTime.parse(map['clinic_date'] as String),
      createdBy: map['created_by'] as String,
    );
  }
}