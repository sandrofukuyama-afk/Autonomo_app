import 'package:flutter/material.dart';

/// A simple localization class that provides translated strings for the
/// supported languages of the application. This implementation uses an
/// internal map to store translations for each supported locale. To add
/// translations for a new string, add the key with its translations to
/// the `_localizedValues` map below. The `translate` method looks up
/// the current locale's translation for the given key and falls back to
/// the key itself when no translation is found. This allows missing
/// translations to be easily spotted during development.
class AppLocalizations {
  /// The locale that this instance should provide translations for.
  final Locale locale;

  AppLocalizations(this.locale);

  /// A map containing all localized strings for each supported language.
  ///
  /// Keys represent a logical identifier for the string (e.g. `description`,
  /// `value`) and values are the translated string in the specified
  /// language. Add entries here for new strings you wish to localize.
  static const Map<String, Map<String, String>> _localizedValues = {
    'pt': {
      'description': 'Descrição',
      'value': 'Valor',
      'payment_method': 'Método de pagamento',
      'payment_cash': 'Dinheiro',
      'payment_credit_card': 'Cartão de crédito',
      'payment_bank_transfer': 'Transferência bancária',
      'payment_other': 'Outro',
      'no_date_selected': 'Nenhuma data selecionada',
      'date': 'Data',
      'select_date': 'Selecionar data',
      'save': 'Salvar',
      'error_fill_fields': 'Preencha todos os campos',
      'error_fill_mandatory_fields': 'Preencha todos os campos obrigatórios',
      'error_select_payment': 'Selecione o método de pagamento',
      'error_invalid_value': 'Valor inválido',
      'entry_added': 'Entrada adicionada!',
      'expense_added': 'Despesa adicionada!',
      'category': 'Categoria',
      'category_food': 'Alimentação',
      'category_transport': 'Transporte',
      'category_housing': 'Moradia',
      'category_entertainment': 'Entretenimento',
      'category_health': 'Saúde',
      'category_other': 'Outros',
      'no_receipt_selected': 'Nenhum recibo selecionado',
      'receipt': 'Recibo',
      'select_receipt': 'Selecionar recibo',
      'monthly_report': 'Relatório Mensal',
      'annual_report': 'Relatório Anual',
      'income': 'Entradas',
      'expenses': 'Saídas',
      'balance': 'Saldo',

      // Navigation bar labels
      'nav_home': 'Início',
      'nav_entries': 'Entradas',
      'nav_expenses': 'Saídas',
      'nav_reports': 'Relatórios',

      // Language selection and names
      'select_language': 'Idioma',
      'lang_pt': 'Português',
      'lang_en': 'Inglês',
      'lang_ja': 'Japonês',
      'lang_es': 'Espanhol',
      'settings': 'Configurações',
      'app_settings': 'Configurações do aplicativo',
      'language_settings_description': 'Escolha o idioma exibido no aplicativo.',
      'save_changes': 'Salvar alterações',
      'cancel': 'Cancelar',
      'language_updated': 'Idioma atualizado com sucesso.',
    },
    'en': {
      'description': 'Description',
      'value': 'Amount',
      'payment_method': 'Payment Method',
      'payment_cash': 'Cash',
      'payment_credit_card': 'Credit Card',
      'payment_bank_transfer': 'Bank Transfer',
      'payment_other': 'Other',
      'no_date_selected': 'No date selected',
      'date': 'Date',
      'select_date': 'Select date',
      'save': 'Save',
      'error_fill_fields': 'Please fill in all fields',
      'error_fill_mandatory_fields': 'Please fill in all mandatory fields',
      'error_select_payment': 'Please select a payment method',
      'error_invalid_value': 'Invalid value',
      'entry_added': 'Income added!',
      'expense_added': 'Expense added!',
      'category': 'Category',
      'category_food': 'Food',
      'category_transport': 'Transport',
      'category_housing': 'Housing',
      'category_entertainment': 'Entertainment',
      'category_health': 'Health',
      'category_other': 'Other',
      'no_receipt_selected': 'No receipt selected',
      'receipt': 'Receipt',
      'select_receipt': 'Select receipt',
      'monthly_report': 'Monthly Report',
      'annual_report': 'Annual Report',
      'income': 'Income',
      'expenses': 'Expenses',
      'balance': 'Balance',

      // Navigation bar labels
      'nav_home': 'Home',
      'nav_entries': 'Income',
      'nav_expenses': 'Expenses',
      'nav_reports': 'Reports',

      // Language selection and names
      'select_language': 'Language',
      'lang_pt': 'Portuguese',
      'lang_en': 'English',
      'lang_ja': 'Japanese',
      'lang_es': 'Spanish',
      'settings': 'Settings',
      'app_settings': 'App Settings',
      'language_settings_description': 'Choose the language shown in the application.',
      'save_changes': 'Save changes',
      'cancel': 'Cancel',
      'language_updated': 'Language updated successfully.',
    },
    'ja': {
      'description': '説明',
      'value': '金額',
      'payment_method': '支払い方法',
      'payment_cash': '現金',
      'payment_credit_card': 'クレジットカード',
      'payment_bank_transfer': '銀行振込',
      'payment_other': 'その他',
      'no_date_selected': '日付が選択されていません',
      'date': '日付',
      'select_date': '日付を選択',
      'save': '保存',
      'error_fill_fields': 'すべてのフィールドを入力してください',
      'error_fill_mandatory_fields': '必須項目を入力してください',
      'error_select_payment': '支払い方法を選択してください',
      'error_invalid_value': '無効な金額',
      'entry_added': '収入が追加されました！',
      'expense_added': '支出が追加されました！',
      'category': 'カテゴリ',
      'category_food': '食費',
      'category_transport': '交通費',
      'category_housing': '住宅費',
      'category_entertainment': '娯楽',
      'category_health': '医療費',
      'category_other': 'その他',
      'no_receipt_selected': '領収書が選択されていません',
      'receipt': '領収書',
      'select_receipt': '領収書を選択',
      'monthly_report': '月次レポート',
      'annual_report': '年次レポート',
      'income': '収入',
      'expenses': '支出',
      'balance': '残高',

      // Navigation bar labels
      'nav_home': 'ホーム',
      'nav_entries': '収入',
      'nav_expenses': '支出',
      'nav_reports': 'レポート',

      // Language selection and names
      'select_language': '言語',
      'lang_pt': 'ポルトガル語',
      'lang_en': '英語',
      'lang_ja': '日本語',
      'lang_es': 'スペイン語',
      'settings': '設定',
      'app_settings': 'アプリ設定',
      'language_settings_description': 'アプリに表示する言語を選択してください。',
      'save_changes': '変更を保存',
      'cancel': 'キャンセル',
      'language_updated': '言語が更新されました。',
    },
    'es': {
      'description': 'Descripción',
      'value': 'Valor',
      'payment_method': 'Método de pago',
      'payment_cash': 'Efectivo',
      'payment_credit_card': 'Tarjeta de crédito',
      'payment_bank_transfer': 'Transferencia bancaria',
      'payment_other': 'Otro',
      'no_date_selected': 'No se ha seleccionado fecha',
      'date': 'Fecha',
      'select_date': 'Seleccionar fecha',
      'save': 'Guardar',
      'error_fill_fields': 'Por favor complete todos los campos',
      'error_fill_mandatory_fields': 'Complete todos los campos obligatorios',
      'error_select_payment': 'Seleccione el método de pago',
      'error_invalid_value': 'Valor inválido',
      'entry_added': 'Ingreso agregado!',
      'expense_added': 'Gasto agregado!',
      'category': 'Categoría',
      'category_food': 'Alimentación',
      'category_transport': 'Transporte',
      'category_housing': 'Vivienda',
      'category_entertainment': 'Entretenimiento',
      'category_health': 'Salud',
      'category_other': 'Otros',
      'no_receipt_selected': 'No se ha seleccionado recibo',
      'receipt': 'Recibo',
      'select_receipt': 'Seleccionar recibo',
      'monthly_report': 'Informe Mensual',
      'annual_report': 'Informe Anual',
      'income': 'Ingresos',
      'expenses': 'Gastos',
      'balance': 'Saldo',

      // Navigation bar labels
      'nav_home': 'Inicio',
      'nav_entries': 'Ingresos',
      'nav_expenses': 'Gastos',
      'nav_reports': 'Informes',

      // Language selection and names
      'select_language': 'Idioma',
      'lang_pt': 'Portugués',
      'lang_en': 'Inglés',
      'lang_ja': 'Japonés',
      'lang_es': 'Español',
      'settings': 'Configuración',
      'app_settings': 'Configuración de la aplicación',
      'language_settings_description': 'Elija el idioma que se mostrará en la aplicación.',
      'save_changes': 'Guardar cambios',
      'cancel': 'Cancelar',
      'language_updated': 'Idioma actualizado correctamente.',
    },
  };

  /// Returns the translated string for the given key. If no translation
  /// exists for the current locale, the key itself is returned as a fallback.
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  /// Shortcut to access the localization from the widget tree.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// A localization delegate that instantiates `AppLocalizations` for
  /// supported locales.
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['pt', 'en', 'ja', 'es'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
