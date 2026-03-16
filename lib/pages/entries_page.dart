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
  List<String> _closedFiscalMonths = [];

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'cash';
  String _category = 'service';

  @override
  void initState() {
    super.initState();
    _loadClosedMonths();
    _loadEntries();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadClosedMonths() async {
    try {
      final months = await SupabaseService.instance.getClosedFiscalMonths();
      if (!mounted) return;
      setState(() {
        _closedFiscalMonths = months;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closedFiscalMonths = [];
      });
    }
  }

  String _extractFiscalMonth(dynamic rawDate) {
    if (rawDate == null) return '';

    if (rawDate is DateTime) {
      final year = rawDate.year.toString().padLeft(4, '0');
      final month = rawDate.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed != null) {
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final text = rawDate.toString().trim();
    if (text.length >= 7 && text[4] == '-') {
      return text.substring(0, 7);
    }

    return '';
  }

  bool _isClosedMonth(dynamic rawDate) {
    final fiscalMonth = _extractFiscalMonth(rawDate);
    if (fiscalMonth.isEmpty) return false;
    return _closedFiscalMonths.contains(fiscalMonth);
  }

  bool _isCurrentMonthClosed() {
    return _isClosedMonth(DateTime.now());
  }

  String _friendlyBlockedMessage([String? month]) {
    if (month != null && month.isNotEmpty) {
      return 'O mês fiscal $month está fechado. Esta operação não é permitida.';
    }
    return 'Este mês fiscal está fechado. Esta operação não é permitida.';
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
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
    await _loadClosedMonths();
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

  String _categoryLabel(String value) {
    switch (value) {
      case 'service':
        return 'Serviço';
      case 'product':
        return 'Produto';
      case 'commission':
        return 'Comissão';
      default:
        return 'Outros';
    }
  }

  List<DropdownMenuItem<String>> _categoryItems() {
    return const [
      DropdownMenuItem(
        value: 'service',
        child: Text('Serviço'),
      ),
      DropdownMenuItem(
        value: 'product',
        child: Text('Produto'),
      ),
      DropdownMenuItem(
        value: 'commission',
        child: Text('Comissão'),
      ),
      DropdownMenuItem(
        value: 'other',
        child: Text('Outros'),
      ),
    ];
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

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  Future<void> _openAddDialog() async {
    if (_isCurrentMonthClosed()) {
      _showMessage(
        _friendlyBlockedMessage(_extractFiscalMonth(DateTime.now())),
        error: true,
      );
      return;
    }

    _descController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now();
    _paymentMethod = 'cash';
    _category = 'service';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nova entrada',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration('Descrição'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration('Valor (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _fieldDecoration('Categoria'),
                          items: _categoryItems(),
                          onChanged: (value) {
                            setStateDialog(() {
                              _category = value ?? 'service';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration('Método de pagamento'),
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
                            borderRadius: BorderRadius.circular(12),
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
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final description = _descController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text
                                      .trim()
                                      .replaceAll(',', '.'),
                                );

                                if (description.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Dados inválidos'),
                                    ),
                                  );
                                  return;
                                }

                                if (_isClosedMonth(_selectedDate)) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _friendlyBlockedMessage(
                                          _extractFiscalMonth(_selectedDate),
                                        ),
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await SupabaseService.instance.addEntry({
                                    'date': _selectedDate.toIso8601String(),
                                    'description': description,
                                    'amount': amount,
                                    'category': _category,
                                    'payment_method': _paymentMethod,
                                  });

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            ),
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Salvar'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    if (_isClosedMonth(entry['date'])) {
      _showMessage(
        _friendlyBlockedMessage(_extractFiscalMonth(entry['date'])),
        error: true,
      );
      return;
    }

    _descController.text = (entry['description'] ?? '').toString();
    _amountController.text = (entry['amount'] ?? '').toString();
    _selectedDate =
        DateTime.tryParse((entry['date'] ?? '').toString()) ?? DateTime.now();
    _paymentMethod = (entry['payment_method'] ?? 'cash').toString();
    _category = (entry['category'] ?? 'service').toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Editar entrada',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration('Descrição'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration('Valor (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _fieldDecoration('Categoria'),
                          items: _categoryItems(),
                          onChanged: (value) {
                            setStateDialog(() {
                              _category = value ?? 'service';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration('Método de pagamento'),
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
                            borderRadius: BorderRadius.circular(12),
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
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final description = _descController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text
                                      .trim()
                                      .replaceAll(',', '.'),
                                );

                                if (description.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Dados inválidos'),
                                    ),
                                  );
                                  return;
                                }

                                if (_isClosedMonth(_selectedDate)) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _friendlyBlockedMessage(
                                          _extractFiscalMonth(_selectedDate),
                                        ),
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await SupabaseService.instance.updateEntry(
                                    entry['id'].toString(),
                                    {
                                      'entry_date':
                                          _selectedDate.toIso8601String(),
                                      'description': description,
                                      'amount': amount,
                                      'category': _category,
                                      'payment_method': _paymentMethod,
                                    },
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            ),
                                      ),
                                      backgroundColor: Colors.red.shade700,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Salvar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

  Future<void> _deleteEntry(String id, {dynamic entryDate}) async {
    if (_isClosedMonth(entryDate)) {
      _showMessage(
        _friendlyBlockedMessage(_extractFiscalMonth(entryDate)),
        error: true,
      );
      return;
    }

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

    try {
      await SupabaseService.instance.deleteEntry(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrada excluída')),
      );

      await _refresh();
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final description = (entry['description'] ?? '').toString();
    final date = _formatDate(entry['date']);
    final amount = _formatYen(entry['amount']);
    final paymentMethod = _paymentLabel(
      (entry['payment_method'] ?? '').toString(),
    );
    final category = _categoryLabel((entry['category'] ?? 'service').toString());
    final isClosed = _isClosedMonth(entry['date']);

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
              '$date • $category • $paymentMethod',
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
                if (isClosed)
                  Tooltip(
                    message: 'Mês fiscal fechado',
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.orange.shade700,
                    ),
                  ),
                if (!isClosed)
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editEntry(entry),
                  ),
                if (!isClosed)
                  IconButton(
                    tooltip: 'Excluir',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteEntry(
                      entry['id'].toString(),
                      entryDate: entry['date'],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _closedMonthBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mês fiscal fechado',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Novas entradas, edição e exclusão ficam bloqueadas para o mês atual.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            icon: Icon(
              Icons.add,
              color: _isCurrentMonthClosed() ? Colors.grey.shade400 : null,
            ),
            tooltip: _isCurrentMonthClosed()
                ? 'Mês fiscal fechado'
                : 'Nova entrada',
            onPressed: _isCurrentMonthClosed() ? null : _openAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isCurrentMonthClosed()) _closedMonthBanner(),
                Expanded(
                  child: _entries.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry =
                                  Map<String, dynamic>.from(_entries[index]);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _entryCard(entry),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
