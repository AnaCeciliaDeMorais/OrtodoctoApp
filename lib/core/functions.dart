import 'errors.dart';
import 'supabase.dart';

/// Chama uma Edge Function do Supabase e devolve o JSON da resposta.
Future<Map<String, dynamic>> callFunction(String name, Map<String, dynamic> body) async {
  final res = await sb.functions.invoke(name, body: body);
  final data = res.data;
  if (data is Map && data['error'] != null) throw AppException(data['error'].toString());
  if (data is Map) return Map<String, dynamic>.from(data);
  return {};
}
