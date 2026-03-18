import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

class SupabaseService {
  SupabaseService._private();

  static final SupabaseService instance = SupabaseService._private();

  final SupabaseClient _client = Supabase.instance.client;

  static const List<String> _defaultEntryCategories = [
    'service',
    'sale',
    'commission',
    'refund',
    'other',
  ];

  static const List<String> _defaultExpenseCategories = [
    'food',
    'transport',
    'rent',
    'services',
    'fees',
    'other',
  ];

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

  Future<List<Map<String, dynamic>>> getEntryCategoryDefinitions() async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final definitions = <Map<String, dynamic>>[];

    for (final code in _defaultEntryCategories) {
      definitions.add({
        'code': code,
        'is_default': true,
        'label_pt': null,
        'label_en': null,
        'label_ja': null,
        'label_es': null,
      });
    }

    final seenCodes = <String>{..._defaultEntryCategories};

    final settings = await getAppSettings();
    final legacyRaw = settings['entry_categories'];

    if (legacyRaw is List) {
      for (final item in legacyRaw) {
        final normalized = _normalizeEntryCategory(item);
        if (normalized.isEmpty || seenCodes.contains(normalized)) continue;
        seenCodes.add(normalized);
        definitions.add({
          'code': normalized,
          'is_default': false,
          'label_pt': item?.toString().trim(),
          'label_en': item?.toString().trim(),
          'label_ja': item?.toString().trim(),
          'label_es': item?.toString().trim(),
        });
      }
    }

    final List<dynamic> rows = await _client
        .from('entry_categories')
        .select('code, label_pt, label_en, label_ja, label_es, created_at')
        .eq('company_id', companyId)
        .order('created_at', ascending: true);

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final code = _normalizeEntryCategory(row['code']);
      if (code.isEmpty || seenCodes.contains(code)) continue;

