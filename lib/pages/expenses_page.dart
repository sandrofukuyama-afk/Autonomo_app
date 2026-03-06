import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/supabase_service.dart';

/// Tela para registrar saídas ou despesas.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory;
  XFile? _receiptFile;

  final List<String> _categories = const [
    'Alimentação',
    'Transporte',
    'Moradia',
    'Entretenimento',
    'Saúde',
    'Outros',
  ];

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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

  Future<void> _pickReceipt() async {
    final ImagePicker picker = ImagePicker();
    // Tenta capturar pela câmera; se não for possível, usa a galeria como fallback.
    XFile? pickedImage;
    try {
      pickedImage = await picker.pickImage(source: ImageSource.camera);
    } catch (_) {
      pickedImage = await picker.pickImage(source: ImageSource.gallery);
    }
    if (pickedImage != null) {
      // Copia o arquivo para o diretório de documentos do aplicativo para persistência.
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = path.basename(pickedImage.path);
      final File savedImage =
          await File(pickedImage.path).copy('${appDir.path}/$fileName');
      setState(() {
        _receiptFile = XFile(savedImage.path);
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_selectedDate == null ||
        _descController.text.isEmpty ||
        _valueController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios')),
      );
      return;
    }
    final double? amount = double.tryParse(_valueController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }
    final Map<String, dynamic> expense = {
      'description': _descController.text,
      'amount': amount,
      'date': _selectedDate!.toIso8601String(),
      'category': _selectedCategory,
      'receipt_path': _receiptFile?.path,
      'created_at': DateTime.now().toIso8601String(),
    };
    await SupabaseService.instance.addExpense(expense);
    _descController.clear();
    _valueController.clear();
    setState(() {
      _selectedDate = null;
      _selectedCategory = null;
      _receiptFile = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Despesa adicionada!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            items: _categories
                .map((c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ))
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
                      : 'Data: \${_selectedDate!.toLocal().toString().split(' ')[0]}',
                ),
              ),
              ElevatedButton(
                onPressed: _pickDate,
                child: const Text('Selecionar data'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _receiptFile == null
                    ? const Text('Nenhum recibo selecionado')
                    : Text('Recibo: \${path.basename(_receiptFile!.path)}'),
              ),
              ElevatedButton(
                onPressed: _pickReceipt,
                child: const Text('Selecionar recibo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveExpense,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}