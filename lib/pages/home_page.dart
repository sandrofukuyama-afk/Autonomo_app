import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../data/auth_service.dart';
import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'entries_page.dart';
import 'expenses_page.dart';
import 'expense_review_page.dart';
import 'receipt_issue_page.dart';
import 'receipt_history_page.dart';
import 'accounts_receivable_page.dart';
import 'clients_page.dart';
import 'client_history_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import 'settings_categories_page.dart';

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
  String? _businessName;
  // ignore: unused_field
  String? _fullName;
  bool _isAdmin = false;
  bool _isTestModeEnabled = false;
  String? _error;

  int _pendingExpenseReviews = 0;

  double _monthEntriesTotal = 0;
  double _monthExpensesTotal = 0;
  double _monthProfit = 0;
  double _monthReceivableTotal = 0;
  int _monthSeikyushoDueCount = 0;
  double _monthSeikyushoDueTotal = 0;

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
    _isTestModeEnabled = SupabaseService.instance.isTestModeEnabled;
    _initializeDashboard();
  }

  Future<void> _setTestModeEnabled(bool value) async {
    await SupabaseService.instance.setTestModeEnabled(value);
    if (!mounted) return;

    setState(() {
      _isTestModeEnabled = SupabaseService.instance.isTestModeEnabled;
    });
  }

  Future<void> _initializeDashboard() async {
    try {
      final String companyId =
          await AuthService.instance.getCurrentCompanyId(forceRefresh: true);
      final String businessName = await AuthService.instance.getCurrentBusinessName();
      final String fullName = await AuthService.instance.getCurrentFullName();
      final String role = await AuthService.instance.getCurrentRole(
        forceRefresh: true,
      );

      await _loadDashboard(companyId);
      await _loadExpenseReviewCount(companyId);
      await _loadFiscalDashboard(companyId);
      await _loadClosedFiscalMonths(companyId);
      await _loadAnnualFiscalDashboard(companyId);

      if (!mounted) return;

      setState(() {
        _companyId = companyId;
        _businessName = businessName;
        _fullName = fullName;
        _isAdmin = role == AppRoles.admin;
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
    final List<dynamic> monthSchedules = await _client
        .from('receipt_payment_schedules')
        .select('amount, status, due_date, receipts!inner(document_kind)')
        .eq('company_id', companyId)
        .gte('due_date', startIso)
        .lt('due_date', endIso);

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
    _monthReceivableTotal = 0;
    _monthSeikyushoDueCount = 0;
    _monthSeikyushoDueTotal = 0;

    for (final raw in monthSchedules) {
      final item = Map<String, dynamic>.from(raw as Map);
      final status = (item['status'] ?? '').toString().toLowerCase();
      final amount = _toDouble(item['amount']);

      if (status != 'paid') {
        _monthReceivableTotal += amount;
      }

      final receipt = item['receipts'];
      Map<String, dynamic> receiptMap = {};
      if (receipt is Map) {
        receiptMap = Map<String, dynamic>.from(receipt);
      } else if (receipt is List && receipt.isNotEmpty && receipt.first is Map) {
        receiptMap = Map<String, dynamic>.from(receipt.first as Map);
      }

      if ((receiptMap['document_kind'] ?? '').toString() == 'seikyuusho') {
        _monthSeikyushoDueCount += 1;
        _monthSeikyushoDueTotal += amount;
      }
    }

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

    return '${negative ? '-' : ''}Â¥${buffer.toString()}';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  String _entryCategoryLabel(AppLocalizations t, dynamic value) {
    final code = (value ?? '').toString().trim().toLowerCase();
    switch (code) {
      case 'service':
        return t.translate('entry_category_service');
      case 'sale':
      case 'product':
        return t.translate('entry_category_sale');
      case 'commission':
        return t.translate('entry_category_commission');
      case 'refund':
        return t.translate('entry_category_refund');
      case 'other':
        return t.translate('entry_category_other');
      default:
        return code.isEmpty ? t.translate('no_category') : code;
    }
  }

  String _expenseCategoryLabel(AppLocalizations t, dynamic value) {
    final code = (value ?? '').toString().trim().toLowerCase();
    switch (code) {
      case 'food':
      case 'transport':
      case 'housing':
      case 'entertainment':
      case 'health':
      case 'other':
        return t.translate('category_$code');
      case 'rent':
        return t.translate('category_housing');
      case 'services':
      case 'fees':
        return t.translate('category_other');
      default:
        return code.isEmpty ? t.translate('no_category') : code;
    }
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

  // ignore: unused_element
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
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onLocaleChanged: widget.onLocaleChanged,
        ),
      ),
    );

    await _refreshDashboard();
  }

  Future<void> _openReceiptIssuePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceiptIssuePage(),
      ),
    );
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
    final t = AppLocalizations.of(context);
    return t.translate('ask_ai');
  }

  String _receiptShortcutSubtitle() {
    switch (widget.currentLocale?.languageCode) {
      case 'ja':
        return 'PDFé ˜åŽæ›¸ã‚’ä½œæˆã—ã¦ä¿å­˜';
      case 'es':
        return 'Crear y guardar recibos en PDF';
      case 'en':
        return 'Create and save PDF receipts';
      default:
        return 'Criar e salvar recibos em PDF';
    }
  }

  String _translatedOrEnglish(AppLocalizations t, String key) {
    final translated = t.translate(key);
    if (translated == key) {
      return t.translateWithLocale(key, 'en');
    }
    return translated;
  }

  String _roleLabel(AppLocalizations t) {
    return _isAdmin
        ? _adminText(t, 'admin_role_label')
        : _adminText(t, 'member_role_label');
  }

  String _adminText(AppLocalizations t, String key) {
    return _translatedOrEnglish(t, key);
  }

  Future<void> _showAdminAccessDialog() async {
    final t = AppLocalizations.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_adminText(t, 'admin_access_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_adminText(t, 'admin_access_description')),
              const SizedBox(height: 12),
              Text('${t.translate('auth_email')}: ${currentUserEmail ?? '-'}'),
              const SizedBox(height: 6),
              Text('${_adminText(t, 'access_level_label')}: ${_roleLabel(t)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t.translate('cancel')),
            ),
          ],
        );
      },
    );
  }

  String? get currentUserEmail => AuthService.instance.currentUser?.email;

  String _helpDialogTitle() {
    final t = AppLocalizations.of(context);
    return t.translate('ask_ai_title');
  }

  String _helpDialogHint() {
    final t = AppLocalizations.of(context);
    return t.translate('ask_ai_hint');
  }

  String _helpSendLabel() {
    final t = AppLocalizations.of(context);
    return t.translate('send');
  }

  String _helpEmptyQuestionLabel() {
    final t = AppLocalizations.of(context);
    return t.translate('type_question');
  }

  String _helpErrorLabel() {
    final t = AppLocalizations.of(context);
    return t.translate('ai_answer_error');
  }

  String _cleanAiAnswer(String value) {
    var text = value.trim();

    if (text.isEmpty) return text;

    text = text.replaceAll('\r\n', '\n');
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    text = text.replaceAll('### ', '');
    text = text.replaceAll('## ', '');
    text = text.replaceAll('# ', '');
    text =
        text.replaceAllMapped(RegExp(r'^\s*-\s+', multiLine: true), (_) => 'â€¢ ');
    text =
        text.replaceAllMapped(RegExp(r'^\s*\*\s+', multiLine: true), (_) => 'â€¢ ');
    text = text.replaceAllMapped(
      RegExp(r'^\s*(\d+)\.\s+\*\*(.+?)\*\*', multiLine: true),
      (m) => '${m.group(1)}. ${m.group(2)}',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*(\d+)\.\s+', multiLine: true),
      (m) => '${m.group(1)}. ',
    );
    text = text.replaceAllMapped(
      RegExp(r'\n{3,}'),
      (_) => '\n\n',
    );

    return text.trim();
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

    return _cleanAiAnswer(answer);
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
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.55,
                            ),
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
                              answer =
                                  e.toString().replaceFirst('Exception: ', '');
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
            (_businessName != null && _businessName!.isNotEmpty)
                ? _businessName!
                : t.translate('financial_dashboard'),
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
              color: Colors.white.withValues(alpha: 0.85),
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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

  // ignore: unused_element
  Widget _buildFiscalLockBanner() {
    final t = AppLocalizations.of(context);
    final currentClosed = _isCurrentFiscalMonthClosed();
    final month = _currentMonthLabel();

    final title = currentClosed
        ? t.translate('fiscal_month_closed_banner_title')
        : t.translate('fiscal_month_open_banner_title');

    final description = currentClosed
        ? t.translateWithParams(
            'fiscal_month_closed_banner_description',
            {'month': month},
          )
        : t.translateWithParams(
            'fiscal_month_open_banner_description',
            {'month': month},
          );

    final Color bgColor =
        currentClosed ? Colors.red.shade50 : Colors.amber.shade50;
    final Color borderColor =
        currentClosed ? Colors.red.shade200 : Colors.amber.shade200;
    final Color iconBgColor =
        currentClosed ? Colors.red.shade100 : Colors.amber.shade100;
    final Color iconColor =
        currentClosed ? Colors.red.shade800 : Colors.amber.shade900;
    final Color textColor =
        currentClosed ? Colors.red.shade900 : Colors.orange.shade900;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              currentClosed ? Icons.lock_clock_outlined : Icons.info_outline,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: currentClosed
                            ? Colors.red.shade100
                            : Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        month,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: textColor,
                  ),
                ),
              ],
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
      {
        'title': t.translate('issue_receipt'),
        'subtitle': _receiptShortcutSubtitle(),
        'icon': Icons.receipt_outlined,
        'color': Colors.orange,
        'onTap': _openReceiptIssuePage,
      },
    ];

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1000 ? 4 : width >= 650 ? 2 : 1;
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
                    backgroundColor: color.withValues(alpha: 0.12),
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
                      '${_formatDate(item['entry_date'])} • ${_entryCategoryLabel(t, item['category'])}',
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
                      '${_formatDate(item['expense_date'])} • ${storeName.isNotEmpty ? storeName : _expenseCategoryLabel(t, item['category'])}',
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
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                  ),
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

  Widget _buildSystemStatusLine({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconBackground,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSystemStatusCard() {
    final t = AppLocalizations.of(context);
    final currentMonthClosed = _isCurrentFiscalMonthClosed();
    final backupLabel = t.translate('active_daily');
    final databaseLabel = t.translate('connected_isolated_company');
    final fiscalLabel = currentMonthClosed
        ? t.translate('current_month_protected_fiscal_lock')
        : t.translate('fiscal_lock_active_monthly_closing');

    return Column(
      children: [
        _buildSystemStatusLine(
          icon: Icons.backup_outlined,
          iconColor: Colors.blue.shade800,
          iconBackground: Colors.blue.shade100,
          title: t.translate('automatic_backup'),
          value: backupLabel,
        ),
        const SizedBox(height: 12),
        _buildSystemStatusLine(
          icon: Icons.storage_rounded,
          iconColor: Colors.green.shade800,
          iconBackground: Colors.green.shade100,
          title: t.translate('database'),
          value: databaseLabel,
        ),
        const SizedBox(height: 12),
        _buildSystemStatusLine(
          icon: currentMonthClosed ? Icons.lock_outline : Icons.verified_user,
          iconColor:
              currentMonthClosed ? Colors.orange.shade800 : Colors.indigo.shade800,
          iconBackground:
              currentMonthClosed ? Colors.orange.shade100 : Colors.indigo.shade100,
          title: t.translate('fiscal_security'),
          value: fiscalLabel,
        ),
      ],
    );
  }

  Widget _buildReceivablesMonthSection() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 700;
    final t = AppLocalizations.of(context);
    final seikyushoValue =
        '${_monthSeikyushoDueCount} - ${_formatYen(_monthSeikyushoDueTotal)}';

    if (compact) {
      return Column(
        children: [
          _buildFiscalSummaryCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: Colors.orange.shade800,
            iconBackground: Colors.orange.shade100,
            title: t.translate('receivable_due_this_month'),
            value: _formatYen(_monthReceivableTotal),
          ),
          const SizedBox(height: 10),
          _buildFiscalSummaryCard(
            icon: Icons.request_quote_outlined,
            iconColor: Colors.blue.shade800,
            iconBackground: Colors.blue.shade100,
            title: t.translate('seikyusho_due_this_month'),
            value: seikyushoValue,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildFiscalSummaryCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: Colors.orange.shade800,
            iconBackground: Colors.orange.shade100,
            title: t.translate('receivable_due_this_month'),
            value: _formatYen(_monthReceivableTotal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildFiscalSummaryCard(
            icon: Icons.request_quote_outlined,
            iconColor: Colors.blue.shade800,
            iconBackground: Colors.blue.shade100,
            title: t.translate('seikyusho_due_this_month'),
            value: seikyushoValue,
          ),
        ),
      ],
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
                          : Colors.white.withValues(alpha: 0.7),
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
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final width = MediaQuery.of(context).size.width;
    final bool wide = width >= 900;

    final children = [
      _buildFiscalSummaryCard(
        icon: Icons.calendar_month,
        iconColor: Colors.green.shade800,
        iconBackground: Colors.green.shade100,
        title: '${t.translate('annual_revenue')} ${now.year}',
        value: _formatYen(_annualEntriesTotal),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.receipt_long,
        iconColor: Colors.red.shade800,
        iconBackground: Colors.red.shade100,
        title: '${t.translate('annual_expenses')} ${now.year}',
        value: _formatYen(_annualExpensesTotal),
      ),
      _buildFiscalSummaryCard(
        icon: _annualProfit >= 0 ? Icons.savings : Icons.warning_amber,
        iconColor:
            _annualProfit >= 0 ? Colors.blue.shade800 : Colors.orange.shade800,
        iconBackground:
            _annualProfit >= 0 ? Colors.blue.shade100 : Colors.orange.shade100,
        title: '${t.translate('annual_profit')} ${now.year}',
        value: _formatYen(_annualProfit),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.account_balance,
        iconColor: Colors.indigo.shade800,
        iconBackground: Colors.indigo.shade100,
        title: '${t.translate('annual_estimated_tax')} ${now.year}',
        value: _formatYen(_annualEstimatedTax),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.lock_outline,
        iconColor: Colors.green.shade800,
        iconBackground: Colors.green.shade100,
        title: t.translate('closed_months'),
        value: _annualClosedMonthsCount.toString(),
      ),
      _buildFiscalSummaryCard(
        icon: Icons.lock_open,
        iconColor: Colors.orange.shade800,
        iconBackground: Colors.orange.shade100,
        title: t.translate('open_months'),
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

  Widget _buildAdminAccessBanner() {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.amber.shade900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _adminText(t, 'admin_access_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _adminText(t, 'admin_access_description'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.verified_user, size: 18),
                      label: Text(_roleLabel(t)),
                    ),
                    if (currentUserEmail != null && currentUserEmail!.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.email_outlined, size: 18),
                        label: Text(currentUserEmail!),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    _adminText(t, 'test_mode_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_adminText(t, 'test_mode_description')),
                  value: _isTestModeEnabled,
                  onChanged: _setTestModeEnabled,
                  activeThumbColor: Colors.amber.shade900,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
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
          if (_isAdmin) ...[
            const SizedBox(height: 14),
            _buildAdminAccessBanner(),
          ],
          if (_pendingExpenseReviews > 0) ...[
            const SizedBox(height: 16),
            _buildExpenseReviewAlertCard(),
          ],
          const SizedBox(height: 16),
          _buildSummaryGrid(),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('receivables_current_month_title'),
            subtitle: t.translate('receivables_current_month_subtitle'),
            child: _buildReceivablesMonthSection(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('fiscal_dashboard'),
            subtitle: t.translate('current_month_tax_overview'),
            child: _buildFiscalDashboardSection(),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: t.translate('annual_fiscal_dashboard'),
            subtitle: t.translate('annual_summary_current_year'),
            child: _buildAnnualFiscalDashboardSection(),
          ),
          const SizedBox(height: 12),
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
        if (_isAdmin) ...[
          const SizedBox(height: 14),
          _buildAdminAccessBanner(),
        ],
        if (_pendingExpenseReviews > 0) ...[
          const SizedBox(height: 16),
          _buildExpenseReviewAlertCard(),
        ],
        const SizedBox(height: 16),
        _buildSummaryGrid(),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: t.translate('receivables_current_month_title'),
          subtitle: t.translate('receivables_current_month_subtitle'),
          child: _buildReceivablesMonthSection(),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: t.translate('fiscal_dashboard'),
          subtitle: t.translate('current_month_tax_overview'),
          child: _buildFiscalDashboardSection(),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: t.translate('annual_fiscal_dashboard'),
          subtitle: t.translate('annual_summary_current_year'),
          child: _buildAnnualFiscalDashboardSection(),
        ),
        const SizedBox(height: 12),
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

  Widget _buildDrawer(BuildContext context) {
    final t = AppLocalizations.of(context);
    final email = currentUserEmail ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text((_businessName != null && _businessName!.isNotEmpty)
                ? _businessName!
                : 'Autonomo App'),
            accountEmail: Text(email),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.business, color: Colors.blue, size: 32),
            ),
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: Text(t.translate('nav_entries')),
            onTap: () {
              Navigator.pop(context);
              _openEntriesPage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: Colors.red),
            title: Text(t.translate('nav_expenses')),
            onTap: () {
              Navigator.pop(context);
              _openExpensesPage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_outlined, color: Colors.orange),
            title: Text(t.translate('issue_receipt')),
            onTap: () {
              Navigator.pop(context);
              _openReceiptIssuePage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline, color: Colors.blue),
            title: Text(t.translate('clients_title')),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ClientsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_search_outlined, color: Colors.indigo),
            title: Text(t.translate('client_history')),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ClientHistoryPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.teal),
            title: Text(t.translate('accounts_receivable')),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountsReceivablePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined, color: Colors.brown),
            title: Text(t.translate('receipt_history')),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReceiptHistoryPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assessment_outlined, color: Colors.purple),
            title: Text(t.translate('nav_reports')),
            onTap: () {
              Navigator.pop(context);
              _openReportsPage();
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.folder_open_outlined, color: Colors.blueGrey),
            title: Text(t.translate('registry')),
            children: [
              ListTile(
                leading: const Icon(Icons.category_outlined, color: Colors.indigo),
                title: Text(t.translate('categories')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsCategoriesPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(_helpButtonLabel()),
            onTap: () {
              Navigator.pop(context);
              _openAiHelp();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(t.translate('settings')),
            onTap: () {
              Navigator.pop(context);
              _openSettingsPage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: Text(t.translate('logout')),
            onTap: () {
              Navigator.pop(context);
              _handleLogout();
            },
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                  title: Text(t.translate('nav_entries'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _openEntriesPage();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.remove, color: Colors.white),
                  ),
                  title: Text(t.translate('nav_expenses'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _openExpensesPage();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.receipt, color: Colors.white),
                  ),
                  title: Text(t.translate('issue_receipt'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _openReceiptIssuePage();
                  },
                ),
              ],
            ),
          ),
        );
      },
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
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: _showAdminAccessDialog,
                tooltip: _adminText(t, 'admin_role_label'),
              ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsPage,
            tooltip: t.translate('settings'),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_outlined),
            onPressed: _openReceiptIssuePage,
            tooltip: t.translate('issue_receipt'),
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
        title: Text(
          (_businessName != null && _businessName!.isNotEmpty)
              ? _businessName!
              : 'Autonomo App',
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: _showAdminAccessDialog,
              tooltip: _adminText(t, 'admin_role_label'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDashboard,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: _buildMainContent(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}


