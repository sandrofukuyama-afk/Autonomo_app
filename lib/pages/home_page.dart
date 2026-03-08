import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'entries_page.dart';
import 'expenses_page.dart';
import 'reports_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onLocaleChanged});

  final void Function(Locale) onLocaleChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  String _text(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;

    const pt = {
      'dashboard_title': 'Dashboard',
      'month_balance': 'Saldo do mês',
      'month_income': 'Entradas do mês',
      'month_expense': 'Saídas do mês',
      'quick_actions': 'Acesso rápido',
      'new_entry': 'Nova entrada',
      'new_expense': 'Nova despesa',
      'view_reports': 'Ver relatórios',
      'loading': 'Carregando...',
      'no_data': 'Sem dados neste mês',
      'summary': 'Resumo financeiro do mês atual',
    };

    const en = {
      'dashboard_title': 'Dashboard',
      'month_balance': 'Monthly balance',
      'month_income': 'Monthly income',
      'month_expense': 'Monthly expenses',
      'quick_actions': 'Quick actions',
      'new_entry': 'New income',
      'new_expense': 'New expense',
      'view_reports': 'View reports',
      'loading': 'Loading...',
      'no_data': 'No data this month',
      'summary': 'Current month financial summary',
    };

    const ja = {
      'dashboard_title': 'ダッシュボード',
      'month_balance': '今月の残高',
      'month_income': '今月の収入',
      'month_expense': '今月の支出',
      'quick_actions': 'クイック操作',
      'new_entry': '新しい収入',
      'new_expense': '新しい支出',
      'view_reports': 'レポートを見る',
      'loading': '読み込み中...',
      'no_data': '今月のデータはありません',
      'summary': '当月の財務サマリー',
    };

    const es = {
      'dashboard_title': 'Panel',
      'month_balance': 'Saldo del mes',
      'month_income': 'Ingresos del mes',
      'month_expense': 'Gastos del mes',
      'quick_actions': 'Accesos rápidos',
      'new_entry': 'Nuevo ingreso',
      'new_expense': 'Nuevo gasto',
      'view_reports': 'Ver informes',
      'loading': 'Cargando...',
      'no_data': 'Sin datos este mes',
      'summary': 'Resumen financiero del mes actual',
    };

    final map = switch (lang) {
      'en' => en,
      'ja' => ja,
      'es' => es,
      _ => pt,
    };

    return map[key] ?? key;
  }

  String _getAppBarTitle(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    switch (_currentIndex) {
      case 1:
        return localizations.translate('nav_entries');
      case 2:
        return localizations.translate('nav_expenses');
      case 3:
        return localizations.translate('nav_reports');
      default:
        return _text(context, 'dashboard_title');
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return const EntriesPage();
      case 2:
        return const ExpensesPage();
      case 3:
        return const ReportsPage();
      default:
        return _DashboardPage(
          onOpenEntries: () {
            setState(() {
              _currentIndex = 1;
            });
          },
          onOpenExpenses: () {
            setState(() {
              _currentIndex = 2;
            });
          },
          onOpenReports: () {
            setState(() {
              _currentIndex = 3;
            });
          },
          textBuilder: _text,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(context)),
        actions: [
          PopupMenuButton<String>(
            tooltip: localizations.translate('select_language'),
            icon: const Icon(Icons.language),
            onSelected: (String languageCode) async {
              if (languageCode == 'logout') {
                await AuthService.instance.signOut();
                return;
              }
              widget.onLocaleChanged(Locale(languageCode));
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'pt',
                child: Text(localizations.translate('lang_pt')),
              ),
              PopupMenuItem<String>(
                value: 'en',
                child: Text(localizations.translate('lang_en')),
              ),
              PopupMenuItem<String>(
                value: 'ja',
                child: Text(localizations.translate('lang_ja')),
              ),
              PopupMenuItem<String>(
                value: 'es',
                child: Text(localizations.translate('lang_es')),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: localizations.translate('nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.attach_money_outlined),
            selectedIcon: const Icon(Icons.attach_money),
            label: localizations.translate('nav_entries'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.money_off_csred_outlined),
            selectedIcon: const Icon(Icons.money_off_csred),
            label: localizations.translate('nav_expenses'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: localizations.translate('nav_reports'),
          ),
        ],
      ),
    );
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage({
    required this.onOpenEntries,
    required this.onOpenExpenses,
    required this.onOpenReports,
    required this.textBuilder,
  });

  final VoidCallback onOpenEntries;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenReports;
  final String Function(BuildContext context, String key) textBuilder;

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
  }

  Future<_DashboardData> _loadDashboard() async {
    final entriesRaw = await SupabaseService.instance.getEntries();
    final expensesRaw = await SupabaseService.instance.getExpenses();

    final now = DateTime.now();

    double income = 0;
    double expense = 0;

    for (final item in entriesRaw) {
      final map = Map<String, dynamic>.from(item as Map);
      final date = DateTime.parse((map['date'] ?? map['entry_date']).toString());
      if (date.year == now.year && date.month == now.month) {
        income += (map['amount'] as num).toDouble();
      }
    }

    for (final item in expensesRaw) {
      final map = Map<String, dynamic>.from(item as Map);
      final date = DateTime.parse((map['date'] ?? map['expense_date']).toString());
      if (date.year == now.year && date.month == now.month) {
        expense += (map['amount'] as num).toDouble();
      }
    }

    return _DashboardData(
      monthIncome: income,
      monthExpense: expense,
      monthBalance: income - expense,
    );
  }

 String _yen(num value) {
  final formatted = value.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  return '¥ $formatted';
}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Text(widget.textBuilder(context, 'loading')),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }

        final data = snapshot.data ??
            const _DashboardData(
              monthIncome: 0,
              monthExpense: 0,
              monthBalance: 0,
            );

        return RefreshIndicator(
          onRefresh: () async {
            final refreshed = _loadDashboard();
            setState(() {
              _future = refreshed;
            });
            await refreshed;
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.textBuilder(context, 'month_balance'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _yen(data.monthBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.textBuilder(context, 'summary'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: widget.textBuilder(context, 'month_income'),
                      value: _yen(data.monthIncome),
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: widget.textBuilder(context, 'month_expense'),
                      value: _yen(data.monthExpense),
                      icon: Icons.north_east,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.textBuilder(context, 'quick_actions'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.add_circle_outline,
                label: widget.textBuilder(context, 'new_entry'),
                onTap: widget.onOpenEntries,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.remove_circle_outline,
                label: widget.textBuilder(context, 'new_expense'),
                onTap: widget.onOpenExpenses,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.bar_chart_outlined,
                label: widget.textBuilder(context, 'view_reports'),
                onTap: widget.onOpenReports,
              ),
              if (data.monthIncome == 0 && data.monthExpense == 0) ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    widget.textBuilder(context, 'no_data'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.monthIncome,
    required this.monthExpense,
    required this.monthBalance,
  });

  final double monthIncome;
  final double monthExpense;
  final double monthBalance;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 10),
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
