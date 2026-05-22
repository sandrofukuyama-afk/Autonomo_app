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
  static const PdfColor _accent = PdfColor.fromInt(0xFF1E88E5);
  static const PdfColor _dark = PdfColor.fromInt(0xFF1A1A2E);
  static const PdfColor _grey = PdfColor.fromInt(0xFF757575);
  static const PdfColor _light = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _white = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _divider = PdfColor.fromInt(0xFFE0E0E0);

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
    final font = await PdfGoogleFonts.notoSansRegular();

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
    final font = await PdfGoogleFonts.notoSansRegular();

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

    String divider(int n) => '─' * n;
    final n = compact ? 28 : 38;
    final numberLabel = isInvoice ? l.invoiceNumberLabel : l.receiptNumber;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text(data.issuedBy, style: style(size: tsB, bold: true))),
        if (data.companyAddress != null) pw.Center(child: pw.Text(data.companyAddress!, style: style())),
        if (data.invoiceNumber != null) pw.Center(child: pw.Text('${l.invoiceNumber}: ${data.invoiceNumber}', style: style())),
        pw.Center(child: pw.Text(divider(n), style: style())),
        pw.Text('${isInvoice ? l.invoice : l.receipt} $numberLabel: ${data.receiptNumber}', style: style(bold: true)),
        pw.Text('${l.issueDate}: ${_fmtDate(data.issueDate, data.language)}', style: style()),
        if (data.clientName != null) pw.Text('${isInvoice ? l.billTo : l.issuedTo}: ${data.clientName}', style: style()),
        if (isInvoice && data.dueDate != null) pw.Text('${l.dueDate}: ${_fmtDate(data.dueDate!, data.language)}', style: style()),
        pw.Text(divider(n), style: style()),
        pw.Text('${isInvoice ? l.description : l.proviso}: ${data.description}', style: style()),
        pw.Text(divider(n), style: style()),
        _thermalRow(l.amount, _fmt(data.amount, l.currencyFmt), style),
        if (data.taxAmount > 0) _thermalRow(l.tax, _fmt(data.taxAmount, l.currencyFmt), style),
        pw.Text(divider(n), style: style()),
        _thermalRow(isInvoice ? l.total : l.amountReceived, _fmt(data.total, l.currencyFmt), style, bold: true, size: tsB),
        pw.Text(divider(n), style: style()),
        pw.Text('${l.payment}: ${_paymentLabel(data.paymentMethod, data.language)}', style: style()),
        if (data.notes != null && data.notes!.isNotEmpty) ...[
          pw.Text(divider(n), style: style()),
          pw.Text('${l.notes}: ${data.notes}', style: style()),
        ],
        pw.Text(divider(n), style: style()),
        pw.Center(child: pw.Text(l.thankYou, style: style(bold: true))),
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
    return _buildPagedReceipt(data, PdfPageFormat.a5);
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
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => _pagedBody(data, l, fontRegular, fontBold),
    ));

    return doc.save();
  }

  static pw.Widget _pagedBody(
    ReceiptData data,
    _Labels l,
    pw.Font regular,
    pw.Font bold,
  ) {
    pw.TextStyle r({double size = 10}) => pw.TextStyle(font: regular, fontSize: size, color: _dark);
    pw.TextStyle b({double size = 10}) => pw.TextStyle(font: bold, fontSize: size, color: _dark);
    pw.TextStyle g({double size = 9}) => pw.TextStyle(font: regular, fontSize: size, color: _grey);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(color: _dark, borderRadius: pw.BorderRadius.circular(8)),
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
                  child: pw.Text(data.documentKind == 'seikyuusho' ? l.invoice : l.receipt, style: b(size: 13).copyWith(color: _white)),
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
            decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(children: [
              pw.Text('${data.documentKind == 'seikyuusho' ? l.billTo : l.issuedTo}: ', style: g()),
              pw.Text('${data.clientName!}${data.language == 'ja' ? ' 様' : ''}', style: b(size: 10)),
              if (data.clientEmail != null) ...[
                pw.Text('  ·  ', style: g()),
                pw.Text(data.clientEmail!, style: r().copyWith(color: _accent)),
              ],
              if (data.documentKind == 'seikyuusho' && data.dueDate != null) ...[
                pw.Text('  ·  ', style: g()),
                pw.Text('${l.dueDate}: ${_fmtDate(data.dueDate!, data.language)}', style: b(size: 9)),
              ],
            ]),
          ),

        pw.SizedBox(height: 16),

        // ── Description table ──────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _divider),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(children: [
            // header row
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _light,
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(data.documentKind == 'seikyuusho' ? l.description : l.proviso, style: b(size: 9)),
                pw.Text(l.amount, style: b(size: 9)),
              ]),
            ),
            pw.Divider(color: _divider, height: 1),
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
              pw.Divider(color: _divider),
              _pagedTotalRow(
                data.documentKind == 'seikyuusho' ? l.total : l.amountReceived,
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
            decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(l.notes, style: g()),
              pw.SizedBox(height: 4),
              pw.Text(data.notes!, style: r()),
            ]),
          ),
        ],

        pw.Spacer(),

        // ── Footer ────────────────────────────────────────────
        pw.Divider(color: _divider),
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
        ? '<tr><td style="padding:4px 0;color:#757575">${l.tax}</td><td style="text-align:right;color:#757575">${_fmt(data.taxAmount, l.currencyFmt)}</td></tr>'
        : '';
    final clientRow = data.clientName != null
        ? '<p style="margin:0 0 4px"><strong>${isInvoice ? l.billTo : l.issuedTo}:</strong> ${data.clientName}${data.clientEmail != null ? ' &lt;${data.clientEmail}&gt;' : ''}</p>'
        : '';
    final notesSection = (data.notes != null && data.notes!.isNotEmpty)
        ? '<div style="background:#f5f5f5;border-radius:6px;padding:10px 14px;margin-top:16px"><p style="margin:0 0 4px;color:#757575;font-size:12px">${l.notes}</p><p style="margin:0">${data.notes}</p></div>'
        : '';
    final invoiceRow = data.invoiceNumber != null
        ? '<p style="margin:0;font-size:11px;color:#90CAF9">${l.invoiceNumber}: ${data.invoiceNumber}</p>'
        : '';

    return '''<!DOCTYPE html>
<html lang="${data.language}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${isInvoice ? l.invoice : l.receipt} ${data.receiptNumber}</title>
</head>
<body style="margin:0;padding:0;background:#f0f0f0;font-family:Arial,sans-serif;color:#1A1A2E">
<div style="max-width:560px;margin:32px auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,.12)">
  <!-- Header -->
  <div style="background:#1A1A2E;padding:24px 28px;display:flex;justify-content:space-between;align-items:flex-start">
    <div>
      <h2 style="margin:0 0 4px;color:#fff;font-size:18px">${data.issuedBy}</h2>
      ${data.companyAddress != null ? '<p style="margin:0 0 2px;color:#BDBDBD;font-size:12px">${data.companyAddress}</p>' : ''}
      ${data.companyPhone != null ? '<p style="margin:0 0 2px;color:#BDBDBD;font-size:12px">${data.companyPhone}</p>' : ''}
      $invoiceRow
    </div>
    <div style="text-align:right">
      <span style="background:#1E88E5;color:#fff;padding:4px 12px;border-radius:6px;font-size:14px;font-weight:bold">${isInvoice ? l.invoice : l.receipt}</span>
      <p style="margin:6px 0 2px;color:#E0E0E0;font-size:13px">${data.receiptNumber}</p>
      <p style="margin:0;color:#BDBDBD;font-size:11px">${_fmtDate(data.issueDate, data.language)}</p>
    </div>
  </div>
  <!-- Body -->
  <div style="padding:24px 28px">
    $clientRow
    <!-- Description table -->
    <table style="width:100%;border-collapse:collapse;margin-top:16px;border:1px solid #E0E0E0;border-radius:6px">
      <thead>
        <tr style="background:#f5f5f5">
          <th style="text-align:left;padding:8px 12px;font-size:12px;font-weight:bold">${l.description}</th>
          <th style="text-align:right;padding:8px 12px;font-size:12px;font-weight:bold">${l.amount}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td style="padding:10px 12px">${data.description}</td>
          <td style="text-align:right;padding:10px 12px">${_fmt(data.amount, l.currencyFmt)}</td>
        </tr>
      </tbody>
    </table>
    <!-- Totals -->
    <table style="width:220px;margin-left:auto;margin-top:12px;font-size:13px">
      <tr><td style="padding:4px 0;color:#757575">${l.amount}</td><td style="text-align:right">${_fmt(data.amount, l.currencyFmt)}</td></tr>
      $taxRow
      <tr><td colspan="2"><hr style="border:none;border-top:1px solid #E0E0E0;margin:6px 0"></td></tr>
      <tr><td style="font-weight:bold;font-size:15px">${l.total}</td><td style="text-align:right;font-weight:bold;font-size:15px">${_fmt(data.total, l.currencyFmt)}</td></tr>
    </table>
    <!-- Payment -->
    <p style="margin-top:16px;font-size:13px"><strong>${l.payment}:</strong> ${_paymentLabel(data.paymentMethod, data.language)}</p>
    $notesSection
  </div>
  <!-- Footer -->
  <div style="background:#f5f5f5;padding:12px 28px;text-align:center;border-top:1px solid #E0E0E0">
    <p style="margin:0;color:#1E88E5;font-weight:bold">${l.thankYou}</p>
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
    final subject = '${l.receipt} ${data.receiptNumber} — ${data.issuedBy}';
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
        fileName: '${l.receipt.toLowerCase()}_${data.receiptNumber}.pdf',
      ));

    await send(message, smtpServer);
  }
}
