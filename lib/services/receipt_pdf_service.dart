import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── Data model ──────────────────────────────────────────────────────────────

class ReceiptData {
  final String receiptNumber;
  final DateTime issueDate;
  final String documentKind;
  final String description;
  final double amount;
  final double taxAmount;
  final String currency;
  final String paymentMethod;
  final String issuedBy;
  final String? companyAddress;
  final String? companyPhone;
  final String? invoiceNumber;
  final String? clientName;
  final String? clientEmail;
  final String? notes;
  final String language;
  final DateTime? dueDate;

  const ReceiptData({
    required this.receiptNumber,
    required this.issueDate,
    required this.documentKind,
    required this.description,
    required this.amount,
    required this.taxAmount,
    required this.currency,
    required this.paymentMethod,
    required this.issuedBy,
    this.companyAddress,
    this.companyPhone,
    this.invoiceNumber,
    this.clientName,
    this.clientEmail,
    this.notes,
    this.language = 'pt',
    this.dueDate,
  });

  double get total => amount + taxAmount;
}

// ── SMTP config ──────────────────────────────────────────────────────────────

class SmtpConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String senderName;
  final bool useSSL;

  const SmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.senderName,
    required this.useSSL,
  });
}

// ── I18n labels ──────────────────────────────────────────────────────────────

class _Labels {
  final String receipt;
  final String invoice;
  final String receiptNumber;
  final String invoiceNumberLabel;
  final String date;
  final String issuedBy;
  final String issuedTo;
  final String description;
  final String amount;
  final String tax;
  final String total;
  final String payment;
  final String notes;
  final String invoiceNumber;
  final String thankYou;
  final String currencyFmt;
  final String dueDate;
  final String amountReceived;
  final String proviso;
  final String billTo;
  final String issueDate;

  const _Labels({
    required this.receipt,
    required this.invoice,
    required this.receiptNumber,
    required this.invoiceNumberLabel,
    required this.date,
    required this.issuedBy,
    required this.issuedTo,
    required this.description,
    required this.amount,
    required this.tax,
    required this.total,
    required this.payment,
    required this.notes,
    required this.invoiceNumber,
    required this.thankYou,
    required this.currencyFmt,
    required this.dueDate,
    required this.amountReceived,
    required this.proviso,
    required this.billTo,
    required this.issueDate,
  });

