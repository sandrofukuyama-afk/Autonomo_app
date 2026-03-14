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

      _filingType = (data['filing_type'] ?? 'white_return').toString();
      _invoiceRegistered = (data['invoice_registered'] ?? false) == true;
      _invoiceNumber.text = (data['invoice_registration_no'] ?? '').toString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configurações: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_companyId == null) return;

    setState(() => _saving = true);

    try {
      await _client.from('app_settings').update({
        'full_name': _fullName.text.trim(),
        'display_name': _displayName.text.trim(),
        'phone': _phone.text.trim(),
        'postal_code': _postalCode.text.trim(),
        'prefecture': _prefecture.text.trim(),
        'city': _city.text.trim(),
        'address_line1': _address1.text.trim(),
        'address_line2': _address2.text.trim(),
        'occupation': _occupation.text.trim(),
        'business_type': _businessType.text.trim(),
        'filing_type': _filingType,
        'invoice_registered': _invoiceRegistered,
        'invoice_registration_no':
            _invoiceRegistered ? _invoiceNumber.text.trim() : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('company_id', _companyId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar configurações: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dados pessoais',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _field('Nome completo', _fullName),
          _field('Nome exibido', _displayName),
          _field('Telefone', _phone),
          _field('CEP', _postalCode),
          _field('Província / Prefeitura', _prefecture),
          _field('Cidade', _city),
          _field('Endereço', _address1),
          _field('Complemento', _address2),
          const SizedBox(height: 24),
          const Text(
            'Dados fiscais',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
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
          _field('Ocupação', _occupation),
          _field('Tipo de negócio', _businessType),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _invoiceRegistered,
            title: const Text('Emissor de Invoice Qualificado'),
            onChanged: (value) {
              setState(() => _invoiceRegistered = value);
            },
          ),
          if (_invoiceRegistered)
            _field('Número do Invoice', _invoiceNumber),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
