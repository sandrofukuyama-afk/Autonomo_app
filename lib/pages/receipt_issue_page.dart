import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../services/receipt_pdf_service.dart';
import 'client_form_page.dart';

class _FormatOption {
  final String value;
  final String labelKey;
  final IconData icon;

  const _FormatOption(this.value, this.labelKey, this.icon);
}

const _formats = [
  _FormatOption('thermal_58', 'format_thermal_58', Icons.receipt_long),
  _FormatOption('thermal_80', 'format_thermal_80', Icons.receipt_long),
  _FormatOption('a5', 'format_a5', Icons.picture_as_pdf),
  _FormatOption('a4', 'format_a4', Icons.picture_as_pdf),
  _FormatOption('email', 'format_email', Icons.email_outlined),
];

class ReceiptIssuePage extends StatefulWidget {
  final Map<String, dynamic>? entryData;

  const ReceiptIssuePage({super.key, this.entryData});

  @override
  State<ReceiptIssuePage> createState() => _ReceiptIssuePageState();
}

class _ReceiptIssuePageState extends State<ReceiptIssuePage> {
  final _formKey = GlobalKey<FormState>();

  final _receiptNumberCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _taxAmountCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _downPaymentCtrl = TextEditingController();
  final _installmentsCountCtrl = TextEditingController();
  final _installmentValueCtrl = TextEditingController();

  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  String _selectedFormat = 'a4';
  String _paymentMethod = 'cash';
  String _paymentCondition = 'a_vista';
  String _documentKind = 'ryoushuusho';
  String _selectedItemType = 'product';
  String? _selectedServiceId;
  bool _createEntryOnSave = true;
  bool _loading = true;
  bool _saving = false;
  bool _sendingEmail = false;

  Map<String, String?> _companyProfile = {};
  String _language = 'pt';
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _clientSuggestions = [];
  bool _showNoClientWarning = false;

  Uint8List? _cachedPdfBytes;
  String? _cachedFormat;

  static const _paymentMethods = [
    'cash',
    'credit_card',
    'bank_transfer',
    'paypay',
    'other',
  ];

  List<_FormatOption> _availableFormatsForKind(String kind) {
    if (kind == 'reshiito') {
      return _formats
          .where((f) => f.value != 'a5' && f.value != 'a4')
          .toList();
    }
    return _formats;
  }

  @override
  void initState() {
    super.initState();
    _createEntryOnSave = widget.entryData == null;
    _loadInitialData();
  }

