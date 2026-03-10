import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late Future<List<dynamic>> _expensesFuture;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    _expensesFuture = SupabaseService.instance.getExpenses();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadExpenses();
    });
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '-';

    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return rawDate.toString();

    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  String _formatYen(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return '¥${number.toStringAsFixed(0)}';
  }

  Widget _expenseCard(Map<String, dynamic> expense) {
    final description = (expense['description'] ?? '').toString();
    final category = (expense['category'] ?? 'outros').toString();
    final date = _formatDate(expense['date']);
    final amount = _formatYen(expense['amount']);
    final receipt = expense['receipt_url'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description.isEmpty ? 'Sem descrição' : description,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "$date • $category",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                if (receipt != null && receipt.toString().isNotEmpty)
                  const Icon(
                    Icons.receipt_long,
                    color: Colors.green,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              "Nenhuma despesa registrada",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "As despesas cadastradas aparecerão aqui.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Erro ao carregar despesas:\n$error",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Despesas"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refresh();
            },
          )
        ],
      ),

      body: FutureBuilder<List<dynamic>>(
        future: _expensesFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _errorState(snapshot.error!);
          }

          final expenses = snapshot.data ?? [];

          if (expenses.isEmpty) {
            return _emptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: expenses.length,
              itemBuilder: (context, index) {

                final expense = Map<String, dynamic>.from(expenses[index]);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _expenseCard(expense),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
