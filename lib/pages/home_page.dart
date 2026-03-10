import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import 'entries_page.dart';
import 'expenses_page.dart';
import 'reports_page.dart';

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

  Future<void> _openReportsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsPage()),
    );

    await _refreshDashboard();
  }

  Widget _buildSummaryMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: iconBackground,
                    child: Icon(icon, color: iconColor),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 900;
    final bool isMedium = width >= 600;

    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _buildSummaryMiniCard(
              title: 'Entradas',
              value: _formatYen(_monthEntriesTotal),
              icon: Icons.trending_up,
              iconColor: Colors.green.shade800,
              iconBackground: Colors.green.shade100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryMiniCard(
              title: 'Despesas',
              value: _formatYen(_monthExpensesTotal),
              icon: Icons.receipt_long,
              iconColor: Colors.red.shade800,
              iconBackground: Colors.red.shade100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryMiniCard(
              title: 'Resultado',
              value: _formatYen(_monthProfit),
              icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
              iconColor: _monthProfit >= 0
                  ? Colors.blue.shade800
                  : Colors.orange.shade800,
              iconBackground: _monthProfit >= 0
                  ? Colors.blue.shade100
                  : Colors.orange.shade100,
            ),
          ),
        ],
      );
    }

    if (isMedium) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryMiniCard(
                  title: 'Entradas',
                  value: _formatYen(_monthEntriesTotal),
                  icon: Icons.trending_up,
                  iconColor: Colors.green.shade800,
                  iconBackground: Colors.green.shade100,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMiniCard(
                  title: 'Despesas',
                  value: _formatYen(_monthExpensesTotal),
                  icon: Icons.receipt_long,
                  iconColor: Colors.red.shade800,
                  iconBackground: Colors.red.shade100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryMiniCard(
            title: 'Resultado',
            value: _formatYen(_monthProfit),
            icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
            iconColor: _monthProfit >= 0
                ? Colors.blue.shade800
                : Colors.orange.shade800,
            iconBackground: _monthProfit >= 0
                ? Colors.blue.shade100
                : Colors.orange.shade100,
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSummaryMiniCard(
          title: 'Entradas',
          value: _formatYen(_monthEntriesTotal),
          icon: Icons.trending_up,
          iconColor: Colors.green.shade800,
          iconBackground: Colors.green.shade100,
        ),
        const SizedBox(height: 12),
        _buildSummaryMiniCard(
          title: 'Despesas',
          value: _formatYen(_monthExpensesTotal),
          icon: Icons.receipt_long,
          iconColor: Colors.red.shade800,
          iconBackground: Colors.red.shade100,
        ),
        const SizedBox(height: 12),
        _buildSummaryMiniCard(
          title: 'Resultado',
          value: _formatYen(_monthProfit),
          icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
          iconColor: _monthProfit >= 0
              ? Colors.blue.shade800
              : Colors.orange.shade800,
          iconBackground: _monthProfit >= 0
              ? Colors.blue.shade100
              : Colors.orange.shade100,
        ),
      ],
    );
  }

  Widget _buildActionShortcuts() {
    final actions = [
      {
        'title': 'Entradas',
        'icon': Icons.add_circle_outline,
        'color': Colors.green,
        'onTap': _openEntriesPage,
      },
      {
        'title': 'Despesas',
        'icon': Icons.receipt_long_outlined,
        'color': Colors.red,
        'onTap': _openExpensesPage,
      },
      {
        'title': 'Relatório Fiscal',
        'icon': Icons.assessment_outlined,
        'color': Colors.blue,
        'onTap': _openReportsPage,
      },
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 3 : width >= 600 ? 3 : 1;
    final childAspectRatio = width >= 600 ? 2.2 : 3.3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        final color = item['color'] as Color;
        final icon = item['icon'] as IconData;
        final title = item['title'] as String;
        final onTap = item['onTap'] as Future<void> Function();

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalBarChart() {
    final bars = [
      {
        'label': 'Entradas',
        'value': _monthEntriesTotal,
        'color': Colors.green,
      },
      {
        'label': 'Despesas',
        'value': _monthExpensesTotal,
        'color': Colors.red,
      },
      {
        'label': _monthProfit >= 0 ? 'Resultado' : 'Prejuízo',
        'value': _monthProfit.abs(),
        'color': _monthProfit >= 0 ? Colors.blue : Colors.orange,
      },
    ];

    double maxValue = 0;
    for (final bar in bars) {
      final value = bar['value'] as double;
      if (value > maxValue) maxValue = value;
    }

    if (maxValue <= 0) {
      maxValue = 1;
    }

    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.map((bar) {
          final value = bar['value'] as double;
          final color = bar['color'] as Color;
          final label = bar['label'] as String;
          final heightFactor = (value / maxValue).clamp(0.0, 1.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatYen(value),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 150 * heightFactor + 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.shade100,
            child: Icon(
              Icons.arrow_downward,
              color: Colors.green.shade800,
            ),
          ),
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
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.red.shade100,
            child: Icon(
              Icons.arrow_upward,
              color: Colors.red.shade800,
            ),
          ),
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
        body: Center(child: CircularProgressIndicator()),
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
            child: Text(
              _error!,
              textAlign: TextAlign.center,
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
              'Resumo do mês',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Empresa: ${_companyId ?? '-'}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            _buildSummaryGrid(),
            const SizedBox(height: 14),
            _buildSectionCard(
              title: 'Acessos rápidos',
              child: _buildActionShortcuts(),
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              title: 'Visão financeira',
              child: _buildVerticalBarChart(),
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              title: 'Últimas entradas',
              child: _buildRecentEntries(),
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              title: 'Últimas despesas',
              child: _buildRecentExpenses(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'entry',
            icon: const Icon(Icons.add),
            label: const Text('Entrada'),
            onPressed: _openEntriesPage,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'expense',
            icon: const Icon(Icons.receipt),
            label: const Text('Despesa'),
            onPressed: _openExpensesPage,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'report',
            icon: const Icon(Icons.assessment),
            label: const Text('Relatório'),
            onPressed: _openReportsPage,
          ),
        ],
      ),
    );
  }
}
