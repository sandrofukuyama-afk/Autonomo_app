import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _category = 'other';
  String _taxType = 'external';
  double _taxAmount = 0;
  String _paymentMethod = 'cash';
  String _taxInclusionType = 'external';

  Uint8List? _selectedReceiptBytes;
  String? _selectedReceiptName;
  String? _selectedReceiptMimeType;
  int? _selectedReceiptSize;

  AppLocalizations get t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _storeController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    final data = await SupabaseService.instance.getExpenses();

    if (!mounted) return;

    setState(() {
      _expenses = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    await _loadExpenses();
  }

  void _clearSelectedReceipt() {
    _selectedReceiptBytes = null;
    _selectedReceiptName = null;
    _selectedReceiptMimeType = null;
    _selectedReceiptSize = null;
  }

  Future<void> _pickReceipt(StateSetter setStateDialog) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('could_not_read_file'))),
      );
      return;
    }

    setStateDialog(() {
      _selectedReceiptBytes = file.bytes;
      _selectedReceiptName = file.name;
      _selectedReceiptMimeType = _mimeFromName(file.name);
      _selectedReceiptSize = file.size;
    });
  }

  Future<void> _capturePhoto(StateSetter setStateDialog) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('could_not_capture_photo'))),
      );
      return;
    }

    setStateDialog(() {
      _selectedReceiptBytes = file.bytes;
      _selectedReceiptName = file.name;
      _selectedReceiptMimeType = _mimeFromName(file.name);
      _selectedReceiptSize = file.size;
    });
  }

  String _mimeFromName(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  bool _isImageMime(String? mime) {
    return mime != null && mime.startsWith('image/');
  }

  bool _isImageUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp');
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '-';

    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return rawDate.toString();

    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  String _formatYen(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    final integerValue = number.toStringAsFixed(0);
    final chars = integerValue.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return '¥${buffer.toString().split('').reversed.join()}';
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'food':
        return t.translate('category_food');
      case 'transport':
        return t.translate('category_transport');
      case 'rent':
        return t.translate('category_rent');
      case 'services':
        return t.translate('category_services');
      case 'fees':
        return t.translate('category_fees');
      default:
        return t.translate('category_other');
    }
  }

  String _paymentMethodLabel(String value) {
    switch (value) {
      case 'cash':
        return t.translate('payment_cash');
      case 'credit_card':
        return t.translate('payment_credit_card');
      case 'furikomi':
        return t.translate('payment_furikomi');
      case 'paypay':
        return t.translate('payment_paypay');
      default:
        return t.translate('payment_other');
    }
  }

  String _taxInclusionTypeLabel(String value) {
    switch (value) {
      case 'inclusive':
        return t.translate('tax_inclusive');
      case 'external':
        return t.translate('tax_external');
      default:
        return t.translate('tax_not_defined');
    }
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '0').toString().replaceAll(',', '.')) ?? 0;
  }

  String _formatTaxRate(dynamic value) {
    final rate = _parseDouble(value);
    if (rate <= 0) return '-';
    if (rate == rate.roundToDouble()) {
      return '${rate.toStringAsFixed(0)}%';
    }
    return '${rate.toStringAsFixed(1)}%';
  }

  String _normalizeOcrCategorySuggestion(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();

    switch (raw) {
      case 'food':
      case 'transport':
      case 'rent':
      case 'services':
      case 'fees':
      case 'other':
        return raw;
      case 'office_supplies':
        return 'other';
      case 'communication':
      case 'utilities':
      case 'insurance':
      case 'software':
      case 'equipment':
      case 'professional_fees':
      case 'advertising':
      case 'taxes':
        return 'services';
      default:
        return 'other';
    }
  }

  DateTime? _parseOcrDate(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;

    final normalized = raw.replaceAll('/', '-').replaceAll('.', '-');
    return DateTime.tryParse(normalized);
  }

  String _calculateOcrTaxRate({
    required dynamic amountValue,
    required dynamic taxAmountValue,
  }) {
    final amount = _parseDouble(amountValue);
    final taxAmount = _parseDouble(taxAmountValue);

    if (amount <= 0 || taxAmount <= 0 || taxAmount >= amount) {
      return '';
    }

    final taxableBase = amount - taxAmount;
    if (taxableBase <= 0) return '';

    final rate = (taxAmount / taxableBase) * 100;
    if (rate <= 0) return '';

    if ((rate - rate.roundToDouble()).abs() < 0.15) {
      return rate.round().toString();
    }

    return rate.toStringAsFixed(1);
  }

  Future<void> _applyOCRSuggestions({
    required String expenseId,
    required StateSetter setStateDialog,
  }) async {
    try {
      final row = await Supabase.instance.client
          .from('expense_receipts')
          .select(
            'ocr_status, ocr_store_name, ocr_amount, ocr_date, ocr_tax_amount, ocr_category_suggestion',
          )
          .eq('expense_id', expenseId)
          .order('uploaded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return;
      final status = (row['ocr_status'] ?? '').toString().toLowerCase();
      if (status != 'processed') return;

      final storeName = (row['ocr_store_name'] ?? '').toString().trim();
      final ocrAmount = _parseDouble(row['ocr_amount']);
      final ocrDate = _parseOcrDate(row['ocr_date']);
      final ocrTaxRate = _calculateOcrTaxRate(
        amountValue: row['ocr_amount'],
        taxAmountValue: row['ocr_tax_amount'],
      );
      final ocrCategory = _normalizeOcrCategorySuggestion(
        row['ocr_category_suggestion'],
      );

      if (!mounted) return;

      setStateDialog(() {
        if (_vendorController.text.trim().isEmpty && storeName.isNotEmpty) {
          _vendorController.text = storeName;
        }
        if (_storeController.text.trim().isEmpty && storeName.isNotEmpty) {
          _storeController.text = storeName;
        }
        if (_amountController.text.trim().isEmpty && ocrAmount > 0) {
          _amountController.text = ocrAmount == ocrAmount.roundToDouble()
              ? ocrAmount.toStringAsFixed(0)
              : ocrAmount.toStringAsFixed(2);
        }
        if (ocrDate != null && _formatDate(_selectedDate.toIso8601String()) == _formatDate(DateTime.now().toIso8601String())) {
          _selectedDate = ocrDate;
        }
        if (_taxRateController.text.trim().isEmpty && ocrTaxRate.isNotEmpty) {
          _taxRateController.text = ocrTaxRate;
        }
        if (_category == 'other' && ocrCategory != 'other') {
          _category = ocrCategory;
        }
      });
    } catch (_) {
      // Mantém o fluxo atual caso OCR ainda não esteja disponível.
    }
  }

  Future<void> _selectDate(StateSetter setStateDialog) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setStateDialog(() {
        _selectedDate = picked;
      });
    }
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  Future<Map<String, dynamic>> _uploadSelectedReceiptIfNeeded() async {
    if (_selectedReceiptBytes == null || _selectedReceiptName == null) {
      return {};
    }

    final publicUrl = await SupabaseService.instance.uploadReceipt(
      _selectedReceiptBytes!,
      _selectedReceiptName!,
      contentType: _selectedReceiptMimeType,
    );

    return {
      'receipt_url': publicUrl,
      'storage_path': publicUrl,
      'file_name': _selectedReceiptName,
      'original_file_name': _selectedReceiptName,
      'mime_type': _selectedReceiptMimeType,
      'file_size_bytes': _selectedReceiptSize,
      'document_type': 'receipt',
      'ocr_status': 'pending',
      'receipt_review_status': 'pending',
    };
  }

  Future<void> _showReceiptPreview(String url) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 900,
            maxHeight: 700,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.translate('receipt_viewer_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isImageUrl(url)
                      ? InteractiveViewer(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              return SelectableText(url);
                            },
                          ),
                        )
                      : Center(
                          child: SelectableText(url),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _quickTaxRateButtons(StateSetter setStateDialog) {
    const rates = ['0', '8', '10'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rates.map((rate) {
        return OutlinedButton(
          onPressed: () {
            setStateDialog(() {
              _taxRateController.text = rate;
            });
          },
          child: Text('$rate%'),
        );
      }).toList(),
    );
  }

  Widget _receiptSection({
    required StateSetter setStateDialog,
    String? existingReceiptUrl,
  }) {
    final hasSelectedReceipt =
        _selectedReceiptBytes != null && _selectedReceiptName != null;
    final hasExistingReceipt =
        existingReceiptUrl != null && existingReceiptUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.translate('receipt_attachment'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (hasSelectedReceipt) ...[
            Row(
              children: [
                const Icon(Icons.attach_file, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedReceiptName!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setStateDialog(() {
                      _clearSelectedReceipt();
                    });
                  },
                  child: Text(t.translate('remove')),
                ),
              ],
            ),
            if (_isImageMime(_selectedReceiptMimeType)) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _selectedReceiptBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ] else if (hasExistingReceipt) ...[
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.translate('existing_receipt_attached'),
                  ),
                ),
                TextButton(
                  onPressed: () => _showReceiptPreview(existingReceiptUrl),
                  child: Text(t.translate('view')),
                ),
              ],
            ),
          ] else ...[
            Text(
              t.translate('no_receipt_selected'),
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          if (hasSelectedReceipt || hasExistingReceipt) const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _openAddDialog() async {
    _descController.clear();
    _amountController.clear();
    _storeController.clear();
    _vendorController.clear();
    _notesController.clear();
    _taxRateController.clear();
    _selectedDate = DateTime.now();
    _category = 'other';
    _taxType = 'external';
    _taxAmount = 0;
    _paymentMethod = 'cash';
    _taxInclusionType = 'external';
    _clearSelectedReceipt();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final dialogT = AppLocalizations.of(context);
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogT.translate('new_expense'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _capturePhoto(setStateDialog),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(dialogT.translate('take_photo')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickReceipt(setStateDialog),
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _selectedReceiptBytes != null
                                    ? dialogT.translate('change_file')
                                    : dialogT.translate('choose_file'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration(dialogT.translate('description')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _storeController,
                          decoration: _fieldDecoration(dialogT.translate('store')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration('${dialogT.translate('value')} (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _fieldDecoration(dialogT.translate('category')),
                          items: [
                            DropdownMenuItem(
                              value: 'food',
                              child: Text(dialogT.translate('category_food')),
                            ),
                            DropdownMenuItem(
                              value: 'transport',
                              child: Text(dialogT.translate('category_transport')),
                            ),
                            DropdownMenuItem(
                              value: 'rent',
                              child: Text(dialogT.translate('category_rent')),
                            ),
                            DropdownMenuItem(
                              value: 'services',
                              child: Text(dialogT.translate('category_services')),
                            ),
                            DropdownMenuItem(
                              value: 'fees',
                              child: Text(dialogT.translate('category_fees')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(dialogT.translate('category_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _category = value ?? 'other';
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          dialogT.translate('fiscal_basic_data'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vendorController,
                          decoration: _fieldDecoration(dialogT.translate('vendor')),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration(dialogT.translate('payment_method')),
                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(dialogT.translate('payment_cash')),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card',
                              child: Text(dialogT.translate('payment_credit_card')),
                            ),
                            DropdownMenuItem(
                              value: 'furikomi',
                              child: Text(dialogT.translate('payment_furikomi')),
                            ),
                            DropdownMenuItem(
                              value: 'paypay',
                              child: Text(dialogT.translate('payment_paypay')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(dialogT.translate('payment_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _fieldDecoration(dialogT.translate('notes')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(dialogT.translate('tax_rate')),
                        ),
                        const SizedBox(height: 10),
                        _quickTaxRateButtons(setStateDialog),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _taxInclusionType,
                          decoration: _fieldDecoration(dialogT.translate('tax_type')),
                          items: [
                            DropdownMenuItem(
                              value: 'external',
                              child: Text(dialogT.translate('tax_external')),
                            ),
                            DropdownMenuItem(
                              value: 'inclusive',
                              child: Text(dialogT.translate('tax_inclusive')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _taxInclusionType = value ?? 'external';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${dialogT.translate('date')}: ${_formatDate(_selectedDate.toIso8601String())}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectDate(setStateDialog),
                                child: Text(dialogT.translate('change')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _receiptSection(setStateDialog: setStateDialog),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: Text(dialogT.translate('cancel')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final description = _descController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text.trim().replaceAll(',', '.'),
                                );

                                if (description.isEmpty || amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(dialogT.translate('invalid_data')),
                                    ),
                                  );
                                  return;
                                }

                                final receiptPayload = await _uploadSelectedReceiptIfNeeded();

                                await SupabaseService.instance.addExpense({
                                  'date': _selectedDate.toIso8601String(),
                                  'store_name': _storeController.text.trim(),
                                  'description': description,
                                  'category': _category,
                                  'amount': amount,
                                  'tax': _taxAmount,
                                  'tax_type': _taxType,
                                  'vendor_name': _vendorController.text.trim(),
                                  'payment_method': _paymentMethod,
                                  'notes': _notesController.text.trim(),
                                  'tax_rate': _parseDouble(_taxRateController.text),
                                  'tax_inclusion_type': _taxInclusionType,
                                  ...receiptPayload,
                                });

                                if (!mounted) return;
                                Navigator.pop(dialogContext, true);
                              },
                              child: Text(dialogT.translate('save')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _clearSelectedReceipt();

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('expense_added'))),
      );
      await _refresh();
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    _descController.text = (expense['description'] ?? '').toString();
    _amountController.text = (expense['amount'] ?? '').toString();
    _storeController.text = (expense['store_name'] ?? '').toString();
    _vendorController.text = (expense['vendor_name'] ?? '').toString();
    _notesController.text = (expense['notes'] ?? '').toString();

    final currentTaxRate = _parseDouble(expense['tax_rate']);
    _taxRateController.text = currentTaxRate <= 0
        ? ''
        : (currentTaxRate == currentTaxRate.roundToDouble()
            ? currentTaxRate.toStringAsFixed(0)
            : currentTaxRate.toStringAsFixed(1));

    _selectedDate =
        DateTime.tryParse((expense['date'] ?? '').toString()) ?? DateTime.now();
    _category = (expense['category'] ?? 'other').toString();
    _taxType = (expense['tax_type'] ?? 'external').toString();
    _taxAmount = expense['tax_amount'] is num
        ? (expense['tax_amount'] as num).toDouble()
        : double.tryParse((expense['tax_amount'] ?? '0').toString()) ?? 0;
    _paymentMethod = (expense['payment_method'] ?? 'cash').toString();
    _taxInclusionType =
        (expense['tax_inclusion_type'] ?? 'external').toString();
    _clearSelectedReceipt();

    final existingReceiptUrl = (expense['receipt_url'] ?? '').toString();
    var ocrSuggestionsRequested = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final dialogT = AppLocalizations.of(context);
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogT.translate('edit_expense'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _capturePhoto(setStateDialog),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(dialogT.translate('take_photo')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickReceipt(setStateDialog),
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _selectedReceiptBytes != null
                                    ? dialogT.translate('change_file')
                                    : dialogT.translate('choose_file'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration(dialogT.translate('description')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _storeController,
                          decoration: _fieldDecoration(dialogT.translate('store')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration('${dialogT.translate('value')} (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _fieldDecoration(dialogT.translate('category')),
                          items: [
                            DropdownMenuItem(
                              value: 'food',
                              child: Text(dialogT.translate('category_food')),
                            ),
                            DropdownMenuItem(
                              value: 'transport',
                              child: Text(dialogT.translate('category_transport')),
                            ),
                            DropdownMenuItem(
                              value: 'rent',
                              child: Text(dialogT.translate('category_rent')),
                            ),
                            DropdownMenuItem(
                              value: 'services',
                              child: Text(dialogT.translate('category_services')),
                            ),
                            DropdownMenuItem(
                              value: 'fees',
                              child: Text(dialogT.translate('category_fees')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(dialogT.translate('category_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _category = value ?? 'other';
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          dialogT.translate('fiscal_basic_data'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vendorController,
                          decoration: _fieldDecoration(dialogT.translate('vendor')),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration(dialogT.translate('payment_method')),
                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(dialogT.translate('payment_cash')),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card',
                              child: Text(dialogT.translate('payment_credit_card')),
                            ),
                            DropdownMenuItem(
                              value: 'furikomi',
                              child: Text(dialogT.translate('payment_furikomi')),
                            ),
                            DropdownMenuItem(
                              value: 'paypay',
                              child: Text(dialogT.translate('payment_paypay')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(dialogT.translate('payment_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _fieldDecoration(dialogT.translate('notes')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(dialogT.translate('tax_rate')),
                        ),
                        const SizedBox(height: 10),
                        _quickTaxRateButtons(setStateDialog),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _taxInclusionType,
                          decoration: _fieldDecoration(dialogT.translate('tax_type')),
                          items: [
                            DropdownMenuItem(
                              value: 'external',
                              child: Text(dialogT.translate('tax_external')),
                            ),
                            DropdownMenuItem(
                              value: 'inclusive',
                              child: Text(dialogT.translate('tax_inclusive')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _taxInclusionType = value ?? 'external';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${dialogT.translate('date')}: ${_formatDate(_selectedDate.toIso8601String())}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectDate(setStateDialog),
                                child: Text(dialogT.translate('change')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _receiptSection(
                          setStateDialog: setStateDialog,
                          existingReceiptUrl: existingReceiptUrl,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: Text(dialogT.translate('cancel')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final description = _descController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text.trim().replaceAll(',', '.'),
                                );

                                if (description.isEmpty || amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text(dialogT.translate('invalid_data')),
                                    ),
                                  );
                                  return;
                                }

                                await SupabaseService.instance.updateExpense(
                                  expense['id'].toString(),
                                  {
                                    'date': _selectedDate.toIso8601String(),
                                    'store_name': _storeController.text.trim(),
                                    'description': description,
                                    'category': _category,
                                    'amount': amount,
                                    'tax': _taxAmount,
                                    'tax_type': _taxType,
                                    'vendor_name': _vendorController.text.trim(),
                                    'payment_method': _paymentMethod,
                                    'notes': _notesController.text.trim(),
                                    'tax_rate': _parseDouble(_taxRateController.text),
                                    'tax_inclusion_type': _taxInclusionType,
                                  },
                                );

                                final receiptPayload = await _uploadSelectedReceiptIfNeeded();

                                if (receiptPayload.isNotEmpty) {
                                  await SupabaseService.instance.attachReceiptToExpense(
                                    expense['id'].toString(),
                                    {
                                      'date': _selectedDate.toIso8601String(),
                                      'store_name': _storeController.text.trim(),
                                      'description': description,
                                      'category': _category,
                                      'amount': amount,
                                      'tax': _taxAmount,
                                      'tax_type': _taxType,
                                      'vendor_name': _vendorController.text.trim(),
                                      'payment_method': _paymentMethod,
                                      'notes': _notesController.text.trim(),
                                      'tax_rate': _parseDouble(_taxRateController.text),
                                      'tax_inclusion_type': _taxInclusionType,
                                      ...receiptPayload,
                                    },
                                  );
                                }

                                if (!mounted) return;
                                Navigator.pop(dialogContext, true);
                              },
                              child: Text(dialogT.translate('save')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _clearSelectedReceipt();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('expense_updated'))),
      );
      await _refresh();
    }
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.translate('delete_expense_title')),
        content: Text(t.translate('delete_expense_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SupabaseService.instance.deleteExpense(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.translate('expense_deleted'))),
    );

    await _refresh();
  }

  Widget _expenseCard(Map<String, dynamic> expense) {
    final description = (expense['description'] ?? '').toString();
    final category = _categoryLabel((expense['category'] ?? 'other').toString());
    final date = _formatDate(expense['date']);
    final amount = _formatYen(expense['amount']);
    final receipt = (expense['receipt_url'] ?? '').toString();
    final vendor = (expense['vendor_name'] ?? '').toString().trim();
    final paymentMethod =
        _paymentMethodLabel((expense['payment_method'] ?? 'other').toString());
    final taxRate = _formatTaxRate(expense['tax_rate']);
    final taxInclusion = _taxInclusionTypeLabel(
      (expense['tax_inclusion_type'] ?? 'external').toString(),
    );
    final notes = (expense['notes'] ?? '').toString().trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description.isEmpty ? t.translate('no_description') : description,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$date • $category',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (vendor.isNotEmpty) _chip('${t.translate('vendor')}: $vendor'),
                _chip('${t.translate('payment')}: $paymentMethod'),
                _chip('${t.translate('tax')}: $taxRate'),
                _chip(taxInclusion),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${t.translate('obs_short')}: $notes',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (receipt.isNotEmpty)
                  IconButton(
                    tooltip: t.translate('view'),
                    icon: const Icon(
                      Icons.receipt_long,
                      color: Colors.green,
                    ),
                    onPressed: () => _showReceiptPreview(receipt),
                  ),
                IconButton(
                  tooltip: t.translate('edit'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editExpense(expense),
                ),
                IconButton(
                  tooltip: t.translate('delete'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteExpense(expense['id'].toString()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              t.translate('no_expenses_registered'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.translate('expenses_will_appear_here'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('expenses')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: t.translate('new_expense_tooltip'),
            onPressed: _openAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final expense = Map<String, dynamic>.from(_expenses[index]);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _expenseCard(expense),
                      );
                    },
                  ),
                ),
    );
  }
}
