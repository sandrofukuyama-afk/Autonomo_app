fimport 'package:supabase_flutter/supabase_flutter.dart';

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

  String? _cachedCompanyId;
  String? _cachedCompanyUserId;
  String? _cachedLanguageCode;
  String? _cachedLanguageUserId;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty) {
      throw Exception('Informe seu e-mail.');
    }

    if (cleanPassword.isEmpty) {
      throw Exception('Informe sua senha.');
    }

    _clearCaches();

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
    final cleanFullName = fullName.trim();
    final cleanBusinessName = businessName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    final AuthResponse response = await _client.auth.signUp(
      email: cleanEmail,
      password: cleanPassword,
      data: {
        'full_name': cleanFullName,
        'business_name': cleanBusinessName,
        'company_name': cleanBusinessName,
        'name': cleanFullName,
      },
    );

    final User? user = response.user;

    if (user == null) {
      throw Exception('Erro ao criar usuário.');
    }

    final bool requiresEmailConfirmation = response.session == null;

    if (requiresEmailConfirmation) {
      return const SignUpResult(
        requiresEmailConfirmation: true,
        message:
            'Cadastro realizado. Verifique seu e-mail para confirmar a conta.',
      );
    }

    return const SignUpResult(
      requiresEmailConfirmation: false,
      message: 'Cadastro realizado com sucesso.',
    );
  }

  Future<Map<String, dynamic>> getCurrentProfile({
    bool forceRefresh = false,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    if (!forceRefresh &&
        _cachedCompanyId != null &&
        _cachedCompanyUserId == user.id &&
        _cachedLanguageUserId == user.id) {
      return {
        'id': user.id,
        'company_id': _cachedCompanyId,
        'language_code': _cachedLanguageCode ?? 'pt',
      };
    }

    final profile = await _client
        .from('profiles')
        .select('id, company_id, language_code')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      throw Exception('Perfil não encontrado.');
    }

    final companyId = profile['company_id'];

    if (companyId == null) {
      throw Exception('Usuário não possui empresa vinculada.');
    }

    final languageCode = (profile['language_code'] ?? 'pt').toString();

    _cachedCompanyId = companyId.toString();
    _cachedCompanyUserId = user.id;
    _cachedLanguageCode = languageCode;
    _cachedLanguageUserId = user.id;

    return {
      'id': user.id,
      'company_id': _cachedCompanyId,
      'language_code': _cachedLanguageCode,
    };
  }

  Future<String> getCurrentCompanyId({bool forceRefresh = false}) async {
    final profile = await getCurrentProfile(forceRefresh: forceRefresh);
    final companyId = profile['company_id'];

    if (companyId == null) {
      throw Exception('Usuário não possui empresa vinculada.');
    }

    return companyId.toString();
  }

  Future<String> getCurrentLanguageCode({bool forceRefresh = false}) async {
    final profile = await getCurrentProfile(forceRefresh: forceRefresh);
    final languageCode = (profile['language_code'] ?? 'pt').toString();

    if (languageCode.isEmpty) return 'pt';
    return languageCode;
  }

  Future<void> updateCurrentLanguageCode(String languageCode) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    const allowed = ['pt', 'es', 'en', 'ja'];

    if (!allowed.contains(languageCode)) {
      throw Exception('Idioma inválido.');
    }

    await _client
        .from('profiles')
        .update({'language_code': languageCode}).eq('id', user.id);

    _cachedLanguageCode = languageCode;
    _cachedLanguageUserId = user.id;
  }

  void _clearCaches() {
    _cachedCompanyId = null;
    _cachedCompanyUserId = null;
    _cachedLanguageCode = null;
    _cachedLanguageUserId = null;
  }

  Future<void> signOut() async {
    _clearCaches();
    await _client.auth.signOut();
  }
}