  static _Labels forLocale(String lang) {
    switch (lang) {
      case 'ja':
        return const _Labels(
          receipt: '領収書',
          invoice: '請求書',
          invoiceNumberLabel: '請求書番号',
          receiptNumber: '領収書番号',
          date: '発行日',
          issuedBy: '発行者',
          issuedTo: '宛先',
          description: '内容',
          amount: '小計',
          tax: '消費税',
          total: '合計',
          payment: '支払方法',
          notes: '備考',
          invoiceNumber: '登録番号',
          thankYou: 'ありがとうございます。',
          currencyFmt: '¥#,##0',
          dueDate: '支払期限',
          amountReceived: '領収金額',
          proviso: '但し',
          billTo: '請求先',
          issueDate: '発行日',
        );
      case 'es':
        return const _Labels(
          receipt: 'RECIBO',
          invoice: 'FACTURA',
          invoiceNumberLabel: 'Nº de Factura',
          receiptNumber: 'Nº de Recibo',
          date: 'Fecha',
          issuedBy: 'Emisor',
          issuedTo: 'Cliente',
          description: 'Descripción',
          amount: 'Subtotal',
          tax: 'Impuesto',
          total: 'Total',
          payment: 'Pago',
          notes: 'Notas',
          invoiceNumber: 'Nº Invoice',
          thankYou: '¡Gracias!',
          currencyFmt: '¥#,##0',
          dueDate: 'Fecha de vencimiento',
          amountReceived: 'Importe recibido',
          proviso: 'Concepto',
          billTo: 'Facturar a',
          issueDate: 'Fecha de emisión',
        );
      case 'en':
        return const _Labels(
          receipt: 'RECEIPT',
          invoice: 'INVOICE',
          invoiceNumberLabel: 'Invoice No.',
          receiptNumber: 'Receipt No.',
          date: 'Date',
          issuedBy: 'Issued By',
          issuedTo: 'Client',
          description: 'Description',
          amount: 'Subtotal',
          tax: 'Tax',
          total: 'Total',
          payment: 'Payment',
          notes: 'Notes',
          invoiceNumber: 'Invoice No.',
          thankYou: 'Thank you!',
          currencyFmt: '¥#,##0',
          dueDate: 'Due Date',
          amountReceived: 'Amount Received',
          proviso: 'For',
          billTo: 'Bill To',
          issueDate: 'Issue Date',
        );
      default: // pt
        return const _Labels(
          receipt: 'RECIBO',
          invoice: 'FATURA',
          invoiceNumberLabel: 'Nº da Fatura',
          receiptNumber: 'Nº do Recibo',
          date: 'Data',
          issuedBy: 'Emitido por',
          issuedTo: 'Cliente',
          description: 'Descrição',
          amount: 'Subtotal',
          tax: 'Imposto',
          total: 'Total',
          payment: 'Pagamento',
          notes: 'Observações',
          invoiceNumber: 'Nº Invoice',
          thankYou: 'Obrigado!',
          currencyFmt: '¥#,##0',
          dueDate: 'Data de Vencimento',
          amountReceived: 'Valor Recebido',
          proviso: 'Referente a',
          billTo: 'Cobrar de',
          issueDate: 'Data de Emissão',
        );
    }
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

class ReceiptPdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF1A1A2E);
  static const PdfColor _accent = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _grey = PdfColor.fromInt(0xFF757575);
  static const PdfColor _lightGrey = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _border = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);

  static Future<pw.Font> _loadRegularFont(String language) async {
    if (language == 'ja') {
      return PdfGoogleFonts.notoSansJPRegular();
    }
    return PdfGoogleFonts.notoSansRegular();
  }

  static Future<pw.Font> _loadBoldFont(String language) async {
    if (language == 'ja') {
      return PdfGoogleFonts.notoSansJPBold();
    }
    return PdfGoogleFonts.notoSansBold();
  }

  // ── number formatting ──────────────────────────────────────
  static String _fmt(double value, String currencyFmt) {
    final formatter = NumberFormat(currencyFmt);
    return formatter.format(value);
  }

  static String _fmtDate(DateTime date, String lang) {
    switch (lang) {
      case 'ja':
        return DateFormat('yyyy年MM月dd日').format(date);
      case 'en':
        return DateFormat('MMM dd, yyyy').format(date);
      default:
        return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  static String _paymentLabel(String code, String lang) {
    const map = {
      'pt': {
        'cash': 'Dinheiro',
        'credit_card': 'Cartão de crédito',
        'bank_transfer': 'Transferência',
        'paypay': 'PayPay',
        'other': 'Outro',
      },
      'en': {
        'cash': 'Cash',
        'credit_card': 'Credit Card',
        'bank_transfer': 'Bank Transfer',
        'paypay': 'PayPay',
        'other': 'Other',
      },
      'ja': {
        'cash': '現金',
        'credit_card': 'クレジットカード',
        'bank_transfer': '銀行振込',
        'paypay': 'PayPay',
        'other': 'その他',
      },
      'es': {
        'cash': 'Efectivo',
        'credit_card': 'Tarjeta de crédito',
        'bank_transfer': 'Transferencia',
        'paypay': 'PayPay',
        'other': 'Otro',
      },
    };

    final langMap = map[lang] ?? map['pt']!;
    return langMap[code] ?? code;
  }

  // ═══════════════════════════════════════════════════════════
  // THERMAL 58mm
  // ═══════════════════════════════════════════════════════════

  static Future<Uint8List> buildThermal58(ReceiptData data) async {
    final l = _Labels.forLocale(data.language);
    final doc = pw.Document();
    const width = 57.5 * PdfPageFormat.mm;
    final font = await _loadRegularFont(data.language);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(width, double.infinity, marginAll: 3 * PdfPageFormat.mm),
      build: (context) => _thermalBody(data, l, font, compact: true),
    ));

    return doc.save();
  }

  // ═══════════════════════════════════════════════════════════
  // THERMAL 80mm
  // ═══════════════════════════════════════════════════════════

  static Future<Uint8List> buildThermal80(ReceiptData data) async {
    final l = _Labels.forLocale(data.language);
    final doc = pw.Document();
    const width = 79.5 * PdfPageFormat.mm;
    final font = await _loadRegularFont(data.language);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(width, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      build: (context) => _thermalBody(data, l, font, compact: false),
    ));

    return doc.save();
  }

  static pw.Widget _thermalBody(ReceiptData data, _Labels l, pw.Font font, {required bool compact}) {
    const ts = 7.5;
    const tsB = 8.5;
    final isInvoice = data.documentKind == 'seikyuusho';

    pw.TextStyle style({double size = ts, bool bold = false}) =>
        pw.TextStyle(font: font, fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    // Dashed divider for thermal receipt
    String dashedDivider(int n) => List.filled(n, '- ').join();
    final n = compact ? 14 : 20;
    final numberLabel = isInvoice ? l.invoiceNumberLabel : l.receiptNumber;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text(data.issuedBy, style: style(size: tsB + 2, bold: true))),
        pw.SizedBox(height: 4),
        if (data.companyAddress != null) pw.Center(child: pw.Text(data.companyAddress!, style: style(), textAlign: pw.TextAlign.center)),
        if (data.companyPhone != null) pw.Center(child: pw.Text(data.companyPhone!, style: style())),
        if (data.invoiceNumber != null) pw.Center(child: pw.Text('${l.invoiceNumber}: ${data.invoiceNumber}', style: style())),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text(dashedDivider(n), style: style())),
        pw.SizedBox(height: 4),
        pw.Text('${isInvoice ? l.invoice : l.receipt} $numberLabel: ${data.receiptNumber}', style: style(bold: true)),
        pw.Text('${l.issueDate}: ${_fmtDate(data.issueDate, data.language)}', style: style()),
        if (data.clientName != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('${isInvoice ? l.billTo : l.issuedTo}: ${data.clientName}', style: style()),
        ],
        if (isInvoice && data.dueDate != null) pw.Text('${l.dueDate}: ${_fmtDate(data.dueDate!, data.language)}', style: style()),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(dashedDivider(n), style: style())),
        pw.SizedBox(height: 4),
        pw.Text('${isInvoice ? l.description : l.proviso}: ${data.description}', style: style()),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(dashedDivider(n), style: style())),
        pw.SizedBox(height: 4),
        _thermalRow(l.amount, _fmt(data.amount, l.currencyFmt), style),
        if (data.taxAmount > 0) _thermalRow(l.tax, _fmt(data.taxAmount, l.currencyFmt), style),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(dashedDivider(n), style: style())),
        pw.SizedBox(height: 4),
        _thermalRow(isInvoice ? l.total : l.amountReceived, _fmt(data.total, l.currencyFmt), style, bold: true, size: tsB + 1),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(dashedDivider(n), style: style())),
        pw.SizedBox(height: 4),
        pw.Text('${l.payment}: ${_paymentLabel(data.paymentMethod, data.language)}', style: style()),
        if (data.notes != null && data.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(dashedDivider(n), style: style())),
          pw.SizedBox(height: 4),
          pw.Text('${l.notes}: ${data.notes}', style: style()),
        ],
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Text(l.thankYou, style: style(bold: true, size: tsB))),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _thermalRow(
    String label,
    String value,
    pw.TextStyle Function({double size, bool bold}) style, {
    bool bold = false,
    double size = 7.5,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style(size: size, bold: bold)),
        pw.Text(value, style: style(size: size, bold: bold)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // A5
  // ═══════════════════════════════════════════════════════════

  static Future<Uint8List> buildA5(ReceiptData data) async {
    return _buildPagedReceipt(data, PdfPageFormat.a5.landscape);
  }

  // ═══════════════════════════════════════════════════════════
  // A4
  // ═══════════════════════════════════════════════════════════

  static Future<Uint8List> buildA4(ReceiptData data) async {
    return _buildPagedReceipt(data, PdfPageFormat.a4);
  }

  static Future<Uint8List> _buildPagedReceipt(ReceiptData data, PdfPageFormat format) async {
    final l = _Labels.forLocale(data.language);
    final doc = pw.Document();
    final fontRegular = await _loadRegularFont(data.language);
    final fontBold = await _loadBoldFont(data.language);

    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        if (data.documentKind == 'seikyuusho') {
          return _buildSeikyushoBody(data, l, fontRegular, fontBold);
        } else if (data.documentKind == 'ryoushuusho') {
          return _buildRyoshushoBody(data, l, fontRegular, fontBold);
        } else {
          return _pagedBodyFallback(data, l, fontRegular, fontBold);
        }
      },
    ));

    return doc.save();
  }

  // ── Seikyusho (Invoice) Premium Layout ────────────────────────────────────
  static pw.Widget _buildSeikyushoBody(ReceiptData data, _Labels l, pw.Font regular, pw.Font bold) {
    pw.TextStyle r({double size = 10, PdfColor? color}) => pw.TextStyle(font: regular, fontSize: size, color: color ?? _primary);
    pw.TextStyle b({double size = 10, PdfColor? color}) => pw.TextStyle(font: bold, fontSize: size, color: color ?? _primary);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title
        pw.Center(
          child: pw.Text(
            l.invoice,
            style: b(size: 24).copyWith(letterSpacing: 2),
          ),
        ),
        pw.SizedBox(height: 24),

        // Header Info
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Bill To
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (data.clientName != null) ...[
                    pw.Text(
                      '${data.clientName!}${data.language == 'ja' ? ' 御中' : ''}',
                      style: b(size: 16),
                    ),
                    pw.Divider(color: _primary, thickness: 1.5, endIndent: 20),
                    pw.SizedBox(height: 4),
                  ],
                  if (data.clientEmail != null) pw.Text(data.clientEmail!, style: r()),
                  pw.SizedBox(height: 12),
                  pw.Text('${l.amountReceived}:', style: r(size: 10, color: _grey)),
                  pw.Text(
                    _fmt(data.total, l.currencyFmt),
                    style: b(size: 20),
                  ),
                ],
              ),
            ),
            
            // Issuer
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('${l.invoiceNumberLabel}: ${data.receiptNumber}', style: r(size: 9)),
                  pw.Text('${l.issueDate}: ${_fmtDate(data.issueDate, data.language)}', style: r(size: 9)),
                  if (data.dueDate != null)
                    pw.Text('${l.dueDate}: ${_fmtDate(data.dueDate!, data.language)}', style: b(size: 9, color: PdfColor.fromInt(0xFFD32F2F))),
                  pw.SizedBox(height: 12),
                  pw.Text(data.issuedBy, style: b(size: 14)),
                  if (data.companyAddress != null) pw.Text(data.companyAddress!, style: r(size: 9), textAlign: pw.TextAlign.right),
                  if (data.companyPhone != null) pw.Text(data.companyPhone!, style: r(size: 9)),
                  if (data.invoiceNumber != null) pw.Text('${l.invoiceNumber}: ${data.invoiceNumber}', style: r(size: 9)),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 32),

        // Table
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const pw.BoxDecoration(
                  color: _lightGrey,
                  borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(l.description, style: b(size: 10)),
                    pw.Text(l.amount, style: b(size: 10)),
                  ],
                ),
              ),
              pw.Divider(color: _border, height: 1),
              // Item
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(data.description, style: r())),
                    pw.Text(_fmt(data.amount, l.currencyFmt), style: r()),
                  ],
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // Totals
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 250,
            child: pw.Column(
              children: [
                _pagedTotalRow(l.amount, _fmt(data.amount, l.currencyFmt), r, r),
                if (data.taxAmount > 0) _pagedTotalRow(l.tax, _fmt(data.taxAmount, l.currencyFmt), r, r),
                pw.Divider(color: _border),
                _pagedTotalRow(l.total, _fmt(data.total, l.currencyFmt), r, r, bold: b(size: 14)),
              ],
            ),
          ),
        ),

        pw.Spacer(),

        // Notes / Payment Info
        if (data.notes != null && data.notes!.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _lightGrey,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(l.notes, style: b(size: 9)),
                pw.SizedBox(height: 4),
                pw.Text(data.notes!, style: r(size: 9)),
              ],
            ),
          ),
        ],

        pw.SizedBox(height: 16),
        pw.Center(child: pw.Text(l.thankYou, style: r(size: 12, color: _accent))),
      ],
    );
  }

  // ── Ryoshusho (Receipt) Premium Layout ────────────────────────────────────
  static pw.Widget _buildRyoshushoBody(ReceiptData data, _Labels l, pw.Font regular, pw.Font bold) {
    pw.TextStyle r({double size = 10, PdfColor? color}) => pw.TextStyle(font: regular, fontSize: size, color: color ?? _primary);
    pw.TextStyle b({double size = 10, PdfColor? color}) => pw.TextStyle(font: bold, fontSize: size, color: color ?? _primary);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Title Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${l.receiptNumber}: ${data.receiptNumber}', style: r(size: 9, color: _grey)),
            pw.Text(
              l.receipt,
              style: b(size: 24).copyWith(letterSpacing: 4),
            ),
            pw.Text('${l.issueDate}: ${_fmtDate(data.issueDate, data.language)}', style: r(size: 10)),
          ],
        ),
        
        pw.SizedBox(height: 32),

        // Client Name
        if (data.clientName != null) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('${data.clientName!}${data.language == 'ja' ? ' 様' : ''}', style: b(size: 18)),
            ],
          ),
          pw.Divider(color: _primary, thickness: 1, endIndent: 200),
        ],
        
        pw.SizedBox(height: 24),

        // Amount Box (Prominent)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF5F7FA),
            border: pw.Border.all(color: _accent, width: 2),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('${l.amountReceived}: ', style: b(size: 14, color: _accent)),
              pw.Text('${_fmt(data.total, l.currencyFmt)} -', style: b(size: 28, color: _accent)),
            ],
          ),
        ),

        pw.SizedBox(height: 24),

        // Description / Proviso
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${l.proviso}: ', style: b(size: 12)),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border))),
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(data.description, style: r(size: 12)),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${l.payment}: ', style: b(size: 12)),
            pw.Expanded(
              child: pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _border))),
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(_paymentLabel(data.paymentMethod, data.language), style: r(size: 12)),
              ),
            ),
          ],
        ),

        pw.Spacer(),

        // Bottom section: Breakdown and Issuer
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Breakdown
            pw.Container(
              width: 180,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pagedTotalRow(l.amount, _fmt(data.amount, l.currencyFmt), r, r),
                  if (data.taxAmount > 0) _pagedTotalRow(l.tax, _fmt(data.taxAmount, l.currencyFmt), r, r),
                ],
              ),
            ),

            // Issuer & Stamp Area
            pw.Row(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(data.issuedBy, style: b(size: 14)),
                    if (data.companyAddress != null) pw.Text(data.companyAddress!, style: r(size: 9)),
                    if (data.companyPhone != null) pw.Text(data.companyPhone!, style: r(size: 9)),
                    if (data.invoiceNumber != null) pw.Text('${l.invoiceNumber}: ${data.invoiceNumber}', style: r(size: 9)),
                  ],
                ),
                pw.SizedBox(width: 16),
                // Stamp area (Inkan)
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFD32F2F), width: 1),
                    borderRadius: pw.BorderRadius.circular(25),
                  ),
                  child: pw.Center(child: pw.Text('印', style: r(size: 14, color: PdfColor.fromInt(0xFFFFCDD2)))),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Fallback Premium Layout ───────────────────────────────────────────────
  static pw.Widget _pagedBodyFallback(ReceiptData data, _Labels l, pw.Font regular, pw.Font bold) {
    pw.TextStyle r({double size = 10}) => pw.TextStyle(font: regular, fontSize: size, color: _primary);
    pw.TextStyle b({double size = 10}) => pw.TextStyle(font: bold, fontSize: size, color: _primary);
    pw.TextStyle g({double size = 9}) => pw.TextStyle(font: regular, fontSize: size, color: _grey);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: _primary, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(data.issuedBy, style: b(size: 16).copyWith(color: _white)),
                if (data.companyAddress != null) pw.Text(data.companyAddress!, style: r(size: 9).copyWith(color: const PdfColor.fromInt(0xFFBDBDBD))),
                if (data.companyPhone != null) pw.Text(data.companyPhone!, style: r(size: 9).copyWith(color: const PdfColor.fromInt(0xFFBDBDBD))),
                if (data.invoiceNumber != null) pw.Text('${l.invoiceNumber}: ${data.invoiceNumber}', style: r(size: 8).copyWith(color: const PdfColor.fromInt(0xFF90CAF9))),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(color: _accent, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Text(l.receipt, style: b(size: 13).copyWith(color: _white)),
                ),
                pw.SizedBox(height: 4),
                pw.Text(data.receiptNumber, style: r(size: 10).copyWith(color: const PdfColor.fromInt(0xFFE0E0E0))),
                pw.Text('${l.issueDate}: ${_fmtDate(data.issueDate, data.language)}', style: r(size: 9).copyWith(color: const PdfColor.fromInt(0xFFBDBDBD))),
              ]),
            ],
          ),
        ),

        pw.SizedBox(height: 16),

        // ── Client info ────────────────────────────────────────
        if (data.clientName != null)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: _lightGrey, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(children: [
              pw.Text('${l.issuedTo}: ', style: g()),
              pw.Text('${data.clientName!}${data.language == 'ja' ? ' 様' : ''}', style: b(size: 10)),
              if (data.clientEmail != null) ...[
                pw.Text('  ·  ', style: g()),
                pw.Text(data.clientEmail!, style: r().copyWith(color: _accent)),
              ],
            ]),
          ),

        pw.SizedBox(height: 16),

        // ── Description table ──────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(children: [
            // header row
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _lightGrey,
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(l.description, style: b(size: 9)),
                pw.Text(l.amount, style: b(size: 9)),
              ]),
            ),
            pw.Divider(color: _border, height: 1),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Expanded(child: pw.Text(data.description, style: r())),
                pw.Text(_fmt(data.amount, l.currencyFmt), style: r()),
              ]),
            ),
          ]),
        ),

        pw.SizedBox(height: 12),

        // ── Totals ────────────────────────────────────────────
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 220,
            child: pw.Column(children: [
              _pagedTotalRow(l.amount, _fmt(data.amount, l.currencyFmt), r, g),
              if (data.taxAmount > 0)
                _pagedTotalRow(l.tax, _fmt(data.taxAmount, l.currencyFmt), r, g),
              pw.Divider(color: _border),
              _pagedTotalRow(
                l.total,
                _fmt(data.total, l.currencyFmt),
                r,
                g,
                bold: b(size: 13),
              ),
            ]),
          ),
        ),

        pw.SizedBox(height: 16),

        // ── Payment method ─────────────────────────────────────
        pw.Row(children: [
          pw.Text('${l.payment}: ', style: g()),
          pw.Text(_paymentLabel(data.paymentMethod, data.language), style: b()),
        ]),

        // ── Notes ─────────────────────────────────────────────
        if (data.notes != null && data.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: _lightGrey, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(l.notes, style: g()),
              pw.SizedBox(height: 4),
              pw.Text(data.notes!, style: r()),
            ]),
          ),
        ],

        pw.Spacer(),

        // ── Footer ────────────────────────────────────────────
        pw.Divider(color: _border),
        pw.Center(child: pw.Text(l.thankYou, style: b().copyWith(color: _accent))),
      ],
    );
  }

  static pw.Widget _pagedTotalRow(
    String label,
    String value,
    pw.TextStyle Function({double size}) r,
    pw.TextStyle Function({double size}) g, {
    pw.TextStyle? bold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: bold != null ? bold : g()),
        pw.Text(value, style: bold ?? r()),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMAIL HTML
  // ═══════════════════════════════════════════════════════════

  static String buildEmailHtml(ReceiptData data) {
    final l = _Labels.forLocale(data.language);
    final isInvoice = data.documentKind == 'seikyuusho';
    final taxRow = data.taxAmount > 0
        ? '<tr><td style="padding:8px 0;color:#757575">${l.tax}</td><td style="text-align:right;color:#757575">${_fmt(data.taxAmount, l.currencyFmt)}</td></tr>'
        : '';
    final clientRow = data.clientName != null
        ? '<div style="margin-bottom:20px;padding-bottom:20px;border-bottom:1px solid #E0E0E0;"><p style="margin:0 0 4px;font-size:16px;"><strong>${isInvoice ? l.billTo : l.issuedTo}:</strong> ${data.clientName}${data.language == 'ja' ? ' 様' : ''}</p>${data.clientEmail != null ? '<p style="margin:0;color:#757575;">${data.clientEmail}</p>' : ''}</div>'
        : '';
    final notesSection = (data.notes != null && data.notes!.isNotEmpty)
        ? '<div style="background:#F5F7FA;border-left:4px solid #1E88E5;padding:12px 16px;margin-top:24px"><p style="margin:0 0 4px;color:#757575;font-size:12px;font-weight:bold;">${l.notes}</p><p style="margin:0;line-height:1.4;">${data.notes!.replaceAll('\n', '<br>')}</p></div>'
        : '';
    final invoiceRow = data.invoiceNumber != null
        ? '<p style="margin:4px 0 0;font-size:12px;color:#90CAF9">${l.invoiceNumber}: ${data.invoiceNumber}</p>'
        : '';

    return '''<!DOCTYPE html>
<html lang="${data.language}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${isInvoice ? l.invoice : l.receipt} ${data.receiptNumber}</title>
</head>
<body style="margin:0;padding:20px;background:#f9f9f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#1A1A2E">
<div style="max-width:600px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 8px 24px rgba(0,0,0,.08)">
  <!-- Header -->
  <div style="background:#1A1A2E;padding:32px;display:flex;justify-content:space-between;align-items:flex-start">
    <div style="flex:1">
      <h2 style="margin:0 0 8px;color:#fff;font-size:22px;letter-spacing:1px;">${data.issuedBy}</h2>
      ${data.companyAddress != null ? '<p style="margin:0 0 4px;color:#BDBDBD;font-size:13px">${data.companyAddress}</p>' : ''}
      ${data.companyPhone != null ? '<p style="margin:0 0 4px;color:#BDBDBD;font-size:13px">${data.companyPhone}</p>' : ''}
      $invoiceRow
    </div>
    <div style="text-align:right;margin-left:20px;">
      <span style="background:#1E88E5;color:#fff;padding:6px 16px;border-radius:20px;font-size:14px;font-weight:bold;display:inline-block;margin-bottom:12px;">${isInvoice ? l.invoice : l.receipt}</span>
      <p style="margin:0 0 4px;color:#E0E0E0;font-size:14px;">${data.receiptNumber}</p>
      <p style="margin:0;color:#BDBDBD;font-size:12px">${_fmtDate(data.issueDate, data.language)}</p>
    </div>
  </div>
  <!-- Body -->
  <div style="padding:32px">
    $clientRow
    
    <!-- Amount Highlight (For Ryoshusho) -->
    ${!isInvoice ? '<div style="background:#F5F7FA;border:2px solid #1E88E5;border-radius:8px;padding:24px;text-align:center;margin-bottom:24px;"><p style="margin:0 0 8px;color:#1E88E5;font-weight:bold;">${l.amountReceived}</p><h1 style="margin:0;color:#1E88E5;font-size:32px;">${_fmt(data.total, l.currencyFmt)} -</h1></div>' : ''}

    <!-- Description table -->
    <table style="width:100%;border-collapse:collapse;margin-top:8px;border:1px solid #E0E0E0;border-radius:8px;overflow:hidden;">
      <thead>
        <tr style="background:#F5F7FA;border-bottom:2px solid #E0E0E0;">
          <th style="text-align:left;padding:12px 16px;font-size:13px;color:#757575;">${isInvoice ? l.description : l.proviso}</th>
          <th style="text-align:right;padding:12px 16px;font-size:13px;color:#757575;">${l.amount}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td style="padding:16px;font-size:15px;border-bottom:1px solid #E0E0E0;">${data.description}</td>
          <td style="text-align:right;padding:16px;font-size:15px;font-weight:bold;border-bottom:1px solid #E0E0E0;">${_fmt(data.amount, l.currencyFmt)}</td>
        </tr>
      </tbody>
    </table>
    <!-- Totals -->
    <table style="width:100%;max-width:280px;margin-left:auto;margin-top:16px;font-size:14px">
      <tr><td style="padding:8px 0;color:#757575">${l.amount}</td><td style="text-align:right">${_fmt(data.amount, l.currencyFmt)}</td></tr>
      $taxRow
      <tr><td colspan="2"><hr style="border:none;border-top:1px solid #E0E0E0;margin:8px 0"></td></tr>
      <tr><td style="padding:12px 0;font-weight:bold;font-size:18px;color:#1A1A2E;">${isInvoice ? l.total : l.amountReceived}</td><td style="text-align:right;font-weight:bold;font-size:18px;color:#1A1A2E;">${_fmt(data.total, l.currencyFmt)}</td></tr>
    </table>
    <!-- Payment -->
    <div style="margin-top:24px;border-top:1px solid #E0E0E0;padding-top:20px;">
      <p style="margin:0;font-size:14px;color:#757575;"><strong>${l.payment}:</strong> <span style="color:#1A1A2E;">${_paymentLabel(data.paymentMethod, data.language)}</span></p>
    </div>
    $notesSection
  </div>
  <!-- Footer -->
  <div style="background:#F5F7FA;padding:20px;text-align:center;border-top:1px solid #E0E0E0">
    <p style="margin:0;color:#1E88E5;font-weight:bold;font-size:14px;">${l.thankYou}</p>
  </div>
</div>
</body>
</html>''';
  }

  // ═══════════════════════════════════════════════════════════
  // SEND EMAIL VIA SMTP
  // ═══════════════════════════════════════════════════════════

  static Future<void> sendByEmail({
    required ReceiptData data,
    required SmtpConfig smtpConfig,
    required Uint8List pdfBytes,
  }) async {
    final l = _Labels.forLocale(data.language);
    final subject = '${isInvoice(data.documentKind) ? l.invoice : l.receipt} ${data.receiptNumber} — ${data.issuedBy}';
    final htmlBody = buildEmailHtml(data);
    final recipientEmail = data.clientEmail;

    if (recipientEmail == null || recipientEmail.isEmpty) {
      throw Exception('E-mail do cliente não informado.');
    }

    final smtpServer = smtpConfig.useSSL
        ? SmtpServer(
            smtpConfig.host,
            port: smtpConfig.port,
            ssl: true,
            username: smtpConfig.username,
            password: smtpConfig.password,
          )
        : SmtpServer(
            smtpConfig.host,
            port: smtpConfig.port,
            ignoreBadCertificate: false,
            username: smtpConfig.username,
            password: smtpConfig.password,
          );

    final message = Message()
      ..from = Address(smtpConfig.username, smtpConfig.senderName)
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..html = htmlBody
      ..attachments.add(StreamAttachment(
        Stream.fromIterable([pdfBytes]),
        'application/pdf',
        fileName: '${isInvoice(data.documentKind) ? l.invoice.toLowerCase() : l.receipt.toLowerCase()}_${data.receiptNumber}.pdf',
      ));

    await send(message, smtpServer);
  }

  static bool isInvoice(String kind) => kind == 'seikyuusho';
}
