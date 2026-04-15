class ClientModel {
  final String id;
  final String name;
  final String? rg;
  final String? cpf;
  final String? phone;
  final String? addressStreet;
  final String? addressNumber;
  final String? neighborhood;
  final String? city;
  final DateTime? birthDate;
  final String? guardianName;

  ClientModel({
    required this.id,
    required this.name,
    this.rg,
    this.cpf,
    this.phone,
    this.addressStreet,
    this.addressNumber,
    this.neighborhood,
    this.city,
    this.birthDate,
    this.guardianName,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] as String,
      name: map['name'] as String,
      rg: map['rg'] as String?,
      cpf: map['cpf'] as String?,
      phone: map['phone'] as String?,
      addressStreet: map['address_street'] as String?,
      addressNumber: map['address_number'] as String?,
      neighborhood: map['neighborhood'] as String?,
      city: map['city'] as String?,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      guardianName: map['guardian_name'] as String?,
    );
  }
}