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

  Future<void> addEntry(Map<String, dynamic> data) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

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
    await _client.from('entries_v2').update({
      'entry_date': data['entry_date'],
      'description': data['description'],
      'amount': data['amount'],
      'payment_method': _normalizePaymentMethod(data['payment_method']),
    }).eq('id', id);
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('entries_v2').delete().eq('id', id);
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final receiptUrl = data['receipt_url'];

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
    await _client.from('expenses_v2').update({
      'expense_date': data['date'],
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

    await _client.from('expenses_v2').update({
      'receipt_status': 'uploaded',
    }).eq('id', expenseId);

    await _insertExpenseReceipt(
      expenseId: expenseId,
      companyId: companyId,
      data: data,
    );
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expense_receipts').delete().eq('expense_id', id);
    await _client.from('expenses_v2').delete().eq('id', id);
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
      case 'payment_cash':
      case 'Dinheiro':
      case 'cash':
        return 'cash';
      case 'payment_bank_transfer':
      case 'Transferência bancária':
      case 'bank_transfer':
      case 'furikomi':
        return 'furikomi';
      case 'payment_credit_card':
      case 'Cartão de crédito':
      case 'card':
      case 'credit_card':
        return 'credit_card';
      case 'payment_paypay':
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
