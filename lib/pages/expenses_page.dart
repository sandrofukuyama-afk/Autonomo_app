import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedCategory;
  XFile? _receiptFile;

  final List<String> _categoryKeys = const [
    'category_food',
    'category_transport',
    'category_housing',
    'category_entertainment',
    'category_health',
    'category_other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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

  Future<void> _pickReceipt() async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedImage != null) {
      setState(() {
        _receiptFile = pickedImage;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_selectedDate == null ||
        _descController.text.isEmpty ||
        _valueController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .translate('error_fill_mandatory_fields'),
          ),
        ),
      );
      return;
    }

    final double? amount = double.tryParse(
      _valueController.text.replaceAll(',', '.'),
    );

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

    String? uploadedReceiptUrl;

    if (_receiptFile != null) {
      final Uint8List bytes = await _receiptFile!.readAsBytes();
      final String fileName = path.basename(_receiptFile!.name);

      uploadedReceiptUrl = await SupabaseService.instance.uploadReceipt(
        bytes,
        fileName,
      );
    }

    final Map<String, dynamic> expense = {
      'description': _descController.text.trim(),
      'amount': amount,
      'date': _selectedDate!.toIso8601String().split('T').first,
      'category': _selectedCategory,
      'receipt_url': uploadedReceiptUrl,
      'created_at': DateTime.now().toIso8601String(),
    };

    await SupabaseService.instance.addExpense(expense);

    _descController.clear();
    _valueController.clear();

    setState(() {
      _selectedDate = null;
      _selectedCategory = null;
      _receiptFile = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).translate('expense_added'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: localizations.translate('category'),
            ),
            items: _categoryKeys
                .map(
                  (key) => DropdownMenuItem<String>(
                    value: key,
                    child: Text(localizations.translate(key)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
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
                onPressed: _pickDate,
                child: Text(localizations.translate('select_date')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _receiptFile == null
                    ? Text(localizations.translate('no_receipt_selected'))
                    : Text(
                        '${localizations.translate('receipt')}: ${path.basename(_receiptFile!.name)}',
                      ),
              ),
              ElevatedButton(
                onPressed: _pickReceipt,
                child: Text(localizations.translate('select_receipt')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveExpense,
            child: Text(localizations.translate('save')),
          ),
        ],
      ),
    );
  }
}
