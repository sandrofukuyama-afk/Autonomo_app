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

  String _period = "year";
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
    DateTime end = DateTime.now();

    if (_period == "year") {
      start = DateTime(_year, 1, 1);
      end = DateTime(_year, 12, 31);
    } else {
      start = DateTime.now().subtract(const Duration(days: 365));
    }

    double totalEntries = 0;
    double totalExpenses = 0;

    for (var e in entries) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && date.isAfter(start) && date.isBefore(end)) {
        totalEntries += (e['amount'] ?? 0).toDouble();
      }
    }

    for (var e in expenses) {
      final date = DateTime.tryParse(e['date'] ?? '');
      if (date != null && date.isAfter(start) && date.isBefore(end)) {
        totalExpenses += (e['amount'] ?? 0).toDouble();
      }
    }

    final profit = totalEntries - totalExpenses;

    final nationalTax = profit * 0.10;
    final residentTax = profit * 0.10;

    return {
      "entries": totalEntries,
      "expenses": totalExpenses,
      "profit": profit,
      "nationalTax": nationalTax,
      "residentTax": residentTax,
      "totalTax": nationalTax + residentTax
    };
  }

  String _yen(double value) {
    return "¥${value.toStringAsFixed(0)}";
  }

  Widget _card(String title, String value, {Color? color}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _period,
            decoration: const InputDecoration(labelText: "Período"),
            items: const [
              DropdownMenuItem(
                value: "year",
                child: Text("Ano específico"),
              ),
              DropdownMenuItem(
                value: "12m",
                child: Text("Últimos 12 meses"),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _period = v!;
                _loadReport();
              });
            },
          ),
        ),
        if (_period == "year") ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int>(
              value: _year,
              decoration: const InputDecoration(labelText: "Ano"),
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
                setState(() {
                  _year = v!;
                  _loadReport();
                });
              },
            ),
          )
        ]
      ],
    );
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    await ReportService.instance.generateFiscalReport(
      year: _year,
      entries: data["entries"],
      expenses: data["expenses"],
      profit: data["profit"],
      nationalTax: data["nationalTax"],
      residentTax: data["residentTax"],
      totalTax: data["totalTax"],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Relatório Fiscal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                _periodSelector(),

                const SizedBox(height: 20),

                _card("Receita total", _yen(data["entries"]),
                    color: Colors.green),

                _card("Despesas totais", _yen(data["expenses"]),
                    color: Colors.red),

                _card("Lucro tributável", _yen(data["profit"]),
                    color: Colors.blue),

                const SizedBox(height: 20),

                const Text(
                  "Estimativa de imposto",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                _card("Income Tax", _yen(data["nationalTax"])),

                _card("Resident Tax", _yen(data["residentTax"])),

                _card("Total estimado", _yen(data["totalTax"]),
                    color: Colors.orange),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("Gerar PDF Fiscal"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => _generatePdf(data),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
