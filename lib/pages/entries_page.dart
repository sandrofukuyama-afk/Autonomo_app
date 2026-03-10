import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  DateTime? _selectedDate;
  String? _paymentMethod;

  final List<String> _paymentMethods = const [
    'Dinheiro',
    'Cartão',
    'Transferência',
    'PayPay',
    'Outros'
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

    final double? amount = double.tryParse(_valueController.text);

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }

    final Map<String, dynamic> entry = {
      'date': _selectedDate!.toIso8601String(),
      'description': _descController.text,
      'amount': amount,
      'payment_method': _paymentMethod,
    };

    await SupabaseService.instance.addEntry(entry);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada registrada')),
    );

    Navigator.pop(context);
  }

  Widget _card({required Widget child}) {
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
        title: const Text('Registrar entrada'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card(
              child: Column(
                children: [
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration:
                        const InputDecoration(labelText: 'Método de pagamento'),
                    items: _paymentMethods
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _paymentMethod = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Salvar entrada'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _saveEntry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
