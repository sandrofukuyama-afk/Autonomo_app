import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_service.dart';
import '../l10n/app_localizations.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isResetPassword = false;
  bool _loading = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.instance.authStateChanges.listen((data) {
      // The recovery flow is now handled by ResetPasswordPage via main.dart routing.
      // We keep the listener for other potential auth events if needed.
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isResetPassword) {
      if (email.isEmpty) {
        _showMessage(l10n.translate('auth_fill_email'));
        return;
      }
    } else if (email.isEmpty || password.isEmpty) {
      _showMessage(l10n.translate('auth_fill_email_password'));
      return;
    }

    if (!_isLogin && !_isResetPassword) {
      if (_fullNameController.text.trim().isEmpty ||
          _businessNameController.text.trim().isEmpty) {
        _showMessage(l10n.translate('auth_fill_signup_fields'));
        return;
      }
    }

    setState(() => _loading = true);

    try {
      if (_isResetPassword) {
        await AuthService.instance.resetPasswordForEmail(email);
        _showMessage(l10n.translate('auth_reset_email_sent'));
        setState(() {
          _isResetPassword = false;
          _isLogin = true;
        });
      } else if (_isLogin) {
        await AuthService.instance.signIn(
          email: email,
          password: password,
        );
      } else {
        final result = await AuthService.instance.signUp(
          fullName: _fullNameController.text.trim(),
          businessName: _businessNameController.text.trim(),
          email: email,
          password: password,
        );

        if (result.requiresEmailConfirmation) {
          _showMessage(result.message);

          setState(() {
            _isLogin = true;
          });

          _passwordController.clear();
        } else {
          _showMessage(result.message);
        }
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

  String _getButtonText() {
    final l10n = AppLocalizations.of(context);
    if (_isResetPassword) return l10n.translate('auth_send_reset_email');
    return _isLogin ? l10n.translate('auth_login') : l10n.translate('auth_signup');
  }

  String _getTitleText() {
    final l10n = AppLocalizations.of(context);
    if (_isResetPassword) return l10n.translate('auth_reset_password_title');
    return _isLogin ? l10n.translate('auth_login') : l10n.translate('auth_signup');
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
                  // BANNER DE DEBUG TEMPORÁRIO (Remover após resolver)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.yellow.shade100,
                    child: Text(
                      'URL Debug: ${Uri.base.toString().substring(0, Uri.base.toString().length > 60 ? 60 : Uri.base.toString().length)}...',
                      style: const TextStyle(fontSize: 10, color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getTitleText(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!_isLogin && !_isResetPassword) ...[
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: l10n.translate('auth_full_name'),
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _businessNameController,
                      decoration: InputDecoration(
                        labelText: l10n.translate('auth_business_name'),
                        prefixIcon: const Icon(Icons.business_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (true) ...[ // Always show email except in recovery (handled by another page)
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.translate('auth_email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_isResetPassword) ...[
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.translate('auth_password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _isResetPassword = true;
                                    _isLogin = false;
                                  });
                                },
                          child: Text(l10n.translate('auth_forgot_password')),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_getButtonText()),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              if (_isResetPassword) {
                                _isResetPassword = false;
                                _isLogin = true;
                              } else {
                                _isLogin = !_isLogin;
                              }
                            });
                          },
                    child: Text(
                      _isResetPassword
                          ? l10n.translate('auth_back_to_login')
                          : (_isLogin
                              ? l10n.translate('auth_no_account')
                              : l10n.translate('auth_already_have_account')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
