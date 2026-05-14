class ClientModel {
  final String id;
  final String name;

  final String? phone;
  final String? cpf;
  final String? rg;

  final String? addressStreet;
  final String? addressNumber;
  final String? neighborhood;
  final String? city;

  final String? guardianName;
  final String? guardianCpf;
  final DateTime? birthDate;

  final String? notes;

  ClientModel({
    required this.id,
    required this.name,
    this.phone,
    this.cpf,
    this.rg,
    this.birthDate,
    this.addressStreet,
    this.addressNumber,
    this.neighborhood,
    this.city,
    this.guardianName,
    this.guardianCpf,
    this.notes,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'],
      name: map['name'] ?? '',

      phone: map['phone'],
      cpf: map['cpf'],
      rg: map['rg'],

      addressStreet: map['street'],
      addressNumber: map['number'],
      neighborhood: map['neighborhood'],
      city: map['city'],

      guardianName: map['guardian_name'],
      guardianCpf: map['guardian_cpf'],
      birthDate: map['birth_date'] != null ? DateTime.parse(map['birth_date'] as String) : null,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,

      'phone': phone,
      'cpf': cpf,
      'rg': rg,
      'birth_date': birthDate?.toIso8601String(),

      'street': addressStreet,
      'number': addressNumber,
      'neighborhood': neighborhood,
      'city': city,

      'guardian_name': guardianName,
      'guardian_cpf': guardianCpf,

      'notes': notes,
    };
  }
}