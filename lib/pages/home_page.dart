import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'entries_page.dart';
import 'expenses_page.dart';
import 'expense_review_page.dart';
import 'reports_page.dart';

class HomePage extends StatefulWidget {
  final Locale? currentLocale;
  final Future<void> Function(Locale) onLocaleChanged;

  const HomePage({
    super.key,
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  String? _companyId;
  String? _error;

  int _pendingExpenseReviews = 0;

  double _monthEntriesTotal = 0;
  double _monthExpensesTotal = 0;
  double _monthProfit = 0;

  double _fiscalMonthExpenses = 0;
  double _deductibleExpenses = 0;
  double _nonDeductibleExpenses = 0;
  double _estimatedTaxImpact = 0;

  List<Map<String, dynamic>> _recentEntries = [];
  List<Map<String, dynamic>> _recentExpenses = [];
  List<String> _closedFiscalMonths = [];
  bool _closingFiscalMonth = false;

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
      await _loadExpenseReviewCount(companyId);
      await _loadFiscalDashboard(companyId);
      await _loadClosedFiscalMonths(companyId);

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

  Future<void> _loadClosedFiscalMonths(String companyId) async {
    final Map<String, dynamic>? settings = await _client
        .from('app_settings')
        .select('closed_fiscal_months')
        .eq('company_id', companyId)
        .maybeSingle();

    final raw = settings?['closed_fiscal_months'];

    if (raw is List) {
      _closedFiscalMonths = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return;
    }

    _closedFiscalMonths = [];
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

  String _currentMonthLabel() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  bool _isFiscalMonthClosed(String month) {
    return _closedFiscalMonths.contains(month);
  }

  bool _isCurrentFiscalMonthClosed() {
    return _isFiscalMonthClosed(_currentMonthLabel());
  }

  Future<void> _closeCurrentFiscalMonth() async {
    if (_companyId == null || _closingFiscalMonth) return;

    final t = AppLocalizations.of(context);
    final month = _currentMonthLabel();

    if (_isFiscalMonthClosed(month)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate('fiscal_month_already_closed')),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(t.translate('close_fiscal_month')),
              content: Text(
                '${t.translate('confirm_close_fiscal_month')} $month?\n\n'
                '${t.translate('close_fiscal_month_warning')}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(t.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(t.translate('confirm_close_month')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _closingFiscalMonth = true;
    });

    try {
      final updatedMonths = [..._closedFiscalMonths, month]..sort();

      await _client
          .from('app_settings')
          .update({'closed_fiscal_months': updatedMonths})
          .eq('company_id', _companyId!);

      await _loadClosedFiscalMonths(_companyId!);

      if (!mounted) return;

      setState(() {
        _closingFiscalMonth = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.translate('fiscal_month_closed_success')} $month.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _closingFiscalMonth = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.translate('failed_to_close_fiscal_month')}: $e'),
        ),
      );
    }
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
      await _loadExpenseReviewCount(_companyId!);
      await _loadFiscalDashboard(_companyId!);
      await _loadClosedFiscalMonths(_companyId!);

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
    final t = AppLocalizations.of(context);

    if (_isCurrentFiscalMonthClosed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate('fiscal_month_closed')),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EntriesPage()),
    );

    await _refreshDashboard();
  }

  Future<void> _openExpensesPage() async {
    final t = AppLocalizations.of(context);

    if (_isCurrentFiscalMonthClosed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate('fiscal_month_closed')),
        ),
      );
      return;
    }

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

  Future<void> _openExpenseReviewPage() async {
    if (_companyId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseReviewPage(companyId: _companyId!),
      ),
    );

    await _refreshDashboard();
  }

  Future<void> _loadExpenseReviewCount(String companyId) async {
    final List<dynamic> reviewExpenses = await _client
        .from('expenses_v2')
        .select('id')
        .eq('company_id', companyId)
        .eq('review_status', 'review_required');

    _pendingExpenseReviews = reviewExpenses.length;
  }

  Future<void> _loadFiscalDashboard(String companyId) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final String startIso = monthStart.toIso8601String().split('T').first;
    final String endIso = nextMonthStart.toIso8601String().split('T').first;

    final List<dynamic> expenses = await _client
        .from('expenses_v2')
        .select('amount, deductibility_status, expense_date')
        .eq('company_id', companyId)
        .gte('expense_date', startIso)
        .lt('expense_date', endIso);

    double monthTotal = 0;
    double deductible = 0;
    double partiallyDeductible = 0;
    double nonDeductible = 0;

    for (final raw in expenses) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(raw as Map);
      final double amount = _toDouble(item['amount']);
      final String status = (item['deductibility_status'] ?? '').toString();

      monthTotal += amount;

      if (status == 'deductible') {
        deductible += amount;
      } else if (status == 'partially_deductible') {
        partiallyDeductible += amount;
      } else if (status == 'non_deductible') {
        nonDeductible += amount;
      }
    }

    _fiscalMonthExpenses = monthTotal;
    _deductibleExpenses = deductible + (partiallyDeductible * 0.5);
    _nonDeductibleExpenses = nonDeductible;
    _estimatedTaxImpact = _deductibleExpenses * 0.30;
  }

  String _languageLabel(AppLocalizations t, String code) {
    switch (code) {
      case 'pt':
        return t.translate('lang_pt');
      case 'en':
        return t.translate('lang_en');
      case 'ja':
        return t.translate('lang_ja');
      case 'es':
        return t.translate('lang_es');
      default:
        return code;
    }
  }

  Future<void> _openSettingsDialog() async {
    final t = AppLocalizations.of(context);
    String selectedLanguage =
        widget.currentLocale?.languageCode.isNotEmpty == true
            ? widget.currentLocale!.languageCode
            : Localizations.localeOf(context).languageCode;

    if (!['pt', 'es', 'en', 'ja'].contains(selectedLanguage)) {
      selectedLanguage = 'pt';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(t.translate('app_settings')),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.translate('language_settings_description'),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedLanguage,
                      decoration: InputDecoration(
                        labelText: t.translate('select_language'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: ['pt', 'es', 'en', 'ja'].map((code) {
                        return DropdownMenuItem<String>(
                          value: code,
                          child: Text(_languageLabel(t, code)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setStateDialog(() {
                          selectedLanguage = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ...['pt', 'es', 'en', 'ja'].map((code) {
                      final selected = selectedLanguage == code;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: Text(_languageLabel(t, code)),
                        onTap: () {
                          setStateDialog(() {
                            selectedLanguage = code;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(t.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await widget.onLocaleChanged(Locale(selectedLanguage));
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(t.translate('save_changes')),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      final updatedT = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updatedT.translate('language_updated'))),
      );
      setState(() {});
    }
  }

  Widget _buildHeroCard() {
    final t = AppLocalizations.of(context);
    final bool positive = _monthProfit >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: positive
              ? const [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A8A),
                ]
              : const [
                  Color(0xFF3F3F46),
                  Color(0xFF7C2D12),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate('financial_dashboard'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${t.translate('month_summary')} ${_currentMonthLabel()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.translate('current_result'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatYen(_monthProfit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroChip(
                icon: Icons.trending_up,
                label:
                    '${t.translate('entries')} ${_formatYen(_monthEntriesTotal)}',
              ),
              _heroChip(
                icon: Icons.receipt_long,
                label:
                    '${t.translate('expenses')} ${_formatYen(_monthExpensesTotal)}',
              ),
              _heroChip(
                icon: positive
                    ? Icons.check_circle_outline
                    : Icons.warning_amber,
                label: positive
                    ? t.translate('positive_month')
                    : t.translate('balance_attention'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    Color? valueColor,
  }) {
    return SizedBox(
      height: 140,
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
              const Spacer(),
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
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final t = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 1000;
    final bool isMedium = width >= 650;

    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _buildSummaryMiniCard(
              title: t.translate('entries'),
              value: _formatYen(_monthEntriesTotal),
              icon: Icons.trending_up,
              iconColor: Colors.green.shade800,
              iconBackground: Colors.green.shade100,
              valueColor: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryMiniCard(
              title: t.translate('expenses'),
              value: _formatYen(_monthExpensesTotal),
              icon: Icons.receipt_long,
              iconColor: Colors.red.shade800,
              iconBackground: Colors.red.shade100,
              valueColor: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryMiniCard(
              title: t.translate('result'),
              value: _formatYen(_monthProfit),
              icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
              iconColor: _monthProfit >= 0
                  ? Colors.blue.shade800
                  : Colors.orange.shade800,
              iconBackground: _monthProfit >= 0
                  ? Colors.blue.shade100
                  : Colors.orange.shade100,
              valueColor: _monthProfit >= 0
                  ? Colors.blue.shade700
                  : Colors.orange.shade700,
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
                  title: t.translate('entries'),
                  value: _formatYen(_monthEntriesTotal),
                  icon: Icons.trending_up,
                  iconColor: Colors.green.shade800,
                  iconBackground: Colors.green.shade100,
                  valueColor: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMiniCard(
                  title: t.translate('expenses'),
                  value: _formatYen(_monthExpensesTotal),
                  icon: Icons.receipt_long,
                  iconColor: Colors.red.shade800,
                  iconBackground: Colors.red.shade100,
                  valueColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryMiniCard(
            title: t.translate('result'),
            value: _formatYen(_monthProfit),
            icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
            iconColor: _monthProfit >= 0
                ? Colors.blue.shade800
                : Colors.orange.shade800,
            iconBackground: _monthProfit >= 0
                ? Colors.blue.shade100
                : Colors.orange.shade100,
            valueColor: _monthProfit >= 0
                ? Colors.blue.shade700
                : Colors.orange.shade700,
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSummaryMiniCard(
          title: t.translate('entries'),
          value: _formatYen(_monthEntriesTotal),
          icon: Icons.trending_up,
          iconColor: Colors.green.shade800,
          iconBackground: Colors.green.shade100,
          valueColor: Colors.green.shade700,
        ),
        const SizedBox(height: 12),
        _buildSummaryMiniCard(
          title: t.translate('expenses'),
          value: _formatYen(_monthExpensesTotal),
          icon: Icons.receipt_long,
          iconColor: Colors.red.shade800,
          iconBackground: Colors.red.shade100,
          valueColor: Colors.red.shade700,
        ),
        const SizedBox(height: 12),
        _buildSummaryMiniCard(
          title: t.translate('result'),
          value: _formatYen(_monthProfit),
          icon: _monthProfit >= 0 ? Icons.savings : Icons.warning_amber,
          iconColor: _monthProfit >= 0
              ? Colors.blue.shade800
              : Colors.orange.shade800,
          iconBackground: _monthProfit >= 0
              ? Colors.blue.shade100
              : Colors.orange.shade100,
          valueColor: _monthProfit >= 0
              ? Colors.blue.shade700
              : Colors.orange.shade700,
        ),
      ],
    );
  }

  Widget _buildActionShortcuts() {
    final t = AppLocalizations.of(context);

    final actions = [
      {
        'title': t.translate('entries'),
        'subtitle': t.translate('entries_shortcut_subtitle'),
        'icon': Icons.add_circle_outline,
        'color': Colors.green,
        'onTap': _openEntriesPage,
      },
      {
        'title': t.translate('expenses'),
        'subtitle': t.translate('expenses_shortcut_subtitle'),
        'icon': Icons.receipt_long_outlined,
        'color': Colors.red,
        'onTap': _openExpensesPage,
      },
      {
        'title': t.translate('fiscal_report'),
        'subtitle': t.translate('fiscal_report_shortcut_subtitle'),
        'icon': Icons.assessment_outlined,
        'color': Colors.blue,
        'onTap': _openReportsPage,
      },
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1000 ? 3 : width >= 650 ? 3 : 1;
    final childAspectRatio = width >= 650 ? 1.8 : 2.8;

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
        final subtitle = item['subtitle'] as String;
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
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
    String? subtitle,
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
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalBarChart() {
    final t = AppLocalizations.of(context);

    final bars = [
      {
        'label': t.translate('entries'),
        'value': _monthEntriesTotal,
        'color': Colors.green,
      },
      {
        'label': t.translate('expenses'),
        'value': _monthExpensesTotal,
        'color': Colors.red,
      },
      {
        'label': _monthProfit >= 0
            ? t.translate('result')
            : t.translate('loss'),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF8FAFC),
      ),
      child: SizedBox(
        height: 260,
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 160 * heightFactor + 10,
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
    final t = AppLocalizations.of(context);

    if (_recentEntries.isEmpty) {
      return _buildEmptyText(t.translate('no_entries_registered'));
    }

    return Column(
      children: _recentEntries.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green.shade100,
                child: Icon(
                  Icons.arrow_downward,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['description'] ?? t.translate('no_description'))
                          .toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(item['entry_date'])} • ${(item['category'] ?? t.translate('no_category')).toString()}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatYen(_toDouble(item['amount'])),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentExpenses() {
    final t = AppLocalizations.of(context);

    if (_recentExpenses.isEmpty) {
      return _buildEmptyText(t.translate('no_expenses_registered'));
    }

    return Column(
      children: _recentExpenses.map((item) {
        final storeName = (item['store_name'] ?? '').toString().trim();
        final description =
            (item['description'] ?? t.translate('no_description')).toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.red.shade100,
                child: Icon(
                  Icons.arrow_upward,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(item['expense_date'])} • ${storeName.isNotEmpty ? storeName : (item['category'] ?? t.translate('no_category')).toString()}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatYen(_toDouble(item['amount'])),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseReviewAlertCard() {
    final t = AppLocalizations.of(context);

    if (_pendingExpenseReviews <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openExpenseReviewPage,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_pendingExpenseReviews ${t.translate('expenses_need_fiscal_review')}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.translate('tap_to_open'),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiscalSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedMonthsChips() {
    final t = AppLocalizations.of(context);

    if (_closedFiscalMonths.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          t.translate('no_closed_fiscal_months_yet'),
          style: const TextStyle(fontSize: 13),
        ),
      );
    }

    final months = [..._closedFiscalMonths]..sort((a, b) => b.compareTo(a));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: months.map((month) {
        final isCurrent = month == _currentMonthLabel();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.green.shade50 : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? Colors.green.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 16,
                color: isCurrent ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                month,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:
                      isCurrent ? Colors.green.shade700 : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFiscalDashboardSection() {
    final t = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool wide = width >= 900;
    final currentMonth = _currentMonthLabel();
    final currentClosed = _isFiscalMonthClosed(currentMonth);

    final children = [
      _buildFiscalSummaryCard(
        icon: Icons.receipt_long,
        iconColor: Colors.indigo.shade800,
        iconBackground: Colors.indigo.shade100,
        title: t.translate('expenses_this_month'),
        value: _formatYen(_fiscalMonthExpenses),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.check_circle,
        iconColor: Colors.green.shade800,
        iconBackground: Colors.green.shade100,
        title: t.translate('deductible_expenses'),
        value: _formatYen(_deductibleExpenses),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.block,
        iconColor: Colors.red.shade800,
        iconBackground: Colors.red.shade100,
        title: t.translate('non_deductible_expenses'),
        value: _formatYen(_nonDeductibleExpenses),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.account_balance,
        iconColor: Colors.blue.shade800,
        iconBackground: Colors.blue.shade100,
        title: t.translate('estimated_tax_impact'),
        value: _formatYen(_estimatedTaxImpact),
      ),
    ];

    final summaryGrid = wide
        ? GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: children.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) => children[index],
          )
        : Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: currentClosed ? Colors.green.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: currentClosed
                  ? Colors.green.shade200
                  : Colors.amber.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentClosed
                          ? Colors.green.shade100
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${t.translate('current_fiscal_month')}: $currentMonth',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: currentClosed
                            ? Colors.green.shade800
                            : Colors.grey.shade900,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentClosed
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      currentClosed
                          ? t.translate('status_closed')
                          : t.translate('status_open'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: currentClosed
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                currentClosed
                    ? t.translate('current_month_closed_description')
                    : t.translate('close_month_after_review_description'),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: currentClosed || _closingFiscalMonth
                      ? null
                      : _closeCurrentFiscalMonth,
                  icon: _closingFiscalMonth
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_clock_outlined),
                  label: Text(
                    currentClosed
                        ? t.translate('fiscal_month_closed')
                        : t.translate('close_fiscal_month'),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        summaryGrid,
        const SizedBox(height: 14),
        Text(
          t.translate('closed_fiscal_months'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 10),
        _buildClosedMonthsChips(),
      ],
    );
  }

  Widget _buildMainContent() {
    final t = AppLocalizations.of(context);
    final width = MediaQuery.of(context).size.width;
    final bool desktop = width >= 1100;

    if (!desktop) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(),
          if (_pendingExpenseReviews > 0) ...[
            const SizedBox(height: 16),
            _buildExpenseReviewAlertCard(),
          ],
          const SizedBox(height: 16),
          _buildSummaryGrid(),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('fiscal_dashboard'),
            subtitle: t.translate('current_month_tax_overview'),
            child: _buildFiscalDashboardSection(),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: t.translate('quick_access'),
            subtitle: t.translate('main_navigation_subtitle'),
            child: _buildActionShortcuts(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('financial_overview'),
            subtitle: t.translate('current_month_comparison'),
            child: _buildVerticalBarChart(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('latest_entries'),
            subtitle: t.translate('latest_five_records'),
            child: _buildRecentEntries(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('latest_expenses'),
            subtitle: t.translate('latest_five_records'),
            child: _buildRecentExpenses(),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroCard(),
        if (_pendingExpenseReviews > 0) ...[
          const SizedBox(height: 16),
          _buildExpenseReviewAlertCard(),
        ],
        const SizedBox(height: 16),
        _buildSummaryGrid(),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: t.translate('fiscal_dashboard'),
          subtitle: t.translate('current_month_tax_overview'),
          child: _buildFiscalDashboardSection(),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildSectionCard(
                    title: t.translate('quick_access'),
                    subtitle: t.translate('main_navigation_subtitle'),
                    child: _buildActionShortcuts(),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: t.translate('financial_overview'),
                    subtitle: t.translate('current_month_comparison'),
                    child: _buildVerticalBarChart(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _buildSectionCard(
                    title: t.translate('latest_entries'),
                    subtitle: t.translate('latest_five_records'),
                    child: _buildRecentEntries(),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: t.translate('latest_expenses'),
                    subtitle: t.translate('latest_five_records'),
                    child: _buildRecentExpenses(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

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
              icon: const Icon(Icons.settings),
              onPressed: _openSettingsDialog,
              tooltip: t.translate('settings'),
            ),
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
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsDialog,
            tooltip: t.translate('settings'),
          ),
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
        child: _buildMainContent(),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'entry',
            icon: const Icon(Icons.add),
            label: Text(t.translate('nav_entries')),
            onPressed: _openEntriesPage,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'expense',
            icon: const Icon(Icons.receipt),
            label: Text(t.translate('nav_expenses')),
            onPressed: _openExpensesPage,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'report',
            icon: const Icon(Icons.assessment),
            label: Text(t.translate('nav_reports')),
            onPressed: _openReportsPage,
          ),
        ],
      ),
    );
  }
}
