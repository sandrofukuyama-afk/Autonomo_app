import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'entries_page.dart';
import 'expenses_page.dart';
import 'expense_review_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';

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

  double _annualEntriesTotal = 0;
  double _annualExpensesTotal = 0;
  double _annualProfit = 0;
  double _annualEstimatedTax = 0;
  int _annualClosedMonthsCount = 0;
  int _annualOpenMonthsCount = 12;

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
      await _loadAnnualFiscalDashboard(companyId);

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

  Future<void> _loadAnnualFiscalDashboard(String companyId) async {
    final now = DateTime.now();
    final year = now.year;
    final yearStart = '$year-01-01';
    final nextYearStart = '${year + 1}-01-01';

    final List<dynamic> annualEntries = await _client
        .from('entries_v2')
        .select('amount')
        .eq('company_id', companyId)
        .gte('entry_date', yearStart)
        .lt('entry_date', nextYearStart);

    final List<dynamic> annualExpenses = await _client
        .from('expenses_v2')
        .select('amount')
        .eq('company_id', companyId)
        .gte('expense_date', yearStart)
        .lt('expense_date', nextYearStart);

    double entriesTotal = 0;
    for (final item in annualEntries) {
      entriesTotal += _toDouble((item as Map)['amount']);
    }

    double expensesTotal = 0;
    for (final item in annualExpenses) {
      expensesTotal += _toDouble((item as Map)['amount']);
    }

    final double annualProfit = entriesTotal - expensesTotal;
    final double taxableAnnualProfit = annualProfit > 0 ? annualProfit : 0.0;
    final double annualEstimatedTax =
        _estimateNationalTax(taxableAnnualProfit) +
            _estimateResidentTax(taxableAnnualProfit);

    final yearPrefix = '$year-';
    final int closedCount = _closedFiscalMonths
        .where((month) => month.startsWith(yearPrefix))
        .length;

    _annualEntriesTotal = entriesTotal;
    _annualExpensesTotal = expensesTotal;
    _annualProfit = annualProfit;
    _annualEstimatedTax = annualEstimatedTax;
    _annualClosedMonthsCount = closedCount.clamp(0, 12).toInt();
    _annualOpenMonthsCount =
        (12 - _annualClosedMonthsCount).clamp(0, 12).toInt();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double _estimateNationalTax(double profit) {
    if (profit <= 0) return 0;

    if (profit <= 1950000) return profit * 0.05;
    if (profit <= 3300000) return (profit * 0.10) - 97500;
    if (profit <= 6950000) return (profit * 0.20) - 427500;
    if (profit <= 9000000) return (profit * 0.23) - 636000;
    if (profit <= 18000000) return (profit * 0.33) - 1536000;
    if (profit <= 40000000) return (profit * 0.40) - 2796000;
    return (profit * 0.45) - 4796000;
  }

  double _estimateResidentTax(double profit) {
    if (profit <= 0) return 0;
    return profit * 0.10;
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

  Future<Map<String, dynamic>> _buildCurrentFiscalSnapshot() async {
    if (_companyId == null) {
      throw Exception('Company not found.');
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);

    final String monthLabel = _currentMonthLabel();
    final String startIso = monthStart.toIso8601String().split('T').first;
    final String endIso = nextMonthStart.toIso8601String().split('T').first;

    final List<dynamic> entries = await _client
        .from('entries_v2')
        .select('id, amount')
        .eq('company_id', _companyId!)
        .gte('entry_date', startIso)
        .lt('entry_date', endIso);

    final List<dynamic> expenses = await _client
        .from('expenses_v2')
        .select('id, amount')
        .eq('company_id', _companyId!)
        .gte('expense_date', startIso)
        .lt('expense_date', endIso);

    final List<dynamic> receipts = await _client
        .from('expense_receipts')
        .select(
            'id, expense_id, expenses_v2!inner(id, expense_date, company_id)')
        .eq('expenses_v2.company_id', _companyId!)
        .gte('expenses_v2.expense_date', startIso)
        .lt('expenses_v2.expense_date', endIso);

    double totalEntries = 0;
    for (final item in entries) {
      totalEntries += _toDouble((item as Map)['amount']);
    }

    double totalExpenses = 0;
    for (final item in expenses) {
      totalExpenses += _toDouble((item as Map)['amount']);
    }

    final double profit = totalEntries - totalExpenses;
    final double taxableProfit = profit > 0 ? profit : 0;
    final double estimatedNationalTax = taxableProfit * 0.10;
    final double estimatedResidentTax = taxableProfit * 0.10;
    final double estimatedTotalTax =
        estimatedNationalTax + estimatedResidentTax;

    return {
      'company_id': _companyId,
      'fiscal_month': monthLabel,
      'total_entries': totalEntries,
      'total_expenses': totalExpenses,
      'profit': profit,
      'estimated_national_tax': estimatedNationalTax,
      'estimated_resident_tax': estimatedResidentTax,
      'estimated_total_tax': estimatedTotalTax,
      'entries_count': entries.length,
      'expenses_count': expenses.length,
      'receipts_count': receipts.length,
      'closed_at': DateTime.now().toIso8601String(),
    };
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
      final snapshot = await _buildCurrentFiscalSnapshot();

      await _client
          .from('monthly_fiscal_snapshots')
          .upsert(snapshot, onConflict: 'company_id,fiscal_month');

      await _client
          .from('app_settings')
          .update({'closed_fiscal_months': updatedMonths})
          .eq('company_id', _companyId!);

      await _loadClosedFiscalMonths(_companyId!);
      await _loadAnnualFiscalDashboard(_companyId!);

      if (!mounted) return;

      setState(() {
        _closingFiscalMonth = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${t.translate('fiscal_month_closed_success')} $month.'),
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
      await _loadAnnualFiscalDashboard(_companyId!);

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

  Future<void> _openSettingsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );

    await _refreshDashboard();
  }

  String _apiBaseUrl() {
    final uri = Uri.base;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  String _currentLanguageCode() {
    final code = widget.currentLocale?.languageCode ?? 'pt';
    if (code == 'pt' || code == 'en' || code == 'ja' || code == 'es') {
      return code;
    }
    return 'pt';
  }

  String _helpButtonLabel() {
    switch (_currentLanguageCode()) {
      case 'ja':
        return '質問する';
      case 'en':
        return 'Ask AI';
      case 'es':
        return 'Sacar duda';
      default:
        return 'Tirar dúvida';
    }
  }

  String _helpDialogTitle() {
    switch (_currentLanguageCode()) {
      case 'ja':
        return 'AIに質問';
      case 'en':
        return 'Ask AI';
      case 'es':
        return 'Consultar IA';
      default:
        return 'Tirar dúvida';
    }
  }

  String _helpDialogHint() {
    switch (_currentLanguageCode()) {
      case 'ja':
        return 'アプリや日本の税務について質問してください';
      case 'en':
        return 'Ask about the app or taxes in Japan';
      case 'es':
        return 'Pregunta sobre la app o impuestos en Japón';
      default:
        return 'Pergunte sobre o app ou imposto no Japão';
    }
  }

  String _helpSendLabel() {
    switch (_currentLanguageCode()) {
      case 'ja':
        return 'Enviar';
      case 'en':
        return 'Send';
      case 'es':
        return 'Enviar';
      default:
        return 'Enviar';
    }
  }

  String _helpEmptyQuestionLabel() {
    switch (_currentLanguageCode()) {
      case 'ja':
        return 'Digite uma pergunta.';
      case 'en':
        return 'Type a question.';
      case 'es':
        return 'Escribe una pregunta.';
      default:
        return 'Digite uma pergunta.';
    }
  }

  String _helpErrorLabel() {
    switch (_currentLanguageCode()) {
      case 'ja':
        return 'Não foi possível obter resposta agora.';
      case 'en':
        return 'Could not get an answer right now.';
      case 'es':
        return 'No fue posible obtener respuesta ahora.';
      default:
        return 'Não foi possível obter resposta agora.';
    }
  }

  Future<String> _askAiHelp(String question) async {
    final response = await http.post(
      Uri.parse('${_apiBaseUrl()}/api/ai-help'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'question': question,
        'language': _currentLanguageCode(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_helpErrorLabel());
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final answer = (data['answer'] ?? '').toString().trim();

    if (answer.isEmpty) {
      throw Exception(_helpErrorLabel());
    }

    return answer;
  }

  Future<void> _openAiHelp() async {
    final TextEditingController questionController = TextEditingController();
    String answer = '';
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_helpDialogTitle()),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: questionController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: _helpDialogHint(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (sending)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (!sending && answer.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SelectableText(
                            answer,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    AppLocalizations.of(context).translate('cancel'),
                  ),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final question = questionController.text.trim();
                          if (question.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(_helpEmptyQuestionLabel()),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            sending = true;
                            answer = '';
                          });

                          try {
                            final result = await _askAiHelp(question);
                            setDialogState(() {
                              answer = result;
                              sending = false;
                            });
                          } catch (e) {
                            setDialogState(() {
                              sending = false;
                              answer = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: Text(_helpSendLabel()),
                ),
              ],
            );
          },
        );
      },
    );

    questionController.dispose();
  }

  Widget _buildHeroCard() {
    final t = AppLocalizations.of(context);
    final bool positive = _monthProfit >= 0;
    final bool currentMonthClosed = _isCurrentFiscalMonthClosed();

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
              _heroChip(
                icon: currentMonthClosed ? Icons.lock : Icons.lock_open,
                label: currentMonthClosed
                    ? t.translate('status_closed')
                    : t.translate('status_open'),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        'label':
            _monthProfit >= 0 ? t.translate('result') : t.translate('loss'),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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

  Widget _buildAnnualFiscalDashboardSection() {
    final now = DateTime.now();
    final width = MediaQuery.of(context).size.width;
    final bool wide = width >= 900;

    final children = [
      _buildFiscalSummaryCard(
        icon: Icons.calendar_month,
        iconColor: Colors.green.shade800,
        iconBackground: Colors.green.shade100,
        title: 'Receitas ${now.year}',
        value: _formatYen(_annualEntriesTotal),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.receipt_long,
        iconColor: Colors.red.shade800,
        iconBackground: Colors.red.shade100,
        title: 'Despesas ${now.year}',
        value: _formatYen(_annualExpensesTotal),
      ),
      _buildFiscalSummaryCard(
        icon: _annualProfit >= 0 ? Icons.savings : Icons.warning_amber,
        iconColor:
            _annualProfit >= 0 ? Colors.blue.shade800 : Colors.orange.shade800,
        iconBackground:
            _annualProfit >= 0 ? Colors.blue.shade100 : Colors.orange.shade100,
        title: 'Lucro ${now.year}',
        value: _formatYen(_annualProfit),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.account_balance,
        iconColor: Colors.indigo.shade800,
        iconBackground: Colors.indigo.shade100,
        title: 'Imposto estimado ${now.year}',
        value: _formatYen(_annualEstimatedTax),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.lock_outline,
        iconColor: Colors.green.shade800,
        iconBackground: Colors.green.shade100,
        title: 'Meses fechados',
        value: _annualClosedMonthsCount.toString(),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.lock_open,
        iconColor: Colors.orange.shade800,
        iconBackground: Colors.orange.shade100,
        title: 'Meses em aberto',
        value: _annualOpenMonthsCount.toString(),
      ),
    ];

    if (wide) {
      return GridView.builder(
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
      );
    }

    return Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 12),
        ],
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
          const SizedBox(height: 12),
          _buildSectionCard(
            title: 'Dashboard fiscal anual',
            subtitle: 'Resumo consolidado do ano atual',
            child: _buildAnnualFiscalDashboardSection(),
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
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Dashboard fiscal anual',
          subtitle: 'Resumo consolidado do ano atual',
          child: _buildAnnualFiscalDashboardSection(),
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
              onPressed: _openSettingsPage,
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
            onPressed: _openSettingsPage,
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
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'ai_help',
            icon: const Icon(Icons.smart_toy_outlined),
            label: Text(_helpButtonLabel()),
            onPressed: _openAiHelp,
          ),
        ],
      ),
    );
  }
}
