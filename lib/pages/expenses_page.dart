import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _category = 'other';
  String _taxType = 'external';
  double _taxAmount = 0;

  Uint8List? _selectedReceiptBytes;
  String? _selectedReceiptName;
  String? _selectedReceiptMimeType;
  int? _selectedReceiptSize;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _storeController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    final data = await SupabaseService.instance.getExpenses();

    if (!mounted) return;

    setState(() {
      _expenses = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    await _loadExpenses();
  }

  void _clearSelectedReceipt() {
    _selectedReceiptBytes = null;
    _selectedReceiptName = null;
    _selectedReceiptMimeType = null;
    _selectedReceiptSize = null;
  }

  Future<void> _pickReceipt(StateSetter setStateDialog) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível ler o arquivo.')),
      );
      return;
    }

    setStateDialog(() {
      _selectedReceiptBytes = file.bytes;
      _selectedReceiptName = file.name;
      _selectedReceiptMimeType = _mimeFromName(file.name);
      _selectedReceiptSize = file.size;
    });
  }

  String _mimeFromName(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  bool _isImageMime(String? mime) {
    return mime != null && mime.startsWith('image/');
  }

  bool _isImageUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp');
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

  String _categoryLabel(String value) {
    switch (value) {
      case 'food':
        return 'Alimentação';
      case 'transport':
        return 'Transporte';
      case 'rent':
        return 'Aluguel';
      case 'services':
        return 'Serviços';
      case 'fees':
        return 'Taxas';
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

  Future<Map<String, dynamic>> _uploadSelectedReceiptIfNeeded() async {
    if (_selectedReceiptBytes == null || _selectedReceiptName == null) {
      return {};
    }

    final publicUrl = await SupabaseService.instance.uploadReceipt(
      _selectedReceiptBytes!,
      _selectedReceiptName!,
      contentType: _selectedReceiptMimeType,
    );

    return {
      'receipt_url': publicUrl,
      'storage_path': publicUrl,
      'file_name': _selectedReceiptName,
      'original_file_name': _selectedReceiptName,
      'mime_type': _selectedReceiptMimeType,
      'file_size_bytes': _selectedReceiptSize,
      'document_type': 'receipt',
      'ocr_status': 'pending',
      'receipt_review_status': 'pending',
    };
  }

  Future<void> _showReceiptPreview(String url) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 900,
            maxHeight: 700,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Recibo anexado',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isImageUrl(url)
                      ? InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return SelectableText(url);
                            },
                          ),
                        )
                      : Center(
                          child: SelectableText(url),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptSection({
    required StateSetter setStateDialog,
    String? existingReceiptUrl,
  }) {
    final hasSelectedReceipt =
        _selectedReceiptBytes != null && _selectedReceiptName != null;
    final hasExistingReceipt =
        existingReceiptUrl != null && existingReceiptUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recibo / comprovante',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (hasSelectedReceipt) ...[
            Row(
              children: [
                const Icon(Icons.attach_file, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedReceiptName!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setStateDialog(() {
                      _clearSelectedReceipt();
                    });
                  },
                  child: const Text('Remover'),
                ),
              ],
            ),
            if (_isImageMime(_selectedReceiptMimeType)) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _selectedReceiptBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ] else if (hasExistingReceipt) ...[
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Já existe um recibo anexado para esta despesa.',
                  ),
                ),
                TextButton(
                  onPressed: () => _showReceiptPreview(existingReceiptUrl),
                  child: const Text('Ver'),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Nenhum recibo selecionado.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _pickReceipt(setStateDialog),
              icon: const Icon(Icons.upload_file),
              label: Text(hasSelectedReceipt ? 'Trocar arquivo' : 'Anexar recibo'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddDialog() async {
    _descController.clear();
    _amountController.clear();
    _storeController.clear();
    _selectedDate = DateTime.now();
    _category = 'other';
    _taxType = 'external';
    _taxAmount = 0;
    _clearSelectedReceipt();

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
                  maxWidth: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nova despesa',
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
                          controller: _storeController,
                          decoration: _fieldDecoration('Loja / fornecedor'),
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
                          items: const [
                            DropdownMenuItem(
                              value: 'food',
                              child: Text('Alimentação'),
                            ),
                            DropdownMenuItem(
                              value: 'transport',
                              child: Text('Transporte'),
                            ),
                            DropdownMenuItem(
                              value: 'rent',
                              child: Text('Aluguel'),
                            ),
                            DropdownMenuItem(
                              value: 'services',
                              child: Text('Serviços'),
                            ),
                            DropdownMenuItem(
                              value: 'fees',
                              child: Text('Taxas'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Outros'),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _category = value ?? 'other';
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
                        const SizedBox(height: 16),
                        _receiptSection(setStateDialog: setStateDialog),
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

                                final receiptPayload =
                                    await _uploadSelectedReceiptIfNeeded();

                                await SupabaseService.instance.addExpense({
                                  'date': _selectedDate.toIso8601String(),
                                  'store_name': _storeController.text.trim(),
                                  'description': description,
                                  'category': _category,
                                  'amount': amount,
                                  'tax': _taxAmount,
                                  'tax_type': _taxType,
                                  ...receiptPayload,
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
              ),
            );
          },
        );
      },
    );

    _clearSelectedReceipt();

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Despesa adicionada')),
      );
      await _refresh();
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    _descController.text = (expense['description'] ?? '').toString();
    _amountController.text = (expense['amount'] ?? '').toString();
    _storeController.text = (expense['store_name'] ?? '').toString();
    _selectedDate =
        DateTime.tryParse((expense['date'] ?? '').toString()) ?? DateTime.now();
    _category = (expense['category'] ?? 'other').toString();
    _taxType = (expense['tax_type'] ?? 'external').toString();
    _taxAmount = expense['tax_amount'] is num
        ? (expense['tax_amount'] as num).toDouble()
        : double.tryParse((expense['tax_amount'] ?? '0').toString()) ?? 0;
    _clearSelectedReceipt();

    final existingReceiptUrl = (expense['receipt_url'] ?? '').toString();

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
                  maxWidth: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Editar despesa',
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
                          controller: _storeController,
                          decoration: _fieldDecoration('Loja / fornecedor'),
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
                          items: const [
                            DropdownMenuItem(
                              value: 'food',
                              child: Text('Alimentação'),
                            ),
                            DropdownMenuItem(
                              value: 'transport',
                              child: Text('Transporte'),
                            ),
                            DropdownMenuItem(
                              value: 'rent',
                              child: Text('Aluguel'),
                            ),
                            DropdownMenuItem(
                              value: 'services',
                              child: Text('Serviços'),
                            ),
                            DropdownMenuItem(
                              value: 'fees',
                              child: Text('Taxas'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Outros'),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _category = value ?? 'other';
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
                        const SizedBox(height: 16),
                        _receiptSection(
                          setStateDialog: setStateDialog,
                          existingReceiptUrl: existingReceiptUrl,
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

                                await SupabaseService.instance.updateExpense(
                                  expense['id'].toString(),
                                  {
                                    'date': _selectedDate.toIso8601String(),
                                    'store_name': _storeController.text.trim(),
                                    'description': description,
                                    'category': _category,
                                    'amount': amount,
                                    'tax': _taxAmount,
                                    'tax_type': _taxType,
                                  },
                                );

                                final receiptPayload =
                                    await _uploadSelectedReceiptIfNeeded();

                                if (receiptPayload.isNotEmpty) {
                                  await SupabaseService.instance
                                      .attachReceiptToExpense(
                                    expense['id'].toString(),
                                    {
                                      'date': _selectedDate.toIso8601String(),
                                      'store_name': _storeController.text.trim(),
                                      'description': description,
                                      'category': _category,
                                      'amount': amount,
                                      'tax': _taxAmount,
                                      'tax_type': _taxType,
                                      ...receiptPayload,
                                    },
                                  );
                                }

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
              ),
            );
          },
        );
      },
    );

    _clearSelectedReceipt();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Despesa atualizada')),
      );
      await _refresh();
    }
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir despesa'),
        content: const Text('Deseja realmente excluir esta despesa?'),
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

    await SupabaseService.instance.deleteExpense(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Despesa excluída')),
    );

    await _refresh();
  }

  Widget _expenseCard(Map<String, dynamic> expense) {
    final description = (expense['description'] ?? '').toString();
    final category = _categoryLabel((expense['category'] ?? 'other').toString());
    final date = _formatDate(expense['date']);
    final amount = _formatYen(expense['amount']);
    final receipt = (expense['receipt_url'] ?? '').toString();

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
              '$date • $category',
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
                if (receipt.isNotEmpty)
                  IconButton(
                    tooltip: 'Ver recibo',
                    icon: const Icon(
                      Icons.receipt_long,
                      color: Colors.green,
                    ),
                    onPressed: () => _showReceiptPreview(receipt),
                  ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editExpense(expense),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteExpense(expense['id'].toString()),
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
              'Nenhuma despesa registrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'As despesas cadastradas aparecerão aqui.',
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
        title: const Text('Despesas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova despesa',
            onPressed: _openAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final expense =
                          Map<String, dynamic>.from(_expenses[index]);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _expenseCard(expense),
                      );
                    },
                  ),
                ),
    );
  }
}
