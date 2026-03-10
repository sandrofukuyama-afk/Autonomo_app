import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {

  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await SupabaseService.instance.getEntries();

    setState(() {
      _entries = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    _descController.clear();
    _amountController.clear();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Nova entrada"),
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

                await SupabaseService.instance.createEntry(
                  description: _descController.text,
                  amount: amount,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadEntries();
                }
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _editEntry(Map entry) async {

    _descController.text = entry["description"] ?? "";
    _amountController.text = entry["amount"].toString();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Editar entrada"),
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

                await SupabaseService.instance.updateEntry(
                  id: entry["id"],
                  description: _descController.text,
                  amount: amount,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _loadEntries();
                }
              },
            )
          ],
        );
      },
    );
  }

  Future<void> _deleteEntry(String id) async {

    await SupabaseService.instance.deleteEntry(id);

    _loadEntries();
  }

  String _yen(value) {
    final v = (value ?? 0).toString();
    return "¥$v";
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Entradas"),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (_, i) {

                final entry = _entries[i];

                return ListTile(
                  leading: const Icon(
                    Icons.arrow_downward,
                    color: Colors.green,
                  ),

                  title: Text(entry["description"] ?? ""),

                  subtitle: Text(
                    entry["entry_date"] ?? "",
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Text(
                        _yen(entry["amount"]),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _editEntry(entry);
                        },
                      ),

                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteEntry(entry["id"]);
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
