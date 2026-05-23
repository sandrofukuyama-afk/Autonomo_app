import 'package:flutter/material.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class SettingsServicesPage extends StatefulWidget {
  const SettingsServicesPage({super.key});

  @override
  State<SettingsServicesPage> createState() => _SettingsServicesPageState();
}

class _SettingsServicesPageState extends State<SettingsServicesPage> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await SupabaseService.instance.getServiceCatalog();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar serviços: $e')),
      );
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? service]) async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: (service?['name'] ?? '').toString());
    final descriptionCtrl = TextEditingController(
      text: (service?['description'] ?? '').toString(),
    );
    final amountCtrl = TextEditingController(
      text: service?['default_amount'] == null
          ? ''
          : service!['default_amount'].toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('service_catalog')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: t.translate('service_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: t.translate('service_description'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.translate('default_amount'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final amountText = amountCtrl.text.trim().replaceAll(',', '');
              final amount = amountText.isEmpty ? null : double.tryParse(amountText);

              try {
                if (service == null) {
                  await SupabaseService.instance.createServiceCatalogItem(
                    name: nameCtrl.text,
                    description: descriptionCtrl.text,
                    defaultAmount: amount,
                  );
                } else {
                  await SupabaseService.instance.updateServiceCatalogItem(
                    id: service['id'].toString(),
                    name: nameCtrl.text,
                    description: descriptionCtrl.text,
                    defaultAmount: amount,
                  );
                }
                if (!mounted) return;
                Navigator.pop(context);
                _loadServices();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text(t.translate('save_service')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('delete_entry')),
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

    if (confirmed != true) return;

    try {
      await SupabaseService.instance.deleteServiceCatalogItem(service['id'].toString());
      _loadServices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _amountLabel(dynamic value) {
    if (value == null) return '-';
    final amount = double.tryParse(value.toString());
    if (amount == null) return '-';
    return '¥${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t.translate('service_catalog'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('service_catalog')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: _services.isEmpty
          ? Center(
              child: Text(t.translate('no_services_registered')),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final service = _services[index];
                final description = (service['description'] ?? '').toString().trim();

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      (service['name'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (description.isNotEmpty) Text(description),
                          const SizedBox(height: 6),
                          Text('${t.translate('default_amount')}: ${_amountLabel(service['default_amount'])}'),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openEditor(service),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteService(service),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
