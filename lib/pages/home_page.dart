import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import 'entries_page.dart';
import 'expenses_page.dart';

class HomePage extends StatefulWidget {
  final Function(Locale) onLocaleChanged;

  const HomePage({super.key, required this.onLocaleChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _companyId;
  String? _error;

  double _monthEntriesTotal = 0;
  double _monthExpensesTotal = 0;
  double _monthProfit = 0;

  List<Map<String, dynamic>> _recentEntries = [];
  List<Map<String, dynamic>> _recentExpenses = [];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
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

      await _loadDashboard(companyId);

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

  Future<void> _loadDashboard(String companyId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final String startIso = monthStart.toIso8601String().split('T').first;
    final String endIso = nextMonthStart.toIso8601String().split('T').first;

    final List<dynamic> entries = await _client
        .from('entries_v2')
        .select('id, entry_date, description, category, amount')
        .eq('company_id', companyId)
        .gte('entry_date', startIso)
        .lt('entry_date', endIso)
        .order('entry_date', ascending: false);

    final List<dynamic> expenses = await _client
        .from('expenses_v2')
        .select('id, expense_date, description, category, amount, store_name')
        .eq('company_id', companyId)
        .gte('expense_date', startIso)
        .lt('expense_date', endIso)
        .order('expense_date', ascending: false);

    final List<dynamic> recentEntries = await _client
        .from('entries_v2')
        .select('id, entry_date, description, category, amount')
        .eq('company_id', companyId)
        .order('entry_date', ascending: false)
        .limit(5);

    final List<dynamic> recentExpenses = await _client
        .from('expenses_v2')
        .select('id, expense_date, description, category, amount, store_name')
        .eq('company_id', companyId)
        .order('expense_date', ascending: false)
        .limit(5);

    double entriesTotal = 0;
    for (final item in entries) {
      entriesTotal += _toDouble(item['amount']);
    }

    double expensesTotal = 0;
    for (final item in expenses) {
      expensesTotal += _toDouble(item['amount']);
    }

    _monthEntriesTotal = entriesTotal;
    _monthExpensesTotal = expensesTotal;
    _monthProfit = entriesTotal - expensesTotal;

    _recentEntries =
        recentEntries.map((e) => Map<String, dynamic>.from(e)).toList();

    _recentExpenses =
        recentExpenses.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatYen(double value) {
    final bool negative = value < 0;
    final String digits = value.abs().round().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final int remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }

    return '${negative ? '-' : ''}¥${buffer.toString()}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  Future<void> _handleLogout() async {
    await AuthService.instance.signOut();
  }

  Future<void> _refreshDashboard() async {
    if (_companyId == null) return;

    setState(() {
      _loading = true;
    });

    await _loadDashboard(_companyId!);

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _openEntriesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EntriesPage()),
    );

    await _refreshDashboard();
  }

  Future<void> _openExpensesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpensesPage()),
    );

    await _refreshDashboard();
  }

  Widget _buildSummary(String title, double value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          _formatYen(value),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEntryItem(Map item) {
    return ListTile(
      leading: const Icon(Icons.arrow_downward, color: Colors.green),
      title: Text(item['description'] ?? ''),
      subtitle: Text(_formatDate(item['entry_date'])),
      trailing: Text(_formatYen(_toDouble(item['amount']))),
    );
  }

  Widget _buildExpenseItem(Map item) {
    return ListTile(
      leading: const Icon(Icons.arrow_upward, color: Colors.red),
      title: Text(item['description'] ?? ''),
      subtitle: Text(_formatDate(item['expense_date'])),
      trailing: Text(_formatYen(_toDouble(item['amount']))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomo App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "entry",
            onPressed: _openEntriesPage,
            icon: const Icon(Icons.add),
            label: const Text('Entrada'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "expense",
            onPressed: _openExpensesPage,
            icon: const Icon(Icons.receipt),
            label: const Text('Despesa'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary('Entradas do mês', _monthEntriesTotal,
              Icons.trending_up),
          _buildSummary('Despesas do mês', _monthExpensesTotal,
              Icons.receipt_long),
          _buildSummary('Resultado do mês', _monthProfit, Icons.savings),
          const SizedBox(height: 20),
          const Text('Últimas entradas',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ..._recentEntries.map(_buildEntryItem),
          const SizedBox(height: 20),
          const Text('Últimas despesas',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ..._recentExpenses.map(_buildExpenseItem),
        ],
      ),
    );
  }
}