  @override
  void dispose() {
    _receiptNumberCtrl.dispose();
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _taxAmountCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientEmailCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _clientAddressCtrl.dispose();
    _notesCtrl.dispose();
    _downPaymentCtrl.dispose();
    _installmentsCountCtrl.dispose();
    _installmentValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final entry = widget.entryData;
      if (entry?['entry_date'] != null) {
        final parsed = DateTime.tryParse(entry!['entry_date'].toString());
        if (parsed != null) {
          _issueDate = parsed;
        }
      } else if (entry?['issue_date'] != null) {
        final parsed = DateTime.tryParse(entry!['issue_date'].toString());
        if (parsed != null) {
          _issueDate = parsed;
        }
      }

      final results = await Future.wait([
        SupabaseService.instance.getCompanyProfile(),
        SupabaseService.instance.getServiceCatalog(),
        SupabaseService.instance.getNextReceiptNumber(_issueDate),
        SupabaseService.instance.getClients(),
      ]);

      _companyProfile = Map<String, String?>.from(results[0] as Map);
      _services = List<Map<String, dynamic>>.from(results[1] as List);
      _language = _companyProfile['language'] ?? 'pt';
      _receiptNumberCtrl.text = results[2] as String;
      _clients = List<Map<String, dynamic>>.from(results[3] as List);

      if (entry != null) {
        if (entry['receipt_number'] != null &&
            entry['receipt_number'].toString().trim().isNotEmpty) {
          _receiptNumberCtrl.text = entry['receipt_number'].toString();
        }
        _descriptionCtrl.text = (entry['description'] ?? '').toString();
        final amount = double.tryParse((entry['amount'] ?? 0).toString()) ?? 0;
        final taxAmount = double.tryParse((entry['tax_amount'] ?? 0).toString()) ?? 0;
        _amountCtrl.text = amount == 0 ? '' : amount.toStringAsFixed(0);
        _taxAmountCtrl.text = taxAmount == 0 ? '' : taxAmount.toStringAsFixed(0);
        _paymentMethod = _normalizePayment(entry['payment_method']);
        _selectedItemType = _inferItemType(entry);
        _documentKind = (entry['document_kind'] ?? _documentKind).toString();
        _selectedServiceId = entry['service_id']?.toString();
        _clientNameCtrl.text =
            (entry['client_name'] ?? entry['customer_name'] ?? '').toString();
        _clientEmailCtrl.text = (entry['client_email'] ?? '').toString();
        _clientPhoneCtrl.text = (entry['client_phone'] ?? '').toString();
        _clientAddressCtrl.text = (entry['client_address'] ?? '').toString();
        _paymentCondition = (entry['payment_condition'] ?? _paymentCondition).toString();
        final downPayment = double.tryParse(
          (entry['down_payment_amount'] ?? 0).toString(),
        );
        if (downPayment != null && downPayment > 0) {
          _downPaymentCtrl.text = downPayment.toStringAsFixed(0);
        }
        final installmentsCount = int.tryParse(
          (entry['installments_count'] ?? 0).toString(),
        );
        if (installmentsCount != null && installmentsCount > 0) {
          _installmentsCountCtrl.text = installmentsCount.toString();
        }
        final installmentValue = double.tryParse(
          (entry['installment_value'] ?? 0).toString(),
        );
        if (installmentValue != null && installmentValue > 0) {
          _installmentValueCtrl.text = installmentValue.toStringAsFixed(0);
        }
        if (entry['due_date'] != null) {
          final parsedDue = DateTime.tryParse(entry['due_date'].toString());
          if (parsedDue != null) _dueDate = parsedDue;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _inferItemType(Map<String, dynamic> entry) {
    final itemType = (entry['item_type'] ?? '').toString().toLowerCase();
    if (itemType == 'service' || itemType == 'product') {
      return itemType;
    }
    final category = (entry['category'] ?? '').toString().toLowerCase();
    if (category.contains('service') || category.contains('serv')) {
      return 'service';
    }
    return 'product';
  }

  Future<void> _refreshReceiptNumber() async {
    final nextNumber = await SupabaseService.instance.getNextReceiptNumber(_issueDate);
    if (!mounted) return;
    setState(() {
      _receiptNumberCtrl.text = nextNumber;
      _invalidatePdfCache();
    });
  }

  String _normalizePayment(dynamic value) {
    final v = (value ?? '').toString().toLowerCase();
    if (_paymentMethods.contains(v)) return v;
    return 'cash';
  }

  Map<String, dynamic>? get _selectedService {
    if (_selectedServiceId == null) return null;
    for (final service in _services) {
      if (service['id'].toString() == _selectedServiceId) {
        return service;
      }
    }
    return null;
  }

  void _applySelectedService(String? serviceId) {
    setState(() {
      _selectedServiceId = serviceId;
      final service = _selectedService;
      if (service != null) {
        final description = (service['description'] ?? '').toString().trim();
        _descriptionCtrl.text = description.isEmpty
            ? (service['name'] ?? '').toString()
            : description;
        final amount = service['default_amount'];
        if (amount != null) {
          final parsedAmount = double.tryParse(amount.toString());
          if (parsedAmount != null && parsedAmount > 0) {
            _amountCtrl.text = parsedAmount.toStringAsFixed(0);
          }
        }
      }
      _calculateInstallmentValue();
      _invalidatePdfCache();
    });
  }

  void _calculateInstallmentValue() {
    if (_paymentCondition != 'parcelado') return;
    
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final taxAmount = double.tryParse(_taxAmountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final total = amount + taxAmount;
    
    final downPayment = double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0.0;
    final installmentsCountStr = _installmentsCountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final installmentsCount = int.tryParse(installmentsCountStr) ?? 0;
    
    if (installmentsCount > 0) {
      final value = (total - downPayment) / installmentsCount;
      if (value > 0) {
        // avoid changing if user is typing a decimal manually, but for JPY it's usually 0 decimals
        _installmentValueCtrl.text = value.toStringAsFixed(0);
      } else {
        _installmentValueCtrl.text = '';
      }
    } else {
      _installmentValueCtrl.text = '';
    }
  }

  void _onClientNameChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _clientSuggestions = [];
        _showNoClientWarning = false;
      });
      _invalidatePdfCache();
      return;
    }

    final matches = _clients.where((c) {
      final name = (c['name'] ?? '').toString().trim().toLowerCase();
      return name.startsWith(query);
    }).toList();

    setState(() {
      _clientSuggestions = matches.take(5).toList();
      _showNoClientWarning = matches.isEmpty;
      if (matches.length == 1) {
        _fillClientFieldsFromRecord(matches.first);
      }
    });
    _invalidatePdfCache();
  }

