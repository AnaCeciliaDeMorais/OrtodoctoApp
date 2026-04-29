class ProfileEmployeeModel {
  final String id;
  final String nome;
  final String? telefone;
  final String? profileLevel;
  final String themeMode;

  ProfileEmployeeModel({
    required this.id,
    required this.nome,
    this.telefone,
    this.profileLevel,
    required this.themeMode,
  });

  factory ProfileEmployeeModel.fromMap(Map<String, dynamic> map) {
    return ProfileEmployeeModel(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? '',
      telefone: map['telefone'] as String?,
      profileLevel: map['profile_level'] as String?,
      themeMode: (map['theme_mode'] as String?) ?? 'light',
    );
  }
}