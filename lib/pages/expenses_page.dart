import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {

  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;

  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _storeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final data = await SupabaseService.instance.getExpenses();

    setState(() {
      _expenses = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _addExpense() async {

    _descController.clear();
    _amountController.clear();
    _storeController.clear();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Nova despesa"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Descrição",
                ),
              ),

              TextField(
                controller: _storeController,
                decoration: const InputDecoration(
                  labelText: "Loja",
                ),
              ),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Valor",
                ),
              ),
            ],
          ),
          actions: [

            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),

            ElevatedButton(
              child: const Text("Salvar"),
              onPressed: () async {

                final amount =
                    double.tryParse(_amountController.text) ?? 0;

                await SupabaseService.instance.createExpense(
                  description: _descController.text,
                  storeName: _storeController.text,
                  amount: amount,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadExpenses();
                }
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _editExpense(Map expense) async {

    _descController.text = expense["description"] ?? "";
    _amountController.text = expense["amount"].toString();
    _storeController.text = expense["store_name"] ?? "";

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Editar despesa"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: "Descrição",
                ),
              ),

              TextField(
                controller: _storeController,
                decoration: const InputDecoration(
                  labelText: "Loja",
                ),
              ),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Valor",
                ),
              ),
            ],
          ),
          actions: [

            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),

            ElevatedButton(
              child: const Text("Salvar"),
              onPressed: () async {

                final amount =
                    double.tryParse(_amountController.text) ?? 0;

                await SupabaseService.instance.updateExpense(
                  id: expense["id"],
                  description: _descController.text,
                  storeName: _storeController.text,
                  amount: amount,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadExpenses();
                }
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _deleteExpense(String id) async {

    await SupabaseService.instance.deleteExpense(id);

    _loadExpenses();
  }

  String _yen(value) {
    final v = (value ?? 0).toString();
    return "¥$v";
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Despesas"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        child: const Icon(Icons.add),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (_, i) {

                final expense = _expenses[i];

                return ListTile(
                  leading: const Icon(
                    Icons.arrow_upward,
                    color: Colors.red,
                  ),

                  title: Text(expense["description"] ?? ""),

                  subtitle: Text(
                    "${expense["expense_date"] ?? ""} • ${expense["store_name"] ?? ""}",
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Text(
                        _yen(expense["amount"]),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _editExpense(expense);
                        },
                      ),

                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteExpense(expense["id"]);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
