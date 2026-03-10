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

    return "$y-$m-$d";
  }

  String _formatYen(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return "¥${number.toStringAsFixed(0)}";
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir despesa"),
        content: const Text("Deseja realmente excluir esta despesa?"),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: const Text("Excluir"),
            onPressed: () => Navigator.pop(context, true),
          )
        ],
      ),
    );

    if (confirm != true) return;

    await SupabaseService.instance.deleteExpense(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Despesa excluída")),
    );

    await _refresh();
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    final descController =
        TextEditingController(text: expense['description'] ?? '');

    final valueController =
        TextEditingController(text: (expense['amount'] ?? '').toString());

    DateTime selectedDate =
        DateTime.tryParse(expense['date'] ?? '') ?? DateTime.now();

    String category = expense['category'] ?? 'other';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Editar despesa"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: descController,
                      decoration:
                          const InputDecoration(labelText: "Descrição"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: "Valor"),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration:
                          const InputDecoration(labelText: "Categoria"),
                      items: const [
                        DropdownMenuItem(
                            value: "food", child: Text("Alimentação")),
                        DropdownMenuItem(
                            value: "transport", child: Text("Transporte")),
                        DropdownMenuItem(value: "rent", child: Text("Aluguel")),
                        DropdownMenuItem(
                            value: "services", child: Text("Serviços")),
                        DropdownMenuItem(value: "fees", child: Text("Taxas")),
                        DropdownMenuItem(value: "other", child: Text("Outros")),
                      ],
                      onChanged: (v) {
                        setStateDialog(() {
                          category = v ?? "other";
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Data: ${_formatDate(selectedDate)}",
                          ),
                        ),
                        ElevatedButton(
                          child: const Text("Selecionar"),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );

                            if (picked != null) {
                              setStateDialog(() {
                                selectedDate = picked;
                              });
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancelar"),
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
                ElevatedButton(
                  child: const Text("Salvar"),
                  onPressed: () async {
                    final description = descController.text.trim();
                    final amount = double.tryParse(valueController.text);

                    if (description.isEmpty || amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Dados inválidos")),
                      );
                      return;
                    }

                    await SupabaseService.instance.updateExpense(
                      expense['id'].toString(),
                      {
                        'date': selectedDate.toIso8601String(),
                        'description': description,
                        'category': category,
                        'amount': amount,
                        'tax': expense['tax_amount'],
                        'tax_type': expense['tax_type'],
                      },
                    );

                    if (!mounted) return;

                    Navigator.pop(dialogContext, true);
                  },
                )
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Despesa atualizada")),
      );

      await _refresh();
    }
  }

  Widget _expenseCard(Map<String, dynamic> expense) {
    final description = expense['description'] ?? '';
    final date = _formatDate(expense['date']);
    final amount = _formatYen(expense['amount']);
    final category = expense['category'] ?? '';
    final receipt = expense['receipt_url'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text("$date • $category"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    amount,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (receipt != null && receipt.toString().isNotEmpty)
                  const Icon(Icons.receipt_long, color: Colors.green),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editExpense(expense),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _deleteExpense(expense['id'].toString()),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text("Nenhuma despesa registrada"),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Despesas"),
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
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
                final expense =
                    Map<String, dynamic>.from(expenses[index]);

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
