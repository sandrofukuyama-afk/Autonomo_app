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

  ExpenseInputMode? _mode;

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

  String _uiText(BuildContext context, String key) {
    final lang = Localizations.localeOf(context).languageCode;

    const pt = {
      'title': 'Adicionar despesa',
      'subtitle':
          'Escolha como deseja registrar a despesa. O ideal é escanear o recibo para preencher automaticamente.',
      'scan_title': 'Escanear recibo',
      'scan_subtitle': 'Tire foto ou escolha uma imagem para preencher dados automaticamente.',
      'manual_title': 'Inserir manualmente',
      'manual_subtitle': 'Preencha os campos manualmente sem usar OCR.',
      'ocr_success': 'Recibo lido com OCR com sucesso',
      'ocr_error': 'Erro ao processar recibo',
      'receipt_source': 'Selecionar origem',
      'camera': 'Câmera',
      'gallery': 'Galeria',
      'processing': 'Lendo recibo...',
      'form_title': 'Dados da despesa',
      'save': 'Salvar despesa',
    };

    const en = {
      'title': 'Add expense',
      'subtitle':
          'Choose how you want to register the expense. The best option is scanning the receipt for auto-fill.',
      'scan_title': 'Scan receipt',
      'scan_subtitle': 'Take a photo or choose an image to auto-fill the fields.',
      'manual_title': 'Enter manually',
      'manual_subtitle': 'Fill the fields manually without OCR.',
      'ocr_success': 'Receipt processed successfully with OCR',
      'ocr_error': 'Error processing receipt',
      'receipt_source': 'Select source',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'processing': 'Reading receipt...',
      'form_title': 'Expense details',
      'save': 'Save expense',
    };

    const ja = {
      'title': '経費を追加',
      'subtitle':
          '登録方法を選択してください。自動入力のため、領収書スキャンがおすすめです。',
      'scan_title': '領収書をスキャン',
      'scan_subtitle': '写真を撮るか画像を選んで自動入力します。',
      'manual_title': '手動入力',
      'manual_subtitle': 'OCRを使わず手動で入力します。',
      'ocr_success': 'OCRで領収書を正常に読み取りました',
      'ocr_error': '領収書の処理エラー',
      'receipt_source': '取得方法を選択',
      'camera': 'カメラ',
      'gallery': 'ギャラリー',
      'processing': '領収書を読み取り中...',
      'form_title': '経費データ',
      'save': '経費を保存',
    };

    const es = {
      'title': 'Agregar gasto',
      'subtitle':
          'Elige cómo deseas registrar el gasto. Lo ideal es escanear el recibo para completar automáticamente.',
      'scan_title': 'Escanear recibo',
      'scan_subtitle': 'Toma una foto o elige una imagen para completar automáticamente.',
      'manual_title': 'Ingresar manualmente',
      'manual_subtitle': 'Completa los campos manualmente sin OCR.',
      'ocr_success': 'Recibo leído correctamente con OCR',
      'ocr_error': 'Error al procesar el recibo',
      'receipt_source': 'Seleccionar origen',
      'camera': 'Cámara',
      'gallery': 'Galería',
      'processing': 'Leyendo recibo...',
      'form_title': 'Datos del gasto',
      'save': 'Guardar gasto',
    };

    final map = switch (lang) {
      'en' => en,
      'ja' => ja,
      'es' => es,
      _ => pt,
    };

    return map[key] ?? key;
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

  Future<void> _startManualMode() async {
    setState(() {
      _mode = ExpenseInputMode.manual;
    });
  }

  Future<void> _startReceiptScan() async {
    setState(() {
      _mode = ExpenseInputMode.scan;
    });

    final ImagePicker picker = ImagePicker();

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(_uiText(context, 'receipt_source')),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(_uiText(context, 'camera')),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(_uiText(context, 'gallery')),
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
        SnackBar(
          content: Text(_uiText(context, 'ocr_success')),
        ),
      );
    } catch (e) {
      setState(() {
        _ocrLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_uiText(context, 'ocr_error')}: $e'),
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
      _mode = null;
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
          Text(
            _uiText(context, 'title'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _uiText(context, 'subtitle'),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _ModeCard(
            icon: Icons.document_scanner_outlined,
            title: _uiText(context, 'scan_title'),
            subtitle: _uiText(context, 'scan_subtitle'),
            isActive: _mode == ExpenseInputMode.scan,
            onTap: _ocrLoading ? null : _startReceiptScan,
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.edit_note_outlined,
            title: _uiText(context, 'manual_title'),
            subtitle: _uiText(context, 'manual_subtitle'),
            isActive: _mode == ExpenseInputMode.manual,
            onTap: _ocrLoading ? null : _startManualMode,
          ),
          const SizedBox(height: 20),
          if (_ocrLoading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _uiText(context, 'processing'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_mode != null) ...[
            const SizedBox(height: 20),
            Text(
              _uiText(context, 'form_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
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
            if (_receiptFile != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '${localizations.translate('receipt')}: ${path.basename(_receiptFile!.name)}',
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _ocrLoading ? null : _saveExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_uiText(context, 'save')),
            ),
          ],
        ],
      ),
    );
  }
}

enum ExpenseInputMode {
  scan,
  manual,
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isActive ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB);
    final backgroundColor =
        isActive ? const Color(0xFFEFF6FF) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isActive
                    ? Icons.check_circle
                    : Icons.arrow_forward_ios_rounded,
                size: isActive ? 24 : 18,
                color: isActive
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
