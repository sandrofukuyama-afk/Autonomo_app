import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final settings = await _loadAppSettings(companyId);
    final monthlySummary = await _loadMonthlySummary(companyId, year);

    final pdfBytes = await _buildFiscalPdfBytes(
      year: year,
      entries: entries,
      expenses: expenses,
      profit: profit,
      nationalTax: nationalTax,
      residentTax: residentTax,
      totalTax: totalTax,
      expenseCount: expenseCount,
      deductibleExpenses: deductibleExpenses,
      nonDeductibleExpenses: nonDeductibleExpenses,
      estimatedTaxImpact: estimatedTaxImpact,
      settings: settings,
      monthlySummary: monthlySummary,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
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

  Future<Map<String, dynamic>> exportFiscalPackage(int year) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final settings = await _loadAppSettings(companyId);
    final monthlySummary = await _loadMonthlySummary(companyId, year);
    final csvResult = await exportFiscalCSV(year);

    final startDate = '$year-01-01';
    final endDate = '$year-12-31';

    final List<dynamic> rawEntries = await _client
        .from('entries_v2')
        .select('amount')
        .eq('company_id', companyId)
        .gte('entry_date', startDate)
        .lte('entry_date', endDate);

    final List<dynamic> rawExpenses = await _client
        .from('expenses_v2')
        .select(
          'amount, deductible_amount, non_deductible_amount, deductibility_status',
        )
        .eq('company_id', companyId)
        .gte('expense_date', startDate)
        .lte('expense_date', endDate);

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

    final totalEntries = entries.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['amount']),
    );

    final totalExpenses = expenses.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['amount']),
    );

    final deductibleExpenses = expenses.fold<double>(0, (sum, row) {
      final explicitDeductible = _toDouble(row['deductible_amount']);
      if (explicitDeductible > 0) {
        return sum + explicitDeductible;
      }

      final explicitNonDeductible = _toDouble(row['non_deductible_amount']);
      final amount = _toDouble(row['amount']);
      final status = (row['deductibility_status'] ?? '').toString();

      if (explicitNonDeductible > 0) {
        return sum + (amount - explicitNonDeductible);
      }

      if (status == 'non_deductible') {
        return sum;
      }

      return sum + amount;
    });

    final double nonDeductibleExpenses =
        (totalExpenses - deductibleExpenses).clamp(0.0, double.infinity).toDouble();

    final profit = totalEntries - totalExpenses;

    final nationalTax = _estimateNationalTax(profit);
    final residentTax = _estimateResidentTax(profit);
    final totalTax = nationalTax + residentTax;
    final estimatedTaxImpact = _estimateTaxImpact(deductibleExpenses);

    final pdfBytes = await _buildFiscalPdfBytes(
      year: year,
      entries: totalEntries,
      expenses: totalExpenses,
      profit: profit,
      nationalTax: nationalTax,
      residentTax: residentTax,
      totalTax: totalTax,
      expenseCount: expenses.length,
      deductibleExpenses: deductibleExpenses,
      nonDeductibleExpenses: nonDeductibleExpenses,
      estimatedTaxImpact: estimatedTaxImpact,
      settings: settings,
      monthlySummary: monthlySummary,
    );

    final entriesCsvBytes = await _downloadStorageFile(
      csvResult['entries_path'].toString(),
    );
    final expensesCsvBytes = await _downloadStorageFile(
      csvResult['expenses_path'].toString(),
    );
    final receiptsCsvBytes = await _downloadStorageFile(
      csvResult['receipts_path'].toString(),
    );

    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'fiscal_report_$year.pdf',
          pdfBytes.length,
          pdfBytes,
        ),
      )
      ..addFile(
        ArchiveFile(
          'entries_$year.csv',
          entriesCsvBytes.length,
          entriesCsvBytes,
        ),
      )
      ..addFile(
        ArchiveFile(
          'expenses_$year.csv',
          expensesCsvBytes.length,
          expensesCsvBytes,
        ),
      )
      ..addFile(
        ArchiveFile(
          'receipts_$year.csv',
          receiptsCsvBytes.length,
          receiptsCsvBytes,
        ),
      );

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    final zipPath = '$companyId/fiscal/$year/Fiscal_$year.zip';

    await _client.storage.from('fiscal_exports').uploadBinary(
          zipPath,
          zipBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/zip',
          ),
        );

    final zipUrl = await _client.storage
        .from('fiscal_exports')
        .createSignedUrl(zipPath, 60 * 60 * 24 * 7);

    return {
      'year': year,
      'company_id': companyId,
      'zip_path': zipPath,
      'zip_url': zipUrl,
      'pdf_file_name': 'fiscal_report_$year.pdf',
      'entries_file_name': 'entries_$year.csv',
      'expenses_file_name': 'expenses_$year.csv',
      'receipts_file_name': 'receipts_$year.csv',
      'entries_count': entries.length,
      'expenses_count': expenses.length,
      'receipts_count': receipts.length,
      'entries_total': totalEntries,
      'expenses_total': totalExpenses,
      'profit': profit,
      'national_tax': nationalTax,
      'resident_tax': residentTax,
      'total_tax': totalTax,
    };
  }

  Future<Uint8List> _buildFiscalPdfBytes({
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
    Map<String, dynamic>? settings,
    List<Map<String, dynamic>> monthlySummary = const [],
  }) async {
    final pdf = pw.Document();

    final fullName = (settings?['full_name'] ?? '').toString().trim();
    final displayName = (settings?['display_name'] ?? '').toString().trim();
    final filingType = (settings?['filing_type'] ?? '').toString().trim();
    final bookkeepingMethod =
        (settings?['bookkeeping_method'] ?? '').toString().trim();
    final invoiceRegistered = settings?['invoice_registered'] == true;
    final invoiceRegistrationNo =
        (settings?['invoice_registration_no'] ?? '').toString().trim();

    final filingTypeLabel = switch (filingType) {
      'blue_return' => 'Blue Return',
      'white_return' => 'White Return',
      _ => filingType.isEmpty ? '' : filingType,
    };

    final bookkeepingLabel = switch (bookkeepingMethod) {
      'simple' => 'Simple',
      'double_entry' => 'Double Entry',
      _ => bookkeepingMethod.isEmpty ? '' : bookkeepingMethod,
    };

    final invoiceStatusLabel =
        invoiceRegistered ? 'Registrado' : 'Não registrado';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Relatório gerado automaticamente pelo Autonomo App',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          );
        },
        build: (context) {
          return [
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
            if (fullName.isNotEmpty ||
                displayName.isNotEmpty ||
                filingTypeLabel.isNotEmpty ||
                bookkeepingLabel.isNotEmpty ||
                invoiceRegistrationNo.isNotEmpty ||
                true) ...[
              pw.SizedBox(height: 20),
              _sectionTitle('Dados fiscais'),
              pw.SizedBox(height: 10),
              if (fullName.isNotEmpty) _row('Contribuinte', fullName),
              if (displayName.isNotEmpty) _row('Nome comercial', displayName),
              if (filingTypeLabel.isNotEmpty)
                _row('Tipo de declaração', filingTypeLabel),
              if (bookkeepingLabel.isNotEmpty)
                _row('Método contábil', bookkeepingLabel),
              _row('Invoice', invoiceStatusLabel),
              if (invoiceRegistered && invoiceRegistrationNo.isNotEmpty)
                _row('Número do invoice', invoiceRegistrationNo),
            ],
            pw.SizedBox(height: 24),
            _sectionTitle('Resumo financeiro'),
            pw.SizedBox(height: 10),
            _row('Receita total', _yen(entries)),
            _row('Despesas totais', _yen(expenses)),
            _row('Lucro tributável', _yen(profit), bold: true),
            if (monthlySummary.isNotEmpty) ...[
              pw.SizedBox(height: 24),
              _sectionTitle('Tabela mensal automática'),
              pw.SizedBox(height: 10),
              _monthlyTable(monthlySummary),
            ],
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
          ];
        },
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  Future<Map<String, dynamic>?> _loadAppSettings(String companyId) async {
    final data = await _client
        .from('app_settings')
        .select()
        .eq('company_id', companyId)
        .maybeSingle();

    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> _loadMonthlySummary(
    String companyId,
    int year,
  ) async {
    final startDate = '$year-01-01';
    final endDate = '$year-12-31';

    final List<dynamic> rawEntries = await _client
        .from('entries_v2')
        .select('entry_date, amount')
        .eq('company_id', companyId)
        .gte('entry_date', startDate)
        .lte('entry_date', endDate);

    final List<dynamic> rawExpenses = await _client
        .from('expenses_v2')
        .select('expense_date, amount')
        .eq('company_id', companyId)
        .gte('expense_date', startDate)
        .lte('expense_date', endDate);

    final entriesByMonth = <int, double>{};
    final expensesByMonth = <int, double>{};

    for (final raw in rawEntries.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final date = _tryParseDate(row['entry_date']);
      if (date == null) continue;

      entriesByMonth[date.month] =
          (entriesByMonth[date.month] ?? 0) + _toDouble(row['amount']);
    }

    for (final raw in rawExpenses.whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final date = _tryParseDate(row['expense_date']);
      if (date == null) continue;

      expensesByMonth[date.month] =
          (expensesByMonth[date.month] ?? 0) + _toDouble(row['amount']);
    }

    return List<Map<String, dynamic>>.generate(12, (index) {
      final month = index + 1;
      final monthEntries = entriesByMonth[month] ?? 0;
      final monthExpenses = expensesByMonth[month] ?? 0;
      final monthProfit = monthEntries - monthExpenses;

      return {
        'month': month,
        'label': _monthLabel(month),
        'entries': monthEntries,
        'expenses': monthExpenses,
        'profit': monthProfit,
      };
    });
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

  Future<Uint8List> _downloadStorageFile(String path) async {
    return _client.storage.from('fiscal_exports').download(path);
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

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double _estimateNationalTax(double profit) {
    if (profit <= 0) return 0;

    if (profit <= 1950000) return profit * 0.05;
    if (profit <= 3300000) return (profit * 0.10) - 97500;
    if (profit <= 6950000) return (profit * 0.20) - 427500;
    if (profit <= 9000000) return (profit * 0.23) - 636000;
    if (profit <= 18000000) return (profit * 0.33) - 1536000;
    if (profit <= 40000000) return (profit * 0.40) - 2796000;
    return (profit * 0.45) - 4796000;
  }

  double _estimateResidentTax(double profit) {
    if (profit <= 0) return 0;
    return profit * 0.10;
  }

  double _estimateTaxImpact(double deductibleExpenses) {
    if (deductibleExpenses <= 0) return 0;
    return deductibleExpenses * 0.15;
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

  pw.Widget _monthlyTable(List<Map<String, dynamic>> monthlySummary) {
    final tableHeaders = ['Mês', 'Receitas', 'Despesas', 'Lucro'];

    final tableData = monthlySummary.map((row) {
      return [
        (row['label'] ?? '').toString(),
        _yen(_toDouble(row['entries'])),
        _yen(_toDouble(row['expenses'])),
        _yen(_toDouble(row['profit'])),
      ];
    }).toList();

    final totalEntries = monthlySummary.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['entries']),
    );
    final totalExpenses = monthlySummary.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['expenses']),
    );
    final totalProfit = monthlySummary.fold<double>(
      0,
      (sum, row) => sum + _toDouble(row['profit']),
    );

    tableData.add([
      'Total',
      _yen(totalEntries),
      _yen(totalExpenses),
      _yen(totalProfit),
    ]);

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableData,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      ),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(1.6),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FlexColumnWidth(1.6),
      },
    );
  }

  String _monthLabel(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Fev';
      case 3:
        return 'Mar';
      case 4:
        return 'Abr';
      case 5:
        return 'Mai';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Ago';
      case 9:
        return 'Set';
      case 10:
        return 'Out';
      case 11:
        return 'Nov';
      case 12:
        return 'Dez';
      default:
        return month.toString();
    }
  }

  String _yen(double value) {
    return '¥${value.toStringAsFixed(0)}';
  }
}