  void _selectClientSuggestion(Map<String, dynamic> client) {
    setState(() {
      _clientNameCtrl.text = (client['name'] ?? '').toString();
      _fillClientFieldsFromRecord(client);
      _clientSuggestions = [];
      _showNoClientWarning = false;
    });
    _invalidatePdfCache();
  }

  void _fillClientFieldsFromRecord(Map<String, dynamic> client) {
    _clientEmailCtrl.text = (client['email'] ?? '').toString();
    _clientPhoneCtrl.text = (client['phone'] ?? '').toString();

    final addressParts = [
      (client['province'] ?? '').toString().trim(),
      (client['city'] ?? '').toString().trim(),
      (client['neighborhood'] ?? '').toString().trim(),
      (client['street_number'] ?? '').toString().trim(),
      (client['apartment'] ?? '').toString().trim(),
    ].where((part) => part.isNotEmpty).toList();
    _clientAddressCtrl.text = addressParts.join(', ');
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _addMonths(DateTime value, int months) {
    final year = value.year + ((value.month - 1 + months) ~/ 12);
    final month = ((value.month - 1 + months) % 12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = value.day > maxDay ? maxDay : value.day;
    return DateTime(year, month, day);
  }

  double _receiptTotal() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0;
    final taxAmount =
        double.tryParse(_taxAmountCtrl.text.replaceAll(',', '')) ?? 0.0;
    return amount + taxAmount;
  }

  List<Map<String, dynamic>> _buildReceivableSchedules() {
    final total = _receiptTotal();
    if (_paymentCondition == 'a_vista' || total <= 0) {
      return const [];
    }

    final dueDate = _dueDate ?? _normalizeDate(DateTime.now());

    if (_paymentCondition == 'faturado') {
      return [
        {
          'installment_number': 1,
          'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
          'amount': total,
          'status': 'pending',
          'payment_method': _paymentMethod,
          'notes': 'Recebimento faturado',
        },
      ];
    }

    final downPayment =
        double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0.0;
    final installmentsCount = int.tryParse(
          _installmentsCountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    final installmentValue =
        double.tryParse(_installmentValueCtrl.text.replaceAll(',', '')) ?? 0.0;

    if (installmentsCount <= 0 || installmentValue <= 0) {
      return const [];
    }

    final financedAmount = (total - downPayment).clamp(0.0, double.infinity);
    final schedules = <Map<String, dynamic>>[];

    for (var index = 0; index < installmentsCount; index++) {
      final isLast = index == installmentsCount - 1;
      final accumulated = installmentValue * index;
      final amount = isLast
          ? (financedAmount - accumulated).clamp(0.0, double.infinity)
          : installmentValue;

      schedules.add({
        'installment_number': index + 1,
        'due_date': DateFormat(
          'yyyy-MM-dd',
        ).format(_addMonths(dueDate, index)),
        'amount': amount,
        'status': 'pending',
        'payment_method': _paymentMethod,
        'notes': 'Parcela ${index + 1} de $installmentsCount',
      });
    }

    return schedules;
  }

  String? _validateReceivableSetup() {
    if (_paymentCondition == 'a_vista') return null;
    if (_dueDate == null) {
      return 'Informe a data de vencimento.';
    }

    if (_paymentCondition == 'parcelado') {
      final installmentsCount = int.tryParse(
            _installmentsCountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      final installmentValue =
          double.tryParse(_installmentValueCtrl.text.replaceAll(',', '')) ?? 0.0;
      final downPayment =
          double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0.0;

      if (installmentsCount <= 0) {
        return 'Informe a quantidade de parcelas.';
      }
      if (installmentValue <= 0) {
        return 'Informe o valor da parcela.';
      }
      if (downPayment > _receiptTotal()) {
        return 'A entrada não pode ser maior que o total.';
      }
    }

    return null;
  }

  String? _buildCombinedNotes() {
    final baseNotes = _notesCtrl.text.trim();
    final parts = <String>[];
    
    if (_paymentCondition == 'faturado') {
      parts.add('Condição: Faturado');
      if (_dueDate != null) {
        parts.add('Vencimento: ${DateFormat('dd/MM/yyyy').format(_dueDate!)}');
      }
    } else if (_paymentCondition == 'parcelado') {
      parts.add('Condição: Parcelado');
      if (_downPaymentCtrl.text.trim().isNotEmpty) {
        parts.add('Entrada: ¥${_downPaymentCtrl.text.trim()}');
      }
      if (_installmentsCountCtrl.text.trim().isNotEmpty) {
        parts.add('Parcelas: ${_installmentsCountCtrl.text.trim()}x');
      }
      if (_installmentValueCtrl.text.trim().isNotEmpty) {
        parts.add('Valor da Parcela: ¥${_installmentValueCtrl.text.trim()}');
      }
      if (_dueDate != null) {
        parts.add('Primeiro Vencimento: ${DateFormat('dd/MM/yyyy').format(_dueDate!)}');
      }
    }
    
    if (baseNotes.isNotEmpty) {
      parts.add(baseNotes);
    }
    
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  ReceiptData _buildReceiptData() {
    return ReceiptData(
      receiptNumber: _receiptNumberCtrl.text.trim(),
      issueDate: _issueDate,
      dueDate: _dueDate,
      documentKind: _documentKind,
      description: _descriptionCtrl.text.trim(),
      amount: double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
      taxAmount: double.tryParse(_taxAmountCtrl.text.replaceAll(',', '')) ?? 0,
      currency: 'JPY',
      paymentMethod: _paymentMethod,
      issuedBy: _companyProfile['name'] ?? '',
      companyAddress: _companyProfile['address'],
      companyPhone: _companyProfile['phone'],
      invoiceNumber: _companyProfile['invoice_number'],
      clientName: _clientNameCtrl.text.trim().isEmpty
          ? null
          : _clientNameCtrl.text.trim(),
      clientEmail: _clientEmailCtrl.text.trim().isEmpty
          ? null
          : _clientEmailCtrl.text.trim(),
      notes: _buildCombinedNotes(),
      language: _language,
      paymentCondition: _paymentCondition,
      downPayment: double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')),
      installmentsCount: int.tryParse(_installmentsCountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')),
      installmentValue: double.tryParse(_installmentValueCtrl.text.replaceAll(',', '')),
    );
  }

  double _entryAmountForLaunch(ReceiptData data) {
    if (_paymentCondition == 'parcelado') {
      return double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0.0;
    }
    return data.amount;
  }

  Future<Uint8List> _generatePdf() async {
    final data = _buildReceiptData();

    if (_cachedFormat == _selectedFormat && _cachedPdfBytes != null) {
      return _cachedPdfBytes!;
    }

    Uint8List bytes;
    switch (_selectedFormat) {
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

    _cachedPdfBytes = bytes;
    _cachedFormat = _selectedFormat;
    return bytes;
  }

  void _invalidatePdfCache() {
    _cachedPdfBytes = null;
    _cachedFormat = null;
  }

  Future<void> _previewPdf() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final bytes = await _generatePdf();
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) => Future.value(bytes));
    } catch (_) {
      if (mounted) {
        _showError(AppLocalizations.of(context).translate('error_generating_pdf'));
      }
    }
  }

  Future<void> _printPdf() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(onLayout: (_) => Future.value(bytes));
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _sharePdf() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_selectedFormat == 'email') {
        final data = _buildReceiptData();
        final html = ReceiptPdfService.buildEmailHtml(data);
        await Share.share(html, subject: 'Recibo ${_receiptNumberCtrl.text}');
        return;
      }

      final bytes = await _generatePdf();
      final fileName = 'recibo_${_receiptNumberCtrl.text}.pdf';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
        subject: 'Recibo ${_receiptNumberCtrl.text}',
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _sendEmail() async {
    final t = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) return;

    final email = _clientEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showError(t.translate('client_email_required'));
      return;
    }

