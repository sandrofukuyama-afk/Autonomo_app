import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class SupabaseService {
  SupabaseService._private();

  static final SupabaseService instance = SupabaseService._private();

  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> getAppSettings() async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final Map<String, dynamic>? row = await _client
        .from('app_settings')
        .select()
        .eq('company_id', companyId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Configurações da empresa não encontradas.');
    }

    return row;
  }

  Future<List<String>> getClosedFiscalMonths() async {
    final settings = await getAppSettings();
    final raw = settings['closed_fiscal_months'];

    if (raw == null) return [];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  Future<void> closeFiscalMonth(String fiscalMonth) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final currentMonths = await getClosedFiscalMonths();

    final normalizedMonth = fiscalMonth.trim();
    if (normalizedMonth.isEmpty) {
      throw Exception('Mês fiscal inválido.');
    }

    if (!currentMonths.contains(normalizedMonth)) {
      currentMonths.add(normalizedMonth);
      currentMonths.sort();
    }

    await _client
        .from('app_settings')
        .update({
          'closed_fiscal_months': currentMonths,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('company_id', companyId);
  }

  Future<void> reopenFiscalMonth(String fiscalMonth) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final currentMonths = await getClosedFiscalMonths();

    final normalizedMonth = fiscalMonth.trim();
    if (normalizedMonth.isEmpty) {
      throw Exception('Mês fiscal inválido.');
    }

    currentMonths.removeWhere((month) => month == normalizedMonth);

    await _client
        .from('app_settings')
        .update({
          'closed_fiscal_months': currentMonths,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('company_id', companyId);
  }

  String _extractFiscalMonth(dynamic value) {
    if (value == null) {
      throw Exception('Data fiscal inválida.');
    }

    if (value is DateTime) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      throw Exception('Data fiscal inválida.');
    }

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    if (text.length >= 7 && text[4] == '-') {
      return text.substring(0, 7);
    }

    throw Exception('Não foi possível identificar o mês fiscal.');
  }

  Future<void> _assertFiscalMonthOpen({
    required dynamic dateValue,
    required String errorMessage,
  }) async {
    final fiscalMonth = _extractFiscalMonth(dateValue);
    final closedMonths = await getClosedFiscalMonths();

    if (closedMonths.contains(fiscalMonth)) {
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>?> _getOwnedEntryRow(String id) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final Map<String, dynamic>? row = await _client
        .from('entries_v2')
        .select('id, company_id, entry_date')
        .eq('id', id)
        .eq('company_id', companyId)
        .maybeSingle();

    return row;
  }

  Future<Map<String, dynamic>?> _getOwnedExpenseRow(String id) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final Map<String, dynamic>? row = await _client
        .from('expenses_v2')
        .select('id, company_id, expense_date')
        .eq('id', id)
        .eq('company_id', companyId)
        .maybeSingle();

    return row;
  }

  Future<void> addEntry(Map<String, dynamic> data) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    await _assertFiscalMonthOpen(
      dateValue: data['date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível adicionar entradas.',
    );

    await _client.from('entries_v2').insert({
      'company_id': companyId,
      'entry_date': data['date'],
      'description': data['description'],
      'category': data['category'] ?? 'service',
      'amount': data['amount'],
      'payment_method': _normalizePaymentMethod(data['payment_method']),
      'tax_rate': data['tax_rate'],
      'tax_inclusion_type': data['tax_inclusion_type'] ?? 'unknown',
      'tax_amount': data['tax_amount'],
      'qualified_invoice_issued': data['qualified_invoice_issued'] ?? false,
      'qualified_invoice_number': data['qualified_invoice_number'],
      'customer_name': data['customer_name'],
      'revenue_type': data['revenue_type'] ?? 'service',
      'fiscal_revenue_category': data['fiscal_revenue_category'],
      'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<dynamic>> getEntries() async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final List<dynamic> response = await _client
        .from('entries_v2')
        .select()
        .eq('company_id', companyId)
        .order('entry_date', ascending: false);

    return response
        .map((item) => {
              ...item,
              'date': item['entry_date'],
            })
        .toList();
  }

  Future<void> updateEntry(String id, Map<String, dynamic> data) async {
    final existingRow = await _getOwnedEntryRow(id);

    if (existingRow == null) {
      throw Exception('Entrada não encontrada.');
    }

    final nextDateValue = data['entry_date'] ?? data['date'];

    await _assertFiscalMonthOpen(
      dateValue: existingRow['entry_date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível editar entradas.',
    );

    await _assertFiscalMonthOpen(
      dateValue: nextDateValue,
      errorMessage:
          'O mês fiscal de destino está fechado. Não é possível salvar a entrada.',
    );

    await _client.from('entries_v2').update({
      'entry_date': nextDateValue,
      'description': data['description'],
      'amount': data['amount'],
      'payment_method': _normalizePaymentMethod(data['payment_method']),
    }).eq('id', id);
  }

  Future<void> deleteEntry(String id) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final row = await _client
        .from('entries_v2')
        .select('id, company_id, entry_date')
        .eq('id', id)
        .eq('company_id', companyId)
        .maybeSingle();

    if (row == null) return;

    await _assertFiscalMonthOpen(
      dateValue: row['entry_date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível excluir entradas.',
    );

    await _client
        .from('entries_v2')
        .delete()
        .eq('id', id)
        .eq('company_id', companyId);
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final receiptUrl = data['receipt_url'];

    await _assertFiscalMonthOpen(
      dateValue: data['date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível adicionar despesas.',
    );

    final inserted = await _client
        .from('expenses_v2')
        .insert({
          'company_id': companyId,
          'expense_date': data['date'],
          'store_name': data['store_name'],
          'description': data['description'],
          'category': _normalizeExpenseCategory(data['category']),
          'amount': data['amount'],
          'tax_amount': data['tax'],
          'tax_type': data['tax_type'],
          'payment_method': _normalizePaymentMethod(data['payment_method']),
          'notes': data['notes'],
          'receipt_status': receiptUrl != null ? 'uploaded' : 'none',
          'deductibility_status':
              data['deductibility_status'] ?? 'review_required',
          'is_mixed_use': data['is_mixed_use'] ?? false,
          'business_use_percent': data['business_use_percent'] ?? 100,
          'private_use_percent': data['private_use_percent'] ?? 0,
          'allocation_basis': data['allocation_basis'],
          'allocation_note': data['allocation_note'],
          'deductible_amount': data['deductible_amount'],
          'non_deductible_amount': data['non_deductible_amount'],
          'tax_rate': data['tax_rate'],
          'tax_inclusion_type': data['tax_inclusion_type'] ?? 'unknown',
          'qualified_invoice_flag': data['qualified_invoice_flag'] ?? false,
          'qualified_invoice_number': data['qualified_invoice_number'],
          'vendor_name': data['vendor_name'],
          'vendor_tax_id_note': data['vendor_tax_id_note'],
          'fiscal_category': data['fiscal_category'],
          'review_status': data['review_status'] ?? 'pending',
          'review_note': data['review_note'],
          'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    if (receiptUrl != null && receiptUrl.toString().trim().isNotEmpty) {
      await _insertExpenseReceipt(
        expenseId: inserted['id'].toString(),
        companyId: companyId,
        data: data,
      );
    }
  }

  Future<List<dynamic>> getExpenses() async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final List<dynamic> expenses = await _client
        .from('expenses_v2')
        .select()
        .eq('company_id', companyId)
        .order('expense_date', ascending: false);

    final List<dynamic> receipts = await _client
        .from('expense_receipts')
        .select('expense_id, public_url, uploaded_at')
        .eq('company_id', companyId)
        .order('uploaded_at', ascending: false);

    final Map<String, String> receiptMap = {};

    for (final row in receipts) {
      final expenseId = row['expense_id'].toString();
      if (!receiptMap.containsKey(expenseId)) {
        receiptMap[expenseId] = (row['public_url'] ?? '').toString();
      }
    }

    return expenses
        .map((item) => {
              ...item,
              'date': item['expense_date'],
              'receipt_url': receiptMap[item['id'].toString()],
            })
        .toList();
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    final existingRow = await _getOwnedExpenseRow(id);

    if (existingRow == null) {
      throw Exception('Despesa não encontrada.');
    }

    final nextDateValue = data['expense_date'] ?? data['date'];

    await _assertFiscalMonthOpen(
      dateValue: existingRow['expense_date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível editar despesas.',
    );

    await _assertFiscalMonthOpen(
      dateValue: nextDateValue,
      errorMessage:
          'O mês fiscal de destino está fechado. Não é possível salvar a despesa.',
    );

    await _client.from('expenses_v2').update({
      'expense_date': data['date'] ?? data['expense_date'],
      'store_name': data['store_name'],
      'description': data['description'],
      'category': _normalizeExpenseCategory(data['category']),
      'amount': data['amount'],
      'tax_amount': data['tax'],
      'tax_type': data['tax_type'],
      'payment_method': _normalizePaymentMethod(data['payment_method']),
      'notes': data['notes'],
      'tax_rate': data['tax_rate'],
      'tax_inclusion_type': data['tax_inclusion_type'],
      'vendor_name': data['vendor_name'],
    }).eq('id', id);
  }

  Future<void> attachReceiptToExpense(
    String expenseId,
    Map<String, dynamic> data,
  ) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final receiptUrl = data['receipt_url'];

    if (receiptUrl == null || receiptUrl.toString().trim().isEmpty) return;

    final existingRow = await _getOwnedExpenseRow(expenseId);

    if (existingRow == null) {
      throw Exception('Despesa não encontrada.');
    }

    await _assertFiscalMonthOpen(
      dateValue: existingRow['expense_date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível editar despesas.',
    );

    await _client
        .from('expenses_v2')
        .update({
          'receipt_status': 'uploaded',
        })
        .eq('id', expenseId)
        .eq('company_id', companyId);

    await _insertExpenseReceipt(
      expenseId: expenseId,
      companyId: companyId,
      data: data,
    );
  }

  Future<void> deleteExpense(String id) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final row = await _client
        .from('expenses_v2')
        .select('id, company_id, expense_date')
        .eq('id', id)
        .eq('company_id', companyId)
        .maybeSingle();

    if (row == null) return;

    await _assertFiscalMonthOpen(
      dateValue: row['expense_date'],
      errorMessage:
          'Este mês fiscal está fechado. Não é possível excluir despesas.',
    );

    await _client
        .from('expense_receipts')
        .delete()
        .eq('expense_id', id)
        .eq('company_id', companyId);

    await _client
        .from('expenses_v2')
        .delete()
        .eq('id', id)
        .eq('company_id', companyId);
  }

  Future<void> _insertExpenseReceipt({
    required String expenseId,
    required String companyId,
    required Map<String, dynamic> data,
  }) async {
    await _client.from('expense_receipts').insert({
      'expense_id': expenseId,
      'company_id': companyId,
      'storage_path': data['storage_path'] ?? data['receipt_url'],
      'public_url': data['receipt_url'],
      'file_name': data['file_name'],
      'original_file_name': data['original_file_name'] ?? data['file_name'],
      'mime_type': data['mime_type'],
      'file_size_bytes': data['file_size_bytes'],
      'ocr_status': data['ocr_status'] ?? 'pending',
      'ocr_engine': data['ocr_engine'] ?? 'google_vision',
      'ocr_raw_text': data['ocr_raw_text'],
      'ocr_store_name': data['ocr_store_name'] ?? data['store_name'],
      'ocr_amount': data['ocr_amount'] ?? data['amount'],
      'ocr_date': data['ocr_date'] ?? data['date'],
      'ocr_tax_amount': data['ocr_tax_amount'] ?? data['tax'],
      'ocr_tax_type': data['ocr_tax_type'] ?? data['tax_type'],
      'ocr_category_suggestion':
          data['ocr_category_suggestion'] ?? data['category'],
      'document_type': data['document_type'] ?? 'receipt',
      'document_date': data['document_date'] ?? data['date'],
      'document_amount': data['document_amount'] ?? data['amount'],
      'document_store_name':
          data['document_store_name'] ?? data['store_name'],
      'search_vendor_name': data['search_vendor_name'] ?? data['store_name'],
      'search_amount': data['search_amount'] ?? data['amount'],
      'search_date': data['search_date'] ?? data['date'],
      'is_electronic_transaction':
          data['is_electronic_transaction'] ?? false,
      'retention_lock_flag': data['retention_lock_flag'] ?? false,
      'review_status': data['receipt_review_status'] ?? 'pending',
      'uploaded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> uploadReceipt(
    Uint8List fileBytes,
    String fileName, {
    String? contentType,
  }) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final storagePath =
        '$companyId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('receipts').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType ?? _guessContentType(fileName),
          ),
        );

    return _client.storage.from('receipts').getPublicUrl(storagePath);
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  String _normalizePaymentMethod(dynamic value) {
    switch (value) {
      case 'cash':
        return 'cash';
      case 'credit_card':
        return 'credit_card';
      case 'furikomi':
        return 'furikomi';
      case 'paypay':
        return 'paypay';
      default:
        return 'other';
    }
  }

  String _normalizeExpenseCategory(dynamic value) {
    switch (value) {
      case 'category_food':
        return 'food';
      case 'category_transport':
        return 'transport';
      case 'category_housing':
        return 'rent';
      case 'category_entertainment':
        return 'services';
      case 'category_health':
        return 'fees';
      default:
        return 'other';
    }
  }
}
