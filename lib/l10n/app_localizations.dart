
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

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
      'cancel': 'Cancelar',
      'error_fill_fields': 'Preencha todos os campos',
      'error_fill_mandatory_fields': 'Preencha todos os campos obrigatórios',
      'error_select_payment': 'Selecione o método de pagamento',
      'error_invalid_value': 'Valor inválido',
      'entry_added': 'Entrada adicionada!',
      'entry_updated': 'Entrada atualizada!',
      'entry_deleted': 'Entrada excluída!',
      'expense_added': 'Despesa adicionada!',
      'category': 'Categoria',
      'new_entry': 'Nova entrada',
      'edit_entry': 'Editar entrada',
      'delete_entry': 'Excluir entrada',
      'confirm_delete_entry': 'Deseja realmente excluir esta entrada?',
      'no_entries_yet': 'Nenhuma entrada registrada',
      'entries_will_appear_here': 'As entradas cadastradas aparecerão aqui.',
      'new_category': 'Nova categoria',
      'register_new_category': 'Cadastrar nova categoria',
      'category_name': 'Nome da categoria',
      'enter_category_name': 'Informe o nome da categoria.',
      'fiscal_month_locked': 'Mês fiscal fechado',
      'fiscal_month_locked_description':
          'Novas entradas, edição e exclusão ficam bloqueadas para o mês atual.',
      'category_other': 'Outros',
      'income': 'Entradas',
      'expenses': 'Despesas',
      'balance': 'Saldo',
      'nav_home': 'Início',
      'nav_entries': 'Entradas',
      'nav_expenses': 'Despesas',
      'nav_reports': 'Relatórios',
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
      'cancel': 'Cancel',
      'error_fill_fields': 'Please fill in all fields',
      'error_fill_mandatory_fields': 'Please fill in all mandatory fields',
      'error_select_payment': 'Please select a payment method',
      'error_invalid_value': 'Invalid value',
      'entry_added': 'Income added!',
      'entry_updated': 'Income updated!',
      'entry_deleted': 'Income deleted!',
      'expense_added': 'Expense added!',
      'category': 'Category',
      'new_entry': 'New income',
      'edit_entry': 'Edit income',
      'delete_entry': 'Delete income',
      'confirm_delete_entry': 'Do you really want to delete this income?',
      'no_entries_yet': 'No income registered',
      'entries_will_appear_here': 'Your income records will appear here.',
      'new_category': 'New category',
      'register_new_category': 'Register new category',
      'category_name': 'Category name',
      'enter_category_name': 'Enter category name.',
      'fiscal_month_locked': 'Fiscal month closed',
      'fiscal_month_locked_description':
          'New income, edits and deletions are blocked for the current month.',
      'category_other': 'Other',
      'income': 'Income',
      'expenses': 'Expenses',
      'balance': 'Balance',
      'nav_home': 'Home',
      'nav_entries': 'Income',
      'nav_expenses': 'Expenses',
      'nav_reports': 'Reports',
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
      'cancel': 'キャンセル',
      'error_fill_fields': 'すべてのフィールドを入力してください',
      'error_fill_mandatory_fields': '必須項目を入力してください',
      'error_select_payment': '支払い方法を選択してください',
      'error_invalid_value': '無効な金額',
      'entry_added': '収入が追加されました',
      'entry_updated': '収入が更新されました',
      'entry_deleted': '収入が削除されました',
      'expense_added': '支出が追加されました',
      'category': 'カテゴリ',
      'new_entry': '新しい収入',
      'edit_entry': '収入を編集',
      'delete_entry': '収入を削除',
      'confirm_delete_entry': 'この収入を削除してもよろしいですか？',
      'no_entries_yet': '収入はまだ登録されていません',
      'entries_will_appear_here': '登録した収入がここに表示されます。',
      'new_category': '新しいカテゴリ',
      'register_new_category': 'カテゴリを追加',
      'category_name': 'カテゴリ名',
      'enter_category_name': 'カテゴリ名を入力してください。',
      'fiscal_month_locked': '会計月が締められました',
      'fiscal_month_locked_description':
          'この月は収入の追加・編集・削除ができません。',
      'category_other': 'その他',
      'income': '収入',
      'expenses': '支出',
      'balance': '残高',
      'nav_home': 'ホーム',
      'nav_entries': '収入',
      'nav_expenses': '支出',
      'nav_reports': 'レポート',
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
      'cancel': 'Cancelar',
      'error_fill_fields': 'Complete todos los campos',
      'error_fill_mandatory_fields': 'Complete todos los campos obligatorios',
      'error_select_payment': 'Seleccione el método de pago',
      'error_invalid_value': 'Valor inválido',
      'entry_added': '¡Ingreso agregado!',
      'entry_updated': '¡Ingreso actualizado!',
      'entry_deleted': '¡Ingreso eliminado!',
      'expense_added': '¡Gasto agregado!',
      'category': 'Categoría',
      'new_entry': 'Nuevo ingreso',
      'edit_entry': 'Editar ingreso',
      'delete_entry': 'Eliminar ingreso',
      'confirm_delete_entry': '¿Desea eliminar este ingreso?',
      'no_entries_yet': 'No hay ingresos registrados',
      'entries_will_appear_here': 'Los ingresos aparecerán aquí.',
      'new_category': 'Nueva categoría',
      'register_new_category': 'Registrar nueva categoría',
      'category_name': 'Nombre de la categoría',
      'enter_category_name': 'Ingrese el nombre de la categoría.',
      'fiscal_month_locked': 'Mes fiscal cerrado',
      'fiscal_month_locked_description':
          'No se pueden crear, editar ni eliminar ingresos este mes.',
      'category_other': 'Otros',
      'income': 'Ingresos',
      'expenses': 'Gastos',
      'balance': 'Saldo',
      'nav_home': 'Inicio',
      'nav_entries': 'Ingresos',
      'nav_expenses': 'Gastos',
      'nav_reports': 'Informes',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
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
