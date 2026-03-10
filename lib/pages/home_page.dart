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
      // Aguarda sessão estar realmente disponível
      Session? session = Supabase.instance.client.auth.currentSession;

      int tries = 0;
      while (session == null && tries < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        session = Supabase.instance.client.auth.currentSession;
        tries++;
      }

      final companyId =
          await AuthService.instance.getCurrentCompanyId(forceRefresh: true);

      setState(() {
        _companyId = companyId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
        body: Center(
          child: Text('Erro ao carregar empresa\n$_error'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomo App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Dashboard'),
      ),
    );
  }
}
