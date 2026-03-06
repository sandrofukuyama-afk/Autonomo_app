import 'package:flutter/material.dart';

/// Tela para registrar entradas de receita.
class EntriesPage extends StatelessWidget {
  const EntriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_circle_outline, size: 80.0),
          SizedBox(height: 16.0),
          Text('Registrar entrada', style: TextStyle(fontSize: 18.0)),
        ],
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final String dateText = _selectedDate == null
        ? 'Nenhuma data selecionada'
        : 'Data: ' + _selectedDate!.toLocal().toString().split(' ')[0];
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
          Row(
            children: [
              Expanded(
                child: Text(dateText),
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
