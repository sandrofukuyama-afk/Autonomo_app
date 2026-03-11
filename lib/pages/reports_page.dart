import 'package:flutter/material.dart';
import '../data/supabase_service.dart';
import '../services/report_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String, dynamic>> _reportFuture;

  String _period = 'year';
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    _reportFuture = _calculateReport();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadReport();
    });
  }

  Future<Map<String, dynamic>> _calculateReport() async {
    final entries = await SupabaseService.instance.getEntries();
    final expenses = await SupabaseService.instance.getExpenses();

    DateTime start;
    DateTime end;

    if (_period == 'year') {
      start = DateTime(_year, 1, 1, 0, 0, 0);
      end = DateTime(_year, 12, 31, 23, 59, 59);
    } else {
      final now = DateTime.now();
      start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 365));
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    double totalEntries = 0;
    double totalExpenses = 0;

    for (final e in entries) {
      final date = DateTime.tryParse((e['date'] ?? '').toString());
      final amount = e['amount'] is num
          ? (e['amount'] as num).toDouble()
          : double.tryParse((e['amount'] ?? '0').toString()) ?? 0;

      if (date != null &&
          !date.isBefore(start) &&
          !date.isAfter(end)) {
        totalEntries += amount;
      }
    }

    for (final e in expenses) {
      final date = DateTime.tryParse((e['date'] ?? '').toString());
      final amount = e['amount'] is num
          ? (e['amount'] as num).toDouble()
          : double.tryParse((e['amount'] ?? '0').toString()) ?? 0;

      if (date != null &&
          !date.isBefore(start) &&
          !date.isAfter(end)) {
        totalExpenses += amount;
      }
    }

    final profit = totalEntries - totalExpenses;
    final taxableProfit = profit > 0 ? profit : 0.0;

    final nationalTax = taxableProfit * 0.10;
    final residentTax = taxableProfit * 0.10;
    final totalTax = nationalTax + residentTax;

    return {
      'entries': totalEntries,
      'expenses': totalExpenses,
      'profit': profit,
      'nationalTax': nationalTax,
      'residentTax': residentTax,
      'totalTax': totalTax,
    };
  }

  String _yen(double value) {
    final formatted = value.toStringAsFixed(0);
    final chars = formatted.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return '¥${buffer.toString().split('').reversed.join()}';
  }

  String _periodLabel() {
    if (_period == 'year') {
      return 'Relatório do ano $_year';
    }
    return 'Relatório dos últimos 12 meses';
  }

  Widget _summaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFF4F7FB),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo fiscal',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _periodLabel(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taxBox(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimativa de imposto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _taxRow('Income Tax', _yen((data['nationalTax'] as num).toDouble())),
          const Divider(height: 22),
          _taxRow('Resident Tax', _yen((data['residentTax'] as num).toDouble())),
          const Divider(height: 22),
          _taxRow(
            'Total estimado',
            _yen((data['totalTax'] as num).toDouble()),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _taxRow(String label, String value, {bool isTotal = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.orange.shade800 : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _periodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _period,
              decoration: const InputDecoration(
                labelText: 'Período',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'year',
                  child: Text('Ano específico'),
                ),
                DropdownMenuItem(
                  value: '12m',
                  child: Text('Últimos 12 meses'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _period = v;
                  _loadReport();
                });
              },
            ),
          ),
          if (_period == 'year') ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<int>(
                value: _year,
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  5,
                  (i) {
                    final year = DateTime.now().year - i;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  },
                ),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _year = v;
                    _loadReport();
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    await ReportService.instance.generateFiscalReport(
      year: _year,
      entries: data['entries'],
      expenses: data['expenses'],
      profit: data['profit'],
      nationalTax: data['nationalTax'],
      residentTax: data['residentTax'],
      totalTax: data['totalTax'],
    );
  }

  Widget _errorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Erro ao carregar relatório: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório Fiscal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _errorState(snapshot.error!);
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryHeader(),
                const SizedBox(height: 16),
                _periodSelector(),
                const SizedBox(height: 18),
                _valueCard(
                  title: 'Receita total',
                  value: _yen((data['entries'] as num).toDouble()),
                  icon: Icons.trending_up,
                  valueColor: Colors.green.shade700,
                ),
                const SizedBox(height: 12),
                _valueCard(
                  title: 'Despesas totais',
                  value: _yen((data['expenses'] as num).toDouble()),
                  icon: Icons.trending_down,
                  valueColor: Colors.red.shade700,
                ),
                const SizedBox(height: 12),
                _valueCard(
                  title: 'Lucro tributável',
                  value: _yen((data['profit'] as num).toDouble()),
                  icon: Icons.account_balance_wallet_outlined,
                  valueColor: Colors.blue.shade700,
                ),
                const SizedBox(height: 18),
                _taxBox(data),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Gerar PDF Fiscal'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _generatePdf(data),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
