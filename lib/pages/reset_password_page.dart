import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_service.dart';
import '../l10n/app_localizations.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _forcedLocale;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.instance.authStateChanges.listen((data) {
      if (mounted) {
        setState(() {}); // Rebuild when session status change
      }
    });

    _attemptManualExchange();
  }

  Future<void> _attemptManualExchange() async {
    final code = Uri.base.queryParameters['code'];
    if (code != null && AuthService.instance.currentUser == null) {
      try {
        await AuthService.instance.exchangeCodeForSession(code);
      } catch (e) {
        if (mounted) {
          _showMessage(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  // Helper to translate with priority to forced locale
  String _t(String key, AppLocalizations l10n) {
    if (_forcedLocale != null) {
      return l10n.translateWithLocale(key, _forcedLocale!);
    }
    return l10n.translate(key);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      _showMessage(_t('auth_fill_email_password', l10n));
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      _showMessage('Erro: Sessão de recuperação não encontrada. Por favor, solicite um novo link.');
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.instance.updatePassword(password);

      if (mounted) {
        AuthService.isRecoveryFromUrl = false;
        AuthService.instance.clearRecoveryMode();
        _showMessage(_t('auth_password_updated', l10n));

        // Sign out so the user logs in with the new password cleanly
        await AuthService.instance.signOut();
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24 * 1.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t('auth_new_password_title', l10n),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _t('auth_new_password_label', l10n),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_loading || AuthService.instance.currentUser == null) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_t('auth_update_password_button', l10n)),
                  ),
                  if (AuthService.instance.currentUser == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Aguardando validação do link... Isso pode levar alguns segundos.',
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _langButton('PT'),
                      _langButton('ES'),
                      _langButton('EN'),
                      _langButton('JP'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _langButton(String label) {
    final Map<String, String> codes = {
      'PT': 'pt',
      'ES': 'es',
      'EN': 'en',
      'JP': 'ja',
    };
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      onPressed: () {
        setState(() {
          _forcedLocale = codes[label];
        });
      },
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
