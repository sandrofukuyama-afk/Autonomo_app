import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart'; // ✅ NOVO

class SettingsCategoriesPage extends StatefulWidget {
  const SettingsCategoriesPage({super.key});

  @override
  State<SettingsCategoriesPage> createState() => _SettingsCategoriesPageState();
}

class _SettingsCategoriesPageState extends State<SettingsCategoriesPage> {
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _entryCategories = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final expenses = await _client
          .from('expense_categories')
          .select()
          .order('created_at');

      final entries = await _client
          .from('entry_categories')
          .select()
          .order('created_at');

      setState(() {
        _expenseCategories = List<Map<String, dynamic>>.from(expenses);
        _entryCategories = List<Map<String, dynamic>>.from(entries);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _addCategory(String type) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('new_category')),
        content: TextField(
          controller: controller,
          decoration:
              InputDecoration(labelText: t.translate('category_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final table =
                  type == 'expense' ? 'expense_categories' : 'entry_categories';

              await _client.from(table).insert({
                'code': name.toLowerCase().replaceAll(' ', '_'),
                'label_pt': name,
              });

              Navigator.pop(context);
              _loadCategories();
            },
            child: Text(t.translate('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategory(
      String type, Map<String, dynamic> category) async {
    final t = AppLocalizations.of(context);
    final controller =
        TextEditingController(text: category['label_pt'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('category_name')),
        content: TextField(
          controller: controller,
          decoration:
              InputDecoration(labelText: t.translate('category_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final table =
                  type == 'expense' ? 'expense_categories' : 'entry_categories';

              await _client.from(table).update({
                'label_pt': name,
              }).eq('id', category['id']);

              Navigator.pop(context);
              _loadCategories();
            },
            child: Text(t.translate('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(
      String type, Map<String, dynamic> category) async {
    final t = AppLocalizations.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('cancel')),
        content: Text(t.translate('confirm_delete_entry')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.translate('delete_entry')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final table =
        type == 'expense' ? 'expense_categories' : 'entry_categories';

    await _client.from(table).delete().eq('id', category['id']);

    _loadCategories();
  }

  Widget _buildSection(
      String titleKey, String type, List<Map<String, dynamic>> data) {
    final t = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.translate(titleKey),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => _addCategory(type),
                  icon: const Icon(Icons.add),
                )
              ],
            ),
            const Divider(),
            ...data.map((item) {
              return ListTile(
                title: Text(item['label_pt'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editCategory(type, item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteCategory(type, item),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('categories')), // ✅ corrigido
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            _buildSection(
              'expenses',
              'expense',
              _expenseCategories,
            ),
            _buildSection(
              'entries',
              'entry',
              _entryCategories,
            ),
          ],
        ),
      ),
    );
  }
}
