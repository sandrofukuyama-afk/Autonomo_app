import 'package:flutter/material.dart';
import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

/// Página para registrar entradas de receita.
class EntriesPage extends StatefulWidget {
  const EntriesPage({super.key});

  @override
  State<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends State<EntriesPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedPaymentMethod;

  final List<String> _paymentMethodsKeys = const [
    'payment_cash',
    'payment_credit_card',
    'payment_bank_transfer',
    'payment_other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (_selectedDate == null ||
        _descController.text.isEmpty ||
        _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).translate('error_fill_fields'),
          ),
        ),
      );
      return;
    }

    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).translate('error_select_payment'),
          ),
        ),
      );
      return;
    }

    final double? amount = double.tryParse(_valueController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).translate('error_invalid_value'),
          ),
        ),
      );
      return;
    }

    final Map<String, dynamic> entry = {
      'description': _descController.text.trim(),
      'amount': amount,
      'date': _selectedDate!.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'payment_method': _selectedPaymentMethod,
      'category': 'service',
      'customer_name': null,
      'notes': null,
    };

    await SupabaseService.instance.addEntry(entry);

    _descController.clear();
    _valueController.clear();

    setState(() {
      _selectedDate = null;
      _selectedPaymentMethod = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).translate('entry_added'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: localizations.translate('description'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: localizations.translate('value'),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedPaymentMethod,
            decoration: InputDecoration(
              labelText: localizations.translate('payment_method'),
            ),
            items: _paymentMethodsKeys
                .map(
                  (methodKey) => DropdownMenuItem<String>(
                    value: methodKey,
                    child: Text(localizations.translate(methodKey)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDate == null
                      ? localizations.translate('no_date_selected')
                      : '${localizations.translate('date')}: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                ),
              ),
              ElevatedButton(
                onPressed: _selectDate,
                child: Text(localizations.translate('select_date')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveEntry,
            child: Text(localizations.translate('save')),
          ),
        ],
      ),
    );
  }
}
