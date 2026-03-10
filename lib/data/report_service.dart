import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'supabase_service.dart';

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  Future<void> generateAnnualFiscalPdf(int year) async {
    final Uri endpoint = Uri.parse('${Uri.base.origin}/api/fiscal-report');
    final String companyId = await AuthService.instance.getCurrentCompanyId();
    final Map<String, dynamic> settings =
        await SupabaseService.instance.getAppSettings();

    final String filingType =
        (settings['filing_type'] ?? 'white_return').toString();
    final bool blueReturn = filingType == 'blue_return';

    final response = await http.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'year': year,
        'reportMode': 'complete',
        'companyId': companyId,
        'filingType': filingType,
        'blueReturn': blueReturn,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao gerar PDF: ${response.body}');
    }

    final Uint8List bytes = response.bodyBytes;
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', 'autonomo_fiscal_$year.pdf')
      ..target = '_blank'
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
