import 'package:flutter/material.dart';

import 'entries_page.dart';
import 'expenses_page.dart';

/// Página inicial com navegação entre telas de entradas e saídas.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    EntriesPage(),
    ExpensesPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Entradas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off),
            label: 'Saídas',
          ),
        ],
      ),
    );
  }
}
