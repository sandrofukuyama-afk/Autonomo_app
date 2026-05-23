import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../services/receipt_pdf_service.dart';
import 'receipt_issue_page.dart';

class ClientHistoryPage extends StatefulWidget {
  const ClientHistoryPage({super.key});

  @override
  State<ClientHistoryPage> createState() => _ClientHistoryPageState();
}

class _ClientHistoryPageState extends State<ClientHistoryPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _receipts = [];
  Map<String, String?> _companyProfile = {};
  String? _selectedClientName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        SupabaseService.instance.getClients(),
        SupabaseService.instance.getAllReceipts(),
        SupabaseService.instance.getCompanyProfile(),
      ]);
      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(results[0] as List);
        _receipts = List<Map<String, dynamic>>.from(results[1] as List);
        _companyProfile = Map<String, String?>.from(results[2] as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar histórico: $e')));
    }
  }

  List<Map<String, dynamic>> _receiptsForSelectedClient() {
    final name = (_selectedClientName ?? '').trim().toLowerCase();
    if (name.isEmpty) return const [];
    return _receipts.where((r) {
      final client = (r['client_name'] ?? '').toString().trim().toLowerCase();
      return client == name;
    }).toList();
  }

  List<Map<String, dynamic>> _servicesForClient() {
    return _receiptsForSelectedClient()
        .where((r) => (r['item_type'] ?? 'product').toString() == 'service')
        .toList();
  }

  List<Map<String, dynamic>> _purchasesForClient() {
    return _receiptsForSelectedClient()
        .where((r) => (r['item_type'] ?? 'product').toString() != 'service')
        .toList();
  }

  String _fmtDate(dynamic value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    if (parsed == null) return '-';
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _fmtAmount(dynamic value) {
    final amount = double.tryParse((value ?? '').toString()) ?? 0;
    return '¥${amount.toStringAsFixed(0)}';
  }

  ReceiptData _receiptDataFromRow(Map<String, dynamic> r) {
    final t = AppLocalizations.of(context);
    final issueDate =
        DateTime.tryParse((r['issue_date'] ?? '').toString()) ?? DateTime.now();
    final dueDate = DateTime.tryParse((r['due_date'] ?? '').toString());
    final amount = double.tryParse((r['amount'] ?? 0).toString()) ?? 0;
    final taxAmount = double.tryParse((r['tax_amount'] ?? 0).toString()) ?? 0;
    final language = (r['language'] ?? _companyProfile['language'] ?? 'pt')
        .toString();

    return ReceiptData(
      receiptNumber: (r['receipt_number'] ?? '-').toString(),
      issueDate: issueDate,
      documentKind: (r['document_kind'] ?? 'ryoushuusho').toString(),
      description: (r['description'] ?? '').toString(),
      amount: amount,
      taxAmount: taxAmount,
      currency: 'JPY',
      paymentMethod: (r['payment_method'] ?? 'cash').toString(),
      issuedBy:
          (r['issued_by'] ?? _companyProfile['name'] ?? t.translate('app_name'))
              .toString(),
      companyAddress:
          (r['company_address'] ?? _companyProfile['address'])?.toString(),
      companyPhone: (r['company_phone'] ?? _companyProfile['phone'])?.toString(),
      invoiceNumber:
          (r['invoice_number'] ?? _companyProfile['invoice_number'])?.toString(),
      clientName: (r['client_name'] ?? '').toString(),
      clientEmail: (r['client_email'] ?? '').toString(),
      notes: (r['notes'] ?? '').toString(),
      language: language,
      dueDate: dueDate,
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> row) async {
    try {
      final data = _receiptDataFromRow(row);
      final format = (row['format'] ?? 'a4').toString();
      late final Uint8List bytes;
      switch (format) {
        case 'thermal_58':
          bytes = await ReceiptPdfService.buildThermal58(data);
          break;
        case 'thermal_80':
          bytes = await ReceiptPdfService.buildThermal80(data);
          break;
        case 'a5':
          bytes = await ReceiptPdfService.buildA5(data);
          break;
        default:
          bytes = await ReceiptPdfService.buildA4(data);
      }
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao imprimir: $e')));
    }
  }

  void _viewDocument(Map<String, dynamic> row) {
    final t = AppLocalizations.of(context);
    final kind = (row['document_kind'] ?? 'ryoushuusho').toString();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${t.translate('document_kind_$kind')} - ${(row['receipt_number'] ?? '').toString()}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.translate('receipt_date')}: ${_fmtDate(row['issue_date'])}'),
            const SizedBox(height: 8),
            Text('${t.translate('description')}: ${(row['description'] ?? '-').toString()}'),
            const SizedBox(height: 8),
            Text('${t.translate('value')}: ${_fmtAmount(row['amount'])}'),
            const SizedBox(height: 8),
            Text('${t.translate('client_name')}: ${(row['client_name'] ?? '-').toString()}'),
          ],
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

  Future<void> _editReceipt(Map<String, dynamic> row) async {
    final payload = Map<String, dynamic>.from(row);
    payload['receipt_id'] = row['id'];
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReceiptIssuePage(entryData: payload)),
    );
    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _deleteReceipt(Map<String, dynamic> row) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('delete_document')),
        content: Text(
          '${t.translate('delete_document')}: ${(row['receipt_number'] ?? '').toString()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.translate('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.instance.deleteReceipt(row['id'].toString());
      if (!mounted) return;
      await _loadData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Documento excluído.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  Widget _historySection(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
  ) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(t.translate('no_records'))
            else
              ...items.map((row) {
                final kind = (row['document_kind'] ?? 'ryoushuusho').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (row['receipt_number'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text((row['description'] ?? '-').toString()),
                        const SizedBox(height: 4),
                        Text('${_fmtDate(row['issue_date'])} • ${_fmtAmount(row['amount'])}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _viewDocument(row),
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: Text('Ver ${t.translate('document_kind_$kind')}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _printReceipt(row),
                              icon: const Icon(Icons.print_outlined, size: 16),
                              label: Text(t.translate('print_receipt')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _editReceipt(row),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(t.translate('edit')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _deleteReceipt(row),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: Text(t.translate('delete')),
                            ),
                          ],
                        ),
                      ],
                    ),
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _receiptsForSelectedClient();
    final services = _servicesForClient();
    final purchases = _purchasesForClient();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).translate('client_history'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedClientName,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).translate('select_client'),
              prefixIcon: const Icon(Icons.person_search_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
            items: _clients
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: (c['name'] ?? '').toString(),
                    child: Text((c['name'] ?? '').toString()),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedClientName = value),
          ),
          const SizedBox(height: 16),
          if (_selectedClientName == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(AppLocalizations.of(context).translate('select_client_to_view_history')),
              ),
            )
          else if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(AppLocalizations.of(context).translate('no_history_for_client')),
              ),
            )
          else ...[
            _historySection(context, AppLocalizations.of(context).translate('services'), services),
            const SizedBox(height: 12),
            _historySection(context, AppLocalizations.of(context).translate('purchases'), purchases),
          ],
        ],
      ),
    );
  }
}
