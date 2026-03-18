import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  static const String _addCategoryValue = '__add_new_category__';

  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  bool _creatingCategory = false;
  bool _isCustomCategoryMode = false;
  List<String> _closedFiscalMonths = [];
  List<String> _entryCategories = const [
    'service',
    'sale',
    'commission',
    'refund',
    'other',
  ];
  Map<String, Map<String, String>> _categoryTranslations = {};

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'cash';
  String _category = 'service';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _translateCategoryWithAi(String text) async {
    final request = await html.HttpRequest.request(
      'https://autonomojp.vercel.app/api/ai-help',
      method: 'POST',
      sendData: jsonEncode({
        'mode': 'translate_category',
        'text': text,
      }),
      requestHeaders: {
        'Content-Type': 'application/json',
      },
    );

    final raw = request.responseText ?? '';
    Map<String, dynamic> data = {};

    if (raw.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        throw Exception('Resposta inválida da API de tradução.');
      }
    }

    final pt = (data['pt'] ?? '').toString().trim();
    final en = (data['en'] ?? '').toString().trim();
    final ja = (data['ja'] ?? '').toString().trim();
    final es = (data['es'] ?? '').toString().trim();

    if (pt.isEmpty || en.isEmpty || ja.isEmpty || es.isEmpty) {
      throw Exception(
        (data['message'] ?? data['error'] ?? 'Falha ao traduzir categoria.')
            .toString(),
      );
    }

    return {
      'pt': pt,
      'en': en,
      'ja': ja,
      'es': es,
    };
  }

  Future<void> _loadClosedMonths() async {
    try {
      final months = await SupabaseService.instance.getClosedFiscalMonths();
      if (!mounted) return;
      setState(() {
        _closedFiscalMonths = months;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closedFiscalMonths = [];
      });
    }
  }

  Future<void> _loadEntryCategories() async {
    try {
      final categories = await SupabaseService.instance.getEntryCategories();
      final definitions =
          await SupabaseService.instance.getEntryCategoryDefinitions();

      final normalized = categories
          .map((item) => _normalizeCategoryForUi(item))
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      if (normalized.isEmpty) {
        normalized.addAll(const [
          'service',
          'sale',
          'commission',
          'refund',
          'other',
        ]);
      }

      if (_category.isNotEmpty && !normalized.contains(_category)) {
        normalized.add(_category);
      }

      final translations = <String, Map<String, String>>{};
      for (final item in definitions) {
        final code = _normalizeCategoryForUi(item['code']);
        if (code.isEmpty) continue;
        translations[code] = {
          'pt': (item['label_pt'] ?? '').toString().trim(),
          'en': (item['label_en'] ?? '').toString().trim(),
          'ja': (item['label_ja'] ?? '').toString().trim(),
          'es': (item['label_es'] ?? '').toString().trim(),
        };
      }

      normalized.sort((a, b) {
        final ai = _categorySortIndex(a);
        final bi = _categorySortIndex(b);
        if (ai != bi) return ai.compareTo(bi);
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _entryCategories = normalized;
        _categoryTranslations = translations;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entryCategories = [
          'service',
          'sale',
          'commission',
          'refund',
          'other',
        ];
        _categoryTranslations = {};
      });
    }
  }

  String _extractFiscalMonth(dynamic rawDate) {
    if (rawDate == null) return '';

    if (rawDate is DateTime) {
      final year = rawDate.year.toString().padLeft(4, '0');
      final month = rawDate.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed != null) {
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final text = rawDate.toString().trim();
    if (text.length >= 7 && text[4] == '-') {
      return text.substring(0, 7);
    }

    return '';
  }

  bool _isClosedMonth(dynamic rawDate) {
    final fiscalMonth = _extractFiscalMonth(rawDate);
    if (fiscalMonth.isEmpty) return false;
    return _closedFiscalMonths.contains(fiscalMonth);
  }

  bool _isCurrentMonthClosed() {
    return _isClosedMonth(DateTime.now());
  }

  String _friendlyBlockedMessage(AppLocalizations t, [String? month]) {
    if (month != null && month.isNotEmpty) {
      return t
          .translate('closed_month_operation_not_allowed_with_month')
          .replaceAll('{month}', month);
    }
    return t.translate('closed_month_operation_not_allowed');
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _loadEntries() async {
    final data = await SupabaseService.instance.getEntries();

    if (!mounted) return;

    setState(() {
      _entries = List<Map<String, dynamic>>.from(data)
          .map(
            (item) => {
              ...item,
              'category': _normalizeCategoryForUi(item['category']),
            },
          )
          .toList();
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    await _loadClosedMonths();
    await _loadEntryCategories();
    await _loadEntries();
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '-';

    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) return rawDate.toString();

    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  String _formatYen(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    final integerValue = number.toStringAsFixed(0);
    final chars = integerValue.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return '¥${buffer.toString().split('').reversed.join()}';
  }

  String _paymentLabel(AppLocalizations t, String value) {
    switch (value) {
      case 'cash':
        return t.translate('payment_cash');
      case 'bank_transfer':
        return t.translate('payment_bank_transfer');
      case 'card':
        return t.translate('payment_credit_card');
      case 'paypay':
        return t.translate('payment_paypay');
      default:
        return t.translate('payment_other');
    }
  }

  String _normalizeCategoryForUi(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return 'service';

    final lower = text.toLowerCase();
    switch (lower) {
      case 'product':
      case 'products':
      case 'produto':
      case 'produtos':
      case 'sale':
      case 'sales':
      case 'venda':
      case 'vendas':
        return 'sale';
      case 'service':
      case 'services':
      case 'servico':
      case 'servicos':
      case 'serviço':
      case 'serviços':
        return 'service';
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
        return 'refund';
      case 'other':
      case 'outro':
      case 'outros':
        return 'other';
      default:
        return lower;
    }
  }

  String _categoryLabel(AppLocalizations t, String value) {
    final normalized = _normalizeCategoryForUi(value);

    switch (normalized) {
      case 'service':
        return t.translate('entry_category_service');
      case 'sale':
        return t.translate('entry_category_sale');
      case 'commission':
        return t.translate('entry_category_commission');
      case 'refund':
        return t.translate('entry_category_refund');
      case 'other':
        return t.translate('entry_category_other');
      default:
        final languageCode = t.locale.languageCode;
        final translated = _categoryTranslations[normalized]?[languageCode];
        if (translated != null && translated.trim().isNotEmpty) {
          return translated.trim();
        }

        final fallback = _categoryTranslations[normalized];
        if (fallback != null) {
          for (final key in ['pt', 'en', 'ja', 'es']) {
            final candidate = fallback[key];
            if (candidate != null && candidate.trim().isNotEmpty) {
              return candidate.trim();
            }
          }
        }

        final raw = value.trim();
        if (raw.isEmpty) return t.translate('entry_category_other');

        return raw
            .split(RegExp(r'[_\s-]+'))
            .where((part) => part.isNotEmpty)
            .map(
              (part) =>
                  '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1) : ''}',
            )
            .join(' ');
    }
  }

  int _categorySortIndex(String value) {
    switch (_normalizeCategoryForUi(value)) {
      case 'service':
        return 0;
      case 'sale':
        return 1;
      case 'commission':
        return 2;
      case 'refund':
        return 3;
      case 'other':
        return 4;
      default:
        return 100;
    }
  }

  List<DropdownMenuItem<String>> _categoryItems(AppLocalizations t) {
    final categories = _entryCategories.isEmpty
        ? [
            'service',
            'sale',
            'commission',
            'refund',
            'other',
          ]
        : List<String>.from(_entryCategories);

    if (!_isCustomCategoryMode && !categories.contains(_category)) {
      categories.add(_category);
    }

    categories.sort((a, b) {
      final ai = _categorySortIndex(a);
      final bi = _categorySortIndex(b);
      if (ai != bi) return ai.compareTo(bi);
      return _categoryLabel(t, a)
          .toLowerCase()
          .compareTo(_categoryLabel(t, b).toLowerCase());
    });

    return [
      ...categories.map(
        (item) => DropdownMenuItem<String>(
          value: item,
          child: Text(_categoryLabel(t, item)),
        ),
      ),
      DropdownMenuItem<String>(
        value: _addCategoryValue,
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, size: 18),
            const SizedBox(width: 8),
            Text(t.translate('register_new_category')),
          ],
        ),
      ),
    ];
  }

  Future<void> _selectDate(StateSetter setStateDialog) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setStateDialog(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleCategorySelection(
    String? value,
    StateSetter setStateDialog,
  ) async {
    if (value == null) return;

    if (value == _addCategoryValue) {
      setStateDialog(() {
        _isCustomCategoryMode = true;
        _customCategoryController.clear();
      });
      return;
    }

    setStateDialog(() {
      _isCustomCategoryMode = false;
      _category = _normalizeCategoryForUi(value);
      _customCategoryController.clear();
    });
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  Future<String> _resolveCategoryBeforeSave() async {
    if (!_isCustomCategoryMode) {
      return _category;
    }

    final raw = _customCategoryController.text.trim();
    if (raw.isEmpty) {
      throw Exception('Informe o nome da categoria.');
    }

    final normalized = _normalizeCategoryForUi(raw);

    if (_entryCategories.contains(normalized)) {
      return normalized;
    }

    if (_creatingCategory) {
      throw Exception('A categoria ainda está sendo criada.');
    }

    _creatingCategory = true;
    try {
      final translations = await _translateCategoryWithAi(raw);

      await SupabaseService.instance.createTranslatedEntryCategory(
        labelPt: translations['pt'] ?? raw,
        labelEn: translations['en'] ?? raw,
        labelJa: translations['ja'] ?? raw,
        labelEs: translations['es'] ?? raw,
      );

      await _loadEntryCategories();
      return _normalizeCategoryForUi(translations['pt'] ?? raw);
    } finally {
      _creatingCategory = false;
    }
  }

  Future<void> _openAddDialog() async {
    final t = AppLocalizations.of(context);

    if (_isCurrentMonthClosed()) {
      _showMessage(
        _friendlyBlockedMessage(t, _extractFiscalMonth(DateTime.now())),
        error: true,
      );
      return;
    }

    _descController.clear();
    _amountController.clear();
    _customCategoryController.clear();
    _selectedDate = DateTime.now();
    _paymentMethod = 'cash';
    _isCustomCategoryMode = false;
    _category = _entryCategories.contains('service')
        ? 'service'
        : (_entryCategories.isNotEmpty ? _entryCategories.first : 'service');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('new_entry'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration(
                            t.translate('description'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              _fieldDecoration('${t.translate('value')} (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _isCustomCategoryMode ? _addCategoryValue : _category,
                          decoration: _fieldDecoration(t.translate('category')),
                          items: _categoryItems(t),
                          onChanged: (value) async {
                            await _handleCategorySelection(
                              value,
                              setStateDialog,
                            );
                          },
                        ),
                        if (_isCustomCategoryMode) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customCategoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration(
                              t.translate('category_name'),
                            ),
                          ),
                          if (_creatingCategory) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    t.locale.languageCode == 'ja'
                                        ? 'カテゴリを保存しています...'
                                        : t.locale.languageCode == 'en'
                                            ? 'Saving category...'
                                            : t.locale.languageCode == 'es'
                                                ? 'Guardando categoría...'
                                                : 'Salvando categoria...',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration(
                            t.translate('payment_method'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(t.translate('payment_cash')),
                            ),
                            DropdownMenuItem(
                              value: 'card',
                              child: Text(t.translate('payment_credit_card')),
                            ),
                            DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text(
                                t.translate('payment_bank_transfer'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'paypay',
                              child: Text(t.translate('payment_paypay')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(t.translate('payment_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.translate('date')}: ${_formatDate(_selectedDate.toIso8601String())}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectDate(setStateDialog),
                                child: Text(t.translate('change')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(t.translate('cancel')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final description = _descController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text
                                      .trim()
                                      .replaceAll(',', '.'),
                                );

                                if (description.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  _showMessage(
                                    t.translate('invalid_data'),
                                    error: true,
                                  );
                                  return;
                                }

                                if (_isClosedMonth(_selectedDate)) {
                                  _showMessage(
                                    _friendlyBlockedMessage(
                                      t,
                                      _extractFiscalMonth(_selectedDate),
                                    ),
                                    error: true,
                                  );
                                  return;
                                }

                                try {
                                  final resolvedCategory =
                                      await _resolveCategoryBeforeSave();

                                  await SupabaseService.instance.addEntry({
                                    'date': _selectedDate.toIso8601String(),
                                    'description': description,
                                    'amount': amount,
                                    'category': resolvedCategory,
                                    'payment_method': _paymentMethod,
                                  });

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);
                                } catch (e) {
                                  if (!mounted) return;
                                  _showMessage(
                                    e.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                    error: true,
                                  );
                                }
                              },
                              child: Text(t.translate('save')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      _showMessage(t.translate('entry_added'));
      await _refresh();
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final t = AppLocalizations.of(context);

    if (_isClosedMonth(entry['date'])) {
      _showMessage(
        _friendlyBlockedMessage(t, _extractFiscalMonth(entry['date'])),
        error: true,
      );
      return;
    }

    _descController.text = (entry['description'] ?? '').toString();
    _amountController.text = (entry['amount'] ?? '').toString();
    _customCategoryController.clear();
    _selectedDate =
        DateTime.tryParse((entry['date'] ?? '').toString()) ?? DateTime.now();
    _paymentMethod = (entry['payment_method'] ?? 'cash').toString();
    _category = _normalizeCategoryForUi(entry['category']);
    _isCustomCategoryMode = false;

    if (!_entryCategories.contains(_category)) {
      setState(() {
        _entryCategories = [..._entryCategories, _category];
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('edit_entry'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration(
                            t.translate('description'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              _fieldDecoration('${t.translate('value')} (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _fieldDecoration(t.translate('category')),
                          items: _categoryItems(t)
                              .where((item) => item.value != _addCategoryValue)
                              .toList(),
                          onChanged: (value) async {
                            await _handleCategorySelection(
                              value,
                              setStateDialog,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration(
                            t.translate('payment_method'),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(t.translate('payment_cash')),
                            ),
                            DropdownMenuItem(
                              value: 'card',
                              child: Text(t.translate('payment_credit_card')),
                            ),
                            DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text(
                                t.translate('payment_bank_transfer'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'paypay',
                              child: Text(t.translate('payment_paypay')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(t.translate('payment_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${t.translate('date')}: ${_formatDate(_selectedDate.toIso8601String())}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectDate(setStateDialog),
                                child: Text(t.translate('change')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(t.translate('cancel')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                final description = _descController.text.trim();
                                final amount = double.tryParse(
                                  _amountController.text
                                      .trim()
                                      .replaceAll(',', '.'),
                                );

                                if (description.isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  _showMessage(
                                    t.translate('invalid_data'),
                                    error: true,
                                  );
                                  return;
                                }

                                if (_isClosedMonth(_selectedDate)) {
                                  _showMessage(
                                    _friendlyBlockedMessage(
                                      t,
                                      _extractFiscalMonth(_selectedDate),
                                    ),
                                    error: true,
                                  );
                                  return;
                                }

                                try {
                                  await SupabaseService.instance.updateEntry(
                                    entry['id'].toString(),
                                    {
                                      'entry_date':
                                          _selectedDate.toIso8601String(),
                                      'description': description,
                                      'amount': amount,
                                      'category': _category,
                                      'payment_method': _paymentMethod,
                                    },
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);
                                } catch (e) {
                                  if (!mounted) return;
                                  _showMessage(
                                    e.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                    error: true,
                                  );
                                }
                              },
                              child: Text(t.translate('save')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      _showMessage(t.translate('entry_updated'));
      await _refresh();
    }
  }

  Future<void> _deleteEntry(String id, {dynamic entryDate}) async {
    final t = AppLocalizations.of(context);

    if (_isClosedMonth(entryDate)) {
      _showMessage(
        _friendlyBlockedMessage(t, _extractFiscalMonth(entryDate)),
        error: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('delete_entry')),
        content: Text(t.translate('confirm_delete_entry')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.translate('delete_entry')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.instance.deleteEntry(id);

      if (!mounted) return;

      _showMessage(t.translate('entry_deleted'));
      await _refresh();
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  Widget _entryCard(AppLocalizations t, Map<String, dynamic> entry) {
    final description = (entry['description'] ?? '').toString();
    final date = _formatDate(entry['date']);
    final amount = _formatYen(entry['amount']);
    final paymentMethod = _paymentLabel(
      t,
      (entry['payment_method'] ?? '').toString(),
    );
    final category = _categoryLabel(
      t,
      _normalizeCategoryForUi(entry['category'] ?? 'service'),
    );
    final isClosed = _isClosedMonth(entry['date']);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description.isEmpty ? t.translate('no_description') : description,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$date • $category • $paymentMethod',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isClosed)
                  Tooltip(
                    message: t.translate('fiscal_month_locked'),
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.orange.shade700,
                    ),
                  ),
                if (!isClosed)
                  IconButton(
                    tooltip: t.translate('edit_entry'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editEntry(entry),
                  ),
                if (!isClosed)
                  IconButton(
                    tooltip: t.translate('delete_entry'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteEntry(
                      entry['id'].toString(),
                      entryDate: entry['date'],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _closedMonthBanner(AppLocalizations t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate('fiscal_month_locked'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.translate('fiscal_month_locked_description'),
                  style: TextStyle(
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              t.translate('no_entries_yet'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.translate('entries_will_appear_here'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('nav_entries')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: _isCurrentMonthClosed() ? Colors.grey.shade400 : null,
            ),
            tooltip: _isCurrentMonthClosed()
                ? t.translate('fiscal_month_locked')
                : t.translate('new_entry'),
            onPressed: _isCurrentMonthClosed() ? null : _openAddDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isCurrentMonthClosed()) _closedMonthBanner(t),
                Expanded(
                  child: _entries.isEmpty
                      ? _emptyState(t)
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry =
                                  Map<String, dynamic>.from(_entries[index]);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _entryCard(t, entry),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
