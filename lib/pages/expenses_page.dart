import 'package:flutter/material.dart';
import '../data/supabase_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController storeController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  final TextEditingController vendorController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController taxRateController = TextEditingController();

  String paymentMethod = "cash";
  String taxType = "external";

  bool loading = false;
  bool loadingExpenses = true;
  List<Map<String, dynamic>> expenses = [];

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    storeController.dispose();
    categoryController.dispose();
    vendorController.dispose();
    notesController.dispose();
    taxRateController.dispose();
    super.dispose();
  }

  Future<void> loadExpenses() async {
    setState(() {
      loadingExpenses = true;
    });

    try {
      final data = await SupabaseService.instance.getExpenses();

      if (!mounted) return;

      setState(() {
        expenses = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar despesas: $e")),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        loadingExpenses = false;
      });
    }
  }

  Future<void> saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      await SupabaseService.instance.addExpense({
        "description": descriptionController.text.trim(),
        "amount": double.tryParse(amountController.text) ?? 0,
        "store_name": storeController.text.trim(),
        "category": categoryController.text.trim(),
        "vendor_name": vendorController.text.trim(),
        "notes": notesController.text.trim(),
        "payment_method": paymentMethod,
        "tax_rate": double.tryParse(taxRateController.text) ?? 0,
        "tax_inclusion_type": taxType,
      });

      descriptionController.clear();
      amountController.clear();
      storeController.clear();
      categoryController.clear();
      vendorController.clear();
      notesController.clear();
      taxRateController.clear();

      setState(() {
        paymentMethod = "cash";
        taxType = "external";
      });

      await loadExpenses();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Despesa salva com sucesso")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar despesa: $e")),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Widget inputField(
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (value) {
          if (!required) return null;
          if (value == null || value.isEmpty) {
            return "Obrigatório";
          }
          return null;
        },
      ),
    );
  }

  String formatYen(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return "¥${number.toStringAsFixed(0)}";
  }

  String paymentMethodLabel(String value) {
    switch (value) {
      case "cash":
        return "Cash";
      case "credit_card":
        return "Credit Card";
      case "furikomi":
        return "Furikomi";
      case "paypay":
        return "PayPay";
      default:
        return "Other";
    }
  }

  String taxTypeLabel(String value) {
    switch (value) {
      case "inclusive":
        return "Imposto incluso";
      case "external":
        return "Imposto fora";
      default:
        return "-";
    }
  }

  Widget buildExpenseCard(Map<String, dynamic> item) {
    final description = (item['description'] ?? '-').toString();
    final storeName = (item['store_name'] ?? '-').toString();
    final category = (item['category'] ?? '-').toString();
    final vendorName = (item['vendor_name'] ?? '').toString();
    final payment = paymentMethodLabel((item['payment_method'] ?? 'other').toString());
    final taxRate = (item['tax_rate'] ?? 0).toString();
    final inclusionType = taxTypeLabel((item['tax_inclusion_type'] ?? '').toString());
    final notes = (item['notes'] ?? '').toString();
    final amount = formatYen(item['amount']);
    final date = (item['date'] ?? item['expense_date'] ?? '-').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$amount",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip("Loja: $storeName"),
              _chip("Categoria: $category"),
              _chip("Fornecedor: ${vendorName.isEmpty ? '-' : vendorName}"),
              _chip("Pagamento: $payment"),
              _chip("Taxa: ${taxRate == '0' || taxRate == '0.0' ? '-' : '$taxRate%'}"),
              _chip(inclusionType),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Data: $date",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Obs: $notes",
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Despesas"),
      ),
      body: RefreshIndicator(
        onRefresh: loadExpenses,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nova Despesa",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    inputField("Descrição", descriptionController),
                    inputField(
                      "Valor",
                      amountController,
                      type: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    inputField("Loja", storeController),
                    inputField("Categoria", categoryController),
                    const SizedBox(height: 6),
                    const Text(
                      "Dados Fiscais",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    inputField("Fornecedor", vendorController, required: false),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: InputDecoration(
                        labelText: "Método de Pagamento",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "cash",
                          child: Text("Cash"),
                        ),
                        DropdownMenuItem(
                          value: "credit_card",
                          child: Text("Credit Card"),
                        ),
                        DropdownMenuItem(
                          value: "furikomi",
                          child: Text("Furikomi"),
                        ),
                        DropdownMenuItem(
                          value: "paypay",
                          child: Text("PayPay"),
                        ),
                        DropdownMenuItem(
                          value: "other",
                          child: Text("Other"),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          paymentMethod = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    inputField(
                      "Taxa de imposto (%)",
                      taxRateController,
                      type: const TextInputType.numberWithOptions(decimal: true),
                      required: false,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            taxRateController.text = '0';
                            setState(() {});
                          },
                          child: const Text("0%"),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            taxRateController.text = '8';
                            setState(() {});
                          },
                          child: const Text("8%"),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            taxRateController.text = '10';
                            setState(() {});
                          },
                          child: const Text("10%"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: taxType,
                      decoration: InputDecoration(
                        labelText: "Tipo de imposto",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "external",
                          child: Text("Imposto fora"),
                        ),
                        DropdownMenuItem(
                          value: "inclusive",
                          child: Text("Imposto incluso"),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          taxType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    inputField(
                      "Observações",
                      notesController,
                      maxLines: 3,
                      required: false,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : saveExpense,
                        child: loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Salvar Despesa"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Despesas Registradas",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loadExpenses,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loadingExpenses)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (expenses.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  "Nenhuma despesa encontrada.",
                  style: TextStyle(fontSize: 15),
                ),
              )
            else
              ...expenses.map(buildExpenseCard),
          ],
        ),
      ),
    );
  }
}
