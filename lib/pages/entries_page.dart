import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  List<Map<String, dynamic>> entries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    setState(() {
      loading = true;
    });

    final data = await SupabaseService.getEntries();

    setState(() {
      entries = data;
      loading = false;
    });
  }

  String formatDate(String date) {
    final d = DateTime.parse(date);
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
  }

  String formatCurrency(num value) {
    return "¥${value.toStringAsFixed(0)}";
  }

  Widget buildEntryCard(Map<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// DESCRIÇÃO
          Text(
            entry['description'] ?? '',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          /// DATA + MÉTODO
          Text(
            "${formatDate(entry['entry_date'])} • ${entry['payment_method'] ?? ''}",
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              /// VALOR
              Expanded(
                child: Text(
                  formatCurrency(entry['amount']),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),

              /// EDITAR
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  // editar entrada
                },
              ),

              /// EXCLUIR
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await SupabaseService.deleteEntry(entry['id']);
                  loadEntries();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text("Entradas"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // abrir formulário
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadEntries,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const Center(
                  child: Text(
                    "Nenhuma entrada cadastrada",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return buildEntryCard(entries[index]);
                  },
                ),
    );
  }
}
