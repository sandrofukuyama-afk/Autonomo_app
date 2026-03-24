import 'package:flutter/material.dart';
import '../data/auth_service.dart';

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
  bool _isRecovering = false;
  bool _loading = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.instance.authStateChanges.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _isRecovering = true;
          _isLogin = false;
          _isResetPassword = false;
        });
      }
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isResetPassword) {
      if (email.isEmpty) {
        _showMessage('Informe seu e-mail.');
        return;
      }
    } else if (email.isEmpty || password.isEmpty) {
      _showMessage('Preencha e-mail e senha.');
      return;
    }

    if (!_isLogin && !_isResetPassword && !_isRecovering) {
      if (_fullNameController.text.trim().isEmpty ||
          _businessNameController.text.trim().isEmpty) {
        _showMessage('Preencha nome e nome do negócio.');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      if (_isRecovering) {
        await AuthService.instance.updatePassword(password);
        _showMessage('Senha atualizada com sucesso!');
        setState(() {
          _isRecovering = false;
          _isLogin = true;
        });
        _passwordController.clear();
      } else if (_isResetPassword) {
        await AuthService.instance.resetPasswordForEmail(email);
        _showMessage('E-mail de recuperação enviado!');
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
    if (_isRecovering) return 'Atualizar senha';
    if (_isResetPassword) return 'Enviar e-mail de recuperação';
    return _isLogin ? 'Entrar' : 'Criar conta';
  }

  String _getTitleText() {
    if (_isRecovering) return 'Nova senha';
    if (_isResetPassword) return 'Recuperar senha';
    return _isLogin ? 'Entrar' : 'Criar conta';
  }

  @override
  Widget build(BuildContext context) {
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
                    _getTitleText(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (!_isLogin && !_isResetPassword && !_isRecovering) ...[
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do negócio',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_isRecovering) ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_isResetPassword) ...[
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: _isRecovering ? 'Nova senha' : 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLogin && !_isRecovering)
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
                          child: const Text('Esqueceu a senha?'),
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
                              if (_isResetPassword || _isRecovering) {
                                _isResetPassword = false;
                                _isRecovering = false;
                                _isLogin = true;
                              } else {
                                _isLogin = !_isLogin;
                              }
                            });
                          },
                    child: Text(
                      _isResetPassword || _isRecovering
                          ? 'Voltar para o login'
                          : (_isLogin
                              ? 'Não tem uma conta? Criar conta'
                              : 'Já tem uma conta? Entrar'),
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
