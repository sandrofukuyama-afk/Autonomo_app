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

    _recentEntries = recentEntries
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _recentExpenses = recentExpenses
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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
      final int positionFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
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
    try {
      await AuthService.instance.signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e')),
      );
    }
  }

  Future<void> _refreshDashboard() async {
    if (_companyId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDashboard(_companyId!);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  Widget _buildRecentEntries() {
    if (_recentEntries.isEmpty) {
      return _buildEmptyText('Nenhuma entrada cadastrada.');
    }

    return Column(
      children: _recentEntries.map((item) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.arrow_downward, color: Colors.green),
          title: Text((item['description'] ?? 'Sem descrição').toString()),
          subtitle: Text(
            '${_formatDate(item['entry_date'])} • ${(item['category'] ?? 'Sem categoria').toString()}',
          ),
          trailing: Text(
            _formatYen(_toDouble(item['amount'])),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentExpenses() {
    if (_recentExpenses.isEmpty) {
      return _buildEmptyText('Nenhuma despesa cadastrada.');
    }

    return Column(
      children: _recentExpenses.map((item) {
        final storeName = (item['store_name'] ?? '').toString().trim();
        final description = (item['description'] ?? 'Sem descrição').toString();

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.arrow_upward, color: Colors.red),
          title: Text(description),
          subtitle: Text(
            '${_formatDate(item['expense_date'])} • ${storeName.isNotEmpty ? storeName : (item['category'] ?? 'Sem categoria').toString()}',
          ),
          trailing: Text(
            _formatYen(_toDouble(item['amount'])),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
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
                  'Erro ao carregar dashboard\n$_error',
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
                  onPressed: _refreshDashboard,
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
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Empresa: ${_companyId ?? '-'}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _buildSummaryCard(
              title: 'Entradas do mês',
              value: _formatYen(_monthEntriesTotal),
              icon: Icons.trending_up,
            ),
            _buildSummaryCard(
              title: 'Despesas do mês',
              value: _formatYen(_monthExpensesTotal),
              icon: Icons.receipt_long,
            ),
            _buildSummaryCard(
              title: 'Resultado do mês',
              value: _formatYen(_monthProfit),
              icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
            ),
            const SizedBox(height: 8),
            _buildSectionCard(
              title: 'Últimas entradas',
              children: [
                _buildRecentEntries(),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              title: 'Últimas despesas',
              children: [
                _buildRecentExpenses(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
