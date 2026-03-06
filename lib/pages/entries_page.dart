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
