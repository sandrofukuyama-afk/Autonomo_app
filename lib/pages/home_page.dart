import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_service.dart';

class HomePage extends StatefulWidget {
  final Function(Locale) onLocaleChanged;

  const HomePage({super.key, required this.onLocaleChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _companyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCompany();
  }

  Future<void> _initializeCompany() async {
    try {
      Session? session = Supabase.instance.client.auth.currentSession;

      int tries = 0;
      while (session == null && tries < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        session = Supabase.instance.client.auth.currentSession;
        tries++;
      }

      final companyId =
          await AuthService.instance.getCurrentCompanyId(forceRefresh: true);

      if (!mounted) return;

      setState(() {
        _companyId = companyId;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.instance.signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Autonomo App'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar empresa\n$_error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _initializeCompany();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomo App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Center(
        child: Text('Dashboard\n$_companyId'),
      ),
    );
  }
}
