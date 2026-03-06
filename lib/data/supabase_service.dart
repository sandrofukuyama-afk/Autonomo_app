import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço responsável por interagir com o banco de dados do Supabase.
class SupabaseService {
  SupabaseService._privateConstructor();

  static final SupabaseService instance = SupabaseService._privateConstructor();

  final SupabaseClient _client = Supabase.instance.client;

  /// Insere um registro de entrada na tabela 'entries'.
  Future<void> addEntry(Map<String, dynamic> entry) async {
    await _client.from('entries').insert(entry);
  }

  /// Busca as entradas ordenadas pela data de criação (mais recentes primeiro).
  Future<List<Map<String, dynamic>>> fetchEntries() async {
    final List data = await _client
        .from('entries')
        .select()
        .order('created_at', ascending: false);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Insere um registro de despesa na tabela 'expenses'.
  Future<void> addExpense(Map<String, dynamic> expense) async {
    await _client.from('expenses').insert(expense);
  }

  /// Busca as despesas ordenadas pela data de criação (mais recentes primeiro).
  Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final List data = await _client
        .from('expenses')
        .select()
        .order('created_at', ascending: false);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
