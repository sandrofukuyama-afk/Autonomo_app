import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {

  static final SupabaseClient client = SupabaseClient(
    'https://dzazwpgjncowkudkdhca.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6YXp3cGdqbmNvd2t1ZGtkaGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MDIyODAsImV4cCI6MjA4ODM3ODI4MH0.mQBxjBlgPQpxb5-QyFNhgitM_WOnWlkEzFStYZPr5Pk',
  );

  static final SupabaseService instance = SupabaseService();

  /// ---------- ENTRADAS ----------

  Future<void> addEntry(Map<String, dynamic> data) async {
    await client.from('entries').insert(data);
  }

  Future<List<dynamic>> getEntries() async {
    final response = await client
        .from('entries')
        .select()
        .order('date', ascending: false);

    return response;
  }

  /// ---------- DESPESAS ----------

  Future<void> addExpense(Map<String, dynamic> data) async {
    await client.from('expenses').insert(data);
  }

  Future<List<dynamic>> getExpenses() async {
    final response = await client
        .from('expenses')
        .select()
        .order('date', ascending: false);

    return response;
  }

}