    final smtpRaw = await SupabaseService.instance.getSmtpSettings();
    if (smtpRaw == null) {
      _showError(t.translate('email_not_configured'));
      return;
    }

    setState(() => _sendingEmail = true);
    try {
      final bytes = await _generatePdf();
      final smtpConfig = SmtpConfig(
        host: smtpRaw['host'] ?? '',
        port: (smtpRaw['port'] as int?) ?? 587,
        username: smtpRaw['username'] ?? '',
        password: smtpRaw['password'] ?? '',
        senderName: smtpRaw['sender_name'] ?? _companyProfile['name'] ?? '',
        useSSL: smtpRaw['use_ssl'] as bool? ?? false,
      );

      await ReceiptPdfService.sendByEmail(
        data: _buildReceiptData(),
        smtpConfig: smtpConfig,
        pdfBytes: bytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate('email_sent')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  Future<void> _saveReceipt() async {
    if (!_formKey.currentState!.validate()) return;
    final receivableError = _validateReceivableSetup();
    if (receivableError != null) {
      _showError(receivableError);
      return;
    }

    setState(() => _saving = true);
    try {
      final data = _buildReceiptData();
      final schedules = _buildReceivableSchedules();
      final shouldCreateEntry =
          _documentKind == 'ryoushuusho' &&
          _createEntryOnSave &&
          widget.entryData == null;
      final entryAmount = _entryAmountForLaunch(data);

      if (shouldCreateEntry && entryAmount > 0) {
        await SupabaseService.instance.addEntry({
          'date': DateFormat('yyyy-MM-dd').format(data.issueDate),
          'description': data.description,
          'category': _selectedItemType == 'service' ? 'service' : 'sale',
          'amount': entryAmount,
          'payment_method': data.paymentMethod,
          'tax_rate': null,
          'tax_inclusion_type': 'unknown',
          'tax_amount': data.taxAmount,
          'qualified_invoice_issued': false,
          'qualified_invoice_number': data.receiptNumber,
          'customer_name': data.clientName,
          'revenue_type': _selectedItemType == 'service' ? 'service' : 'product',
          'fiscal_revenue_category': null,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final payload = {
        'entry_id': widget.entryData?['entry_id'] ?? widget.entryData?['id'],
        'receipt_number': data.receiptNumber,
        'issue_date': DateFormat('yyyy-MM-dd').format(data.issueDate),
        'due_date':
            _dueDate == null ? null : DateFormat('yyyy-MM-dd').format(_dueDate!),
        'document_kind': _documentKind,
        'item_type': _selectedItemType,
        'service_id': _selectedItemType == 'service' ? _selectedServiceId : null,
        'client_name': data.clientName,
        'client_email': data.clientEmail,
        'description': data.description,
        'amount': data.amount,
        'tax_amount': data.taxAmount,
        'payment_method': data.paymentMethod,
        'payment_condition': _paymentCondition,
        'down_payment_amount':
            double.tryParse(_downPaymentCtrl.text.replaceAll(',', '')) ?? 0,
        'installments_count': int.tryParse(
              _installmentsCountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            1,
        'installment_value':
            double.tryParse(_installmentValueCtrl.text.replaceAll(',', '')),
        'receivable_schedules': schedules,
        'notes': _buildCombinedNotes(),
        'format': _selectedFormat,
        'language': _language,
        'issued_by': data.issuedBy,
        'company_address': data.companyAddress,
        'company_phone': data.companyPhone,
        'invoice_number': data.invoiceNumber,
      };
      final receiptId = widget.entryData?['receipt_id']?.toString();
      if (receiptId != null && receiptId.isNotEmpty) {
        await SupabaseService.instance.updateReceipt(receiptId, payload);
      } else {
        await SupabaseService.instance.saveReceipt(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('receipt_saved')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t.translate('issue_receipt'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          t.translate('issue_receipt'),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_saving || _sendingEmail)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader(context, t.translate('receipt_data'), Icons.receipt_outlined),
            const SizedBox(height: 12),
            _textField(
              controller: _receiptNumberCtrl,
              label: t.translate('receipt_number'),
              icon: Icons.tag,
              validator: _requiredValidator,
              onChanged: (_) => _invalidatePdfCache(),
            ),
            const SizedBox(height: 12),
            _datePicker(context, t),
            const SizedBox(height: 12),
            _documentKindSelector(context, t),
            if (_documentKind == 'seikyuusho') ...[
              const SizedBox(height: 12),
              _dueDatePicker(context, t),
            ],
            const SizedBox(height: 12),
            _itemTypeSelector(context, t),
            const SizedBox(height: 12),
            _textField(
              controller: _descriptionCtrl,
              label: t.translate('description'),
              icon: Icons.description_outlined,
              maxLines: 2,
              validator: _requiredValidator,
              onChanged: (_) => _invalidatePdfCache(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    controller: _amountCtrl,
                    label: t.translate('value'),
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    validator: _requiredValidator,
                    onChanged: (_) {
                      _calculateInstallmentValue();
                      _invalidatePdfCache();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    controller: _taxAmountCtrl,
                    label: t.translate('tax_rate'),
                    icon: Icons.percent,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      _calculateInstallmentValue();
                      _invalidatePdfCache();
                    },
                  ),
                ),
              ],
            ),
            if (_documentKind != 'seikyuusho') ...[
              const SizedBox(height: 12),
              _paymentSelector(context, t),
            ],
            const SizedBox(height: 12),
            _paymentConditionSelector(context, t),
            if (_paymentCondition == 'faturado' && _documentKind != 'seikyuusho') ...[
              const SizedBox(height: 12),
              _dueDatePicker(context, t),
            ],
            if (_paymentCondition == 'parcelado') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _downPaymentCtrl,
                      label: 'Valor Entrada',
                      icon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculateInstallmentValue();
                        _invalidatePdfCache();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _installmentsCountCtrl,
                      label: 'Parcelas',
                      icon: Icons.format_list_numbered,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _calculateInstallmentValue();
                        _invalidatePdfCache();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _installmentValueCtrl,
                      label: 'Valor Parcela',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _invalidatePdfCache(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _dueDatePicker(context, t)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _sectionHeader(
              context,
              t.translate('client_data'),
              Icons.person_outline,
              trailing: TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(t.translate('new_client')),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientFormPage()),
                  );
                  try {
                    final clients = await SupabaseService.instance.getClients();
                    if (mounted) {
                      setState(() {
                        _clients = List<Map<String, dynamic>>.from(clients);
                      });
                    }
                  } catch (e) {
                    debugPrint('Erro ao recarregar clientes: $e');
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _clientNameCtrl,
              label: t.translate('client_name'),
              icon: Icons.person,
              onChanged: _onClientNameChanged,
              validator: _requiredForSeikyuushoValidator,
            ),
            if (_clientSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: _clientSuggestions.map((client) {
                    final name = (client['name'] ?? '').toString();
                    final email = (client['email'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_search_outlined),
                      title: Text(name),
                      subtitle: email.isEmpty ? null : Text(email),
                      onTap: () => _selectClientSuggestion(client),
                    );
                  }).toList(),
                ),
              ),
            ],
            if (_showNoClientWarning) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.translate('no_client_name_match'),
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _textField(
              controller: _clientEmailCtrl,
              label: t.translate('client_email'),
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _invalidatePdfCache(),
              validator: _requiredForSeikyuushoValidator,
            ),
            if (_documentKind == 'seikyuusho') ...[
              const SizedBox(height: 12),
              _textField(
                controller: _clientPhoneCtrl,
                label: t.translate('client_phone'),
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                onChanged: (_) => _invalidatePdfCache(),
                validator: _requiredForSeikyuushoValidator,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _clientAddressCtrl,
                label: t.translate('client_address'),
                icon: Icons.location_on_outlined,
                maxLines: 2,
                onChanged: (_) => _invalidatePdfCache(),
                validator: _requiredForSeikyuushoValidator,
              ),
            ],
            const SizedBox(height: 24),
            _sectionHeader(context, t.translate('receipt_format'), Icons.tune),
            const SizedBox(height: 12),
            _formatSelector(context, t),
            const SizedBox(height: 24),
            _textField(
              controller: _notesCtrl,
              label: t.translate('notes'),
              icon: Icons.notes,
              maxLines: 3,
              onChanged: (_) => _invalidatePdfCache(),
            ),
            if (_documentKind == 'ryoushuusho' && widget.entryData == null) ...[
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _createEntryOnSave,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _createEntryOnSave = value;
                  });
                },
                title: Text(
                  t.translate('receipt_launch_entry_title'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  t.translate('receipt_launch_entry_description'),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 32),
            _actionButtons(context, t),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, IconData icon, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return AppLocalizations.of(context).translate('error_fill_mandatory_fields');
    }
    return null;
  }

  String? _requiredForSeikyuushoValidator(String? value) {
    if (_documentKind != 'seikyuusho') return null;
    if ((value ?? '').trim().isEmpty) {
      return AppLocalizations.of(context).translate('error_fill_mandatory_fields');
    }
    return null;
  }

  Widget _dueDatePicker(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    final dateStr = _dueDate == null ? '' : DateFormat('dd/MM/yyyy').format(_dueDate!);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (picked != null) {
          setState(() {
            _dueDate = picked;
          });
          _invalidatePdfCache();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: t.translate('due_date'),
          prefixIcon: const Icon(Icons.event),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        child: Text(dateStr, style: theme.textTheme.bodyLarge),
      ),
    );
  }

  Widget _datePicker(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd/MM/yyyy').format(_issueDate);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _issueDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) {
          setState(() {
            _issueDate = picked;
          });
          await _refreshReceiptNumber();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: t.translate('receipt_date'),
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        child: Text(dateStr, style: theme.textTheme.bodyLarge),
      ),
    );
  }

