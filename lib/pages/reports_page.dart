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
  bool _generatingPdf = false;
  int? _selectedFiscalYear;

  Map<String, int> _monthlyIncome = {};
  Map<String, int> _monthlyExpense = {};
  Map<int, int> _annualIncome = {};
  Map<int, int> _annualExpense = {};

  Map<String, List<Map<String, dynamic>>> _monthlyExpenseItems = {};

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

    final Map<String, int> incomeByMonth = {};
    final Map<int, int> incomeByYear = {};

    for (final entry in entries) {
      final date = DateTime.parse(entry['date']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final yearKey = date.year;
      final amount = (entry['amount'] as num).toInt();

      incomeByMonth[monthKey] = (incomeByMonth[monthKey] ?? 0) + amount;
      incomeByYear[yearKey] = (incomeByYear[yearKey] ?? 0) + amount;
    }

    final Map<String, int> expenseByMonth = {};
    final Map<int, int> expenseByYear = {};
    final Map<String, List<Map<String, dynamic>>> expenseItemsByMonth = {};

    for (final expense in expenses) {
      final date = DateTime.parse(expense['date']);
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final yearKey = date.year;
      final amount = (expense['amount'] as num).toInt();

      expenseByMonth[monthKey] = (expenseByMonth[monthKey] ?? 0) + amount;
      expenseByYear[yearKey] = (expenseByYear[yearKey] ?? 0) + amount;

      final monthItems =
          expenseItemsByMonth.putIfAbsent(monthKey, () => []);
      monthItems.add(expense);
    }

    if (!mounted) return;

    setState(() {
      _monthlyIncome = incomeByMonth;
      _annualIncome = incomeByYear;
      _monthlyExpense = expenseByMonth;
      _annualExpense = expenseByYear;
      _monthlyExpenseItems = expenseItemsByMonth;
      _loading = false;
    });
  }



  Future<void> _generateFiscalPdf() async {
    final int? year = _selectedFiscalYear;
    if (year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o ano fiscal.')),
      );
      return;
    }

    setState(() {
      _generatingPdf = true;
    });

    try {
      await ReportService.instance.generateAnnualFiscalPdf(year);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF fiscal gerado com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF fiscal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
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
                title: const Text('Recibo'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _expenseItem(
      AppLocalizations localizations, Map<String, dynamic> item) {
    final description = item['description'] ?? '-';
    final amount = (item['amount'] as num).toInt();
    final date = item['date'];
    final category = item['category'];
    final receiptUrl = item['receipt_url'];

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
          Text(description,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            '$date • $category',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_yen(amount),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (receiptUrl != null)
                TextButton.icon(
                  onPressed: () => _showReceipt(receiptUrl),
                  icon: const Icon(Icons.receipt),
                  label: const Text('Ver recibo'),
                )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final localizations = AppLocalizations.of(context);

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

    _selectedFiscalYear ??= allYears.isNotEmpty ? allYears.first : DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Relatório Fiscal Anual PDF',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _selectedFiscalYear,
                    decoration: const InputDecoration(
                      labelText: 'Ano fiscal',
                      border: OutlineInputBorder(),
                    ),
                    items: allYears.isNotEmpty
                        ? allYears
                            .map((year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(year.toString()),
                                ))
                            .toList()
                        : [
                            DropdownMenuItem<int>(
                              value: DateTime.now().year,
                              child: Text(DateTime.now().year.toString()),
                            ),
                          ],
                    onChanged: (value) {
                      setState(() {
                        _selectedFiscalYear = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generatingPdf ? null : _generateFiscalPdf,
                      icon: _generatingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_generatingPdf ? 'Gerando PDF...' : 'Gerar PDF Fiscal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            localizations.translate('monthly_report'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...allMonths.map((month) {
            final income = _monthlyIncome[month] ?? 0;
            final expense = _monthlyExpense[month] ?? 0;
            final balance = income - expense;

            final expenseItems = _monthlyExpenseItems[month] ?? [];

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
                  if (expenseItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        children: expenseItems
                            .map((e) => _expenseItem(localizations, e))
                            .toList(),
                      ),
                    )
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
            final income = _annualIncome[year] ?? 0;
            final expense = _annualExpense[year] ?? 0;
            final balance = income - expense;

            return Card(
              child: ListTile(
                title: Text(year.toString()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${localizations.translate('income')}: ${_yen(income)}'),
                    Text('${localizations.translate('expenses')}: ${_yen(expense)}'),
                    Text('${localizations.translate('balance')}: ${_yen(balance)}'),
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
