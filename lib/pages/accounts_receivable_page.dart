import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/supabase_service.dart';
import '../services/receipt_pdf_service.dart';

class AccountsReceivablePage extends StatefulWidget {
  const AccountsReceivablePage({super.key});

  @override
  State<AccountsReceivablePage> createState() => _AccountsReceivablePageState();
}

class _AccountsReceivablePageState extends State<AccountsReceivablePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseService.instance.getReceiptPaymentSchedules();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar contas a receber: $e')),
      );
    }
  }

  Map<String, dynamic> _receiptOf(Map<String, dynamic> item) {
    final receipt = item['receipts'];
    if (receipt is Map) {
      return Map<String, dynamic>.from(receipt);
    }
    if (receipt is List && receipt.isNotEmpty && receipt.first is Map) {
      return Map<String, dynamic>.from(receipt.first as Map);
    }
    return const {};
  }

  DateTime? _parseDate(dynamic value) {
    return DateTime.tryParse((value ?? '').toString());
  }

  bool _isPaid(Map<String, dynamic> item) {
    return (item['status'] ?? '').toString() == 'paid';
  }

  bool _isOverdue(Map<String, dynamic> item) {
    if (_isPaid(item)) return false;
    final dueDate = _parseDate(item['due_date']);
    if (dueDate == null) return false;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDue = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return normalizedDue.isBefore(normalizedToday);
  }

  double _toDouble(dynamic value) {
    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  String _formatAmount(dynamic value) {
    return '\u00A5${_toDouble(value).toStringAsFixed(0)}';
  }

  String _formatDate(dynamic value) {
    final parsed = _parseDate(value);
    if (parsed == null) return '-';
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _monthGroupKey(Map<String, dynamic> item) {
    final dueDate = _parseDate(item['due_date']);
    if (dueDate == null) return 'Sem vencimento';
    return DateFormat('MMMM/yyyy', 'pt_BR').format(dueDate);
  }

  String _monthGroupLabel(String key) {
    if (key == 'Sem vencimento') return key;
    if (key.isEmpty) return key;
    return '${key[0].toUpperCase()}${key.substring(1)}';
  }

  Future<void> _printSettlementReceipt(Map<String, dynamic> item) async {
    final receipt = _receiptOf(item);
    final profile = await SupabaseService.instance.getCompanyProfile();
    final now = DateTime.now();
    final receiptNumber = (receipt['receipt_number'] ?? '-').toString();
    final installmentNumber = (item['installment_number'] ?? '-').toString();
    final paidAmount = _toDouble(item['paid_amount'] ?? item['amount']);
    final paymentMethod = (item['payment_method'] ?? receipt['payment_method'] ?? 'cash')
        .toString();
    final clientName = (receipt['client_name'] ?? '').toString().trim();
    final baseDescription = (receipt['description'] ?? '').toString().trim();

    final data = ReceiptData(
      receiptNumber: '${receiptNumber}_P$installmentNumber',
      issueDate: now,
      dueDate: _parseDate(item['due_date']),
      documentKind: 'ryoushuusho',
      description: baseDescription.isEmpty
          ? 'Baixa da parcela $installmentNumber do recibo $receiptNumber'
          : '$baseDescription - Baixa parcela $installmentNumber',
      amount: paidAmount,
      taxAmount: 0,
      currency: 'JPY',
      paymentMethod: paymentMethod,
      issuedBy: profile['name'] ?? '',
      companyAddress: profile['address'],
      companyPhone: profile['phone'],
      invoiceNumber: profile['invoice_number'],
      clientName: clientName.isEmpty ? null : clientName,
      notes: 'Recebimento confirmado em ${DateFormat('dd/MM/yyyy').format(now)}',
      language: (profile['language'] ?? 'pt').toString(),
    );

    final bytes = await ReceiptPdfService.buildA4(data);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _markAsPaid(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar recebimento'),
        content: Text(
          'Dar baixa na parcela ${item['installment_number'] ?? '-'} no valor de ${_formatAmount(item['amount'])}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar baixa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final receipt = _receiptOf(item);
      final paidValue = _toDouble(item['amount']);
      final installmentNumber = item['installment_number'] ?? '-';
      final receiptNumber = (receipt['receipt_number'] ?? '-').toString();
      final baseDescription = (receipt['description'] ?? '').toString().trim();
      final paymentMethod = (item['payment_method'] ??
              receipt['payment_method'] ??
              'cash')
          .toString();
      final itemType = (receipt['item_type'] ?? 'product').toString();

      await SupabaseService.instance.markReceiptPaymentScheduleAsPaid(
        item['id'].toString(),
        paymentMethod: paymentMethod,
        paidAmount: paidValue,
      );

      await SupabaseService.instance.addEntry({
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'description': baseDescription.isEmpty
            ? 'Recebimento do recibo $receiptNumber - Parcela $installmentNumber'
            : '$baseDescription - Parcela $installmentNumber',
        'category': itemType == 'service' ? 'service' : 'sale',
        'amount': paidValue,
        'payment_method': paymentMethod,
        'tax_rate': null,
        'tax_inclusion_type': 'unknown',
        'tax_amount': null,
        'qualified_invoice_issued': false,
        'qualified_invoice_number': receiptNumber,
        'customer_name': receipt['client_name'],
        'revenue_type': itemType == 'service' ? 'service' : 'product',
        'fiscal_revenue_category': null,
        'created_at': DateTime.now().toIso8601String(),
      );

      try {
        await _printSettlementReceipt(item);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Baixa concluÃ­da, mas nÃ£o foi possÃ­vel imprimir o recibo: $e')),
          );
        }
      }
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao dar baixa: $e')),
      );
    }
  }

  Future<void> _reopenPayment(Map<String, dynamic> item) async {
    try {
      await SupabaseService.instance.reopenReceiptPaymentSchedule(
        item['id'].toString(),
      );
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao reabrir parcela: $e')),
      );
    }
  }

  Future<void> _editDueDate(Map<String, dynamic> item) async {
    final initialDate = _parseDate(item['due_date']) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked == null) return;

    try {
      await SupabaseService.instance.updateReceiptPaymentScheduleDueDate(
        item['id'].toString(),
        picked,
      );
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar vencimento: $e')),
      );
    }
  }

  Widget _summaryCard({
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(Map<String, dynamic> item) {
    late final Color color;
    late final String label;

    if (_isPaid(item)) {
      color = Colors.green;
      label = 'Pago';
    } else if (_isOverdue(item)) {
      color = Colors.red;
      label = 'Atrasado';
    } else {
      color = Colors.orange;
      label = 'Pendente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final key = _monthGroupKey(item);
      groupedItems.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }

    final pendingTotal = _items
        .where((item) => !_isPaid(item))
        .fold<double>(0.0, (sum, item) => sum + _toDouble(item['amount']));
    final paidTotal = _items
        .where(_isPaid)
        .fold<double>(
          0.0,
          (sum, item) => sum + _toDouble(item['paid_amount'] ?? item['amount']),
        );
    final overdueTotal = _items
        .where(_isOverdue)
        .fold<double>(0.0, (sum, item) => sum + _toDouble(item['amount']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas a Receber'),
        actions: [
          IconButton(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _summaryCard(
                        color: Colors.orange,
                        label: 'Em aberto',
                        value: _formatAmount(pendingTotal),
                      ),
                      const SizedBox(width: 12),
                      _summaryCard(
                        color: Colors.green,
                        label: 'Recebido',
                        value: _formatAmount(paidTotal),
                      ),
                      const SizedBox(width: 12),
                      _summaryCard(
                        color: Colors.red,
                        label: 'Atrasado',
                        value: _formatAmount(overdueTotal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text(
                        'Nenhum recebimento faturado ou parcelado encontrado.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...groupedItems.entries.expand((entry) {
                      final monthItems = entry.value;
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
                        ...monthItems.map((item) {
                          final receipt = _receiptOf(item);
                          final clientName =
                              (receipt['client_name'] ?? '-').toString();
                          final description =
                              (receipt['description'] ?? '-').toString();
                          final receiptNumber =
                              (receipt['receipt_number'] ?? '-').toString();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              receiptNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              clientName,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _statusChip(item),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(description),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _infoChip(
                                        Icons.receipt_long_outlined,
                                        'Parcela ${item['installment_number'] ?? '-'}',
                                      ),
                                      _infoChip(
                                        Icons.event_outlined,
                                        'Vence em ${_formatDate(item['due_date'])}',
                                      ),
                                      _infoChip(
                                        Icons.attach_money,
                                        _formatAmount(item['amount']),
                                      ),
                                      if (_isPaid(item))
                                        _infoChip(
                                          Icons.check_circle_outline,
                                          'Pago em ${_formatDate(item['paid_at'])}',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (!_isPaid(item))
                                        FilledButton.icon(
                                          onPressed: () => _markAsPaid(item),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Dar baixa'),
                                        ),
                                      if (!_isPaid(item)) const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _editDueDate(item),
                                        icon: const Icon(Icons.edit_calendar, size: 18),
                                        label: const Text('Editar vencimento'),
                                      ),
                                      if (_isPaid(item)) const SizedBox(width: 8),
                                      if (_isPaid(item))
                                        TextButton(
                                          onPressed: () => _reopenPayment(item),
                                          child: const Text('Reabrir'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ];
                    }),
                ],
              ),
            ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

