import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._private();

  static final AuthService instance = AuthService._private();

  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUp({
    required String fullName,
    required String businessName,
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName.trim(),
        'business_name': businessName.trim(),
      },
    );

    final User? user = response.user;
    if (user == null) {
      throw Exception('Não foi possível criar o usuário.');
    }
  }

  Future<String> getCurrentCompanyId() async {
    final User? user = currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final List<dynamic> rows = await _client
        .from('companies')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(1);

    if (rows.isEmpty) {
      throw Exception('Empresa não encontrada para o usuário.');
    }

    return rows.first['id'] as String;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
