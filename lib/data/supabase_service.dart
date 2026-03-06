import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  static final SupabaseService instance = SupabaseService();

  /// ---------- ENTRADAS ----------

  Future<void> addEntry(Map<String, dynamic> data) async {
    await client.from('entries').insert(data);
  }

  Future<List<dynamic>> getEntries() async {
    final response =
        await client.from('entries').select().order('date', ascending: false);

    return response;
  }

  /// ---------- DESPESAS ----------

  Future<void> addExpense(Map<String, dynamic> data) async {
    await client.from('expenses').insert(data);
  }

  Future<List<dynamic>> getExpenses() async {
    final response =
        await client.from('expenses').select().order('date', ascending: false);

    return response;
  }

  /// ---------- UPLOAD RECIBO ----------

  Future<String> uploadReceipt(Uint8List fileBytes, String fileName) async {
    final path = 'receipt_${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await client.storage.from('receipts').uploadBinary(path, fileBytes);

    final url = client.storage.from('receipts').getPublicUrl(path);

    return url;
  }
}
