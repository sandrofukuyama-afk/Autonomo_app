import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _companyId;
  String? _error;

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

  String _filingType = 'white_return';
  bool _invoiceRegistered = false;
  String _language = 'pt';
  String _currency = 'JPY';
  int _fiscalYearStartMonth = 1;

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
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final companyId = await AuthService.instance.getCurrentCompanyId();

      final data = await _client
          .from('app_settings')
          .select()
          .eq('company_id', companyId)
          .single();

      _companyId = companyId;
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
      _filingType = (data['filing_type'] ?? 'white_return').toString();
      _invoiceRegistered = data['invoice_registered'] == true;
      _language = (data['language'] ?? 'pt').toString();
      _currency = (data['currency'] ?? 'JPY').toString();
      _fiscalYearStartMonth = _toInt(data['fiscal_year_start_month'], 1);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _save() async {
    if (_companyId == null) return;

    if (_fullName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome completo.')),
      );
      return;
    }

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
        'occupation':
            _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
        'business_type': _businessType.text.trim().isEmpty
            ? null
            : _businessType.text.trim(),
        'filing_type': _filingType,
        'invoice_registered': _invoiceRegistered,
        'invoice_registration_no': _invoiceRegistered &&
                _invoiceNumber.text.trim().isNotEmpty
            ? _invoiceNumber.text.trim()
            : null,
        'language': _language,
        'currency': _currency,
        'fiscal_year_start_month': _fiscalYearStartMonth,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('company_id', _companyId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas com sucesso.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t.translate('settings'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.translate('settings'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Dados pessoais'),
          _field(label: 'Nome completo', controller: _fullName),
          _field(label: 'Nome exibido', controller: _displayName),
          _field(
            label: 'Telefone',
            controller: _phone,
            keyboardType: TextInputType.phone,
          ),
          _field(label: 'CEP', controller: _postalCode),
          _field(label: 'Província / Prefeitura', controller: _prefecture),
          _field(label: 'Cidade', controller: _city),
          _field(label: 'Endereço', controller: _address1),
          _field(label: 'Complemento', controller: _address2),
          const SizedBox(height: 16),
          _sectionTitle('Configuração fiscal'),
          DropdownButtonFormField<String>(
            value: _filingType,
            decoration: const InputDecoration(
              labelText: 'Tipo de declaração',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'white_return',
                child: Text('White Return'),
              ),
              DropdownMenuItem(
                value: 'blue_return',
                child: Text('Blue Return'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _filingType = value);
            },
          ),
          const SizedBox(height: 12),
          _field(label: 'Ocupação', controller: _occupation),
          _field(label: 'Tipo de negócio', controller: _businessType),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _invoiceRegistered,
            title: const Text('Emissor de invoice qualificado'),
            onChanged: (value) {
              setState(() => _invoiceRegistered = value);
            },
          ),
          if (_invoiceRegistered)
            _field(
              label: 'Número do invoice',
              controller: _invoiceNumber,
            ),
          const SizedBox(height: 16),
          _sectionTitle('Preferências'),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(
              labelText: 'Idioma',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'pt', child: Text('Português')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ja', child: Text('日本語')),
              DropdownMenuItem(value: 'es', child: Text('Español')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _language = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _fiscalYearStartMonth,
            decoration: const InputDecoration(
              labelText: 'Mês inicial do ano fiscal',
              border: OutlineInputBorder(),
            ),
            items: List.generate(12, (index) {
              final month = index + 1;
              return DropdownMenuItem<int>(
                value: month,
                child: Text(month.toString()),
              );
            }),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _fiscalYearStartMonth = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: const InputDecoration(
              labelText: 'Moeda',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'JPY', child: Text('JPY')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _currency = value);
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.translate('save_changes')),
            ),
          ),
        ],
      ),
    );
  }
}
