class TreatmentItemModel {
  final String id;
  final String title;
  final String? description;
  final double? originalPrice;
  final double? promotionalPrice;
  final bool isPromotion;
  final bool isActive;

  TreatmentItemModel({
    required this.id,
    required this.title,
    this.description,
    this.originalPrice,
    this.promotionalPrice,
    required this.isPromotion,
    required this.isActive,
  });

  factory TreatmentItemModel.fromMap(Map<String, dynamic> map) {
    return TreatmentItemModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      originalPrice: map['original_price'] != null
          ? (map['original_price'] as num).toDouble()
          : null,
      promotionalPrice: map['promotional_price'] != null
          ? (map['promotional_price'] as num).toDouble()
          : null,
      isPromotion: (map['is_promotion'] as bool?) ?? false,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}