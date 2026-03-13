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
  List<String> _closedFiscalMonths = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
    });

    await Future.wait([
      _loadClosedMonths(),
      _loadExpenses(),
    ]);

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadClosedMonths() async {
    final settings = await supabase
        .from('app_settings')
        .select('closed_fiscal_months')
        .eq('company_id', widget.companyId)
        .maybeSingle();

    final raw = settings?['closed_fiscal_months'];

    if (!mounted) return;

    setState(() {
      if (raw is List) {
        _closedFiscalMonths = raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        _closedFiscalMonths = [];
      }
    });
  }

  Future<void> _loadExpenses() async {
    final data = await supabase
        .from('expenses_v2')
        .select()
        .eq('company_id', widget.companyId)
        .or('review_status.eq.review_required,fiscal_category.is.null')
        .order('expense_date', ascending: false);

    if (!mounted) return;
    setState(() {
      _expenses = data;
    });
  }

  String? _extractFiscalMonth(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      final year = value.year.toString().padLeft(4, '0');
      final month = value.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      return '$year-$month';
    }

    if (text.length >= 7 && text[4] == '-') {
      return text.substring(0, 7);
    }

    return null;
  }

  bool _isClosedMonth(dynamic dateValue) {
    final fiscalMonth = _extractFiscalMonth(dateValue);
    if (fiscalMonth == null) return false;
    return _closedFiscalMonths.contains(fiscalMonth);
  }

  Future<void> _markReviewed(String id, dynamic expenseDate) async {
    if (_isClosedMonth(expenseDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This fiscal month is closed. Review status cannot be changed.',
          ),
        ),
      );
      return;
    }

    await supabase
        .from('expenses_v2')
        .update({'review_status': 'reviewed'})
        .eq('id', id)
        .eq('company_id', widget.companyId);

    await _loadPage();
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
                    final isClosed = _isClosedMonth(e['expense_date']);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e['vendor_name'] ?? 'Unknown vendor',
                              ),
                            ),
                            if (isClosed)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.lock,
                                  size: 18,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Amount: ¥${e['amount']}'),
                            Text('Category: ${e['fiscal_category'] ?? 'None'}'),
                            Text('Review: ${e['review_status']}'),
                            if (isClosed)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'Closed fiscal month: review locked',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isClosed
                            ? const Icon(
                                Icons.lock_outline,
                                color: Colors.orange,
                              )
                            : IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () => _markReviewed(
                                  e['id'].toString(),
                                  e['expense_date'],
                                ),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
