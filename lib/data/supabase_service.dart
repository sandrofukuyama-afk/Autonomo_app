import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class SupabaseService {
  SupabaseService._private();

  static final SupabaseService instance = SupabaseService._private();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> addEntry(Map<String, dynamic> data) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    await _client.from('entries_v2').insert({
      'company_id': companyId,
      'entry_date': data['date'],
      'description': data['description'],
      'category': data['category'] ?? 'service',
      'amount': data['amount'],
      'payment_method': _normalizePaymentMethod(data['payment_method']),
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
          'receipt_status': receiptUrl != null ? 'uploaded' : 'none',
          'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    if (receiptUrl != null && receiptUrl.toString().trim().isNotEmpty) {
      await _client.from('expense_receipts').insert({
        'expense_id': inserted['id'],
        'company_id': companyId,
        'storage_path': receiptUrl,
        'public_url': receiptUrl,
        'file_name': data['file_name'],
        'ocr_status': 'processed',
        'ocr_store_name': data['store_name'],
        'ocr_amount': data['amount'],
        'ocr_date': data['date'],
        'ocr_tax_amount': data['tax'],
        'ocr_tax_type': data['tax_type'],
        'ocr_category_suggestion': data['category'],
        'uploaded_at': DateTime.now().toIso8601String(),
      });
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
        .select('expense_id, public_url')
        .eq('company_id', companyId);

    final Map<String, String> receiptMap = {};

    for (final row in receipts) {
      receiptMap[row['expense_id'].toString()] =
          (row['public_url'] ?? '').toString();
    }

    return expenses
        .map((item) => {
              ...item,
              'date': item['expense_date'],
              'receipt_url': receiptMap[item['id'].toString()],
            })
        .toList();
  }

  Future<String> uploadReceipt(Uint8List fileBytes, String fileName) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final storagePath =
        '$companyId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('receipts').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return _client.storage.from('receipts').getPublicUrl(storagePath);
  }

  String _normalizePaymentMethod(dynamic value) {
    switch (value) {
      case 'payment_cash':
      case 'Dinheiro':
        return 'cash';
      case 'payment_bank_transfer':
      case 'Transferência bancária':
        return 'bank_transfer';
      case 'payment_credit_card':
      case 'Cartão de crédito':
        return 'card';
      case 'payment_paypay':
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
