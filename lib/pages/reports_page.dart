import 'package:flutter/material.dart';

import '../data/supabase_service.dart';

/// Página de relatórios que exibe totais mensais e anuais de entradas e saídas.
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final entries = await SupabaseService.instance.fetchEntries();
    final expenses = await SupabaseService.instance.fetchExpenses();

    final Map<String, double> incomeByMonth = {};
    final Map<int, double> incomeByYear = {};
    for (final Map<String, dynamic> entry in entries) {
      final DateTime date = DateTime.parse(entry['date']);
      final String monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final int yearKey = date.year;
      final double amount = (entry['amount'] as num).toDouble();
      incomeByMonth[monthKey] = (incomeByMonth[monthKey] ?? 0) + amount;
      incomeByYear[yearKey] = (incomeByYear[yearKey] ?? 0) + amount;
    }

    final Map<String, double> expenseByMonth = {};
    final Map<int, double> expenseByYear = {};
    for (final Map<String, dynamic> expense in expenses) {
      final DateTime date = DateTime.parse(expense['date']);
      final String monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final int yearKey = date.year;
      final double amount = (expense['amount'] as num).toDouble();
      expenseByMonth[monthKey] = (expenseByMonth[monthKey] ?? 0) + amount;
      expenseByYear[yearKey] = (expenseByYear[yearKey] ?? 0) + amount;
    }

    setState(() {
      _monthlyIncome = incomeByMonth;
      _annualIncome = incomeByYear;
      _monthlyExpense = expenseByMonth;
      _annualExpense = expenseByYear;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Combine keys and sort them to display all months/years that have data.
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
          const Text(
            'Relatório Mensal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...allMonths.map((String month) {
            final double income = _monthlyIncome[month] ?? 0;
            final double expense = _monthlyExpense[month] ?? 0;
            final double balance = income - expense;
            return Card(
              child: ListTile(
                title: Text(month),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Entradas: ${income.toStringAsFixed(2)}'),
                    Text('Saídas: ${expense.toStringAsFixed(2)}'),
                    Text('Saldo: ${balance.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            'Relatório Anual',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...allYears.map((int year) {
            final double income = _annualIncome[year] ?? 0;
            final double expense = _annualExpense[year] ?? 0;
            final double balance = income - expense;
            return Card(
              child: ListTile(
                title: Text(year.toString()),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Entradas: ${income.toStringAsFixed(2)}'),
                    Text('Saídas: ${expense.toStringAsFixed(2)}'),
                    Text('Saldo: ${balance.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}