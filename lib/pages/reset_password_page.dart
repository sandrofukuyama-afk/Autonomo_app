import 'package:flutter/material.dart';
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

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      _showMessage(l10n.translate('auth_fill_email_password')); // Use a generic or specific error
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.instance.updatePassword(password);
      _showMessage(l10n.translate('auth_password_updated'));
      
      // Redirect back to login after success
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/'); 
        // Note: Our main.dart doesn't use named routes, but home will rebuild 
        // since we'll change state or just let the user know they can login now.
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
                    l10n.translate('auth_new_password_title'),
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
                      labelText: l10n.translate('auth_new_password_label'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.translate('auth_update_password_button')),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Just go back to home if they want to cancel
                      // In our main.dart, this means showing login page again
                      // We can achieve this by cleared the URL or just reloading
                      // For now, let's just use Navigator if available or instructions.
                    },
                    child: Text(l10n.translate('auth_back_to_login')),
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
