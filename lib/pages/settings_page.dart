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

  String _filingType = 'white_return';
  bool _invoiceRegistered = false;
  String? _invoiceNumber;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final companyId = await AuthService.instance.getCompanyId();

      if (companyId == null) {
        setState(() => _loading = false);
        return;
      }

      _companyId = companyId;

      final data = await _client
          .from('app_settings')
          .select()
          .eq('company_id', companyId)
          .single();

      _fullName.text = data['full_name'] ?? '';
      _displayName.text = data['display_name'] ?? '';
      _phone.text = data['phone'] ?? '';
      _postalCode.text = data['postal_code'] ?? '';
      _prefecture.text = data['prefecture'] ?? '';
      _city.text = data['city'] ?? '';
      _address1.text = data['address_line1'] ?? '';
      _address2.text = data['address_line2'] ?? '';
      _occupation.text = data['occupation'] ?? '';
      _businessType.text = data['business_type'] ?? '';

      _filingType = data['filing_type'] ?? 'white_return';
      _invoiceRegistered = data['invoice_registered'] ?? false;
      _invoiceNumber = data['invoice_registration_no'];

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_companyId == null) return;

    await _client.from('app_settings').update({
      'full_name': _fullName.text,
      'display_name': _displayName.text,
      'phone': _phone.text,
      'postal_code': _postalCode.text,
      'prefecture': _prefecture.text,
      'city': _city.text,
      'address_line1': _address1.text,
      'address_line2': _address2.text,
      'occupation': _occupation.text,
      'business_type': _businessType.text,
      'filing_type': _filingType,
      'invoice_registered': _invoiceRegistered,
      'invoice_registration_no': _invoiceNumber,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('company_id', _companyId!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas')),
      );
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
    final t = AppLocalizations.of(context);

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
          _field('Prefecture', _prefecture),
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
            onChanged: (v) => setState(() => _filingType = v!),
          ),

          const SizedBox(height: 12),

          _field('Ocupação', _occupation),
          _field('Tipo de negócio', _businessType),

          const SizedBox(height: 12),

          SwitchListTile(
            value: _invoiceRegistered,
            title: const Text('Emissor de Invoice Qualificado'),
            onChanged: (v) => setState(() => _invoiceRegistered = v),
          ),

          if (_invoiceRegistered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Número do Invoice',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _invoiceNumber = v,
              ),
            ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _save,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
