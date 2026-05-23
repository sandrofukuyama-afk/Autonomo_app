import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../services/receipt_pdf_service.dart';
import 'receipt_issue_page.dart';

class ReceiptHistoryPage extends StatefulWidget {
  const ReceiptHistoryPage({super.key});

  @override
  State<ReceiptHistoryPage> createState() => _ReceiptHistoryPageState();
}

class _ReceiptHistoryPageState extends State<ReceiptHistoryPage> {
  List<Map<String, dynamic>> _receipts = [];
  bool _loading = true;
  String _selectedKind = 'ryoushuusho';
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  final Set<String> _paidReceiptIds = <String>{};

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
    if (amount == null) return '¥0';
    final formatter = NumberFormat('#,##0', 'en_US');
    return '¥${formatter.format(amount)}';
  }

  String _paymentConditionLabel(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'faturado':
        return 'Faturado';
      case 'parcelado':
        return 'Parcelado';
      default:
        return 'À vista';
    }
  }

  int _countByKind(String kind) {
    return _receipts
        .where((r) => (r['document_kind'] ?? 'ryoushuusho').toString() == kind)
        .length;
  }

  List<Map<String, dynamic>> _filteredReceipts() {
    return _receipts.where((r) {
      final kindMatches =
          (r['document_kind'] ?? 'ryoushuusho').toString() == _selectedKind;
      if (!kindMatches) return false;

      final parsed = DateTime.tryParse((r['issue_date'] ?? '').toString());
      if (parsed == null) return false;

      return parsed.year == _selectedMonth.year &&
          parsed.month == _selectedMonth.month;
    }).toList();
  }

  bool _isReceiptPaid(Map<String, dynamic> receipt) {
    final id = (receipt['id'] ?? '').toString();
    if (id.isNotEmpty && _paidReceiptIds.contains(id)) return true;
    return (receipt['entry_id'] ?? '').toString().trim().isNotEmpty;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Selecionar mês',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  Future<void> _markAsPaid(Map<String, dynamic> receipt) async {
    if (_isReceiptPaid(receipt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este recibo já está quitado.')),
      );
      return;
    }

    try {
      final issueDate = DateTime.tryParse((receipt['issue_date'] ?? '').toString());
      final date = issueDate == null
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : DateFormat('yyyy-MM-dd').format(issueDate);
      final amount = double.tryParse((receipt['amount'] ?? '0').toString()) ?? 0;

      await SupabaseService.instance.addEntry({
        'date': date,
        'description': (receipt['description'] ?? '').toString(),
        'category': ((receipt['item_type'] ?? 'product').toString() == 'service')
            ? 'service'
            : 'sale',
        'amount': amount,
        'payment_method': (receipt['payment_method'] ?? 'cash').toString(),
        'tax_rate': null,
        'tax_inclusion_type': 'unknown',
        'tax_amount':
            double.tryParse((receipt['tax_amount'] ?? '0').toString()) ?? 0,
        'qualified_invoice_issued': false,
        'qualified_invoice_number': receipt['receipt_number'],
        'customer_name': receipt['client_name'],
        'revenue_type':
            ((receipt['item_type'] ?? 'product').toString() == 'service')
                ? 'service'
                : 'product',
        'fiscal_revenue_category': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() {
        final id = (receipt['id'] ?? '').toString();
        if (id.isNotEmpty) _paidReceiptIds.add(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recibo quitado e enviado para Entradas.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao quitar recibo: $e')),
      );
    }
  }

  ReceiptData _toReceiptData(Map<String, dynamic> receipt) {
    final issueDate =
        DateTime.tryParse((receipt['issue_date'] ?? '').toString()) ??
            DateTime.now();
    final dueDate = DateTime.tryParse((receipt['due_date'] ?? '').toString());
    final amount = double.tryParse((receipt['amount'] ?? '0').toString()) ?? 0;
    final taxAmount =
        double.tryParse((receipt['tax_amount'] ?? '0').toString()) ?? 0;

    return ReceiptData(
      receiptNumber: (receipt['receipt_number'] ?? '').toString(),
      issueDate: issueDate,
      dueDate: dueDate,
      documentKind: (receipt['document_kind'] ?? 'ryoushuusho').toString(),
      description: (receipt['description'] ?? '').toString(),
      amount: amount,
      taxAmount: taxAmount,
      currency: 'JPY',
      paymentMethod: (receipt['payment_method'] ?? 'cash').toString(),
      issuedBy: '',
      companyAddress: null,
      companyPhone: null,
      invoiceNumber: null,
      clientName: (receipt['client_name'] ?? '').toString().isEmpty
          ? null
          : (receipt['client_name'] ?? '').toString(),
      clientEmail: (receipt['client_email'] ?? '').toString().isEmpty
          ? null
          : (receipt['client_email'] ?? '').toString(),
      notes: (receipt['notes'] ?? '').toString().isEmpty
          ? null
          : (receipt['notes'] ?? '').toString(),
      language: (receipt['language'] ?? 'pt').toString(),
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> receipt) async {
    final data = _toReceiptData(receipt);
    final format = (receipt['format'] ?? 'a4').toString();

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

    await Printing.layoutPdf(onLayout: (_) => Future.value(bytes));
  }

  Future<void> _editReceipt(Map<String, dynamic> receipt) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptIssuePage(entryData: receipt),
      ),
    );
    await _loadReceipts();
  }

  String _monthGroupKey(Map<String, dynamic> receipt) {
    final parsed = DateTime.tryParse((receipt['issue_date'] ?? '').toString());
    if (parsed == null) return 'Sem data';
    return DateFormat('MMMM/yyyy', 'pt_BR').format(parsed);
  }

  String _monthGroupLabel(String key) {
    if (key == 'Sem data' || key.isEmpty) return key;
    return '${key[0].toUpperCase()}${key.substring(1)}';
  }

  Widget _kindCard({
    required BuildContext context,
    required AppLocalizations t,
    required String kind,
    required IconData icon,
  }) {
    final selected = _selectedKind == kind;
    final cs = Theme.of(context).colorScheme;
    final count = _countByKind(kind);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedKind = kind),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                t.translate('document_kind_$kind'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
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
                Text(
                  '${t.translate('receipt_date')}: ${_formatDate(receipt['issue_date'])}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('document_kind')}: ${t.translate('document_kind_$documentKind')}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('receipt_item_type')}: ${t.translate('receipt_item_$itemType')}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('description')}: ${(receipt['description'] ?? '-').toString()}',
                ),
                const SizedBox(height: 8),
                Text('${t.translate('value')}: ${_formatAmount(receipt['amount'])}'),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('client_name')}: ${(receipt['client_name'] ?? '-').toString()}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('client_email')}: ${(receipt['client_email'] ?? '-').toString()}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.translate('payment_method')}: ${(receipt['payment_method'] ?? '-').toString()}',
                ),
                const SizedBox(height: 8),
                Text('Condição: ${_paymentConditionLabel(receipt['payment_condition'])}'),
                const SizedBox(height: 8),
                Text('Vencimento: ${_formatDate(receipt['due_date'])}'),
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
    final filtered = _filteredReceipts();
    final groupedReceipts = <String, List<Map<String, dynamic>>>{};
    for (final receipt in filtered) {
      final key = _monthGroupKey(receipt);
      groupedReceipts.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(receipt);
    }

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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _kindCard(
                      context: context,
                      t: t,
                      kind: 'ryoushuusho',
                      icon: Icons.receipt_long_outlined,
                    ),
                    const SizedBox(width: 12),
                    _kindCard(
                      context: context,
                      t: t,
                      kind: 'seikyuusho',
                      icon: Icons.request_quote_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickMonth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined),
                        const SizedBox(width: 10),
                        Text(
                          _monthGroupLabel(
                            DateFormat('MMMM/yyyy', 'pt_BR').format(_selectedMonth),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhum recibo em ${_monthGroupLabel(DateFormat('MMMM/yyyy', 'pt_BR').format(_selectedMonth))} (${t.translate('document_kind_$_selectedKind')})',
                      ),
                    ),
                  )
                else
                  ...groupedReceipts.entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                        child: Text(
                          _monthGroupLabel(entry.key),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      ...entry.value.map((receipt) {
                        final paid = _isReceiptPaid(receipt);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (receipt['receipt_number'] ?? '').toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (paid)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'QUITADO',
                                            style: TextStyle(
                                              color: Colors.green.shade900,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text((receipt['description'] ?? '-').toString()),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_formatDate(receipt['issue_date'])} • ${_formatAmount(receipt['amount'])}',
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _actionButton(
                                        icon: Icons.check_circle_outline,
                                        label: 'Quitar',
                                        color: paid ? Colors.green.shade800 : null,
                                        onPressed: () => _markAsPaid(receipt),
                                      ),
                                      _actionButton(
                                        icon: Icons.print_outlined,
                                        label: 'Imprimir',
                                        onPressed: () => _printReceipt(receipt),
                                      ),
                                      _actionButton(
                                        icon: Icons.edit_outlined,
                                        label: 'Editar',
                                        onPressed: () => _editReceipt(receipt),
                                      ),
                                      _actionButton(
                                        icon: Icons.visibility_outlined,
                                        label: 'Ver',
                                        onPressed: () => _showDetails(receipt),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ];
                  }),
              ],
            ),
    );
  }
}
