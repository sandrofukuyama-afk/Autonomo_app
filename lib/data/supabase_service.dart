import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._private();

  static final SupabaseService instance = SupabaseService._private();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> addEntry(Map<String, dynamic> data) async {
    await _client.from('entries').insert(data);
  }

  Future<List<dynamic>> getEntries() async {
    final response = await _client
        .from('entries')
        .select()
        .order('date', ascending: false);

    return response;
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    await _client.from('expenses').insert(data);
  }

  Future<List<dynamic>> getExpenses() async {
    final response = await _client
        .from('expenses')
        .select()
        .order('date', ascending: false);

    return response;
  }

  Future<String> uploadReceipt(Uint8List fileBytes, String fileName) async {
    await _client.storage.from('receipts').uploadBinary(
      fileName,
      fileBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final String publicUrl =
        _client.storage.from('receipts').getPublicUrl(fileName);

    return publicUrl;
  }
}
