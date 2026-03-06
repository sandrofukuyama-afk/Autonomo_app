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

  Map<String, double> _monthlyIncome = {};
  Map<String, double> _monthlyExpense = {};
  Map<int, double> _annualIncome = {};
  Map<int, double> _annualExpense = {};

  Map<String, Map<String, double>> _monthlyCategoryExpense = {};
  Map<int, Map<String, double>> _annualCategoryExpense = {};

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

    final Map<String, double> incomeByMonth = {};
    final Map<int, double> incomeByYear = {};

    for (final entry in entries) {
      final DateTime date = DateTime.parse(entry['date'].toString());
      final String monthKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final int yearKey = date.year;
      final double amount = (entry['amount'] as num).toDouble();

      incomeByMonth[monthKey] = (incomeByMonth[monthKey] ?? 0) + amount;
      incomeByYear[yearKey] = (incomeByYear[yearKey] ?? 0) + amount;
    }

    final Map<String, double> expenseByMonth = {};
    final Map<int, double> expenseByYear = {};
    final Map<String, Map<String, double>> expenseCategoryByMonth = {};
    final Map<int, Map<String, double>> expenseCategoryByYear = {};

    for (final expense in expenses) {
      final DateTime date = DateTime.parse(expense['date'].toString());
      final String monthKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final int yearKey = date.year;
      final double amount = (expense['amount'] as num).toDouble();

      expenseByMonth[monthKey] = (expenseByMonth[monthKey] ?? 0) + amount;
      expenseByYear[yearKey] = (expenseByYear[yearKey] ?? 0) + amount;

      final String category = (expense['category'] ?? 'Outros').toString();

      final monthMap =
          expenseCategoryByMonth.putIfAbsent(monthKey, () => <String, double>{});
      monthMap[category] = (monthMap[category] ?? 0) + amount;

      final yearMap =
          expenseCategoryByYear.putIfAbsent(yearKey, () => <String, double>{});
      yearMap[category] = (yearMap[category] ?? 0) + amount;
    }

    if (!mounted) return;

    setState(() {
      _monthlyIncome = incomeByMonth;
      _annualIncome = incomeByYear;
      _monthlyExpense = expenseByMonth;
      _annualExpense = expenseByYear;
      _monthlyCategoryExpense = expenseCategoryByMonth;
      _annualCategoryExpense = expenseCategoryByYear;
      _loading = false;
    });
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
      ..sort();

    final List<int> allYears = {
      ..._annualIncome.keys,
      ..._annualExpense.keys,
    }.toList()
      ..sort();

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
            final double income = _monthlyIncome[month] ?? 0;
            final double expense = _monthlyExpense[month] ?? 0;
            final double balance = income - expense;
            final Map<String, double> categoryMap =
                _monthlyCategoryExpense[month] ?? {};

            return Card(
              child: ExpansionTile(
                title: Text(month),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${localizations.translate('income')}: ${income.toStringAsFixed(2)}',
                    ),
                    Text(
                      '${localizations.translate('expenses')}: ${expense.toStringAsFixed(2)}',
                    ),
                    Text(
                      '${localizations.translate('balance')}: ${balance.toStringAsFixed(2)}',
                    ),
                  ],
                ),
                children: [
                  if (categoryMap.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: categoryMap.entries.map((entry) {
                          final String categoryKey =
                              _categoryKeyMapping[entry.key] ?? entry.key;
                          final String categoryLabel =
                              localizations.translate(categoryKey);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(categoryLabel),
                              Text(entry.value.toStringAsFixed(2)),
                            ],
                          );
                        }).toList(),
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
            final double income = _annualIncome[year] ?? 0;
            final double expense = _annualExpense[year] ?? 0;
            final double balance = income - expense;
            final Map<String, double> categoryMap =
                _annualCategoryExpense[year] ?? {};

            return Card(
              child: ExpansionTile(
                title: Text(year.toString()),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${localizations.translate('income')}: ${income.toStringAsFixed(2)}',
                    ),
                    Text(
                      '${localizations.translate('expenses')}: ${expense.toStringAsFixed(2)}',
                    ),
                    Text(
                      '${localizations.translate('balance')}: ${balance.toStringAsFixed(2)}',
                    ),
                  ],
                ),
                children: [
                  if (categoryMap.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: categoryMap.entries.map((entry) {
                          final String categoryKey =
                              _categoryKeyMapping[entry.key] ?? entry.key;
                          final String categoryLabel =
                              localizations.translate(categoryKey);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(categoryLabel),
                              Text(entry.value.toStringAsFixed(2)),
                            ],
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
