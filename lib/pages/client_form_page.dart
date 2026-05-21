import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';

class ClientFormPage extends StatefulWidget {
  final Map<String, dynamic>? client;

  const ClientFormPage({Key? key, this.client}) : super(key: key);

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingAddress = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _streetController = TextEditingController();
  final _apartmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _nameController.text = widget.client!['name'] ?? '';
      _emailController.text = widget.client!['email'] ?? '';
      _phoneController.text = widget.client!['phone'] ?? '';
      _postalCodeController.text = widget.client!['postal_code'] ?? '';
      _provinceController.text = widget.client!['province'] ?? '';
      _cityController.text = widget.client!['city'] ?? '';
      _neighborhoodController.text = widget.client!['neighborhood'] ?? '';
      _streetController.text = widget.client!['street_number'] ?? '';
      _apartmentController.text = widget.client!['apartment'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddressFromPostalCode() async {
    final zip = _postalCodeController.text.replaceAll('-', '').trim();
    if (zip.isEmpty) return;

    setState(() => _isFetchingAddress = true);
    try {
      final url = Uri.parse('https://postcode.teraren.com/postcodes/$zip.json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['prefecture_roman'] != null) {
          setState(() {
            _provinceController.text = data['prefecture_roman'] ?? '';
            _cityController.text = data['city_roman'] ?? '';
            _neighborhoodController.text = data['suburb_roman'] ?? '';
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Endereço não encontrado para este CEP.')),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endereço não encontrado para este CEP.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar endereço: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'province': _provinceController.text.trim(),
        'city': _cityController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim(),
        'street_number': _streetController.text.trim(),
        'apartment': _apartmentController.text.trim(),
      };

      if (widget.client == null) {
        await SupabaseService.instance.createClient(data);
      } else {
        await SupabaseService.instance.updateClient(widget.client!['id'], data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('client_saved'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isEditing = widget.client != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.translate(isEditing ? 'edit_client' : 'add_client')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: t.translate('client_name'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Campo obrigatório';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: t.translate('client_email') == 'client_email' ? 'E-mail do Cliente' : t.translate('client_email'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: t.translate('client_phone'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _postalCodeController,
                            decoration: InputDecoration(
                              labelText: t.translate('postal_code'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isFetchingAddress ? null : _fetchAddressFromPostalCode,
                          icon: _isFetchingAddress
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search),
                          label: Text(t.translate('fetch_address')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _provinceController,
                      decoration: InputDecoration(
                        labelText: t.translate('province'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: t.translate('city'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _neighborhoodController,
                      decoration: InputDecoration(
                        labelText: t.translate('neighborhood'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _streetController,
                      decoration: InputDecoration(
                        labelText: t.translate('street_number'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apartmentController,
                      decoration: InputDecoration(
                        labelText: t.translate('apartment'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _save,
                        child: Text(t.translate('save_client')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
