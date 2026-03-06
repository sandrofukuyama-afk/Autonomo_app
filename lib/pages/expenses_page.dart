import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  String? _uploadedReceiptUrl;
  bool _ocrLoading = false;

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

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Selecionar origem'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedImage == null) return;

      setState(() {
        _receiptFile = pickedImage;
        _ocrLoading = true;
      });

      final Uint8List bytes = await pickedImage.readAsBytes();
      final String fileName = path.basename(pickedImage.name);

      final String uploadedUrl = await SupabaseService.instance.uploadReceipt(
        bytes,
        fileName,
      );

      final Uri endpoint = Uri.parse('${Uri.base.origin}/api/receipt-ocr');

      final response = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageUrl': uploadedUrl}),
      );

      if (response.statusCode != 200) {
        throw Exception('OCR HTTP ${response.statusCode}: ${response.body}');
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(response.body) as Map);

      if (data['success'] != true) {
        throw Exception((data['error'] ?? 'Erro no OCR').toString());
      }

      final dynamic amount = data['amount'];
      final dynamic date = data['date'];
      final dynamic store = data['store'];

      setState(() {
        _uploadedReceiptUrl = uploadedUrl;

        if (amount != null) {
          _valueController.text = amount.toString();
        }

        if (date != null && date.toString().trim().isNotEmpty) {
          _selectedDate = DateTime.tryParse(date.toString()) ?? _selectedDate;
        }

        if (_descController.text.trim().isEmpty &&
            store != null &&
            store.toString().trim().isNotEmpty) {
          _descController.text = store.toString().trim();
        }

        _ocrLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recibo lido com OCR com sucesso'),
        ),
      );
    } catch (e) {
      setState(() {
        _ocrLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar recibo: $e'),
        ),
      );
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

    final int? amount = int.tryParse(
      _valueController.text.replaceAll(',', '').trim(),
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

    final Map<String, dynamic> expense = {
      'description': _descController.text.trim(),
      'amount': amount,
      'date': _selectedDate!.toIso8601String().split('T').first,
      'category': _selectedCategory,
      'receipt_url': _uploadedReceiptUrl,
      'created_at': DateTime.now().toIso8601String(),
    };

    await SupabaseService.instance.addExpense(expense);

    _descController.clear();
    _valueController.clear();

    setState(() {
      _selectedDate = null;
      _selectedCategory = null;
      _receiptFile = null;
      _uploadedReceiptUrl = null;
      _ocrLoading = false;
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
            keyboardType: TextInputType.number,
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
                onPressed: _ocrLoading ? null : _pickReceipt,
                child: Text(
                  _ocrLoading
                      ? 'Lendo...'
                      : localizations.translate('select_receipt'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _ocrLoading ? null : _saveExpense,
            child: Text(localizations.translate('save')),
          ),
        ],
      ),
    );
  }
}
