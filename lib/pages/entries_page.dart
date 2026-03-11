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

    final integerValue = number.toStringAsFixed(0);
    final chars = integerValue.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return '¥${buffer.toString().split('').reversed.join()}';
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
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nova entrada',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor (¥)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Método de pagamento',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
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
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Data: ${_formatDate(_selectedDate.toIso8601String())}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _selectDate(setStateDialog),
                              child: const Text('Alterar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final description = _descController.text.trim();
                              final amount = double.tryParse(
                                _amountController.text.trim().replaceAll(',', '.'),
                              );

                              if (description.isEmpty ||
                                  amount == null ||
                                  amount <= 0) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dados inválidos'),
                                  ),
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
                      ),
                    ],
                  ),
                ),
              ),
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
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Editar entrada',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor (¥)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Método de pagamento',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
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
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Data: ${_formatDate(_selectedDate.toIso8601String())}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _selectDate(setStateDialog),
                              child: const Text('Alterar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final description = _descController.text.trim();
                              final amount = double.tryParse(
                                _amountController.text.trim().replaceAll(',', '.'),
                              );

                              if (description.isEmpty ||
                                  amount == null ||
                                  amount <= 0) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dados inválidos'),
                                  ),
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
