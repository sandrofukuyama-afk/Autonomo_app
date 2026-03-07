import 'package:flutter/material.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;

  Map<String, int> _monthlyIncome = {};
  Map<String, int> _monthlyExpense = {};
  Map<int, int> _annualIncome = {};
  Map<int, int> _annualExpense = {};

  Map<String, Map<String, int>> _monthlyCategoryExpense = {};
  Map<int, Map<String, int>> _annualCategoryExpense = {};

  Map<String, List<Map<String, dynamic>>> _monthlyExpenseItems = {};

  static const Map<String, String> _categoryKeyMapping = {
    'Alimentação': 'category_food',
    'Transporte': 'category_transport',
    'Moradia': 'category_housing',
    'Entretenimento': 'category_entertainment',
    'Saúde': 'category_health',
    'Outros': 'category_other',
    'category_food': 'category_food',
    'category_transport': 'category_transport',
    'category_housing': 'category_housing',
    'category_entertainment': 'category_entertainment',
    'category_health': 'category_health',
    'category_other': 'category_other',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _yen(num value) {
    final formatted = value.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '¥ $formatted';
  }

  Future<void> _loadData() async {
    final List<dynamic> entriesRaw = await SupabaseService.instance.getEntries();
    final List<dynamic> expensesRaw =
        await SupabaseService.instance.getExpenses();

    final List<Map<String, dynamic>> entries = entriesRaw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final List<Map<String, dynamic>> expenses = expensesRaw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final Map<String, int> incomeByMonth = {};
    final Map<int, int> incomeByYear = {};

    for (final entry in entries) {
      final DateTime date = DateTime.parse(entry['date'].toString());
      final String monthKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final int yearKey = date.year;
      final int amount = (entry['amount'] as num).toInt();

      incomeByMonth[monthKey] = (incomeByMonth[monthKey] ?? 0) + amount;
      incomeByYear[yearKey] = (incomeByYear[yearKey] ?? 0) + amount;
    }

    final Map<String, int> expenseByMonth = {};
    final Map<int, int> expenseByYear = {};
    final Map<String, Map<String, int>> expenseCategoryByMonth = {};
    final Map<int, Map<String, int>> expenseCategoryByYear = {};
    final Map<String, List<Map<String, dynamic>>> expenseItemsByMonth = {};

    for (final expense in expenses) {
      final DateTime date = DateTime.parse(expense['date'].toString());
      final String monthKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final int yearKey = date.year;
      final int amount = (expense['amount'] as num).toInt();

      expenseByMonth[monthKey] = (expenseByMonth[monthKey] ?? 0) + amount;
      expenseByYear[yearKey] = (expenseByYear[yearKey] ?? 0) + amount;

      final String category = (expense['category'] ?? 'Outros').toString();

      final monthMap =
          expenseCategoryByMonth.putIfAbsent(monthKey, () => <String, int>{});
      monthMap[category] = (monthMap[category] ?? 0) + amount;

      final yearMap =
          expenseCategoryByYear.putIfAbsent(yearKey, () => <String, int>{});
      yearMap[category] = (yearMap[category] ?? 0) + amount;

      final monthItems =
          expenseItemsByMonth.putIfAbsent(monthKey, () => <Map<String, dynamic>>[]);
      monthItems.add(expense);
    }

    for (final item in expenseItemsByMonth.values) {
      item.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
    }

    if (!mounted) return;

    setState(() {
      _monthlyIncome = incomeByMonth;
      _annualIncome = incomeByYear;
      _monthlyExpense = expenseByMonth;
      _annualExpense = expenseByYear;
      _monthlyCategoryExpense = expenseCategoryByMonth;
      _annualCategoryExpense = expenseCategoryByYear;
      _monthlyExpenseItems = expenseItemsByMonth;
      _loading = false;
    });
  }

  void _showReceipt(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Recibo'),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Não foi possível carregar o recibo.'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseItem(
    AppLocalizations localizations,
    Map<String, dynamic> item,
  ) {
    final String description =
        (item['description'] ?? '').toString().trim().isEmpty
            ? '-'
            : item['description'].toString().trim();

    final int amount = (item['amount'] as num).toInt();
    final String categoryRaw = (item['category'] ?? 'Outros').toString();
    final String categoryKey = _categoryKeyMapping[categoryRaw] ?? categoryRaw;
    final String categoryLabel = localizations.translate(categoryKey);
    final String date = item['date'].toString();
    final String? receiptUrl = item['receipt_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$date  •  $categoryLabel',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _yen(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (receiptUrl != null && receiptUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showReceipt(receiptUrl),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ver recibo'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final AppLocalizations localizations = AppLocalizations.of(context);

    final List<String> allMonths = {
      ..._monthlyIncome.keys,
      ..._monthlyExpense.keys,
    }.toList()
      ..sort()
      ..reverse();

    final List<int> allYears = {
      ..._annualIncome.keys,
      ..._annualExpense.keys,
    }.toList()
      ..sort()
      ..reverse();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.translate('monthly_report'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...allMonths.map((month) {
            final int income = _monthlyIncome[month] ?? 0;
            final int expense = _monthlyExpense[month] ?? 0;
            final int balance = income - expense;
            final Map<String, int> categoryMap =
                _monthlyCategoryExpense[month] ?? {};
            final List<Map<String, dynamic>> expenseItems =
                _monthlyExpenseItems[month] ?? [];

            return Card(
              child: ExpansionTile(
                title: Text(month),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${localizations.translate('income')}: ${_yen(income)}'),
                      Text('${localizations.translate('expenses')}: ${_yen(expense)}'),
                      Text('${localizations.translate('balance')}: ${_yen(balance)}'),
                    ],
                  ),
                ),
                children: [
                  if (categoryMap.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          const Text(
                            'Categorias',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...categoryMap.entries.map((entry) {
                            final String categoryKey =
                                _categoryKeyMapping[entry.key] ?? entry.key;
                            final String categoryLabel =
                                localizations.translate(categoryKey);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(categoryLabel),
                                  Text(_yen(entry.value)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  if (expenseItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Despesas do mês',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...expenseItems.map(
                            (item) => _buildExpenseItem(localizations, item),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            localizations.translate('annual_report'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...allYears.map((year) {
            final int income = _annualIncome[year] ?? 0;
            final int expense = _annualExpense[year] ?? 0;
            final int balance = income - expense;
            final Map<String, int> categoryMap =
                _annualCategoryExpense[year] ?? {};

            return Card(
              child: ExpansionTile(
                title: Text(year.toString()),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${localizations.translate('income')}: ${_yen(income)}'),
                      Text('${localizations.translate('expenses')}: ${_yen(expense)}'),
                      Text('${localizations.translate('balance')}: ${_yen(balance)}'),
                    ],
                  ),
                ),
                children: [
                  if (categoryMap.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: categoryMap.entries.map((entry) {
                          final String categoryKey =
                              _categoryKeyMapping[entry.key] ?? entry.key;
                          final String categoryLabel =
                              localizations.translate(categoryKey);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(categoryLabel),
                                Text(_yen(entry.value)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
