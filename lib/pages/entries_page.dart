import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  late Future<List<dynamic>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _entriesFuture = SupabaseService.instance.getEntries();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadEntries();
    });
  }

  String _paymentLabel(String value) {
    switch (value) {
      case 'cash':
        return 'Dinheiro';
      case 'bank_transfer':
        return 'Transferência';
      case 'card':
        return 'Cartão';
      case 'paypay':
        return 'PayPay';
      default:
        return 'Outros';
    }
  }

  Future<void> _deleteEntry(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir entrada'),
        content: const Text('Deseja realmente excluir esta entrada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.instance.deleteEntry(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada excluída')),
      );

      _refresh();
    }
  }

  Future<void> _editEntry(Map entry) async {
    final descController =
        TextEditingController(text: entry['description'] ?? '');

    final valueController =
        TextEditingController(text: (entry['amount'] ?? '').toString());

    DateTime selectedDate =
        DateTime.tryParse(entry['date'] ?? '') ?? DateTime.now();

    String payment = entry['payment_method'] ?? 'cash';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar entrada'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: payment,
                    decoration: const InputDecoration(
                      labelText: 'Método de pagamento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Dinheiro'),
                      ),
                      DropdownMenuItem(
                        value: 'card',
                        child: Text('Cartão'),
                      ),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Transferência'),
                      ),
                      DropdownMenuItem(
                        value: 'paypay',
                        child: Text('PayPay'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Outros'),
                      ),
                    ],
                    onChanged: (v) {
                      setStateDialog(() {
                        payment = v ?? 'cash';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Data: ${selectedDate.toLocal().toString().split(' ')[0]}",
                        ),
                      ),
                      ElevatedButton(
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
                        child: const Text("Selecionar"),
                      )
                    ],
                  )
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(valueController.text);

                if (descController.text.isEmpty || amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dados inválidos')),
                  );
                  return;
                }

                await SupabaseService.instance.updateEntry(
                  entry['id'],
                  {
                    'entry_date': selectedDate.toIso8601String(),
                    'description': descController.text,
                    'amount': amount,
                    'payment_method': payment,
                  },
                );

                Navigator.pop(context, true);
              },
              child: const Text('Salvar'),
            )
          ],
        );
      },
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada atualizada')),
      );

      _refresh();
    }
  }

  Widget _entryCard(Map entry) {
    final value = entry['amount'] ?? 0;
    final date = entry['date'] ?? '';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        title: Text(entry['description'] ?? ''),
        subtitle: Text(
          "$date • ${_paymentLabel(entry['payment_method'] ?? '')}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("¥${value.toString()}"),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editEntry(entry),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteEntry(entry['id']),
            ),
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
          Text("Nenhuma entrada registrada"),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Entradas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return _emptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _entryCard(entries[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
