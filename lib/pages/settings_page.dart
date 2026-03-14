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
        allowed: const ['pt', 'en', 'ja', 'es'],
        fallback: 'pt',
      );
      _currency = _normalizeString(
        data['currency'],
        allowed: const ['JPY'],
        fallback: 'JPY',
      );
      _filingType = _normalizeString(
        data['filing_type'],
        allowed: const ['white_return', 'blue_return'],
        fallback: 'white_return',
      );
      _consumptionTaxStatus = _normalizeString(
        data['consumption_tax_status'],
        allowed: const ['exempt', 'taxable'],
        fallback: 'exempt',
      );
      _bookkeepingMethod = _normalizeString(
        data['bookkeeping_method'],
        allowed: const ['simple', 'double_entry'],
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

      _invoiceRegistered = (data['invoice_registered'] ?? false) == true;
      _handlesReducedTaxRate = (data['handles_reduced_tax_rate'] ?? true) == true;
      _useTwoTenthsSpecialRule =
          (data['use_two_tenths_special_rule'] ?? false) == true;
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

  String _normalizeString(
    dynamic value, {
    required List<String> allowed,
    required String fallback,
  }) {
    final text = (value ?? '').toString();
    if (allowed.contains(text)) return text;
    return fallback;
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
        'language': _language,
        'currency': _currency,
        'fiscal_year_start_month': _fiscalYearStartMonth,
        'filing_type': _filingType,
        'consumption_tax_status': _consumptionTaxStatus,
        'invoice_registered': _invoiceRegistered,
        'invoice_registration_no':
            _invoiceRegistered ? _invoiceNumber.text.trim() : null,
        'handles_reduced_tax_rate': _handlesReducedTaxRate,
        'use_two_tenths_special_rule': _useTwoTenthsSpecialRule,
        'bookkeeping_method': _bookkeepingMethod,
        'fiscal_notes': _fiscalNotes.text.trim().isEmpty
            ? null
            : _fiscalNotes.text.trim(),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
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
          _buildCard([
            _sectionTitle('Dados pessoais'),
            _field('Nome completo', _fullName),
            _field('Nome exibido', _displayName),
            _field('Telefone', _phone, keyboardType: TextInputType.phone),
            _field('CEP', _postalCode, keyboardType: TextInputType.text),
            _field('Província / Prefeitura', _prefecture),
            _field('Cidade', _city),
            _field('Endereço', _address1),
            _field('Complemento', _address2),
          ]),
          const SizedBox(height: 12),
          _buildCard([
            _sectionTitle('Dados fiscais'),
            _dropdown<String>(
              label: 'Tipo de declaração',
              value: _filingType,
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
            _dropdown<String>(
              label: 'Status do imposto sobre consumo',
              value: _consumptionTaxStatus,
              items: const [
                DropdownMenuItem(
                  value: 'exempt',
                  child: Text('Isento'),
                ),
                DropdownMenuItem(
                  value: 'taxable',
                  child: Text('Tributável'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _consumptionTaxStatus = value);
              },
            ),
            _dropdown<String>(
              label: 'Método de escrituração',
              value: _bookkeepingMethod,
              items: const [
                DropdownMenuItem(
                  value: 'simple',
                  child: Text('Simples'),
                ),
                DropdownMenuItem(
                  value: 'double_entry',
                  child: Text('Partidas dobradas'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _bookkeepingMethod = value);
              },
            ),
            _field('Ocupação', _occupation),
            _field('Tipo de negócio', _businessType),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _invoiceRegistered,
              title: const Text('Emissor de Invoice Qualificado'),
              onChanged: (value) {
                setState(() => _invoiceRegistered = value);
              },
            ),
            if (_invoiceRegistered) _field('Número do Invoice', _invoiceNumber),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _handlesReducedTaxRate,
              title: const Text('Usa taxa reduzida'),
              onChanged: (value) {
                setState(() => _handlesReducedTaxRate = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useTwoTenthsSpecialRule,
              title: const Text('Usar regra especial 2/10'),
              onChanged: (value) {
                setState(() => _useTwoTenthsSpecialRule = value);
              },
            ),
            _field('Observações fiscais', _fiscalNotes, maxLines: 4),
          ]),
          const SizedBox(height: 12),
          _buildCard([
            _sectionTitle('Preferências'),
            _dropdown<String>(
              label: 'Idioma do app',
              value: _language,
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
            _dropdown<String>(
              label: 'Moeda',
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
              label: 'Mês inicial do ano fiscal',
              value: _fiscalYearStartMonth,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 - Janeiro')),
                DropdownMenuItem(value: 2, child: Text('2 - Fevereiro')),
                DropdownMenuItem(value: 3, child: Text('3 - Março')),
                DropdownMenuItem(value: 4, child: Text('4 - Abril')),
                DropdownMenuItem(value: 5, child: Text('5 - Maio')),
                DropdownMenuItem(value: 6, child: Text('6 - Junho')),
                DropdownMenuItem(value: 7, child: Text('7 - Julho')),
                DropdownMenuItem(value: 8, child: Text('8 - Agosto')),
                DropdownMenuItem(value: 9, child: Text('9 - Setembro')),
                DropdownMenuItem(value: 10, child: Text('10 - Outubro')),
                DropdownMenuItem(value: 11, child: Text('11 - Novembro')),
                DropdownMenuItem(value: 12, child: Text('12 - Dezembro')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _fiscalYearStartMonth = value);
              },
            ),
          ]),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
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