      seenCodes.add(code);
      definitions.add({
        'code': code,
        'is_default': false,
        'label_pt': _normalizeNullableText(row['label_pt']),
        'label_en': _normalizeNullableText(row['label_en']),
        'label_ja': _normalizeNullableText(row['label_ja']),
        'label_es': _normalizeNullableText(row['label_es']),
      });
    }

    return definitions;
  }

  Future<List<String>> getEntryCategories() async {
    final definitions = await getEntryCategoryDefinitions();
    return definitions
        .map((item) => (item['code'] ?? '').toString().trim())
        .where((code) => code.isNotEmpty)
        .toList();
  }

  Future<Map<String, String>> getEntryCategoryLabelsByCode() async {
    final definitions = await getEntryCategoryDefinitions();
    final labels = <String, String>{};

    for (final item in definitions) {
      final code = (item['code'] ?? '').toString().trim();
      if (code.isEmpty) continue;

      final customLabel = _firstNonEmpty([
        item['label_pt'],
        item['label_en'],
        item['label_ja'],
        item['label_es'],
      ]);

      labels[code] = customLabel ?? code;
    }

    return labels;
  }

  Future<Map<String, dynamic>?> getEntryCategoryDefinitionByCode(
    String code,
  ) async {
    final normalizedCode = _normalizeEntryCategory(code);
    if (normalizedCode.isEmpty) return null;

    final definitions = await getEntryCategoryDefinitions();
    for (final item in definitions) {
      if ((item['code'] ?? '').toString().trim() == normalizedCode) {
        return item;
      }
    }

    return null;
  }


  Future<int> getEntryCategoryUsageCount(String code) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final normalizedCode = _normalizeEntryCategory(code);
    if (normalizedCode.isEmpty) return 0;

    final List<dynamic> rows = await _client
        .from('entries_v2')
        .select('id')
        .eq('company_id', companyId)
        .eq('category', normalizedCode);

    return rows.length;
  }

  Future<void> updateTranslatedEntryCategory({
    required String code,
    required String labelPt,
    required String labelEn,
    required String labelJa,
    required String labelEs,
  }) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final normalizedCode = _normalizeEntryCategory(code);

    if (normalizedCode.isEmpty) {
      throw Exception('Código da categoria inválido.');
    }

    if (_defaultEntryCategories.contains(normalizedCode)) {
      throw Exception('Categorias padrão não podem ser editadas.');
    }

    final existing = await getEntryCategoryDefinitionByCode(normalizedCode);
    if (existing == null) {
      throw Exception('Categoria não encontrada.');
    }

    final seedLabel = _firstNonEmpty([
      labelPt.trim(),
      labelEn.trim(),
      labelJa.trim(),
      labelEs.trim(),
    ]);

    if (seedLabel == null || seedLabel.isEmpty) {
      throw Exception('Informe pelo menos um nome para a categoria.');
    }

    await _client
        .from('entry_categories')
        .update({
          'label_pt': labelPt.trim().isEmpty ? seedLabel : labelPt.trim(),
          'label_en': labelEn.trim().isEmpty ? seedLabel : labelEn.trim(),
          'label_ja': labelJa.trim().isEmpty ? seedLabel : labelJa.trim(),
          'label_es': labelEs.trim().isEmpty ? seedLabel : labelEs.trim(),
        })
        .eq('company_id', companyId)
        .eq('code', normalizedCode);
  }

  Future<void> deleteEntryCategory(String code) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final normalizedCode = _normalizeEntryCategory(code);

    if (normalizedCode.isEmpty) {
      throw Exception('Código da categoria inválido.');
    }

    if (_defaultEntryCategories.contains(normalizedCode)) {
      throw Exception('Categorias padrão não podem ser excluídas.');
    }

    final usageCount = await getEntryCategoryUsageCount(normalizedCode);
    if (usageCount > 0) {
      throw Exception('Esta categoria está em uso e não pode ser excluída.');
    }

    await _client
        .from('entry_categories')
        .delete()
        .eq('company_id', companyId)
        .eq('code', normalizedCode);

    final currentCategories = await getEntryCategories();
    final filtered = currentCategories
        .where((item) => _normalizeEntryCategory(item) != normalizedCode)
        .toList();

    if (filtered.isNotEmpty) {
      await saveEntryCategories(filtered);
    }
  }

  Future<void> createTranslatedEntryCategory({
    required String labelPt,
    required String labelEn,
    required String labelJa,
    required String labelEs,
    String? code,
  }) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final normalizedLabelPt = labelPt.trim();
    final normalizedLabelEn = labelEn.trim();
    final normalizedLabelJa = labelJa.trim();
    final normalizedLabelEs = labelEs.trim();

    final seedLabel = _firstNonEmpty([
      normalizedLabelPt,
      normalizedLabelEn,
      normalizedLabelJa,
      normalizedLabelEs,
    ]);

    if (seedLabel == null || seedLabel.isEmpty) {
      throw Exception('Categoria inválida.');
    }

    final normalizedCode = _normalizeEntryCategory(
      code ?? _buildCategoryCode(seedLabel),
    );

    if (normalizedCode.isEmpty) {
      throw Exception('Código da categoria inválido.');
    }

    final existing = await getEntryCategoryDefinitionByCode(normalizedCode);
    if (existing != null) {
      throw Exception('Esta categoria já existe.');
    }

    await _client.from('entry_categories').insert({
      'company_id': companyId,
      'code': normalizedCode,
      'label_pt': normalizedLabelPt.isEmpty ? seedLabel : normalizedLabelPt,
      'label_en': normalizedLabelEn.isEmpty ? seedLabel : normalizedLabelEn,
      'label_ja': normalizedLabelJa.isEmpty ? seedLabel : normalizedLabelJa,
      'label_es': normalizedLabelEs.isEmpty ? seedLabel : normalizedLabelEs,
      'created_at': DateTime.now().toIso8601String(),
    });

    final legacyCategories = await getEntryCategories();
    if (!legacyCategories.contains(normalizedCode)) {
      await saveEntryCategories([...legacyCategories, normalizedCode]);
    }
  }

  Future<void> saveEntryCategories(List<String> categories) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final normalized = <String>[];
    final seen = <String>{};

    for (final item in categories) {
      final value = _normalizeEntryCategory(item);
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        normalized.add(value);
      }
    }

    if (normalized.isEmpty) {
      throw Exception('A lista de categorias de entradas não pode ficar vazia.');
    }

    await _client
        .from('app_settings')
        .update({
          'entry_categories': normalized,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('company_id', companyId);
  }

  Future<void> addEntryCategory(String category) async {
    final raw = category.trim();

    if (raw.isEmpty) {
      throw Exception('Categoria inválida.');
    }

    final normalizedCode = _normalizeEntryCategory(_buildCategoryCode(raw));
    final existing = await getEntryCategoryDefinitionByCode(normalizedCode);

    if (existing != null) {
      return;
    }

    await createTranslatedEntryCategory(
      code: normalizedCode,
      labelPt: raw,
      labelEn: raw,
      labelJa: raw,
      labelEs: raw,
    );
  }

  Future<List<Map<String, dynamic>>> getExpenseCategoryDefinitions() async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final definitions = <Map<String, dynamic>>[];

    for (final code in _defaultExpenseCategories) {
      definitions.add({
        'code': code,
        'is_default': true,
        'label_pt': null,
        'label_en': null,
        'label_ja': null,
        'label_es': null,
      });
    }

    final seenCodes = <String>{..._defaultExpenseCategories};

    final settings = await getAppSettings();
    final legacyRaw = settings['expense_categories'];

    if (legacyRaw is List) {
      for (final item in legacyRaw) {
        final normalized = _normalizeExpenseCategory(item);
        if (normalized.isEmpty || seenCodes.contains(normalized)) continue;
        seenCodes.add(normalized);
        definitions.add({
          'code': normalized,
          'is_default': false,
          'label_pt': item?.toString().trim(),
          'label_en': item?.toString().trim(),
          'label_ja': item?.toString().trim(),
          'label_es': item?.toString().trim(),
        });
      }
    }

    final List<dynamic> rows = await _client
        .from('expense_categories')
        .select('code, label_pt, label_en, label_ja, label_es, created_at')
        .eq('company_id', companyId)
        .order('created_at', ascending: true);

    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final code = _normalizeExpenseCategory(row['code']);
      if (code.isEmpty || seenCodes.contains(code)) continue;

      seenCodes.add(code);
      definitions.add({
        'code': code,
        'is_default': false,
        'label_pt': _normalizeNullableText(row['label_pt']),
        'label_en': _normalizeNullableText(row['label_en']),
        'label_ja': _normalizeNullableText(row['label_ja']),
        'label_es': _normalizeNullableText(row['label_es']),
      });
    }

    return definitions;
  }

  Future<List<String>> getExpenseCategories() async {
    final definitions = await getExpenseCategoryDefinitions();
    return definitions
        .map((item) => (item['code'] ?? '').toString().trim())
        .where((code) => code.isNotEmpty)
        .toList();
  }

  Future<Map<String, String>> getExpenseCategoryLabelsByCode() async {
    final definitions = await getExpenseCategoryDefinitions();
    final labels = <String, String>{};

    for (final item in definitions) {
      final code = (item['code'] ?? '').toString().trim();
      if (code.isEmpty) continue;

      final customLabel = _firstNonEmpty([
        item['label_pt'],
        item['label_en'],
        item['label_ja'],
        item['label_es'],
      ]);

      labels[code] = customLabel ?? code;
    }

    return labels;
  }

  Future<Map<String, dynamic>?> getExpenseCategoryDefinitionByCode(
    String code,
  ) async {
    final normalizedCode = _normalizeExpenseCategory(code);
    if (normalizedCode.isEmpty) return null;

    final definitions = await getExpenseCategoryDefinitions();
    for (final item in definitions) {
      if ((item['code'] ?? '').toString().trim() == normalizedCode) {
        return item;
      }
    }

    return null;
  }


  Future<int> getExpenseCategoryUsageCount(String code) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final normalizedCode = _normalizeExpenseCategory(code);
    if (normalizedCode.isEmpty) return 0;

    final List<dynamic> rows = await _client
        .from('expenses_v2')
        .select('id')
        .eq('company_id', companyId)
        .eq('category', normalizedCode);

    return rows.length;
  }

  Future<void> updateTranslatedExpenseCategory({
    required String code,
    required String labelPt,
    required String labelEn,
    required String labelJa,
    required String labelEs,
  }) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final normalizedCode = _normalizeExpenseCategory(code);

    if (normalizedCode.isEmpty) {
      throw Exception('Código da categoria inválido.');
    }

    if (_defaultExpenseCategories.contains(normalizedCode)) {
      throw Exception('Categorias padrão não podem ser editadas.');
    }

    final existing = await getExpenseCategoryDefinitionByCode(normalizedCode);
    if (existing == null) {
      throw Exception('Categoria não encontrada.');
    }

    final seedLabel = _firstNonEmpty([
      labelPt.trim(),
      labelEn.trim(),
      labelJa.trim(),
      labelEs.trim(),
    ]);

    if (seedLabel == null || seedLabel.isEmpty) {
      throw Exception('Informe pelo menos um nome para a categoria.');
    }

    await _client
        .from('expense_categories')
        .update({
          'label_pt': labelPt.trim().isEmpty ? seedLabel : labelPt.trim(),
          'label_en': labelEn.trim().isEmpty ? seedLabel : labelEn.trim(),
          'label_ja': labelJa.trim().isEmpty ? seedLabel : labelJa.trim(),
          'label_es': labelEs.trim().isEmpty ? seedLabel : labelEs.trim(),
        })
        .eq('company_id', companyId)
        .eq('code', normalizedCode);
  }

  Future<void> deleteExpenseCategory(String code) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();
    final normalizedCode = _normalizeExpenseCategory(code);

    if (normalizedCode.isEmpty) {
      throw Exception('Código da categoria inválido.');
    }

    if (_defaultExpenseCategories.contains(normalizedCode)) {
      throw Exception('Categorias padrão não podem ser excluídas.');
    }

    final usageCount = await getExpenseCategoryUsageCount(normalizedCode);
    if (usageCount > 0) {
      throw Exception('Esta categoria está em uso e não pode ser excluída.');
    }

    await _client
        .from('expense_categories')
        .delete()
        .eq('company_id', companyId)
        .eq('code', normalizedCode);

    final currentCategories = await getExpenseCategories();
    final filtered = currentCategories
        .where((item) => _normalizeExpenseCategory(item) != normalizedCode)
        .toList();

    if (filtered.isNotEmpty) {
      await saveExpenseCategories(filtered);
    }
  }

  Future<void> createTranslatedExpenseCategory({
    required String labelPt,
    required String labelEn,
    required String labelJa,
    required String labelEs,
    String? code,
  }) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final normalizedLabelPt = labelPt.trim();
    final normalizedLabelEn = labelEn.trim();
    final normalizedLabelJa = labelJa.trim();
    final normalizedLabelEs = labelEs.trim();

    final seedLabel = _firstNonEmpty([
      normalizedLabelPt,
      normalizedLabelEn,
      normalizedLabelJa,
      normalizedLabelEs,
    ]);

    if (seedLabel == null || seedLabel.isEmpty) {
      throw Exception('Categoria inválida.');
    }

    final normalizedCode = _normalizeExpenseCategory(
      code ?? _buildCategoryCode(seedLabel),
    );

    if (normalizedCode.isEmpty) {
      throw Exception('Código da categoria inválido.');
    }

    final existing = await getExpenseCategoryDefinitionByCode(normalizedCode);
    if (existing != null) {
      throw Exception('Esta categoria já existe.');
    }

    await _client.from('expense_categories').insert({
      'company_id': companyId,
      'code': normalizedCode,
      'label_pt': normalizedLabelPt.isEmpty ? seedLabel : normalizedLabelPt,
      'label_en': normalizedLabelEn.isEmpty ? seedLabel : normalizedLabelEn,
      'label_ja': normalizedLabelJa.isEmpty ? seedLabel : normalizedLabelJa,
      'label_es': normalizedLabelEs.isEmpty ? seedLabel : normalizedLabelEs,
      'created_at': DateTime.now().toIso8601String(),
    });

    final legacyCategories = await getExpenseCategories();
    if (!legacyCategories.contains(normalizedCode)) {
      await saveExpenseCategories([...legacyCategories, normalizedCode]);
    }
  }

  Future<void> saveExpenseCategories(List<String> categories) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final normalized = <String>[];
    final seen = <String>{};

    for (final item in categories) {
      final value = _normalizeExpenseCategory(item);
      if (value.isEmpty) continue;
      if (seen.add(value)) {
        normalized.add(value);
      }
    }

    if (normalized.isEmpty) {
      throw Exception('A lista de categorias de despesas não pode ficar vazia.');
    }

    await _client
        .from('app_settings')
        .update({
          'expense_categories': normalized,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('company_id', companyId);
  }

  Future<void> addExpenseCategory(String category) async {
    final raw = category.trim();

    if (raw.isEmpty) {
      throw Exception('Categoria inválida.');
    }

    final normalizedCode = _normalizeExpenseCategory(_buildCategoryCode(raw));
    final existing = await getExpenseCategoryDefinitionByCode(normalizedCode);

    if (existing != null) {
      return;
    }

    await createTranslatedExpenseCategory(
      code: normalizedCode,
      labelPt: raw,
      labelEn: raw,
      labelJa: raw,
      labelEs: raw,
    );
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
        .select('id, company_id, entry_date, category')
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
      'category': _normalizeEntryCategory(data['category']),
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
              'category': _normalizeEntryCategory(item['category']),
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
      'category': data.containsKey('category')
          ? _normalizeEntryCategory(data['category'])
          : _normalizeEntryCategory(existingRow['category']),
      'amount': data['amount'],
      'payment_method': _normalizePaymentMethod(data['payment_method']),
    }).eq('id', id);
  }

  Future<void> deleteEntry(String id) async {
    final companyId = await AuthService.instance.getCurrentCompanyId();

    final row = await _client
        .from('entries_v2')
        .select('id, company_id, entry_date, category')
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
          'tax_type': _normalizeTaxType(data['tax_type']),
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
      'tax_type': _normalizeTaxType(data['tax_type']),
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

  String _normalizeEntryCategory(dynamic value) {
    if (value == null) return 'service';

    final raw = value.toString().trim();
    if (raw.isEmpty) return 'service';

    final normalized = raw.toLowerCase();

    switch (normalized) {
      case 'service':
      case 'services':
      case 'servico':
      case 'serviços':
      case 'servicos':
        return 'service';

      case 'product':
      case 'products':
      case 'sale':
      case 'sales':
      case 'produto':
      case 'produtos':
      case 'venda':
      case 'vendas':
        return 'sale';

      case 'commission':
      case 'comission':
      case 'commissions':
      case 'comissao':
      case 'comissão':
      case 'comissoes':
      case 'comissões':
        return 'commission';

      case 'refund':
      case 'refunds':
      case 'reembolso':
      case 'reembolsos':
      case 'estorno':
      case 'estornos':
        return 'refund';

      case 'other':
      case 'outro':
      case 'outros':
        return 'other';

      default:
        return normalized;
    }
  }

  String _buildCategoryCode(String value) {
    var text = value.trim().toLowerCase();
    if (text.isEmpty) return '';

    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };

    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    text = text.replaceAll(RegExp(r'_+'), '_');
    text = text.replaceAll(RegExp(r'^_+|_+$'), '');

    if (text.isEmpty) {
      text = 'categoria_${DateTime.now().millisecondsSinceEpoch}';
    }

    return text;
  }

  String? _normalizeNullableText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String _normalizePaymentMethod(dynamic value) {
    if (value == null) return 'other';

    final normalized = value.toString().trim().toLowerCase();

    switch (normalized) {
      case 'cash':
        return 'cash';

      case 'credit_card':
      case 'card':
        return 'card';

      case 'furikomi':
      case 'bank':
      case 'bank_transfer':
        return 'bank_transfer';

      case 'paypay':
        return 'paypay';

      default:
        return 'other';
    }
  }

  String _normalizeExpenseCategory(dynamic value) {
    if (value == null) return 'other';

    final raw = value.toString().trim();
    if (raw.isEmpty) return 'other';

    final normalized = raw.toLowerCase();

    switch (normalized) {
      case 'category_food':
      case 'food':
      case 'alimentacao':
      case 'alimentação':
      case 'comida':
        return 'food';

      case 'category_transport':
      case 'transport':
      case 'transporte':
        return 'transport';

      case 'category_housing':
      case 'rent':
      case 'housing':
      case 'moradia':
      case 'aluguel':
        return 'rent';

      case 'category_entertainment':
      case 'services':
      case 'service':
      case 'servicos':
      case 'serviços':
      case 'servico':
      case 'serviço':
        return 'services';

      case 'category_health':
      case 'fees':
      case 'health':
      case 'saude':
      case 'saúde':
      case 'taxas':
      case 'taxa':
        return 'fees';

      case 'other':
      case 'outro':
      case 'outros':
        return 'other';

      default:
        return normalized;
    }
  }

  String? _normalizeTaxType(dynamic value) {
    if (value == null) return null;

    final normalized = value.toString().trim().toLowerCase();

    switch (normalized) {
      case '税込':
      case 'tax_included':
      case 'included':
        return '税込';

      case '税抜':
      case 'tax_excluded':
      case 'excluded':
        return '税抜';

      default:
        return null;
    }
  }
}
