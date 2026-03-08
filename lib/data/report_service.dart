import 'dart:html' as html;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  Future<void> generateAnnualFiscalPdf(int year) async {
    final Uri endpoint = Uri.parse('${Uri.base.origin}/api/fiscal-report');
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final response = await http.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: '{"year":$year,"reportMode":"complete","companyId":"$companyId"}',
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao gerar PDF: ${response.body}');
    }

    final Uint8List bytes = response.bodyBytes;
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'autonomo_fiscal_$year.pdf')
      ..target = '_blank'
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
