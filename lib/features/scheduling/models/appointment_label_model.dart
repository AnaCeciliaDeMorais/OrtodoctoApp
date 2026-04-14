class AppointmentLabelModel {
  final String id;
  final String name;

  AppointmentLabelModel({
    required this.id,
    required this.name,
  });

  factory AppointmentLabelModel.fromMap(Map<String, dynamic> map) {
    return AppointmentLabelModel(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}