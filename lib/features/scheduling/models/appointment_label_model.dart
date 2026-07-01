class AppointmentLabelModel {
  final String id;
  final String name;
  final DateTime? createdAt;

  const AppointmentLabelModel({
    required this.id,
    required this.name,
    this.createdAt,
  });

  factory AppointmentLabelModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return AppointmentLabelModel(
      id: map['id'],
      name: map['name'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }
}
