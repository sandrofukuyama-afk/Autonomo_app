import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpResult {
  final bool requiresEmailConfirmation;
  final String message;

  const SignUpResult({
    required this.requiresEmailConfirmation,
    required this.message,
  });
}

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
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password.trim();

    if (cleanEmail.isEmpty) {
      throw Exception('Informe seu e-mail.');
    }

    if (cleanPassword.isEmpty) {
      throw Exception('Informe sua senha.');
    }

    await _client.auth.signInWithPassword(
      email: cleanEmail,
      password: cleanPassword,
    );
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String businessName,
    required String email,
    required String password,
  }) async {
    final String cleanFullName = fullName.trim();
    final String cleanBusinessName = businessName.trim();
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password.trim();

    if (cleanFullName.isEmpty) {
      throw Exception('Informe seu nome.');
    }

    if (cleanBusinessName.isEmpty) {
      throw Exception('Informe o nome do negócio.');
    }

    if (cleanEmail.isEmpty) {
      throw Exception('Informe seu e-mail.');
    }

    if (cleanPassword.isEmpty) {
      throw Exception('Informe sua senha.');
    }

    final AuthResponse response = await _client.auth.signUp(
      email: cleanEmail,
      password: cleanPassword,
      data: {
        'full_name': cleanFullName,
        'business_name': cleanBusinessName,
      },
    );

    final User? user = response.user;
    if (user == null) {
      throw Exception('Não foi possível criar o usuário.');
    }

    final bool requiresEmailConfirmation = response.session == null;

    if (requiresEmailConfirmation) {
      return const SignUpResult(
        requiresEmailConfirmation: true,
        message:
            'Cadastro realizado com sucesso. Verifique seu e-mail para confirmar a conta antes de entrar.',
      );
    }

    return const SignUpResult(
      requiresEmailConfirmation: false,
      message: 'Cadastro realizado com sucesso.',
    );
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
