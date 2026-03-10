import 'package:flutter/material.dart';
import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../data/report_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;

  int _totalIncome = 0;
  int _totalDeductibleExpense = 0;
  int _pendingReview = 0;
  int _missingReceipt = 0;

  Map<String, int> _monthlyIncome = {};
  Map<String, int> _monthlyExpense = {};
  Map<int, int> _annualIncome = {};
  Map<int, int> _annualExpense = {};

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
    final entries = await SupabaseService.instance.getEntries();
    final expenses = await SupabaseService.instance.getExpenses();

    int incomeTotal = 0;
    int deductibleTotal = 0;
    int review = 0;
    int noReceipt = 0;

    final Map<String, int> incomeByMonth = {};
    final Map<int, int> incomeByYear = {};

    for (final entry in entries) {
      final date = DateTime.parse(entry['date']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final yearKey = date.year;
      final amount = (entry['amount'] as num).toInt();

      incomeTotal += amount;

      incomeByMonth[monthKey] = (incomeByMonth[monthKey] ?? 0) + amount;
      incomeByYear[yearKey] = (incomeByYear[yearKey] ?? 0) + amount;
    }

    final Map<String, int> expenseByMonth = {};
    final Map<int, int> expenseByYear = {};

    for (final expense in expenses) {
      final date = DateTime.parse(expense['date']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final yearKey = date.year;

      final amount = (expense['amount'] as num).toDouble();
      final status = expense['deductibility_status'];
      final deductibleAmount = expense['deductible_amount'];
      final businessPercent = expense['business_use_percent'];

      double fiscalAmount = 0;

      if (status == 'deductible_full') {
        fiscalAmount = amount;
      } else if (status == 'deductible_partial') {
        if (deductibleAmount != null) {
          fiscalAmount = (deductibleAmount as num).toDouble();
        } else if (businessPercent != null) {
          fiscalAmount = amount * ((businessPercent as num).toDouble() / 100);
        }
      } else if (status == 'review_required') {
        review++;
      }

      if (expense['receipt_status'] != 'uploaded') {
        noReceipt++;
      }

      final fiscalInt = fiscalAmount.round();

      deductibleTotal += fiscalInt;

      expenseByMonth[monthKey] =
          (expenseByMonth[monthKey] ?? 0) + fiscalInt;

      expenseByYear[yearKey] =
          (expenseByYear[yearKey] ?? 0) + fiscalInt;
    }

    if (!mounted) return;

    setState(() {
      _totalIncome = incomeTotal;
      _totalDeductibleExpense = deductibleTotal;
      _pendingReview = review;
      _missingReceipt = noReceipt;

      _monthlyIncome = incomeByMonth;
      _monthlyExpense = expenseByMonth;
      _annualIncome = incomeByYear;
      _annualExpense = expenseByYear;

      _loading = false;
    });
  }

  Widget _fiscalCard(String title, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _yen(value),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final balance = _totalIncome - _totalDeductibleExpense;

    final List<String> allMonths = ({
      ..._monthlyIncome.keys,
      ..._monthlyExpense.keys,
    }.toList()
      ..sort())
        .reversed
        .toList();

    final List<int> allYears = ({
      ..._annualIncome.keys,
      ..._annualExpense.keys,
    }.toList()
      ..sort())
        .reversed
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 10),

          Row(
            children: [
              _fiscalCard("Receita", _totalIncome, Colors.green),
              _fiscalCard("Despesas", _totalDeductibleExpense, Colors.red),
            ],
          ),

          Row(
            children: [
              _fiscalCard("Lucro", balance, Colors.blue),
              _fiscalCard("Pendentes", _pendingReview, Colors.orange),
            ],
          ),

          Row(
            children: [
              _fiscalCard("Sem Recibo", _missingReceipt, Colors.grey),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            "Relatório Mensal",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...allMonths.map((month) {
            final income = _monthlyIncome[month] ?? 0;
            final expense = _monthlyExpense[month] ?? 0;
            final balance = income - expense;

            return Card(
              child: ListTile(
                title: Text(month),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receita: ${_yen(income)}'),
                    Text('Despesa: ${_yen(expense)}'),
                    Text('Resultado: ${_yen(balance)}'),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          const Text(
            "Relatório Anual",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          ...allYears.map((year) {
            final income = _annualIncome[year] ?? 0;
            final expense = _annualExpense[year] ?? 0;
            final balance = income - expense;

            return Card(
              child: ListTile(
                title: Text(year.toString()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Receita: ${_yen(income)}'),
                    Text('Despesa: ${_yen(expense)}'),
                    Text('Resultado: ${_yen(balance)}'),
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
