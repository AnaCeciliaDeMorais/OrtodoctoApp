class CashEntryModel {
  final String id;
  final String status;
  final double value;
  final String? observation;
  final String? paymentMethod;
  final DateTime createdAt;

  CashEntryModel({
    required this.id,
    required this.status,
    required this.value,
    this.observation,
    this.paymentMethod,
    required this.createdAt,
  });

  factory CashEntryModel.fromMap(Map<String, dynamic> map) {
    return CashEntryModel(
      id: map['id'] as String,
      status: (map['status'] as String?) ?? 'paid',
      value: (map['value'] as num).toDouble(),
      observation: map['observation'] as String?,
      paymentMethod: map['payment_method'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}