  Widget _itemTypeSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedItemType,
      decoration: InputDecoration(
        labelText: t.translate('receipt_item_type'),
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: [
        DropdownMenuItem(
          value: 'product',
          child: Text(t.translate('receipt_item_product')),
        ),
        DropdownMenuItem(
          value: 'service',
          child: Text(t.translate('receipt_item_service')),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedItemType = value;
          if (value == 'product') {
            _selectedServiceId = null;
          }
          _invalidatePdfCache();
        });
      },
    );
  }

  Widget _documentKindSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      initialValue: _documentKind,
      decoration: InputDecoration(
        labelText: t.translate('document_kind'),
        prefixIcon: const Icon(Icons.description_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: [
        DropdownMenuItem(
          value: 'seikyuusho',
          child: Text(t.translate('document_kind_seikyuusho')),
        ),
        DropdownMenuItem(
          value: 'ryoushuusho',
          child: Text(t.translate('document_kind_ryoushuusho')),
        ),
        DropdownMenuItem(
          value: 'reshiito',
          child: Text(t.translate('document_kind_reshiito')),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _documentKind = value;
          if (value == 'seikyuusho') {
            _createEntryOnSave = false;
            _dueDate ??= DateTime.now().add(const Duration(days: 30));
            final bankInfo = _companyProfile['bank_info'];
            if (bankInfo != null && bankInfo.isNotEmpty) {
              _notesCtrl.text = bankInfo;
            }
          } else if (widget.entryData == null) {
            _createEntryOnSave = true;
          }
          final allowedFormats = _availableFormatsForKind(value);
          final selectedStillAllowed = allowedFormats.any(
            (format) => format.value == _selectedFormat,
          );
          if (!selectedStillAllowed && allowedFormats.isNotEmpty) {
            _selectedFormat = allowedFormats.first.value;
          }
          _invalidatePdfCache();
        });
      },
    );
  }

  // ignore: unused_element
  Widget _serviceSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedServiceId,
      decoration: InputDecoration(
        labelText: t.translate('choose_service'),
        prefixIcon: const Icon(Icons.design_services_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        helperText: _services.isEmpty ? t.translate('no_services_registered') : null,
      ),
      validator: (value) {
        if (_selectedItemType == 'service' && (value == null || value.isEmpty)) {
          return t.translate('service_required');
        }
        return null;
      },
      items: _services
          .map(
            (service) => DropdownMenuItem<String>(
              value: service['id'].toString(),
              child: Text((service['name'] ?? '').toString()),
            ),
          )
          .toList(),
      onChanged: _services.isEmpty ? null : _applySelectedService,
    );
  }

  Widget _paymentSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      decoration: InputDecoration(
        labelText: t.translate('payment_method'),
        prefixIcon: const Icon(Icons.payment),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: _paymentMethods
          .map(
            (method) => DropdownMenuItem(
              value: method,
              child: Text(t.translate('payment_$method')),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _paymentMethod = value;
          _invalidatePdfCache();
        });
      },
    );
  }

  Widget _paymentConditionSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      initialValue: _paymentCondition,
      decoration: InputDecoration(
        labelText: t.translate('payment_condition'),
        prefixIcon: const Icon(Icons.handshake_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: [
        DropdownMenuItem(value: 'a_vista', child: Text(t.translate('payment_condition_cash'))),
        DropdownMenuItem(value: 'faturado', child: Text(t.translate('payment_condition_billed'))),
        DropdownMenuItem(value: 'parcelado', child: Text(t.translate('payment_condition_installment'))),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _paymentCondition = value;
          if ((value == 'faturado' || value == 'parcelado') && _dueDate == null) {
            _dueDate = DateTime.now().add(const Duration(days: 30));
          }
          _calculateInstallmentValue();
          _invalidatePdfCache();
        });
      },
    );
  }

  Widget _formatSelector(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    final availableFormats = _availableFormatsForKind(_documentKind);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableFormats.map((format) {
        final isSelected = _selectedFormat == format.value;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedFormat = format.value;
            _invalidatePdfCache();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  format.icon,
                  size: 18,
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  t.translate(format.labelKey),
                  style: TextStyle(
                    color: isSelected ? cs.onPrimary : cs.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _actionButtons(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    final isEmail = _selectedFormat == 'email';

    return Column(
      children: [
        Row(
          children: [
            _actionBtn(
              icon: Icons.visibility_outlined,
              label: t.translate('preview_receipt'),
              color: cs.tertiary,
              onTap: _previewPdf,
              flex: 2,
            ),
            const SizedBox(width: 8),
            if (!isEmail)
              _actionBtn(
                icon: Icons.print_outlined,
                label: t.translate('print_receipt'),
                color: cs.secondary,
                onTap: _printPdf,
                flex: 2,
              ),
            if (!isEmail) const SizedBox(width: 8),
            _actionBtn(
              icon: Icons.share_outlined,
              label: t.translate('share_receipt'),
              color: cs.primary,
              onTap: _sharePdf,
              flex: 2,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _actionBtn(
              icon: Icons.email_outlined,
              label: t.translate('send_by_email'),
              color: Colors.teal,
              onTap: _sendEmail,
              flex: 2,
              loading: _sendingEmail,
            ),
            const SizedBox(width: 8),
            _actionBtn(
              icon: Icons.save_outlined,
              label: t.translate('save_receipt'),
              color: Colors.green,
              onTap: _saveReceipt,
              flex: 3,
              loading: _saving,
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int flex = 1,
    bool loading = false,
  }) {
    return Expanded(
      flex: flex,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
