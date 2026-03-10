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
      final companyId =
          await AuthService.instance.getCurrentCompanyId(forceRefresh: true);

      await _loadDashboard(companyId);

      if (!mounted) return;

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

  Future<void> _loadDashboard(String companyId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final String startIso = monthStart.toIso8601String().split('T').first;
    final String endIso = nextMonthStart.toIso8601String().split('T').first;

    final entries = await _client
        .from('entries_v2')
        .select('entry_date, description, amount')
        .eq('company_id', companyId)
        .gte('entry_date', startIso)
        .lt('entry_date', endIso);

    final expenses = await _client
        .from('expenses_v2')
        .select('expense_date, description, amount')
        .eq('company_id', companyId)
        .gte('expense_date', startIso)
        .lt('expense_date', endIso);

    double entryTotal = 0;
    for (final e in entries) {
      entryTotal += (e['amount'] ?? 0).toDouble();
    }

    double expenseTotal = 0;
    for (final e in expenses) {
      expenseTotal += (e['amount'] ?? 0).toDouble();
    }

    _monthEntriesTotal = entryTotal;
    _monthExpensesTotal = expenseTotal;
    _monthProfit = entryTotal - expenseTotal;

    _recentEntries = List<Map<String, dynamic>>.from(entries.take(5));
    _recentExpenses = List<Map<String, dynamic>>.from(expenses.take(5));
  }

  Future<void> _openEntriesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EntriesPage()),
    );
    await _initializeDashboard();
  }

  Future<void> _openExpensesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExpensesPage()),
    );
    await _initializeDashboard();
  }

  String _yen(double value) {
    return "¥${value.toStringAsFixed(0)}";
  }

  Widget _summaryCard(
      String title, double value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(
                _yen(value),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listItem(String title, String date, double amount, bool income) {
    return ListTile(
      leading: Icon(
        income ? Icons.arrow_downward : Icons.arrow_upward,
        color: income ? Colors.green : Colors.red,
      ),
      title: Text(title),
      subtitle: Text(date),
      trailing: Text(
        _yen(amount),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
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
      return Scaffold(body: Center(child: Text(_error!)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Autonomo App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
            },
          )
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: "entry",
            icon: const Icon(Icons.add),
            label: const Text("Entrada"),
            onPressed: _openEntriesPage,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "expense",
            icon: const Icon(Icons.receipt),
            label: const Text("Despesa"),
            onPressed: _openExpensesPage,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Resumo do mês",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              _summaryCard(
                  "Entradas", _monthEntriesTotal, Icons.trending_up, Colors.green),
              const SizedBox(width: 10),
              _summaryCard("Despesas", _monthExpensesTotal,
                  Icons.trending_down, Colors.red),
              const SizedBox(width: 10),
              _summaryCard("Resultado", _monthProfit, Icons.account_balance,
                  Colors.blue),
            ],
          ),

          const SizedBox(height: 30),

          const Text(
            "Últimas entradas",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          ..._recentEntries.map((e) => _listItem(
                e['description'] ?? '',
                e['entry_date'] ?? '',
                (e['amount'] ?? 0).toDouble(),
                true,
              )),

          const SizedBox(height: 20),

          const Text(
            "Últimas despesas",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          ..._recentExpenses.map((e) => _listItem(
                e['description'] ?? '',
                e['expense_date'] ?? '',
                (e['amount'] ?? 0).toDouble(),
                false,
              )),
        ],
      ),
    );
  }
}
