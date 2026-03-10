import 'package:flutter/material.dart';
import '../data/supabase_service.dart';
import '../data/tax_calculator_jp.dart';
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

  int _totalIncome = 0;
  int _totalDeductibleExpense = 0;
  int _pendingReview = 0;
  int _missingReceipt = 0;

  Map<String, int> _monthlyIncome = {};
  Map<String, int> _monthlyExpense = {};
  Map<int, int> _annualIncome = {};
  Map<int, int> _annualExpense = {};
  Map<String, List<Map<String, dynamic>>> _monthlyExpenseItems = {};

  TaxResultJP? _taxResult;

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
    final Map<String, List<Map<String, dynamic>>> expenseItemsByMonth = {};

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

      expenseByMonth[monthKey] = (expenseByMonth[monthKey] ?? 0) + fiscalInt;
      expenseByYear[yearKey] = (expenseByYear[yearKey] ?? 0) + fiscalInt;

      final monthItems = expenseItemsByMonth.putIfAbsent(monthKey, () => []);
      monthItems.add(expense);
    }

    final TaxResultJP taxResult = TaxCalculatorJP.calculate(
      totalIncome: incomeTotal,
      deductibleExpenses: deductibleTotal,
      blueReturn: true,
    );

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
      _monthlyExpenseItems = expenseItemsByMonth;
      _taxResult = taxResult;

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
                  ),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fiscalCard(String title, String value, Color color) {
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
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

  Widget _taxSummaryCard() {
    final result = _taxResult;
    if (result == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo Fiscal (確定申告)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _taxLine('Receita total', _yen(result.totalIncome)),
            _taxLine('Despesas dedutíveis', _yen(result.deductibleExpenses)),
            _taxLine('Lucro do negócio', _yen(result.businessProfit)),
            const Divider(height: 24),
            _taxLine('Dedução básica', _yen(result.basicDeduction)),
            _taxLine('Dedução Blue Return', _yen(result.blueReturnDeduction)),
            const Divider(height: 24),
            _taxLine('Base tributável', _yen(result.taxableIncome)),
            _taxLine(
              'Imposto estimado',
              _yen(result.estimatedTax),
              valueColor: Colors.red,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _taxLine(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseItem(
    AppLocalizations localizations,
    Map<String, dynamic> item,
  ) {
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
          Text(
            description,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$date • $category',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _yen(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (receiptUrl != null)
                TextButton.icon(
                  onPressed: () => _showReceipt(receiptUrl),
                  icon: const Icon(Icons.receipt),
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

    final localizations = AppLocalizations.of(context);
    final int businessBalance = _totalIncome - _totalDeductibleExpense;

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

    _selectedFiscalYear ??=
        allYears.isNotEmpty ? allYears.first : DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _fiscalCard('Receita', _yen(_totalIncome), Colors.green),
              _fiscalCard(
                'Despesas',
                _yen(_totalDeductibleExpense),
                Colors.red,
              ),
            ],
          ),
          Row(
            children: [
              _fiscalCard('Lucro', _yen(businessBalance), Colors.blue),
              _fiscalCard('Pendentes', _pendingReview.toString(), Colors.orange),
            ],
          ),
          Row(
            children: [
              _fiscalCard(
                'Sem Recibo',
                _missingReceipt.toString(),
                Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _taxSummaryCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Relatório Fiscal Anual PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                            .map(
                              (year) => DropdownMenuItem<int>(
                                value: year,
                                child: Text(year.toString()),
                              ),
                            )
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
                      label: Text(
                        _generatingPdf ? 'Gerando PDF...' : 'Gerar PDF Fiscal',
                      ),
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
                      Text(
                        '${localizations.translate('income')}: ${_yen(income)}',
                      ),
                      Text(
                        '${localizations.translate('expenses')}: ${_yen(expense)}',
                      ),
                      Text(
                        '${localizations.translate('balance')}: ${_yen(balance)}',
                      ),
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
            final income = _annualIncome[year] ?? 0;
            final expense = _annualExpense[year] ?? 0;
            final balance = income - expense;

            return Card(
              child: ListTile(
                title: Text(year.toString()),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${localizations.translate('income')}: ${_yen(income)}',
                    ),
                    Text(
                      '${localizations.translate('expenses')}: ${_yen(expense)}',
                    ),
                    Text(
                      '${localizations.translate('balance')}: ${_yen(balance)}',
                    ),
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
