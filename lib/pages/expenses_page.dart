import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  static const String _addCategoryValue = '__add_new_category__';

  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String _reviewFilter = 'all';
  bool _creatingCategory = false;
  bool _isCustomCategoryMode = false;
  List<String> _closedFiscalMonths = [];
  List<String> _expenseCategories = const [
    'food',
    'transport',
    'rent',
    'services',
    'fees',
    'other',
  ];
  Map<String, Map<String, String>> _categoryTranslations = {};

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _category = 'other';
  String _taxType = 'external';
  double _taxAmount = 0;
  String _paymentMethod = 'cash';
  String _taxInclusionType = 'external';

  Uint8List? _selectedReceiptBytes;
  String? _selectedReceiptName;
  String? _selectedReceiptMimeType;
  int? _selectedReceiptSize;

  AppLocalizations get t => AppLocalizations.of(context);

  String _tr(String key) {
    final translated = t.translate(key);
    if (translated != key) return translated;

    final lang = Localizations.localeOf(context).languageCode;

    const fallback = <String, Map<String, String>>{
      'pt': {
        'cancel': 'Cancelar',
        'category': 'Categoria',
        'category_fees': 'Taxas',
        'category_food': 'Alimentação',
        'category_other': 'Outros',
        'category_rent': 'Aluguel',
        'category_services': 'Serviços',
        'category_transport': 'Transporte',
        'change': 'Alterar',
        'change_file': 'Alterar arquivo',
        'choose_file': 'Escolher arquivo',
        'could_not_capture_photo': 'Não foi possível capturar a foto.',
        'could_not_read_file': 'Não foi possível ler o arquivo.',
        'date': 'Data',
        'delete': 'Excluir',
        'delete_expense_confirm': 'Deseja realmente excluir esta despesa?',
        'delete_expense_title': 'Excluir despesa',
        'description': 'Descrição',
        'edit': 'Editar',
        'edit_expense': 'Editar despesa',
        'existing_receipt_attached': 'Recibo já anexado',
        'expense_added': 'Despesa adicionada!',
        'expense_deleted': 'Despesa excluída!',
        'expense_updated': 'Despesa atualizada!',
        'expenses': 'Despesas',
        'expenses_will_appear_here': 'As despesas aparecerão aqui.',
        'fiscal_basic_data': 'Dados fiscais básicos',
        'invalid_data': 'Dados inválidos.',
        'new_expense': 'Nova despesa',
        'new_expense_tooltip': 'Nova despesa',
        'no_description': 'Sem descrição',
        'no_expenses_registered': 'Nenhuma despesa cadastrada.',
        'no_receipt_selected': 'Nenhum recibo selecionado',
        'notes': 'Observações',
        'obs_short': 'Obs.',
        'payment': 'Pagamento',
        'payment_cash': 'Dinheiro',
        'payment_credit_card': 'Cartão de crédito',
        'payment_furikomi': 'Furikomi',
        'payment_method': 'Método de pagamento',
        'payment_other': 'Outro',
        'payment_paypay': 'PayPay',
        'receipt_attachment': 'Anexo do recibo',
        'receipt_viewer_title': 'Visualizar recibo',
        'remove': 'Remover',
        'save': 'Salvar',
        'store': 'Loja',
        'take_photo': 'Tirar foto',
        'tax': 'Imposto',
        'tax_external': 'Imposto externo',
        'tax_inclusive': 'Imposto incluso',
        'tax_not_defined': 'Imposto não definido',
        'tax_rate': 'Taxa de imposto',
        'tax_type': 'Tipo de imposto',
        'value': 'Valor',
        'vendor': 'Fornecedor',
        'view': 'Ver',
        'filter_all': 'Todas',
        'filter_review_pending': 'Pendentes de revisão',
        'filter_reviewed': 'Revisadas',
        'review_filter': 'Filtro de revisão',
        'fiscal_month_closed': 'Mês fiscal fechado',
        'fiscal_month_closed_message': 'Este mês fiscal está fechado. Não é possível criar, editar ou excluir despesas.',
        'cannot_edit_closed_month': 'Este mês fiscal está fechado. Não é possível editar esta despesa.',
        'cannot_delete_closed_month': 'Este mês fiscal está fechado. Não é possível excluir esta despesa.',
        'cannot_add_closed_month': 'O mês fiscal atual está fechado. Não é possível cadastrar nova despesa.',
        'cannot_save_closed_month': 'O mês selecionado está fechado. Não é possível salvar esta despesa.',
      },
      'en': {
        'cancel': 'Cancel',
        'category': 'Category',
        'category_fees': 'Fees',
        'category_food': 'Food',
        'category_other': 'Other',
        'category_rent': 'Rent',
        'category_services': 'Services',
        'category_transport': 'Transport',
        'change': 'Change',
        'change_file': 'Change file',
        'choose_file': 'Choose file',
        'could_not_capture_photo': 'Could not capture photo.',
        'could_not_read_file': 'Could not read file.',
        'date': 'Date',
        'delete': 'Delete',
        'delete_expense_confirm': 'Do you really want to delete this expense?',
        'delete_expense_title': 'Delete expense',
        'description': 'Description',
        'edit': 'Edit',
        'edit_expense': 'Edit expense',
        'existing_receipt_attached': 'Receipt already attached',
        'expense_added': 'Expense added!',
        'expense_deleted': 'Expense deleted!',
        'expense_updated': 'Expense updated!',
        'expenses': 'Expenses',
        'expenses_will_appear_here': 'Expenses will appear here.',
        'fiscal_basic_data': 'Basic fiscal data',
        'invalid_data': 'Invalid data.',
        'new_expense': 'New expense',
        'new_expense_tooltip': 'New expense',
        'no_description': 'No description',
        'no_expenses_registered': 'No expenses registered.',
        'no_receipt_selected': 'No receipt selected',
        'notes': 'Notes',
        'obs_short': 'Notes',
        'payment': 'Payment',
        'payment_cash': 'Cash',
        'payment_credit_card': 'Credit Card',
        'payment_furikomi': 'Furikomi',
        'payment_method': 'Payment method',
        'payment_other': 'Other',
        'payment_paypay': 'PayPay',
        'receipt_attachment': 'Receipt attachment',
        'receipt_viewer_title': 'Receipt viewer',
        'remove': 'Remove',
        'save': 'Save',
        'store': 'Store',
        'take_photo': 'Take photo',
        'tax': 'Tax',
        'tax_external': 'External tax',
        'tax_inclusive': 'Tax included',
        'tax_not_defined': 'Tax not defined',
        'tax_rate': 'Tax rate',
        'tax_type': 'Tax type',
        'value': 'Value',
        'vendor': 'Vendor',
        'view': 'View',
        'filter_all': 'All',
        'filter_review_pending': 'Pending review',
        'filter_reviewed': 'Reviewed',
        'review_filter': 'Review filter',
        'fiscal_month_closed': 'Fiscal month closed',
        'fiscal_month_closed_message': 'This fiscal month is closed. You cannot create, edit, or delete expenses.',
        'cannot_edit_closed_month': 'This fiscal month is closed. You cannot edit this expense.',
        'cannot_delete_closed_month': 'This fiscal month is closed. You cannot delete this expense.',
        'cannot_add_closed_month': 'The current fiscal month is closed. You cannot create a new expense.',
        'cannot_save_closed_month': 'The selected month is closed. You cannot save this expense.',
      },
      'ja': {
        'cancel': 'キャンセル',
        'category': 'カテゴリ',
        'category_fees': '手数料',
        'category_food': '食費',
        'category_other': 'その他',
        'category_rent': '家賃',
        'category_services': 'サービス',
        'category_transport': '交通費',
        'change': '変更',
        'change_file': 'ファイルを変更',
        'choose_file': 'ファイルを選択',
        'could_not_capture_photo': '写真を取得できませんでした。',
        'could_not_read_file': 'ファイルを読み込めませんでした。',
        'date': '日付',
        'delete': '削除',
        'delete_expense_confirm': 'この支出を削除してもよろしいですか？',
        'delete_expense_title': '支出を削除',
        'description': '説明',
        'edit': '編集',
        'edit_expense': '支出を編集',
        'existing_receipt_attached': '領収書はすでに添付されています',
        'expense_added': '支出が追加されました！',
        'expense_deleted': '支出が削除されました！',
        'expense_updated': '支出が更新されました！',
        'expenses': '支出',
        'expenses_will_appear_here': '支出はここに表示されます。',
        'fiscal_basic_data': '基本税務データ',
        'invalid_data': '無効なデータです。',
        'new_expense': '新しい経費',
        'new_expense_tooltip': '新しい経費',
        'no_description': '説明なし',
        'no_expenses_registered': '支出はまだ登録されていません。',
        'no_receipt_selected': '領収書が選択されていません',
        'notes': 'メモ',
        'obs_short': '備考',
        'payment': '支払',
        'payment_cash': '現金',
        'payment_credit_card': 'クレジットカード',
        'payment_furikomi': '振込',
        'payment_method': '支払い方法',
        'payment_other': 'その他',
        'payment_paypay': 'PayPay',
        'receipt_attachment': '領収書添付',
        'receipt_viewer_title': '領収書表示',
        'remove': '削除',
        'save': '保存',
        'store': '店舗',
        'take_photo': '写真を撮る',
        'tax': '税',
        'tax_external': '外税',
        'tax_inclusive': '内税',
        'tax_not_defined': '税未設定',
        'tax_rate': '税率',
        'tax_type': '税タイプ',
        'value': '金額',
        'vendor': '仕入先',
        'view': '表示',
        'filter_all': 'すべて',
        'filter_review_pending': 'レビュー待ち',
        'filter_reviewed': 'レビュー済み',
        'review_filter': 'レビューフィルター',
        'fiscal_month_closed': '会計月が締め済みです',
        'fiscal_month_closed_message': 'この会計月は締め済みのため、経費の新規作成・編集・削除はできません。',
        'cannot_edit_closed_month': 'この会計月は締め済みのため、この経費は編集できません。',
        'cannot_delete_closed_month': 'この会計月は締め済みのため、この経費は削除できません。',
        'cannot_add_closed_month': '現在の会計月は締め済みのため、新しい経費は登録できません。',
        'cannot_save_closed_month': '選択した月は締め済みのため、この経費は保存できません。',
      },
      'es': {
        'cancel': 'Cancelar',
        'category': 'Categoría',
        'category_fees': 'Tarifas',
        'category_food': 'Alimentación',
        'category_other': 'Otros',
        'category_rent': 'Alquiler',
        'category_services': 'Servicios',
        'category_transport': 'Transporte',
        'change': 'Cambiar',
        'change_file': 'Cambiar archivo',
        'choose_file': 'Elegir archivo',
        'could_not_capture_photo': 'No se pudo capturar la foto.',
        'could_not_read_file': 'No se pudo leer el archivo.',
        'date': 'Fecha',
        'delete': 'Eliminar',
        'delete_expense_confirm': '¿Desea eliminar este gasto?',
        'delete_expense_title': 'Eliminar gasto',
        'description': 'Descripción',
        'edit': 'Editar',
        'edit_expense': 'Editar gasto',
        'existing_receipt_attached': 'Recibo ya adjunto',
        'expense_added': '¡Gasto agregado!',
        'expense_deleted': '¡Gasto eliminado!',
        'expense_updated': '¡Gasto actualizado!',
        'expenses': 'Gastos',
        'expenses_will_appear_here': 'Los gastos aparecerán aquí.',
        'fiscal_basic_data': 'Datos fiscales básicos',
        'invalid_data': 'Datos inválidos.',
        'new_expense': 'Nuevo gasto',
        'new_expense_tooltip': 'Nuevo gasto',
        'no_description': 'Sin descripción',
        'no_expenses_registered': 'No hay gastos registrados.',
        'no_receipt_selected': 'No se ha seleccionado recibo',
        'notes': 'Notas',
        'obs_short': 'Obs.',
        'payment': 'Pago',
        'payment_cash': 'Efectivo',
        'payment_credit_card': 'Tarjeta de crédito',
        'payment_furikomi': 'Furikomi',
        'payment_method': 'Método de pago',
        'payment_other': 'Otro',
        'payment_paypay': 'PayPay',
        'receipt_attachment': 'Adjunto del recibo',
        'receipt_viewer_title': 'Visor de recibo',
        'remove': 'Quitar',
        'save': 'Guardar',
        'store': 'Tienda',
        'take_photo': 'Tomar foto',
        'tax': 'Impuesto',
        'tax_external': 'Impuesto externo',
        'tax_inclusive': 'Impuesto incluido',
        'tax_not_defined': 'Impuesto no definido',
        'tax_rate': 'Tasa de impuesto',
        'tax_type': 'Tipo de impuesto',
        'value': 'Valor',
        'vendor': 'Proveedor',
        'view': 'Ver',
        'filter_all': 'Todas',
        'filter_review_pending': 'Pendientes de revisión',
        'filter_reviewed': 'Revisadas',
        'review_filter': 'Filtro de revisión',
        'fiscal_month_closed': 'Mes fiscal cerrado',
        'fiscal_month_closed_message': 'Este mes fiscal está cerrado. No es posible crear, editar ni eliminar gastos.',
        'cannot_edit_closed_month': 'Este mes fiscal está cerrado. No es posible editar este gasto.',
        'cannot_delete_closed_month': 'Este mes fiscal está cerrado. No es posible eliminar este gasto.',
        'cannot_add_closed_month': 'El mes fiscal actual está cerrado. No es posible registrar un nuevo gasto.',
        'cannot_save_closed_month': 'El mes seleccionado está cerrado. No es posible guardar este gasto.',
      },
    };

    return fallback[lang]?[key] ?? fallback['en']?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _storeController.dispose();
    _vendorController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  String _apiBaseUrl() {
    final uri = Uri.base;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  Future<Map<String, String>> _translateCategoryWithAi(String text) async {
    final request = await html.HttpRequest.request(
      '${_apiBaseUrl()}/api/ai-help',
      method: 'POST',
      sendData: jsonEncode({
  'mode': 'translate_category',
  'text': text,
}),
requestHeaders: {'Content-Type': 'application/json'},
          ),

          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              if (_category != null) {
                //_showCategoryActions(_category!);
              }
            },
          ),
        ],
      ),
      requestHeaders: {'Content-Type': 'application/json'},
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

    return {'pt': pt, 'en': en, 'ja': ja, 'es': es};
  }

  Future<void> _loadExpenseCategories() async {
    try {
      final categories = await SupabaseService.instance.getExpenseCategories();
      final definitions =
          await SupabaseService.instance.getExpenseCategoryDefinitions();

      final normalized = categories
          .map((item) => _normalizeCategoryForUi(item))
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      if (normalized.isEmpty) {
        normalized.addAll(const [
          'food',
          'transport',
          'rent',
          'services',
          'fees',
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
        _expenseCategories = normalized;
        _categoryTranslations = translations;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _expenseCategories = [
          'food',
          'transport',
          'rent',
          'services',
          'fees',
          'other',
        ];
        _categoryTranslations = {};
      });
    }
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

  String _extractFiscalMonth(dynamic value) {
    if (value == null) return '';

    if (value is DateTime) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '';

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    if (text.length >= 7 && text[4] == '-') {
      return text.substring(0, 7);
    }

    return '';
  }

  bool _isClosedMonth(dynamic dateValue) {
    final fiscalMonth = _extractFiscalMonth(dateValue);
    if (fiscalMonth.isEmpty) return false;
    return _closedFiscalMonths.contains(fiscalMonth);
  }

  bool _isCurrentMonthClosed() {
    return _isClosedMonth(DateTime.now());
  }

  void _showFiscalClosedSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorSnackBar(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Widget _fiscalClosedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: 
    ),
  ],
),

                          items: _expenseCategoryItems(),
                          onChanged: (value) async {
                            await _handleExpenseCategorySelection(value, setStateDialog);
                          },
                        ),
                        if (_isCustomCategoryMode) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _customCategoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration(_tr('category_name')),
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
                                    Localizations.localeOf(context).languageCode == 'ja'
                                        ? 'カテゴリを保存しています...'
                                        : Localizations.localeOf(context).languageCode == 'en'
                                            ? 'Saving category...'
                                            : Localizations.localeOf(context).languageCode == 'es'
                                                ? 'Guardando categoría...'
                                                : 'Salvando categoria...',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),
                        Text(
                          _tr('fiscal_basic_data'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vendorController,
                          decoration: _fieldDecoration(_tr('vendor')),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration(_tr('payment_method')),

const SizedBox(height: 8),
Row(
  children: [
    TextButton.icon(
      onPressed: _category == null ? null : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Editar categoria (implementar depois)')),
        );
      },
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Editar categoria'),
    ),
    const SizedBox(width: 8),
    TextButton.icon(
      onPressed: _category == null ? null : () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excluir categoria (implementar depois)')),
        );
      },
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Excluir categoria'),
    ),
  ],
),

                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(_tr('payment_cash')),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card',
                              child: Text(_tr('payment_credit_card')),
                            ),
                            DropdownMenuItem(
                              value: 'furikomi',
                              child: Text(_tr('payment_furikomi')),
                            ),
                            DropdownMenuItem(
                              value: 'paypay',
                              child: Text(_tr('payment_paypay')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(_tr('payment_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _fieldDecoration(_tr('notes')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(_tr('tax_rate')),
                        ),
                        const SizedBox(height: 10),
                        _quickTaxRateButtons(setStateDialog),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _taxInclusionType,
                          decoration: _fieldDecoration(_tr('tax_type')),
                          items: [
                            DropdownMenuItem(
                              value: 'external',
                              child: Text(_tr('tax_external')),
                            ),
                            DropdownMenuItem(
                              value: 'inclusive',
                              child: Text(_tr('tax_inclusive')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _taxInclusionType = value ?? 'external';
                              _taxType = _taxInclusionType;
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
                                  '${_tr('date')}: ${_formatDate(_selectedDate.toIso8601String())}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectDate(setStateDialog),
                                child: Text(_tr('change')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _receiptSection(setStateDialog: setStateDialog),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: Text(_tr('cancel')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  final description = _descController.text.trim();
                                  final amount = double.tryParse(
                                    _amountController.text
                                        .trim()
                                        .replaceAll(',', '.'),
                                  );

                                  if (description.isEmpty ||
                                      amount == null ||
                                      amount <= 0) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(_tr('invalid_data')),
                                      ),
                                    );
                                    return;
                                  }

                                  if (_isClosedMonth(_selectedDate)) {
                                    _showFiscalClosedSnackBar(
                                      _tr('cannot_save_closed_month'),
                                    );
                                    return;
                                  }

                                  final resolvedCategory =
                                      await _resolveExpenseCategoryBeforeSave();

                                  final basePayload = {
                                    'date': _selectedDate.toIso8601String(),
                                    'store_name': _storeController.text.trim(),
                                    'description': description,
                                    'category': resolvedCategory,
                                    'amount': amount,
                                    'tax': _taxAmount,
                                    'tax_type':
                                        _dbTaxTypeFromInclusion(_taxInclusionType),
                                    'vendor_name': _vendorController.text.trim(),
                                    'payment_method': _paymentMethod,
                                    'notes': _notesController.text.trim(),
                                    'tax_rate':
                                        _parseDouble(_taxRateController.text),
                                    'tax_inclusion_type': _taxInclusionType,
                                  };

                                  await SupabaseService.instance
                                      .addExpense(basePayload);

                                  if (_selectedReceiptBytes != null &&
                                      _selectedReceiptName != null) {
                                    final receiptPayload =
                                        await _uploadSelectedReceiptIfNeeded();

                                    final expenseId =
                                        await _findRecentlyCreatedExpenseId(
                                      date: _selectedDate,
                                      description: description,
                                      amount: amount,
                                      storeName: _storeController.text.trim(),
                                      vendorName: _vendorController.text.trim(),
                                    );

                                    await SupabaseService.instance
                                        .attachReceiptToExpense(
                                      expenseId,
                                      {
                                        ...basePayload,
                                        ...receiptPayload,
                                      },
                                    );
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);
                                } catch (error) {
                                  _showErrorSnackBar(error);
                                }
                              },
                              child: Text(_tr('save')),
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

    _clearSelectedReceipt();

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('expense_added'))),
      );
      await _refresh();
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    if (_isClosedMonth(expense['date'])) {
      _showFiscalClosedSnackBar(_tr('cannot_edit_closed_month'));
      return;
    }

    _descController.text = (expense['description'] ?? '').toString();
    _amountController.text = (expense['amount'] ?? '').toString();
    _storeController.text = (expense['store_name'] ?? '').toString();
    _vendorController.text = (expense['vendor_name'] ?? '').toString();
    _notesController.text = (expense['notes'] ?? '').toString();

    final currentTaxRate = _parseDouble(expense['tax_rate']);
    _taxRateController.text = currentTaxRate <= 0
        ? ''
        : (currentTaxRate == currentTaxRate.roundToDouble()
            ? currentTaxRate.toStringAsFixed(0)
            : currentTaxRate.toStringAsFixed(1));

    _selectedDate =
        DateTime.tryParse((expense['date'] ?? '').toString()) ?? DateTime.now();
    _isCustomCategoryMode = false;
    _customCategoryController.clear();
    _category = _normalizeCategoryForUi((expense['category'] ?? 'other').toString());
    _taxType = _uiTaxInclusionType(
      (expense['tax_type'] ?? 'external').toString(),
    );
    _taxAmount = expense['tax_amount'] is num
        ? (expense['tax_amount'] as num).toDouble()
        : double.tryParse((expense['tax_amount'] ?? '0').toString()) ?? 0;
    _paymentMethod = _uiPaymentMethodValue(
      (expense['payment_method'] ?? 'cash').toString(),
    );
    _taxInclusionType = _uiTaxInclusionType(
      (expense['tax_inclusion_type'] ?? expense['tax_type'] ?? 'external')
          .toString(),
    );
    _clearSelectedReceipt();

    final existingReceiptUrl = (expense['receipt_url'] ?? '').toString();

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
                constraints: const BoxConstraints(
                  maxWidth: 560,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr('edit_expense'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _capturePhoto(setStateDialog),
                              icon: const Icon(Icons.camera_alt),
                              label: Text(_tr('take_photo')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickReceipt(setStateDialog),
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _selectedReceiptBytes != null
                                    ? _tr('change_file')
                                    : _tr('choose_file'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _descController,
                          decoration: _fieldDecoration(_tr('description')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _storeController,
                          decoration: _fieldDecoration(_tr('store')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration('${_tr('value')} (¥)'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: _fieldDecoration(_tr('category')),
                          items: _expenseCategoryItems()
                              .where((item) => item.value != _addCategoryValue)
                              .toList(),
                          onChanged: (value) async {
                            await _handleExpenseCategorySelection(value, setStateDialog);
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _tr('fiscal_basic_data'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vendorController,
                          decoration: _fieldDecoration(_tr('vendor')),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _fieldDecoration(_tr('payment_method')),
                          items: [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text(_tr('payment_cash')),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card',
                              child: Text(_tr('payment_credit_card')),
                            ),
                            DropdownMenuItem(
                              value: 'furikomi',
                              child: Text(_tr('payment_furikomi')),
                            ),
                            DropdownMenuItem(
                              value: 'paypay',
                              child: Text(_tr('payment_paypay')),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(_tr('payment_other')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _fieldDecoration(_tr('notes')),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _taxRateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration(_tr('tax_rate')),
                        ),
                        const SizedBox(height: 10),
                        _quickTaxRateButtons(setStateDialog),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _taxInclusionType,
                          decoration: _fieldDecoration(_tr('tax_type')),
                          items: [
                            DropdownMenuItem(
                              value: 'external',
                              child: Text(_tr('tax_external')),
                            ),
                            DropdownMenuItem(
                              value: 'inclusive',
                              child: Text(_tr('tax_inclusive')),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              _taxInclusionType = value ?? 'external';
                              _taxType = _taxInclusionType;
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
                                  '${_tr('date')}: ${_formatDate(_selectedDate.toIso8601String())}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectDate(setStateDialog),
                                child: Text(_tr('change')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _receiptSection(
                          setStateDialog: setStateDialog,
                          existingReceiptUrl: existingReceiptUrl,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext, false),
                              child: Text(_tr('cancel')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  final description = _descController.text.trim();
                                  final amount = double.tryParse(
                                    _amountController.text
                                        .trim()
                                        .replaceAll(',', '.'),
                                  );

                                  if (description.isEmpty ||
                                      amount == null ||
                                      amount <= 0) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(_tr('invalid_data')),
                                      ),
                                    );
                                    return;
                                  }

                                  if (_isClosedMonth(_selectedDate)) {
                                    _showFiscalClosedSnackBar(
                                      _tr('cannot_save_closed_month'),
                                    );
                                    return;
                                  }

                                  final basePayload = {
                                    'date': _selectedDate.toIso8601String(),
                                    'store_name': _storeController.text.trim(),
                                    'description': description,
                                    'category': _category,
                                    'amount': amount,
                                    'tax': _taxAmount,
                                    'tax_type':
                                        _dbTaxTypeFromInclusion(_taxInclusionType),
                                    'vendor_name': _vendorController.text.trim(),
                                    'payment_method': _paymentMethod,
                                    'notes': _notesController.text.trim(),
                                    'tax_rate':
                                        _parseDouble(_taxRateController.text),
                                    'tax_inclusion_type': _taxInclusionType,
                                  };

                                  await SupabaseService.instance.updateExpense(
                                    expense['id'].toString(),
                                    basePayload,
                                  );

                                  final receiptPayload =
                                      await _uploadSelectedReceiptIfNeeded();

                                  if (receiptPayload.isNotEmpty) {
                                    await SupabaseService.instance
                                        .attachReceiptToExpense(
                                      expense['id'].toString(),
                                      {
                                        ...basePayload,
                                        ...receiptPayload,
                                      },
                                    );
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(dialogContext, true);
                                } catch (error) {
                                  _showErrorSnackBar(error);
                                }
                              },
                              child: Text(_tr('save')),
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

    _clearSelectedReceipt();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr('expense_updated'))),
      );
      await _refresh();
    }
  }

  Future<void> _deleteExpense(String id, {dynamic expenseDate}) async {
    if (_isClosedMonth(expenseDate)) {
      _showFiscalClosedSnackBar(_tr('cannot_delete_closed_month'));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_tr('delete_expense_title')),
        content: Text(_tr('delete_expense_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SupabaseService.instance.deleteExpense(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('expense_deleted'))),
    );

    await _refresh();
  }

  bool _isReviewPending(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    return value.isEmpty ||
        value == 'pending' ||
        value == 'review_required' ||
        value == 'needs_review' ||
        value == 'review_pending';
  }

  bool _isReviewed(String? status) {
    final value = (status ?? '').trim().toLowerCase();
    return value == 'reviewed' ||
        value == 'approved' ||
        value == 'done' ||
        value == 'completed';
  }

  List<Map<String, dynamic>> _filteredExpenses() {
    if (_reviewFilter == 'all') return _expenses;

    return _expenses.where((expense) {
      final status = expense['review_status']?.toString();
      if (_reviewFilter == 'pending') {
        return _isReviewPending(status);
      }
      if (_reviewFilter == 'reviewed') {
        return _isReviewed(status);
      }
      return true;
    }).toList();
  }

  Widget _reviewFilterBar() {
    final filters = [
      ('all', _tr('filter_all')),
      ('pending', _tr('filter_review_pending')),
      ('reviewed', _tr('filter_reviewed')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('review_filter'),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filters.map((filter) {
            final selected = _reviewFilter == filter.$1;
            return ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _reviewFilter = filter.$1;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _expenseCard(Map<String, dynamic> expense) {
    final locked = _isClosedMonth(expense['date']);
    final description = (expense['description'] ?? '').toString();
    final category = _categoryLabel((expense['category'] ?? 'other').toString());
    final date = _formatDate(expense['date']);
    final amount = _formatYen(expense['amount']);
    final receipt = (expense['receipt_url'] ?? '').toString();
    final vendor = (expense['vendor_name'] ?? '').toString().trim();
    final paymentMethod =
        _paymentMethodLabel((expense['payment_method'] ?? 'other').toString());
    final taxRate = _formatTaxRate(expense['tax_rate']);
    final taxInclusion = _taxInclusionTypeLabel(
      (expense['tax_inclusion_type'] ?? 'external').toString(),
    );
    final notes = (expense['notes'] ?? '').toString().trim();

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
              description.isEmpty ? _tr('no_description') : description,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$date • $category',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (vendor.isNotEmpty) _chip('${_tr('vendor')}: $vendor'),
                _chip('${_tr('payment')}: $paymentMethod'),
                _chip('${_tr('tax')}: $taxRate'),
                _chip(taxInclusion),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${_tr('obs_short')}: $notes',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (receipt.isNotEmpty)
                  IconButton(
                    tooltip: _tr('view'),
                    icon: const Icon(
                      Icons.receipt_long,
                      color: Colors.green,
                    ),
                    onPressed: () => _showReceiptPreview(receipt),
                  ),
                if (locked)
                  Tooltip(
                    message: _tr('fiscal_month_closed'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.lock_outline,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                if (!locked)
                  IconButton(
                    tooltip: _tr('edit'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editExpense(expense),
                  ),
                if (!locked)
                  IconButton(
                    tooltip: _tr('delete'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteExpense(
                      expense['id'].toString(),
                      expenseDate: expense['date'],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 64,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              _tr('no_expenses_registered'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _tr('expenses_will_appear_here'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('expenses')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _tr('new_expense_tooltip'),
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
          : Builder(
              builder: (context) {
                final visibleExpenses = _filteredExpenses();

                if (_expenses.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_isCurrentMonthClosed()) ...[
                        _fiscalClosedBanner(),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _emptyState(),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleExpenses.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isCurrentMonthClosed()) ...[
                                _fiscalClosedBanner(),
                                const SizedBox(height: 16),
                              ],
                              _reviewFilterBar(),
                            ],
                          ),
                        );
                      }

                      if (visibleExpenses.isEmpty) {
                        return _emptyState();
                      }

                      final expense = Map<String, dynamic>.from(
                        visibleExpenses[index - 1],
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _expenseCard(expense),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
