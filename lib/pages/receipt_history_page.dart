import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ReceiptHistoryPage extends StatefulWidget {
  const ReceiptHistoryPage({super.key});

  @override
  State<ReceiptHistoryPage> createState() => _ReceiptHistoryPageState();
}

class _ReceiptHistoryPageState extends State<ReceiptHistoryPage> {
  List<Map<String, dynamic>> _receipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    try {
      final receipts = await SupabaseService.instance.getAllReceipts();
      if (!mounted) return;
      setState(() {
        _receipts = receipts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar recibos: $e')),
      );
    }
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    if (parsed == null) return '-';
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _formatAmount(dynamic value) {
    final amount = double.tryParse((value ?? '').toString());
    if (amount == null) return 'JPY 0';
    return 'JPY ${amount.toStringAsFixed(0)}';
  }

  void _showDetails(Map<String, dynamic> receipt) {
    final t = AppLocalizations.of(context);
    final itemType = (receipt['item_type'] ?? 'product').toString();
    final documentKind = (receipt['document_kind'] ?? 'ryoushuusho').toString();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((receipt['receipt_number'] ?? '').toString()),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${t.translate('receipt_date')}: ${_formatDate(receipt['issue_date'])}'),
                const SizedBox(height: 8),
                Text('${t.translate('document_kind')}: ${t.translate('document_kind_$documentKind')}'),
                const SizedBox(height: 8),
                Text('${t.translate('receipt_item_type')}: ${t.translate('receipt_item_$itemType')}'),
                const SizedBox(height: 8),
                Text('${t.translate('description')}: ${(receipt['description'] ?? '-').toString()}'),
                const SizedBox(height: 8),
                Text('${t.translate('value')}: ${_formatAmount(receipt['amount'])}'),
                const SizedBox(height: 8),
                Text('${t.translate('client_name')}: ${(receipt['client_name'] ?? '-').toString()}'),
                const SizedBox(height: 8),
                Text('${t.translate('client_email')}: ${(receipt['client_email'] ?? '-').toString()}'),
                const SizedBox(height: 8),
                Text('${t.translate('payment_method')}: ${(receipt['payment_method'] ?? '-').toString()}'),
                const SizedBox(height: 8),
                Text('${t.translate('notes')}: ${(receipt['notes'] ?? '-').toString()}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.translate('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t.translate('receipt_history'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('receipt_history')),
      ),
      body: _receipts.isEmpty
          ? Center(
              child: Text(t.translate('no_receipts_yet')),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _receipts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final receipt = _receipts[index];
                return Card(
                  child: ListTile(
                    onTap: () => _showDetails(receipt),
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      (receipt['receipt_number'] ?? '').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text((receipt['description'] ?? '-').toString()),
                          const SizedBox(height: 6),
                          Text('${_formatDate(receipt['issue_date'])} • ${_formatAmount(receipt['amount'])}'),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }
}
