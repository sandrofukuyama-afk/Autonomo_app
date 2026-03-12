import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  ReportService._private();

  static final ReportService instance = ReportService._private();

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
