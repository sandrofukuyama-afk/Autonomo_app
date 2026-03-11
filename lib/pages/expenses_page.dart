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

  Future<void> saveExpense() async {

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {

      await SupabaseService.client.from('expenses_v2').insert({

        "description": descriptionController.text,
        "amount": double.tryParse(amountController.text) ?? 0,
        "store_name": storeController.text,
        "category": categoryController.text,

        "vendor_name": vendorController.text,
        "notes": notesController.text,
        "payment_method": paymentMethod,
        "tax_rate": double.tryParse(taxRateController.text) ?? 0,
        "tax_inclusion_type": taxType,

      });

      if (mounted) {
        Navigator.pop(context);
      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar despesa: $e")),
      );

    }

    setState(() {
      loading = false;
    });

  }

  Widget inputField(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text}) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Obrigatório";
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nova Despesa"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              inputField("Descrição", descriptionController),

              inputField(
                "Valor",
                amountController,
                type: TextInputType.number,
              ),

              inputField("Loja", storeController),

              inputField("Categoria", categoryController),

              const SizedBox(height: 10),

              const Text(
                "Dados Fiscais",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              inputField("Fornecedor", vendorController),

              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(
                  labelText: "Método de Pagamento",
                  border: OutlineInputBorder(),
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

              inputField("Taxa de imposto (%)", taxRateController,
                  type: TextInputType.number),

              DropdownButtonFormField<String>(
                value: taxType,
                decoration: const InputDecoration(
                  labelText: "Tipo de imposto",
                  border: OutlineInputBorder(),
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

              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Observações",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: loading ? null : saveExpense,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Salvar Despesa"),
              ),

              const SizedBox(height: 10),

              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancelar"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
