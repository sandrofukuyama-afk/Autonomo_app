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

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final data = await SupabaseService.instance.getEntries();

    if (!mounted) return;

    setState(() {
      _entries = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    await _loadEntries();
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

  Future<void> _selectDate(StateSetter setStateDialog) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setStateDialog(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _openAddDialog() async {
    _descController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now();
    _paymentMethod = 'cash';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nova entrada'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
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
                      onChanged: (value) {
                        setStateDialog(() {
                          _paymentMethod = value ?? 'cash';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Data: ${_formatDate(_selectedDate.toIso8601String())}',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _selectDate(setStateDialog),
                          child: const Text('Selecionar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final description = _descController.text.trim();
                    final amount = double.tryParse(
                      _amountController.text.trim().replaceAll(',', '.'),
                    );

                    if (description.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Dados inválidos')),
                      );
                      return;
                    }

                    await SupabaseService.instance.addEntry({
                      'date': _selectedDate.toIso8601String(),
                      'description': description,
                      'amount': amount,
                      'payment_method': _paymentMethod,
                    });

                    if (!mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada adicionada')),
      );
      await _refresh();
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    _descController.text = (entry['description'] ?? '').toString();
    _amountController.text = (entry['amount'] ?? '').toString();
    _selectedDate =
        DateTime.tryParse((entry['date'] ?? '').toString()) ?? DateTime.now();
    _paymentMethod = (entry['payment_method'] ?? 'cash').toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar entrada'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
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
                      onChanged: (value) {
                        setStateDialog(() {
                          _paymentMethod = value ?? 'cash';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Data: ${_formatDate(_selectedDate.toIso8601String())}',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _selectDate(setStateDialog),
                          child: const Text('Selecionar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final description = _descController.text.trim();
                    final amount = double.tryParse(
                      _amountController.text.trim().replaceAll(',', '.'),
                    );

                    if (description.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Dados inválidos')),
                      );
                      return;
                    }

                    await SupabaseService.instance.updateEntry(
                      entry['id'].toString(),
                      {
                        'entry_date': _selectedDate.toIso8601String(),
                        'description': description,
                        'amount': amount,
                        'payment_method': _paymentMethod,
                      },
                    );

                    if (!mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada atualizada')),
      );
      await _refresh();
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

    if (confirm != true) return;

    await SupabaseService.instance.deleteEntry(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada excluída')),
    );

    await _refresh();
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final description = (entry['description'] ?? '').toString();
    final date = _formatDate(entry['date']);
    final amount = _formatYen(entry['amount']);
    final paymentMethod = _paymentLabel(
      (entry['payment_method'] ?? '').toString(),
    );

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
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$date • $paymentMethod',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editEntry(entry),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteEntry(entry['id'].toString()),
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
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhuma entrada registrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'As entradas cadastradas aparecerão aqui.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entradas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova entrada',
            onPressed: _openAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refresh();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = Map<String, dynamic>.from(_entries[index]);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _entryCard(entry),
                      );
                    },
                  ),
                ),
    );
  }
}
