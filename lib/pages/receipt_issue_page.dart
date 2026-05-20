import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../services/receipt_pdf_service.dart';

// ─── Format option model ─────────────────────────────────────────────────────

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

// ─── Page ────────────────────────────────────────────────────────────────────

class ReceiptIssuePage extends StatefulWidget {
  /// Entry data to pre-populate the form.
  final Map<String, dynamic>? entryData;

  const ReceiptIssuePage({super.key, this.entryData});

  @override
  State<ReceiptIssuePage> createState() => _ReceiptIssuePageState();
}

class _ReceiptIssuePageState extends State<ReceiptIssuePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _receiptNumberCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _taxAmountCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _issueDate = DateTime.now();
  String _selectedFormat = 'a4';
  String _paymentMethod = 'cash';
  bool _loading = true;
  bool _saving = false;
  bool _sendingEmail = false;

  // Company profile
  Map<String, String?> _companyProfile = {};
  String _language = 'pt';

  // Generated PDF bytes (cached)
  Uint8List? _cachedPdfBytes;
  String? _cachedFormat;

  static const _paymentMethods = [
    'cash', 'credit_card', 'bank_transfer', 'paypay', 'other'
  ];

  @override
  void initState() {
    super.initState();
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
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final profile = await SupabaseService.instance.getCompanyProfile();
      final nextNumber = await SupabaseService.instance
          .getNextReceiptNumber(DateTime.now());

      _companyProfile = profile;
      _language = profile['language'] ?? 'pt';

      _receiptNumberCtrl.text = nextNumber;

      // Pre-fill from entry data if provided
      final entry = widget.entryData;
      if (entry != null) {
        _descriptionCtrl.text =
            (entry['description'] ?? '').toString();
        final amount = (entry['amount'] ?? 0).toDouble();
        final taxAmount = (entry['tax_amount'] ?? 0).toDouble();
        _amountCtrl.text = amount.toStringAsFixed(0);
        _taxAmountCtrl.text = taxAmount.toStringAsFixed(0);
        _paymentMethod = _normalizePayment(entry['payment_method']);
        if (entry['customer_name'] != null) {
          _clientNameCtrl.text = entry['customer_name'].toString();
        }
        if (entry['entry_date'] != null) {
          final parsed = DateTime.tryParse(entry['entry_date'].toString());
          if (parsed != null) _issueDate = parsed;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normalizePayment(dynamic value) {
    final v = (value ?? '').toString().toLowerCase();
    if (_paymentMethods.contains(v)) return v;
    return 'cash';
  }

  ReceiptData _buildReceiptData() {
    return ReceiptData(
      receiptNumber: _receiptNumberCtrl.text.trim(),
      issueDate: _issueDate,
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
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      language: _language,
    );
  }

  Future<Uint8List> _generatePdf() async {
    final data = _buildReceiptData();

    // Use cache if format hasn't changed
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
      default: // a4
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
    } catch (e) {
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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/recibo_${_receiptNumberCtrl.text}.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
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

    setState(() => _saving = true);
    try {
      final data = _buildReceiptData();
      await SupabaseService.instance.saveReceipt({
        'entry_id': widget.entryData?['id'],
        'receipt_number': data.receiptNumber,
        'issue_date': DateFormat('yyyy-MM-dd').format(data.issueDate),
        'client_name': data.clientName,
        'client_email': data.clientEmail,
        'description': data.description,
        'amount': data.amount,
        'tax_amount': data.taxAmount,
        'payment_method': data.paymentMethod,
        'notes': data.notes,
        'format': _selectedFormat,
        'language': _language,
        'issued_by': data.issuedBy,
        'company_address': data.companyAddress,
        'company_phone': data.companyPhone,
        'invoice_number': data.invoiceNumber,
      });

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

  // ─── Build ────────────────────────────────────────────────────────────────

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
            // ── Receipt data section ──────────────────────────────
            _sectionHeader(context, t.translate('receipt_data'), Icons.receipt_outlined),
            const SizedBox(height: 12),

            // Receipt number (editable)
            _textField(
              controller: _receiptNumberCtrl,
              label: t.translate('receipt_number'),
              icon: Icons.tag,
              validator: _requiredValidator,
              onChanged: (_) => _invalidatePdfCache(),
            ),
            const SizedBox(height: 12),

            // Issue date
            _datePicker(context, t),
            const SizedBox(height: 12),

            // Description
            _textField(
              controller: _descriptionCtrl,
              label: t.translate('description'),
              icon: Icons.description_outlined,
              maxLines: 2,
              validator: _requiredValidator,
              onChanged: (_) => _invalidatePdfCache(),
            ),
            const SizedBox(height: 12),

            // Amount + Tax row
            Row(children: [
              Expanded(
                child: _textField(
                  controller: _amountCtrl,
                  label: t.translate('value'),
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: _requiredValidator,
                  onChanged: (_) => _invalidatePdfCache(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  controller: _taxAmountCtrl,
                  label: t.translate('tax_rate'),
                  icon: Icons.percent,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _invalidatePdfCache(),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Payment method
            _paymentSelector(context, t),

            const SizedBox(height: 24),

            // ── Client data section ────────────────────────────────
            _sectionHeader(context, t.translate('client_data'), Icons.person_outline),
            const SizedBox(height: 12),

            _textField(
              controller: _clientNameCtrl,
              label: t.translate('client_name'),
              icon: Icons.person,
              onChanged: (_) => _invalidatePdfCache(),
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _clientEmailCtrl,
              label: t.translate('client_email'),
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _invalidatePdfCache(),
            ),

            const SizedBox(height: 24),

            // ── Format selector ────────────────────────────────────
            _sectionHeader(context, t.translate('receipt_format'), Icons.tune),
            const SizedBox(height: 12),
            _formatSelector(context, t),

            const SizedBox(height: 24),

            // ── Notes ─────────────────────────────────────────────
            _textField(
              controller: _notesCtrl,
              label: t.translate('notes'),
              icon: Icons.notes,
              maxLines: 3,
              onChanged: (_) => _invalidatePdfCache(),
            ),

            const SizedBox(height: 32),

            // ── Action buttons ─────────────────────────────────────
            _actionButtons(context, t),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: cs.primary),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }

  // ─── Text field ───────────────────────────────────────────────────────────

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
      return AppLocalizations.of(context)
          .translate('error_fill_mandatory_fields');
    }
    return null;
  }

  // ─── Date picker ─────────────────────────────────────────────────────────

  Widget _datePicker(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd/MM/yyyy').format(_issueDate);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _issueDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() {
            _issueDate = picked;
            _invalidatePdfCache();
          });
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

  // ─── Payment selector ─────────────────────────────────────────────────────

  Widget _paymentSelector(BuildContext context, AppLocalizations t) {
    return DropdownButtonFormField<String>(
      value: _paymentMethod,
      decoration: InputDecoration(
        labelText: t.translate('payment_method'),
        prefixIcon: const Icon(Icons.payment),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: _paymentMethods.map((m) {
        return DropdownMenuItem(
          value: m,
          child: Text(t.translate('payment_$m')),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() {
            _paymentMethod = v;
            _invalidatePdfCache();
          });
        }
      },
    );
  }

  // ─── Format selector ─────────────────────────────────────────────────────

  Widget _formatSelector(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(spacing: 8, runSpacing: 8, children: _formats.map((f) {
      final isSelected = _selectedFormat == f.value;
      return GestureDetector(
        onTap: () => setState(() {
          _selectedFormat = f.value;
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              f.icon,
              size: 18,
              color: isSelected ? cs.onPrimary : cs.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              t.translate(f.labelKey),
              style: TextStyle(
                color: isSelected ? cs.onPrimary : cs.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      );
    }).toList());
  }

  // ─── Action buttons ───────────────────────────────────────────────────────

  Widget _actionButtons(BuildContext context, AppLocalizations t) {
    final cs = Theme.of(context).colorScheme;
    final isEmail = _selectedFormat == 'email';

    return Column(children: [
      // Row 1: Preview / Print / Share
      Row(children: [
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
      ]),

      const SizedBox(height: 8),

      // Row 2: Send email / Save
      Row(children: [
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
      ]),
    ]);
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
