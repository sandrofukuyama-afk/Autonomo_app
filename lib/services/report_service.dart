import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';

class ReportService {
  ReportService._private();

  static final ReportService instance = ReportService._private();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> generateFiscalReport({
    required int year,
    required double entries,
    required double expenses,
    required double profit,
    required double nationalTax,
    required double residentTax,
    required double totalTax,
    int? expenseCount,
    double? deductibleExpenses,
    double? nonDeductibleExpenses,
    double? estimatedTaxImpact,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Relatório Fiscal',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Ano: $year',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 24),
              _sectionTitle('Resumo financeiro'),
              pw.SizedBox(height: 10),
              _row('Receita total', _yen(entries)),
              _row('Despesas totais', _yen(expenses)),
              _row('Lucro tributável', _yen(profit), bold: true),
              if (expenseCount != null ||
                  deductibleExpenses != null ||
                  nonDeductibleExpenses != null ||
                  estimatedTaxImpact != null) ...[
                pw.SizedBox(height: 24),
                _sectionTitle('Resumo fiscal'),
                pw.SizedBox(height: 10),
                if (expenseCount != null)
                  _row('Quantidade de despesas', expenseCount.toString()),
                if (deductibleExpenses != null)
                  _row('Despesas dedutíveis', _yen(deductibleExpenses)),
                if (nonDeductibleExpenses != null)
                  _row('Despesas não dedutíveis', _yen(nonDeductibleExpenses)),
                if (estimatedTaxImpact != null)
                  _row(
                    'Impacto fiscal estimado',
                    _yen(estimatedTaxImpact),
                    bold: true,
                  ),
              ],
              pw.SizedBox(height: 24),
              _sectionTitle('Estimativa de imposto'),
              pw.SizedBox(height: 10),
              _row('Income Tax', _yen(nationalTax)),
              _row('Resident Tax', _yen(residentTax)),
              pw.Divider(),
              _row('Total estimado', _yen(totalTax), bold: true),
              pw.Spacer(),
              pw.Text(
                'Relatório gerado automaticamente pelo Autonomo App',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<Map<String, dynamic>> exportFiscalCSV(int year) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final startDate = '$year-01-01';
    final endDate = '$year-12-31';

    final List<dynamic> rawEntries = await _client
        .from('entries_v2')
        .select()
        .eq('company_id', companyId)
        .gte('entry_date', startDate)
        .lte('entry_date', endDate)
        .order('entry_date', ascending: true);

    final List<dynamic> rawExpenses = await _client
        .from('expenses_v2')
        .select()
        .eq('company_id', companyId)
        .gte('expense_date', startDate)
        .lte('expense_date', endDate)
        .order('expense_date', ascending: true);

    final List<dynamic> rawReceipts = await _client
        .from('expense_receipts')
        .select()
        .eq('company_id', companyId)
        .order('uploaded_at', ascending: true);

    final entries = rawEntries
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final expenses = rawExpenses
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final receipts = rawReceipts
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => _receiptBelongsToYear(row, year))
        .toList();

    final entriesCsv = _toCsv(entries);
    final expensesCsv = _toCsv(expenses);
    final receiptsCsv = _toCsv(receipts);

    final basePath = '$companyId/fiscal/$year';
    final entriesPath = '$basePath/entries_$year.csv';
    final expensesPath = '$basePath/expenses_$year.csv';
    final receiptsPath = '$basePath/receipts_$year.csv';

    await _uploadCsv(entriesPath, entriesCsv);
    await _uploadCsv(expensesPath, expensesCsv);
    await _uploadCsv(receiptsPath, receiptsCsv);

    final entriesUrl = await _client.storage
        .from('fiscal_exports')
        .createSignedUrl(entriesPath, 60 * 60 * 24 * 7);
    final expensesUrl = await _client.storage
        .from('fiscal_exports')
        .createSignedUrl(expensesPath, 60 * 60 * 24 * 7);
    final receiptsUrl = await _client.storage
        .from('fiscal_exports')
        .createSignedUrl(receiptsPath, 60 * 60 * 24 * 7);

    return {
      'year': year,
      'company_id': companyId,
      'entries_path': entriesPath,
      'expenses_path': expensesPath,
      'receipts_path': receiptsPath,
      'entries_url': entriesUrl,
      'expenses_url': expensesUrl,
      'receipts_url': receiptsUrl,
      'entries_count': entries.length,
      'expenses_count': expenses.length,
      'receipts_count': receipts.length,
    };
  }

  Future<void> _uploadCsv(String path, String csv) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));

    await _client.storage.from('fiscal_exports').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'text/csv; charset=utf-8',
          ),
        );
  }

  bool _receiptBelongsToYear(Map<String, dynamic> row, int year) {
    final candidates = [
      row['document_date'],
      row['search_date'],
      row['ocr_date'],
      row['uploaded_at'],
      row['created_at'],
    ];

    for (final value in candidates) {
      final parsed = _tryParseDate(value);
      if (parsed != null && parsed.year == year) {
        return true;
      }
    }

    return false;
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _toCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return 'id\n';
    }

    final headers = <String>[];
    for (final row in rows) {
      for (final key in row.keys) {
        if (!headers.contains(key)) {
          headers.add(key);
        }
      }
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.map(_escapeCsv).join(','));

    for (final row in rows) {
      final values = headers.map((header) {
        final value = row[header];
        if (value is List || value is Map) {
          return _escapeCsv(jsonEncode(value));
        }
        return _escapeCsv(value?.toString() ?? '');
      }).join(',');
      buffer.writeln(values);
    }

    return buffer.toString();
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 17,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _row(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(
            value,
            style: bold
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : const pw.TextStyle(),
          ),
        ],
      ),
    );
  }

  String _yen(double value) {
    return '¥${value.toStringAsFixed(0)}';
  }
}
