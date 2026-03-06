import 'package:flutter/material.dart';

/// Tela para registrar saídas ou despesas.
class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.remove_circle_outline, size: 80.0),
          SizedBox(height: 16.0),
          Text('Registrar saída', style: TextStyle(fontSize: 18.0)),
        ],
      ),
    );
  }
}
