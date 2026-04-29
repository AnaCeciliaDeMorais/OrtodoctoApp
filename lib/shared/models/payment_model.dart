class PaymentModel {
  final String id;
  final double value;
  final String? status; // 'paid', 'pending', 'cancelled'
  final String? observation;
  final String? paymentMethod; // 'pix', 'card', 'cash', 'bank_slip'
  final String createdBy;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.value,
    this.status,
    this.observation,
    this.paymentMethod,
    required this.createdBy,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String,
      value: map['value'] != null ? (map['value'] as num).toDouble() : 0.0,
      status: map['status'] as String?,
      observation: map['observation'] as String?,
      paymentMethod: map['payment_method'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'value': value,
      'status': status,
      'observation': observation,
      'payment_method': paymentMethod,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
