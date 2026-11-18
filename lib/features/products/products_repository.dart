import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters.dart';
import '../../core/supabase.dart';
import '../../shared/models/models.dart';

class ProductsRepository {
  static const bucket = 'products';

  Future<List<Product>> list(String companyId) async {
    final rows = await sb.from('products').select().eq('company_id', companyId);
    return rows.map(Product.fromMap).toList()..sort(Product.showcaseOrder);
  }

  Future<void> save({
    String? id,
    required String companyId,
    required String name,
    String? description,
    String? category,
    required double price,
    required bool isPromotion,
    double? promoPrice,
    DateTime? promoUntil,
    required bool featured,
    required bool active,
    String? imageUrl,
    String? imagePath,
  }) async {
    final data = {
      'company_id': companyId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'is_promotion': isPromotion,
      'promo_price': isPromotion ? promoPrice : null,
      'promo_until': isPromotion && promoUntil != null ? isoDate(promoUntil) : null,
      'featured': featured,
      'active': active,
      'image_url': imageUrl,
      'image_path': imagePath,
    };
    if (id == null) {
      await sb.from('products').insert(data);
    } else {
      await sb.from('products').update(data).eq('id', id);
    }
  }

  Future<void> delete(Product p) async {
    await sb.from('products').delete().eq('id', p.id);
    if (p.imagePath != null) await removeImage(p.imagePath!);
  }

  /// Envia a foto para o Storage e devolve (caminho, endereço público).
  Future<(String, String)> uploadImage(String companyId, Uint8List bytes, String contentType) async {
    final ext = contentType.contains('png') ? 'png' : (contentType.contains('webp') ? 'webp' : 'jpg');
    final name = '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000000000)}.$ext';
    final path = '$companyId/$name';
    await sb.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return (path, sb.storage.from(bucket).getPublicUrl(path));
  }

  Future<void> removeImage(String path) async {
    try {
      await sb.storage.from(bucket).remove([path]);
    } catch (_) {
      // Imagem órfã no Storage não atrapalha o app.
    }
  }
}
