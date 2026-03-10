import 'package:flutter/material.dart';
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
      final companyId =
          await AuthService.instance.getCurrentCompanyId(forceRefresh: true);

      setState(() {
        _companyId = companyId;
        _loading = false;
      });
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 800));

      try {
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
