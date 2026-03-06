import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

/// Página para registrar entradas de receita.
class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  DateTime? _selectedDate;
  // Novo campo para armazenar o método de pagamento selecionado.
  String? _selectedPaymentMethod;
  
  // Lista de opções de métodos de pagamento disponíveis.
  final List<String> _paymentMethods = [
    'Dinheiro',
    'Cartão de crédito',
    'Transferência bancária',
    'Outro',
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

  Future<void> _saveEntry() async {
    if (_selectedDate == null ||
        _descController.text.isEmpty ||
        _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos')),
      );
      return;
    }
    // Verifica se o método de pagamento foi selecionado.
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o método de pagamento')),
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
    final Map<String, dynamic> entry = {
      'description': _descController.text,
      'amount': amount,
      'date': _selectedDate!.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'payment_method': _selectedPaymentMethod,
    };
    await SupabaseService.instance.addEntry(entry);
    _descController.clear();
    _valueController.clear();
    setState(() {
      _selectedDate = null;
      _selectedPaymentMethod = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada adicionada!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
          // Dropdown para selecionar o método de pagamento.
          DropdownButtonFormField<String>(
            value: _selectedPaymentMethod,
            decoration: const InputDecoration(
              labelText: 'Método de pagamento',
            ),
            items: _paymentMethods
                .map((method) => DropdownMenuItem<String>(
                      value: method,
                      child: Text(method),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value;
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
                onPressed: _selectDate,
                child: const Text('Selecionar data'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveEntry,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}