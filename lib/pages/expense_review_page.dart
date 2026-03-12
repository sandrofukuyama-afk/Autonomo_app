import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseReviewPage extends StatefulWidget {
  final String companyId;

  const ExpenseReviewPage({super.key, required this.companyId});

  @override
  State<ExpenseReviewPage> createState() => _ExpenseReviewPageState();
}

class _ExpenseReviewPageState extends State<ExpenseReviewPage> {
  final supabase = Supabase.instance.client;

  List<dynamic> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _loading = true;
    });

    final data = await supabase
        .from('expenses_v2')
        .select()
        .eq('company_id', widget.companyId)
        .or('review_status.eq.review_required,fiscal_category.is.null')
        .order('expense_date', ascending: false);

    setState(() {
      _expenses = data;
      _loading = false;
    });
  }

  Future<void> _markReviewed(String id) async {
    await supabase
        .from('expenses_v2')
        .update({'review_status': 'reviewed'})
        .eq('id', id);

    _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Review'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text('No expenses requiring review'))
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final e = _expenses[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(e['vendor_name'] ?? 'Unknown vendor'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Amount: ¥${e['amount']}'),
                            Text('Category: ${e['fiscal_category'] ?? 'None'}'),
                            Text('Review: ${e['review_status']}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () => _markReviewed(e['id']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
