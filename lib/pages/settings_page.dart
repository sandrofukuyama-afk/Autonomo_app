import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  final Future<void> Function(Locale)? onLocaleChanged;

  const SettingsPage({
    super.key,
    this.onLocaleChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _submitted = false;
  bool _updatingFiscalLock = false;
  String? _companyId;

  final _fullName = TextEditingController();
  final _displayName = TextEditingController();
  final _phone = TextEditingController();
  final _postalCode = TextEditingController();
  final _prefecture = TextEditingController();
  final _city = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _occupation = TextEditingController();
  final _businessType = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _fiscalNotes = TextEditingController();

  String _language = 'pt';
  String _currency = 'JPY';
  String _filingType = 'white_return';
  String _consumptionTaxStatus = 'exempt';
  String _bookkeepingMethod = 'simple';
  int _fiscalYearStartMonth = 1;
  bool _invoiceRegistered = false;
  bool _handlesReducedTaxRate = true;
  bool _useTwoTenthsSpecialRule = false;
  List<String> _closedFiscalMonths = [];

  static const List<String> _supportedLanguages = ['pt', 'en', 'ja', 'es'];
  static const List<String> _supportedCurrencies = ['JPY'];
  static const List<String> _supportedFilingTypes = [
    'white_return',
    'blue_return',
  ];
  static const List<String> _supportedConsumptionTaxStatuses = [
    'exempt',
    'taxable',
  ];
  static const List<String> _supportedBookkeepingMethods = [
    'simple',
    'double_entry',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _displayName.dispose();
    _phone.dispose();
    _postalCode.dispose();
    _prefecture.dispose();
    _city.dispose();
    _address1.dispose();
    _address2.dispose();
    _occupation.dispose();
    _businessType.dispose();
    _invoiceNumber.dispose();
    _fiscalNotes.dispose();
    super.dispose();
  }

  String _text(String key, AppLocalizations t) {
    const custom = {
      'pt': {
        'page_title': 'Configurações',
        'page_subtitle':
            'Dados do autônomo, preferências do aplicativo e regras fiscais do Japão.',
        'section_personal': 'Dados pessoais',
        'section_personal_subtitle':
            'Informações básicas do titular que podem aparecer em relatórios e exportações.',
        'section_fiscal': 'Configuração fiscal',
        'section_fiscal_subtitle':
            'Defina o enquadramento fiscal e regras que impactam a escrituração.',
        'section_preferences': 'Preferências',
        'section_preferences_subtitle':
            'Idioma, moeda e início do ano fiscal usados no aplicativo.',
        'section_fiscal_lock': 'Fechamento fiscal',
        'section_fiscal_lock_subtitle':
            'Bloqueia alterações em meses já finalizados para manter consistência contábil.',
        'full_name': 'Nome completo',
        'display_name': 'Nome exibido',
        'phone': 'Telefone',
        'postal_code': 'CEP / Código postal',
        'prefecture': 'Província / Prefeitura',
        'city': 'Cidade',
        'address_line1': 'Endereço',
        'address_line2': 'Complemento',
        'occupation': 'Ocupação',
        'business_type': 'Tipo de negócio',
        'filing_type': 'Tipo de declaração',
        'filing_type_helper':
            'Escolha entre declaração branca ou azul para ajustar o comportamento fiscal.',
        'white_return': 'White Return',
        'blue_return': 'Blue Return',
        'consumption_tax_status': 'Status do imposto sobre consumo',
        'consumption_tax_status_helper':
            'Controle se o contribuinte está isento ou sujeito ao imposto sobre consumo.',
        'consumption_tax_exempt': 'Isento',
        'consumption_tax_taxable': 'Tributável',
        'bookkeeping_method': 'Método de escrituração',
        'bookkeeping_method_helper':
            'Use partidas dobradas quando mantiver contabilidade mais detalhada.',
        'bookkeeping_simple': 'Simples',
        'bookkeeping_double_entry': 'Partidas dobradas',
        'invoice_registered': 'Emissor de Invoice Qualificado',
        'invoice_registered_helper':
            'Ative apenas se estiver registrado no sistema japonês de Qualified Invoice.',
        'invoice_number': 'Número do Invoice',
        'handles_reduced_tax_rate': 'Usa taxa reduzida',
        'handles_reduced_tax_rate_helper':
            'Mostra que o negócio opera com itens sujeitos a alíquota reduzida.',
        'use_two_tenths_special_rule': 'Usar regra especial 2/10',
        'use_two_tenthsSpecial_rule_helper':
            'Habilite somente se essa regra especial realmente se aplicar ao seu caso.',
        'use_two_tenths_special_rule_helper':
            'Habilite somente se essa regra especial realmente se aplicar ao seu caso.',
        'fiscal_notes': 'Observações fiscais',
        'fiscal_notes_helper':
            'Use este campo para registrar observações importantes para o contador.',
        'language': 'Idioma do app',
        'currency': 'Moeda',
        'fiscal_year_start_month': 'Mês inicial do ano fiscal',
        'language_helper':
            'O idioma salvo aqui será usado como preferência padrão do aplicativo.',
        'currency_helper': 'No momento o app opera em iene japonês.',
        'fiscal_year_helper':
            'Defina o mês em que começa seu ano fiscal para relatórios futuros.',
        'save_success': 'Configurações salvas com sucesso.',
        'load_error': 'Erro ao carregar configurações:',
        'save_error': 'Erro ao salvar configurações:',
        'required_field': 'Campo obrigatório.',
        'invoice_required': 'Informe o número do invoice.',
        'postal_invalid': 'Informe um código postal válido.',
        'phone_invalid': 'Informe um telefone válido.',
        'save_button': 'Salvar configurações',
        'saving': 'Salvando...',
        'status_ready': 'Pronto para salvar',
        'status_review': 'Revise os campos obrigatórios',
        'language_pt': 'Português',
        'language_en': 'English',
        'language_ja': '日本語',
        'language_es': 'Español',
        'month_1': '1 - Janeiro',
        'month_2': '2 - Fevereiro',
        'month_3': '3 - Março',
        'month_4': '4 - Abril',
        'month_5': '5 - Maio',
        'month_6': '6 - Junho',
        'month_7': '7 - Julho',
        'month_8': '8 - Agosto',
        'month_9': '9 - Setembro',
        'month_10': '10 - Outubro',
        'month_11': '11 - Novembro',
        'month_12': '12 - Dezembro',
        'close_current_month': 'Fechar mês atual',
        'closed_months': 'Meses fechados',
        'no_closed_months': 'Nenhum mês fechado até o momento.',
        'reopen': 'Reabrir',
        'current_month': 'Mês atual',
        'fiscal_month_closed_success': 'Mês fechado com sucesso.',
        'fiscal_month_reopened_success': 'Mês reaberto com sucesso.',
        'fiscal_lock_error': 'Erro ao atualizar fechamento fiscal:',
      },
      'en': {
        'page_title': 'Settings',
        'page_subtitle':
            'Sole proprietor details, app preferences, and Japanese fiscal rules.',
        'section_personal': 'Personal information',
        'section_personal_subtitle':
            'Basic owner details that may appear in reports and exports.',
        'section_fiscal': 'Fiscal settings',
        'section_fiscal_subtitle':
            'Define the fiscal framework and rules that affect bookkeeping.',
        'section_preferences': 'Preferences',
        'section_preferences_subtitle':
            'Language, currency, and fiscal year settings used by the app.',
        'section_fiscal_lock': 'Fiscal lock',
        'section_fiscal_lock_subtitle':
            'Blocks changes to finalized months to keep accounting consistency.',
        'full_name': 'Full name',
        'display_name': 'Display name',
        'phone': 'Phone',
        'postal_code': 'Postal code',
        'prefecture': 'Prefecture',
        'city': 'City',
        'address_line1': 'Address',
        'address_line2': 'Address line 2',
        'occupation': 'Occupation',
        'business_type': 'Business type',
        'filing_type': 'Filing type',
        'filing_type_helper':
            'Choose between white return and blue return to adjust fiscal behavior.',
        'white_return': 'White Return',
        'blue_return': 'Blue Return',
        'consumption_tax_status': 'Consumption tax status',
        'consumption_tax_status_helper':
            'Set whether the taxpayer is exempt or subject to consumption tax.',
        'consumption_tax_exempt': 'Exempt',
        'consumption_tax_taxable': 'Taxable',
        'bookkeeping_method': 'Bookkeeping method',
        'bookkeeping_method_helper':
            'Use double-entry when you keep more detailed accounting records.',
        'bookkeeping_simple': 'Simple',
        'bookkeeping_double_entry': 'Double-entry',
        'invoice_registered': 'Qualified Invoice issuer',
        'invoice_registered_helper':
            'Enable this only if you are registered in Japan’s Qualified Invoice system.',
        'invoice_number': 'Invoice number',
        'handles_reduced_tax_rate': 'Uses reduced tax rate',
        'handles_reduced_tax_rate_helper':
            'Indicates that the business handles items subject to reduced tax rates.',
        'use_two_tenths_special_rule': 'Use special 2/10 rule',
        'use_two_tenths_special_rule_helper':
            'Enable only when this special rule actually applies to your case.',
        'fiscal_notes': 'Fiscal notes',
        'fiscal_notes_helper':
            'Use this field to store important notes for your accountant.',
        'language': 'App language',
        'currency': 'Currency',
        'fiscal_year_start_month': 'Fiscal year start month',
        'language_helper':
            'The language saved here will be used as the app default.',
        'currency_helper': 'The app currently operates in Japanese yen.',
        'fiscal_year_helper':
            'Set the month when your fiscal year starts for future reports.',
        'save_success': 'Settings saved successfully.',
        'load_error': 'Failed to load settings:',
        'save_error': 'Failed to save settings:',
        'required_field': 'Required field.',
        'invoice_required': 'Enter the invoice number.',
        'postal_invalid': 'Enter a valid postal code.',
        'phone_invalid': 'Enter a valid phone number.',
        'save_button': 'Save settings',
        'saving': 'Saving...',
        'status_ready': 'Ready to save',
        'status_review': 'Review required fields',
        'language_pt': 'Português',
        'language_en': 'English',
        'language_ja': '日本語',
        'language_es': 'Español',
        'month_1': '1 - January',
        'month_2': '2 - February',
        'month_3': '3 - March',
        'month_4': '4 - April',
        'month_5': '5 - May',
        'month_6': '6 - June',
        'month_7': '7 - July',
        'month_8': '8 - August',
        'month_9': '9 - September',
        'month_10': '10 - October',
        'month_11': '11 - November',
        'month_12': '12 - December',
        'close_current_month': 'Close current month',
        'closed_months': 'Closed months',
        'no_closed_months': 'No closed months yet.',
        'reopen': 'Reopen',
        'current_month': 'Current month',
        'fiscal_month_closed_success': 'Month closed successfully.',
        'fiscal_month_reopened_success': 'Month reopened successfully.',
        'fiscal_lock_error': 'Failed to update fiscal lock:',
      },
      'ja': {
        'page_title': '設定',
        'page_subtitle': '個人事業主の情報、アプリ設定、日本の税務ルールを管理します。',
        'section_personal': '個人情報',
        'section_personal_subtitle': 'レポートやエクスポートに表示される基本情報です。',
        'section_fiscal': '税務設定',
        'section_fiscal_subtitle': '記帳に影響する税務区分とルールを設定します。',
        'section_preferences': '環境設定',
        'section_preferences_subtitle': 'アプリで使う言語、通貨、会計年度の設定です。',
        'section_fiscal_lock': '会計締め',
        'section_fiscal_lock_subtitle':
            '締め済み月への変更をブロックし、会計の整合性を保ちます。',
        'full_name': '氏名',
        'display_name': '表示名',
        'phone': '電話番号',
        'postal_code': '郵便番号',
        'prefecture': '都道府県',
        'city': '市区町村',
        'address_line1': '住所',
        'address_line2': '建物名・補足',
        'occupation': '職業',
        'business_type': '事業種別',
        'filing_type': '申告区分',
        'filing_type_helper': '白色申告または青色申告を選択して税務挙動を調整します。',
        'white_return': '白色申告',
        'blue_return': '青色申告',
        'consumption_tax_status': '消費税区分',
        'consumption_tax_status_helper': '免税事業者か課税事業者かを設定します。',
        'consumption_tax_exempt': '免税',
        'consumption_tax_taxable': '課税',
        'bookkeeping_method': '記帳方式',
        'bookkeeping_method_helper': 'より詳細な帳簿を付ける場合は複式簿記を選択します。',
        'bookkeeping_simple': '簡易',
        'bookkeeping_double_entry': '複式簿記',
        'invoice_registered': '適格請求書発行事業者',
        'invoice_registered_helper':
            '日本の適格請求書発行事業者として登録済みの場合のみ有効にしてください。',
        'invoice_number': 'インボイス番号',
        'handles_reduced_tax_rate': '軽減税率を扱う',
        'handles_reduced_tax_rate_helper':
            '軽減税率対象の商品・サービスを扱う場合に有効にします。',
        'use_two_tenths_special_rule': '2割特例を使う',
        'use_two_tenths_special_rule_helper':
            '実際に2割特例の対象となる場合のみ有効にしてください。',
        'fiscal_notes': '税務メモ',
        'fiscal_notes_helper': '税理士向けの重要なメモを残せます。',
        'language': 'アプリ言語',
        'currency': '通貨',
        'fiscal_year_start_month': '会計年度の開始月',
        'language_helper': 'ここで保存した言語がアプリの既定言語になります。',
        'currency_helper': '現在、このアプリは日本円で運用されます。',
        'fiscal_year_helper': '将来のレポート用に会計年度の開始月を設定します。',
        'save_success': '設定を保存しました。',
        'load_error': '設定の読み込みエラー:',
        'save_error': '設定の保存エラー:',
        'required_field': '必須項目です。',
        'invoice_required': 'インボイス番号を入力してください。',
        'postal_invalid': '正しい郵便番号を入力してください。',
        'phone_invalid': '正しい電話番号を入力してください。',
        'save_button': '設定を保存',
        'saving': '保存中...',
        'status_ready': '保存可能',
        'status_review': '必須項目を確認してください',
        'language_pt': 'Português',
        'language_en': 'English',
        'language_ja': '日本語',
        'language_es': 'Español',
        'month_1': '1 - 1月',
        'month_2': '2 - 2月',
        'month_3': '3 - 3月',
        'month_4': '4 - 4月',
        'month_5': '5 - 5月',
        'month_6': '6 - 6月',
        'month_7': '7 - 7月',
        'month_8': '8 - 8月',
        'month_9': '9 - 9月',
        'month_10': '10 - 10月',
        'month_11': '11 - 11月',
        'month_12': '12 - 12月',
        'close_current_month': '今月を締める',
        'closed_months': '締め済み月',
        'no_closed_months': '締め済みの月はまだありません。',
        'reopen': '再開',
        'current_month': '今月',
        'fiscal_month_closed_success': '月を締めました。',
        'fiscal_month_reopened_success': '月を再開しました。',
        'fiscal_lock_error': '会計締めの更新エラー:',
      },
      'es': {
        'page_title': 'Configuración',
        'page_subtitle':
            'Datos del autónomo, preferencias de la app y reglas fiscales de Japón.',
        'section_personal': 'Datos personales',
        'section_personal_subtitle':
            'Información básica del titular que puede aparecer en reportes y exportaciones.',
        'section_fiscal': 'Configuración fiscal',
        'section_fiscal_subtitle':
            'Defina el encuadre fiscal y las reglas que afectan la contabilidad.',
        'section_preferences': 'Preferencias',
        'section_preferences_subtitle':
            'Idioma, moneda y configuración del año fiscal usados por la app.',
        'section_fiscal_lock': 'Cierre fiscal',
        'section_fiscal_lock_subtitle':
            'Bloquea cambios en meses ya finalizados para mantener consistencia contable.',
        'full_name': 'Nombre completo',
        'display_name': 'Nombre visible',
        'phone': 'Teléfono',
        'postal_code': 'Código postal',
        'prefecture': 'Prefectura',
        'city': 'Ciudad',
        'address_line1': 'Dirección',
        'address_line2': 'Complemento',
        'occupation': 'Ocupación',
        'business_type': 'Tipo de negocio',
        'filing_type': 'Tipo de declaración',
        'filing_type_helper':
            'Elija entre declaración blanca o azul para ajustar el comportamiento fiscal.',
        'white_return': 'White Return',
        'blue_return': 'Blue Return',
        'consumption_tax_status': 'Estado del impuesto al consumo',
        'consumption_tax_status_helper':
            'Defina si el contribuyente está exento o sujeto al impuesto al consumo.',
        'consumption_tax_exempt': 'Exento',
        'consumption_tax_taxable': 'Gravado',
        'bookkeeping_method': 'Método contable',
        'bookkeeping_method_helper':
            'Use partida doble cuando mantenga una contabilidad más detallada.',
        'bookkeeping_simple': 'Simple',
        'bookkeeping_double_entry': 'Partida doble',
        'invoice_registered': 'Emisor de Invoice Calificado',
        'invoice_registered_helper':
            'Actívelo solo si está registrado en el sistema japonés de Qualified Invoice.',
        'invoice_number': 'Número de Invoice',
        'handles_reduced_tax_rate': 'Usa tasa reducida',
        'handles_reduced_tax_rate_helper':
            'Indica que el negocio maneja artículos sujetos a tasa reducida.',
        'use_two_tenths_special_rule': 'Usar regla especial 2/10',
        'use_two_tenths_special_rule_helper':
            'Actívelo solo si esta regla especial realmente aplica a su caso.',
        'fiscal_notes': 'Notas fiscales',
        'fiscal_notes_helper':
            'Use este campo para guardar observaciones importantes para el contador.',
        'language': 'Idioma de la app',
        'currency': 'Moneda',
        'fiscal_year_start_month': 'Mes inicial del año fiscal',
        'language_helper':
            'El idioma guardado aquí se usará como preferencia predeterminada.',
        'currency_helper': 'Actualmente la app opera en yen japonés.',
        'fiscal_year_helper':
            'Defina el mes de inicio del año fiscal para los reportes futuros.',
        'save_success': 'Configuración guardada correctamente.',
        'load_error': 'Error al cargar la configuración:',
        'save_error': 'Error al guardar la configuración:',
        'required_field': 'Campo obligatorio.',
        'invoice_required': 'Ingrese el número de invoice.',
        'postal_invalid': 'Ingrese un código postal válido.',
        'phone_invalid': 'Ingrese un teléfono válido.',
        'save_button': 'Guardar configuración',
        'saving': 'Guardando...',
        'status_ready': 'Listo para guardar',
        'status_review': 'Revise los campos obligatorios',
        'language_pt': 'Português',
        'language_en': 'English',
        'language_ja': '日本語',
        'language_es': 'Español',
        'month_1': '1 - Enero',
        'month_2': '2 - Febrero',
        'month_3': '3 - Marzo',
        'month_4': '4 - Abril',
        'month_5': '5 - Mayo',
        'month_6': '6 - Junio',
        'month_7': '7 - Julio',
        'month_8': '8 - Agosto',
        'month_9': '9 - Septiembre',
        'month_10': '10 - Octubre',
        'month_11': '11 - Noviembre',
        'month_12': '12 - Diciembre',
        'close_current_month': 'Cerrar mes actual',
        'closed_months': 'Meses cerrados',
        'no_closed_months': 'Todavía no hay meses cerrados.',
        'reopen': 'Reabrir',
        'current_month': 'Mes actual',
        'fiscal_month_closed_success': 'Mes cerrado correctamente.',
        'fiscal_month_reopened_success': 'Mes reabierto correctamente.',
        'fiscal_lock_error': 'Error al actualizar el cierre fiscal:',
      },
    };

    final lang = custom[t.locale.languageCode] ?? custom['pt']!;
    return lang[key] ?? t.translate(key);
  }

  Future<void> _loadSettings() async {
    try {
      final companyId = await AuthService.instance.getCurrentCompanyId();
      _companyId = companyId;

      final data = await _client
          .from('app_settings')
          .select()
          .eq('company_id', companyId)
          .single();

      _fullName.text = (data['full_name'] ?? '').toString();
      _displayName.text = (data['display_name'] ?? '').toString();
      _phone.text = (data['phone'] ?? '').toString();
      _postalCode.text = (data['postal_code'] ?? '').toString();
      _prefecture.text = (data['prefecture'] ?? '').toString();
      _city.text = (data['city'] ?? '').toString();
      _address1.text = (data['address_line1'] ?? '').toString();
      _address2.text = (data['address_line2'] ?? '').toString();
      _occupation.text = (data['occupation'] ?? '').toString();
      _businessType.text = (data['business_type'] ?? '').toString();
      _invoiceNumber.text = (data['invoice_registration_no'] ?? '').toString();
      _fiscalNotes.text = (data['fiscal_notes'] ?? '').toString();

      _language = _normalizeString(
        data['language'],
        allowed: _supportedLanguages,
        fallback: 'pt',
      );
      _currency = _normalizeString(
        data['currency'],
        allowed: _supportedCurrencies,
        fallback: 'JPY',
      );
      _filingType = _normalizeString(
        data['filing_type'],
        allowed: _supportedFilingTypes,
        fallback: 'white_return',
      );
      _consumptionTaxStatus = _normalizeString(
        data['consumption_tax_status'],
        allowed: _supportedConsumptionTaxStatuses,
        fallback: 'exempt',
      );
      _bookkeepingMethod = _normalizeString(
        data['bookkeeping_method'],
        allowed: _supportedBookkeepingMethods,
        fallback: 'simple',
      );

      final monthValue = data['fiscal_year_start_month'];
      if (monthValue is int && monthValue >= 1 && monthValue <= 12) {
        _fiscalYearStartMonth = monthValue;
      } else if (monthValue is num) {
        final parsed = monthValue.toInt();
        if (parsed >= 1 && parsed <= 12) {
          _fiscalYearStartMonth = parsed;
        }
      }

      final closedRaw = data['closed_fiscal_months'];
      if (closedRaw is List) {
        _closedFiscalMonths = closedRaw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
          ..sort();
      }

      _invoiceRegistered = (data['invoice_registered'] ?? false) == true;
      _handlesReducedTaxRate =
          (data['handles_reduced_tax_rate'] ?? true) == true;
      _useTwoTenthsSpecialRule =
          (data['use_two_tenths_special_rule'] ?? false) == true;
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_text('load_error', t)} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _normalizeString(
    dynamic value, {
    required List<String> allowed,
    required String fallback,
  }) {
    final text = (value ?? '').toString();
    if (allowed.contains(text)) return text;
    return fallback;
  }

  bool get _isTaxable => _consumptionTaxStatus == 'taxable';

  String get _currentFiscalMonth {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  String _formatFiscalMonth(String fiscalMonth, AppLocalizations t) {
    final parts = fiscalMonth.split('-');
    if (parts.length != 2) return fiscalMonth;

    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return fiscalMonth;

    return '${parts[0]} · ${_text('month_$month', t)}';
  }

  String? _requiredValidator(String? value, AppLocalizations t) {
    if ((value ?? '').trim().isEmpty) {
      return _text('required_field', t);
    }
    return null;
  }

  String? _phoneValidator(String? value, AppLocalizations t) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final normalized = text.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalized.length < 8) {
      return _text('phone_invalid', t);
    }
    return null;
  }

  String? _postalValidator(String? value, AppLocalizations t) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final normalized = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.length < 5) {
      return _text('postal_invalid', t);
    }
    return null;
  }

  String? _invoiceValidator(String? value, AppLocalizations t) {
    if (!_invoiceRegistered) return null;
    if ((value ?? '').trim().isEmpty) {
      return _text('invoice_required', t);
    }
    return null;
  }

  Future<void> _closeCurrentMonth() async {
    final t = AppLocalizations.of(context);

    setState(() => _updatingFiscalLock = true);

    try {
      final fiscalMonth = _currentFiscalMonth;
      await SupabaseService.instance.closeFiscalMonth(fiscalMonth);

      if (!_closedFiscalMonths.contains(fiscalMonth)) {
        _closedFiscalMonths.add(fiscalMonth);
        _closedFiscalMonths.sort();
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text('fiscal_month_closed_success', t))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_text('fiscal_lock_error', t)} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingFiscalLock = false);
      }
    }
  }

  Future<void> _reopenFiscalMonth(String fiscalMonth) async {
    final t = AppLocalizations.of(context);

    setState(() => _updatingFiscalLock = true);

    try {
      await SupabaseService.instance.reopenFiscalMonth(fiscalMonth);
      _closedFiscalMonths.remove(fiscalMonth);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text('fiscal_month_reopened_success', t))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_text('fiscal_lock_error', t)} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingFiscalLock = false);
      }
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_companyId == null) return;

    setState(() => _saving = true);

    try {
      await _client.from('app_settings').update({
        'full_name': _fullName.text.trim(),
        'display_name': _displayName.text.trim().isEmpty
            ? null
            : _displayName.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'postal_code':
            _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim(),
        'prefecture':
            _prefecture.text.trim().isEmpty ? null : _prefecture.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'address_line1':
            _address1.text.trim().isEmpty ? null : _address1.text.trim(),
        'address_line2':
            _address2.text.trim().isEmpty ? null : _address2.text.trim(),
        'occupation': _occupation.text.trim(),
        'business_type':
            _businessType.text.trim().isEmpty ? null : _businessType.text.trim(),
        'language': _language,
        'currency': _currency,
        'fiscal_year_start_month': _fiscalYearStartMonth,
        'filing_type': _filingType,
        'consumption_tax_status': _consumptionTaxStatus,
        'invoice_registered': _invoiceRegistered,
        'invoice_registration_no':
            _invoiceRegistered ? _invoiceNumber.text.trim() : null,
        'handles_reduced_tax_rate': _isTaxable ? _handlesReducedTaxRate : false,
        'use_two_tenths_special_rule':
            _isTaxable ? _useTwoTenthsSpecialRule : false,
        'bookkeeping_method': _bookkeepingMethod,
        'fiscal_notes': _fiscalNotes.text.trim().isEmpty
            ? null
            : _fiscalNotes.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('company_id', _companyId!);

      if (widget.onLocaleChanged != null &&
          _supportedLanguages.contains(_language)) {
        await widget.onLocaleChanged!(Locale(_language));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text('save_success', t))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_text('save_error', t)} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _sectionHeader(
    BuildContext context,
    AppLocalizations t, {
    required IconData icon,
    required String titleKey,
    required String subtitleKey,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(titleKey, t),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _text(subtitleKey, t),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _field(
    AppLocalizations t, {
    required String labelKey,
    required TextEditingController controller,
    String? helperKey,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        decoration: InputDecoration(
          labelText: _text(labelKey, t),
          helperText: helperKey == null ? null : _text(helperKey, t),
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required AppLocalizations t,
    required String labelKey,
    String? helperKey,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: _text(labelKey, t),
          helperText: helperKey == null ? null : _text(helperKey, t),
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _switchTile(
    BuildContext context,
    AppLocalizations t, {
    required String titleKey,
    required String helperKey,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
        child: SwitchListTile.adaptive(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          value: value,
          title: Text(_text(titleKey, t)),
          subtitle: Text(_text(helperKey, t)),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _languageItems(AppLocalizations t) {
    return [
      DropdownMenuItem(value: 'pt', child: Text(_text('language_pt', t))),
      DropdownMenuItem(value: 'en', child: Text(_text('language_en', t))),
      DropdownMenuItem(value: 'ja', child: Text(_text('language_ja', t))),
      DropdownMenuItem(value: 'es', child: Text(_text('language_es', t))),
    ];
  }

  List<DropdownMenuItem<int>> _monthItems(AppLocalizations t) {
    return List.generate(
      12,
      (index) => DropdownMenuItem<int>(
        value: index + 1,
        child: Text(_text('month_${index + 1}', t)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentMonthClosed = _closedFiscalMonths.contains(_currentFiscalMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(_text('page_title', t)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('page_title', t),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text('page_subtitle', t),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _formKey.currentState?.validate() == false && _submitted
                              ? _text('status_review', t)
                              : _text('status_ready', t),
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.language, size: 18),
                        label: Text(_language.toUpperCase()),
                      ),
                      Chip(
                        avatar: const Icon(Icons.currency_yen, size: 18),
                        label: Text(_currency),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard([
              _sectionHeader(
                context,
                t,
                icon: Icons.person_outline,
                titleKey: 'section_personal',
                subtitleKey: 'section_personal_subtitle',
              ),
              const SizedBox(height: 16),
              _field(
                t,
                labelKey: 'full_name',
                controller: _fullName,
                validator: (value) => _requiredValidator(value, t),
              ),
              _field(
                t,
                labelKey: 'display_name',
                controller: _displayName,
              ),
              _field(
                t,
                labelKey: 'phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: (value) => _phoneValidator(value, t),
              ),
              _field(
                t,
                labelKey: 'postal_code',
                controller: _postalCode,
                keyboardType: TextInputType.text,
                validator: (value) => _postalValidator(value, t),
              ),
              _field(
                t,
                labelKey: 'prefecture',
                controller: _prefecture,
              ),
              _field(
                t,
                labelKey: 'city',
                controller: _city,
              ),
              _field(
                t,
                labelKey: 'address_line1',
                controller: _address1,
              ),
              _field(
                t,
                labelKey: 'address_line2',
                controller: _address2,
              ),
            ]),
            const SizedBox(height: 12),
            _buildCard([
              _sectionHeader(
                context,
                t,
                icon: Icons.receipt_long_outlined,
                titleKey: 'section_fiscal',
                subtitleKey: 'section_fiscal_subtitle',
              ),
              const SizedBox(height: 16),
              _dropdown<String>(
                t: t,
                labelKey: 'filing_type',
                helperKey: 'filing_type_helper',
                value: _filingType,
                items: [
                  DropdownMenuItem(
                    value: 'white_return',
                    child: Text(_text('white_return', t)),
                  ),
                  DropdownMenuItem(
                    value: 'blue_return',
                    child: Text(_text('blue_return', t)),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _filingType = value);
                },
              ),
              _dropdown<String>(
                t: t,
                labelKey: 'consumption_tax_status',
                helperKey: 'consumption_tax_status_helper',
                value: _consumptionTaxStatus,
                items: [
                  DropdownMenuItem(
                    value: 'exempt',
                    child: Text(_text('consumption_tax_exempt', t)),
                  ),
                  DropdownMenuItem(
                    value: 'taxable',
                    child: Text(_text('consumption_tax_taxable', t)),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _consumptionTaxStatus = value;
                    if (!_isTaxable) {
                      _handlesReducedTaxRate = false;
                      _useTwoTenthsSpecialRule = false;
                    }
                  });
                },
              ),
              _dropdown<String>(
                t: t,
                labelKey: 'bookkeeping_method',
                helperKey: 'bookkeeping_method_helper',
                value: _bookkeepingMethod,
                items: [
                  DropdownMenuItem(
                    value: 'simple',
                    child: Text(_text('bookkeeping_simple', t)),
                  ),
                  DropdownMenuItem(
                    value: 'double_entry',
                    child: Text(_text('bookkeeping_double_entry', t)),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _bookkeepingMethod = value);
                },
              ),
              _field(
                t,
                labelKey: 'occupation',
                controller: _occupation,
                validator: (value) => _requiredValidator(value, t),
              ),
              _field(
                t,
                labelKey: 'business_type',
                controller: _businessType,
              ),
              _switchTile(
                context,
                t,
                titleKey: 'invoice_registered',
                helperKey: 'invoice_registered_helper',
                value: _invoiceRegistered,
                onChanged: (value) {
                  setState(() {
                    _invoiceRegistered = value;
                    if (!value) {
                      _invoiceNumber.clear();
                    }
                  });
                },
              ),
              if (_invoiceRegistered)
                _field(
                  t,
                  labelKey: 'invoice_number',
                  controller: _invoiceNumber,
                  validator: (value) => _invoiceValidator(value, t),
                ),
              if (_isTaxable) ...[
                _switchTile(
                  context,
                  t,
                  titleKey: 'handles_reduced_tax_rate',
                  helperKey: 'handles_reduced_tax_rate_helper',
                  value: _handlesReducedTaxRate,
                  onChanged: (value) {
                    setState(() => _handlesReducedTaxRate = value);
                  },
                ),
                _switchTile(
                  context,
                  t,
                  titleKey: 'use_two_tenths_special_rule',
                  helperKey: 'use_two_tenths_special_rule_helper',
                  value: _useTwoTenthsSpecialRule,
                  onChanged: (value) {
                    setState(() => _useTwoTenthsSpecialRule = value);
                  },
                ),
              ],
              _field(
                t,
                labelKey: 'fiscal_notes',
                helperKey: 'fiscal_notes_helper',
                controller: _fiscalNotes,
                maxLines: 4,
              ),
            ]),
            const SizedBox(height: 12),
            _buildCard([
              _sectionHeader(
                context,
                t,
                icon: Icons.tune_outlined,
                titleKey: 'section_preferences',
                subtitleKey: 'section_preferences_subtitle',
              ),
              const SizedBox(height: 16),
              _dropdown<String>(
                t: t,
                labelKey: 'language',
                helperKey: 'language_helper',
                value: _language,
                items: _languageItems(t),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _language = value);
                },
              ),
              _dropdown<String>(
                t: t,
                labelKey: 'currency',
                helperKey: 'currency_helper',
                value: _currency,
                items: const [
                  DropdownMenuItem(value: 'JPY', child: Text('JPY')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _currency = value);
                },
              ),
              _dropdown<int>(
                t: t,
                labelKey: 'fiscal_year_start_month',
                helperKey: 'fiscal_year_helper',
                value: _fiscalYearStartMonth,
                items: _monthItems(t),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _fiscalYearStartMonth = value);
                },
              ),
            ]),
            const SizedBox(height: 12),
            _buildCard([
              _sectionHeader(
                context,
                t,
                icon: Icons.lock_outline,
                titleKey: 'section_fiscal_lock',
                subtitleKey: 'section_fiscal_lock_subtitle',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_text('current_month', t)}: ${_formatFiscalMonth(_currentFiscalMonth, t)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      currentMonthClosed ? Icons.lock : Icons.lock_open,
                      size: 18,
                    ),
                    label: Text(
                      currentMonthClosed ? '🔒' : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_updatingFiscalLock || currentMonthClosed)
                    ? null
                    : _closeCurrentMonth,
                icon: const Icon(Icons.lock),
                label: Text(_text('close_current_month', t)),
              ),
              const SizedBox(height: 16),
              Text(
                _text('closed_months', t),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (_closedFiscalMonths.isEmpty)
                Text(
                  _text('no_closed_months', t),
                  style: theme.textTheme.bodySmall,
                )
              else
                Column(
                  children: _closedFiscalMonths.map((month) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_formatFiscalMonth(month, t)),
                          ),
                          TextButton(
                            onPressed: _updatingFiscalLock
                                ? null
                                : () => _reopenFiscalMonth(month),
                            child: Text(_text('reopen', t)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ]),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(_text('saving', t)),
                      ],
                    )
                  : Text(_text('save_button', t)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
