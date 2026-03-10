import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../data/supabase_service.dart';

enum ExpenseInputMode { scan, manual }

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
  ExpenseInputMode? _mode;

  XFile? _receiptFile;
  String? _uploadedReceiptUrl;

  final List<String> _categoryKeys = const [
    'Alimentação',
    'Transporte',
    'Moradia',
    'Lazer',
    'Saúde',
    'Outros',
  ];

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
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

  Future<void> _saveExpense() async {
    if (_selectedDate == null ||
        _descController.text.isEmpty ||
        _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos')),
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
      'date': _selectedDate!.toIso8601String(),
      'description': _descController.text,
      'amount': amount,
      'category': _selectedCategory,
      'receipt_url': _uploadedReceiptUrl,
      'file_name':
          _receiptFile != null ? path.basename(_receiptFile!.path) : null,
    };

    await SupabaseService.instance.addExpense(expense);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Despesa registrada')),
    );

    Navigator.pop(context);
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        _modeCard(
          icon: Icons.document_scanner,
          title: 'Escanear recibo',
          subtitle:
              'Tire foto ou escolha imagem para preencher automaticamente',
          onTap: () {
            setState(() {
              _mode = ExpenseInputMode.scan;
            });
          },
        ),
        const SizedBox(height: 16),
        _modeCard(
          icon: Icons.edit_note,
          title: 'Inserir manualmente',
          subtitle: 'Preencher os campos manualmente',
          onTap: () {
            setState(() {
              _mode = ExpenseInputMode.manual;
            });
          },
        ),
      ],
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue.shade100,
          child: Icon(icon, color: Colors.blue.shade800),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildManualForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _formCard(
          child: Column(
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
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _formCard(
          child: Row(
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
                child: const Text('Selecionar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Salvar despesa'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
          ),
          onPressed: _saveExpense,
        ),
      ],
    );
  }

  Widget _formCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
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
