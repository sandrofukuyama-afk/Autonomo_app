import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

enum ExpenseInputMode { scan, manual }

class _ExpensesPageState extends State<ExpensesPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedCategory;
  XFile? _receiptFile;
  String? _uploadedReceiptUrl;
  bool _ocrLoading = false;

  ExpenseInputMode? _mode;

  final List<String> _categoryKeys = const [
    'category_food',
    'category_transport',
    'category_housing',
    'category_entertainment',
    'category_health',
    'category_other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (_selectedDate == null ||
        _descController.text.isEmpty ||
        _valueController.text.isEmpty) {
      return;
    }

    final double? amount = double.tryParse(_valueController.text);

    if (amount == null) return;

    final Map<String, dynamic> expense = {
      'date': _selectedDate!.toIso8601String(),
      'description': _descController.text,
      'amount': amount,
      'category': _selectedCategory,
      'store_name': null,
      'tax': 0,
      'tax_type': null,
      'receipt_url': _uploadedReceiptUrl,
      'file_name': _receiptFile != null ? path.basename(_receiptFile!.path) : null,
    };

    await SupabaseService.instance.addExpense(expense);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Despesa salva com sucesso')),
    );

    Navigator.pop(context);
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Widget _buildManualForm() {
    return Column(
      children: [
        TextField(
          controller: _descController,
          decoration: const InputDecoration(labelText: 'Descrição'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _valueController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Valor'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: _categoryKeys
              .map(
                (key) => DropdownMenuItem(
                  value: key,
                  child: Text(key),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Nenhuma data selecionada'
                    : 'Data: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
              ),
            ),
            ElevatedButton(
              onPressed: _selectDate,
              child: const Text('Selecionar data'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _saveExpense,
          child: const Text('Salvar despesa'),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.document_scanner),
          title: const Text('Escanear recibo'),
          subtitle: const Text(
              'Tire foto ou escolha uma imagem para preencher automaticamente.'),
          onTap: () {
            setState(() {
              _mode = ExpenseInputMode.scan;
            });
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.edit_note),
          title: const Text('Inserir manualmente'),
          subtitle:
              const Text('Preencha os campos manualmente sem usar OCR.'),
          onTap: () {
            setState(() {
              _mode = ExpenseInputMode.manual;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar despesa'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: _mode == null ? _buildModeSelector() : _buildManualForm(),
        ),
      ),
    );
  }
}
