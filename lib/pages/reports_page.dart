import 'package:flutter/material.dart';

import '../data/supabase_service.dart';
import '../l10n/app_localizations.dart';
import '../services/report_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late Future<Map<String, dynamic>> _reportFuture;

  String _period = 'year';
  int _year = DateTime.now().year;
  List<String> _closedFiscalMonths = <String>[];

  @override
  void initState() {
    super.initState();
    _loadReport();
    _loadClosedFiscalMonths();
  }

  void _loadReport() {
    _reportFuture = _calculateReport();
  }

  Future<void> _loadClosedFiscalMonths() async {
    try {
      final months = await SupabaseService.instance.getClosedFiscalMonths();
      if (!mounted) return;
      setState(() {
        _closedFiscalMonths = months;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _closedFiscalMonths = <String>[];
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadReport();
    });
    await _loadClosedFiscalMonths();
    await _reportFuture;
  }

  Future<Map<String, dynamic>> _calculateReport() async {
    final entries = await SupabaseService.instance.getEntries();
    final expenses = await SupabaseService.instance.getExpenses();

    DateTime start;
    DateTime end;

    if (_period == 'year') {
      start = DateTime(_year, 1, 1, 0, 0, 0);
      end = DateTime(_year, 12, 31, 23, 59, 59);
    } else {
      final now = DateTime.now();
      start =
          DateTime(now.year, now.month, now.day).subtract(const Duration(days: 365));
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    double totalEntries = 0;
    double totalExpenses = 0;

    for (final e in entries) {
      final date = DateTime.tryParse((e['date'] ?? '').toString());
      final amount = e['amount'] is num
          ? (e['amount'] as num).toDouble()
          : double.tryParse((e['amount'] ?? '0').toString()) ?? 0;

      if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
        totalEntries += amount;
      }
    }

    for (final e in expenses) {
      final date = DateTime.tryParse((e['date'] ?? '').toString());
      final amount = e['amount'] is num
          ? (e['amount'] as num).toDouble()
          : double.tryParse((e['amount'] ?? '0').toString()) ?? 0;

      if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
        totalExpenses += amount;
      }
    }

    final profit = totalEntries - totalExpenses;
    final taxableProfit = profit > 0 ? profit : 0.0;

    final nationalTax = taxableProfit * 0.10;
    final residentTax = taxableProfit * 0.10;
    final totalTax = nationalTax + residentTax;

    return {
      'entries': totalEntries,
      'expenses': totalExpenses,
      'profit': profit,
      'nationalTax': nationalTax,
      'residentTax': residentTax,
      'totalTax': totalTax,
    };
  }

  String _currentFiscalMonthKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  bool _isCurrentFiscalMonthClosed() {
    return _closedFiscalMonths.contains(_currentFiscalMonthKey());
  }

  String _yen(double value) {
    final formatted = value.toStringAsFixed(0);
    final chars = formatted.split('').reversed.toList();
    final buffer = StringBuffer();

    for (int i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return '¥${buffer.toString().split('').reversed.join()}';
  }

  String _tr(BuildContext context, String key, String pt, String en, String ja, String es) {
    final t = AppLocalizations.of(context);
    final translated = t.translate(key);
    if (translated != key) return translated;

    switch (Localizations.localeOf(context).languageCode) {
      case 'en':
        return en;
      case 'ja':
        return ja;
      case 'es':
        return es;
      case 'pt':
      default:
        return pt;
    }
  }

  String _periodLabel(BuildContext context) {
    if (_period == 'year') {
      return '${_tr(
        context,
        'year_report_label',
        'Relatório do ano',
        'Report for year',
        '年次レポート',
        'Informe del año',
      )} $_year';
    }

    return _tr(
      context,
      'last_12_months_report_label',
      'Relatório dos últimos 12 meses',
      'Report for the last 12 months',
      '過去12か月のレポート',
      'Informe de los últimos 12 meses',
    );
  }

  Widget _summaryHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFF4F7FB),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        context,
                        'fiscal_summary',
                        'Resumo fiscal',
                        'Fiscal summary',
                        '税務サマリー',
                        'Resumen fiscal',
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _periodLabel(context),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _fiscalStatusChip(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fiscalStatusChip(BuildContext context) {
    final isClosed = _isCurrentFiscalMonthClosed();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isClosed ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isClosed ? Colors.orange.shade300 : Colors.green.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isClosed ? Icons.lock_outline : Icons.check_circle_outline,
            size: 16,
            color: isClosed ? Colors.orange.shade800 : Colors.green.shade800,
          ),
          const SizedBox(width: 6),
          Text(
            isClosed
                ? _tr(
                    context,
                    'fiscal_month_closed',
                    'Mês fiscal fechado',
                    'Fiscal month closed',
                    '会計月は締め済み',
                    'Mes fiscal cerrado',
                  )
                : _tr(
                    context,
                    'fiscal_month_open',
                    'Mês fiscal aberto',
                    'Fiscal month open',
                    '会計月はオープン',
                    'Mes fiscal abierto',
                  ),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isClosed ? Colors.orange.shade800 : Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiscalInfoBanner(BuildContext context) {
    final isClosed = _isCurrentFiscalMonthClosed();
    final currentMonth = _currentFiscalMonthKey();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClosed ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isClosed ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isClosed ? Icons.lock_clock_outlined : Icons.info_outline,
            color: isClosed ? Colors.orange.shade800 : Colors.blue.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClosed
                      ? _tr(
                          context,
                          'fiscal_month_closed_title',
                          'Mês fiscal encerrado',
                          'Fiscal month closed',
                          '会計月は締め済みです',
                          'Mes fiscal cerrado',
                        )
                      : _tr(
                          context,
                          'fiscal_month_open_title',
                          'Mês fiscal em aberto',
                          'Fiscal month open',
                          '会計月はオープン中です',
                          'Mes fiscal abierto',
                        ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isClosed ? Colors.orange.shade900 : Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isClosed
                      ? '${_tr(
                          context,
                          'fiscal_reports_closed_info',
                          'O mês atual está fechado para alterações. Os relatórios continuam disponíveis para consulta e exportação.',
                          'The current month is closed for changes. Reports remain available for review and export.',
                          '今月は変更できません。レポートは引き続き閲覧・出力できます。',
                          'El mes actual está cerrado para cambios. Los informes siguen disponibles para consulta y exportación.',
                        )} ($currentMonth)'
                      : '${_tr(
                          context,
                          'fiscal_reports_open_info',
                          'O mês atual ainda está aberto. Os relatórios exibem os dados mais recentes para acompanhamento fiscal.',
                          'The current month is still open. Reports show the latest data for fiscal monitoring.',
                          '今月はまだオープンです。レポートには最新の会計データが表示されます。',
                          'El mes actual sigue abierto. Los informes muestran los datos más recientes para el seguimiento fiscal.',
                        )} ($currentMonth)',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isClosed ? Colors.orange.shade900 : Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueCard({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taxBox(BuildContext context, Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              context,
              'estimated_tax',
              'Estimativa de imposto',
              'Tax estimate',
              '税額見込み',
              'Estimación de impuesto',
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _taxRow(
            _tr(
              context,
              'income_tax',
              'Imposto de renda',
              'Income tax',
              '所得税',
              'Impuesto sobre la renta',
            ),
            _yen((data['nationalTax'] as num).toDouble()),
          ),
          const Divider(height: 22),
          _taxRow(
            _tr(
              context,
              'resident_tax',
              'Imposto municipal',
              'Resident tax',
              '住民税',
              'Impuesto municipal',
            ),
            _yen((data['residentTax'] as num).toDouble()),
          ),
          const Divider(height: 22),
          _taxRow(
            _tr(
              context,
              'estimated_total_tax',
              'Total estimado',
              'Estimated total',
              '推定合計税額',
              'Total estimado',
            ),
            _yen((data['totalTax'] as num).toDouble()),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _taxRow(String label, String value, {bool isTotal = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.orange.shade800 : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _periodSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _period,
              decoration: InputDecoration(
                labelText: _tr(
                  context,
                  'period',
                  'Período',
                  'Period',
                  '期間',
                  'Período',
                ),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'year',
                  child: Text(
                    _tr(
                      context,
                      'specific_year',
                      'Ano específico',
                      'Specific year',
                      '特定の年',
                      'Año específico',
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: '12m',
                  child: Text(
                    _tr(
                      context,
                      'last_12_months',
                      'Últimos 12 meses',
                      'Last 12 months',
                      '過去12か月',
                      'Últimos 12 meses',
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _period = v;
                  _loadReport();
                });
              },
            ),
          ),
          if (_period == 'year') ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<int>(
                value: _year,
                decoration: InputDecoration(
                  labelText: _tr(
                    context,
                    'year',
                    'Ano',
                    'Year',
                    '年',
                    'Año',
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: List.generate(
                  5,
                  (i) {
                    final year = DateTime.now().year - i;
                    return DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    );
                  },
                ),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _year = v;
                    _loadReport();
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    await ReportService.instance.generateFiscalReport(
      year: _year,
      entries: data['entries'],
      expenses: data['expenses'],
      profit: data['profit'],
      nationalTax: data['nationalTax'],
      residentTax: data['residentTax'],
      totalTax: data['totalTax'],
    );
  }

  Widget _errorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${_tr(
            context,
            'error_loading_report',
            'Erro ao carregar relatório',
            'Error loading report',
            'レポートの読み込みエラー',
            'Error al cargar el informe',
          )}: $error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tr(
            context,
            'fiscal_report',
            'Relatório Fiscal',
            'Fiscal Report',
            '税務レポート',
            'Informe Fiscal',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _errorState(context, snapshot.error!);
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryHeader(context),
                const SizedBox(height: 16),
                _fiscalInfoBanner(context),
                const SizedBox(height: 16),
                _periodSelector(context),
                const SizedBox(height: 18),
                _valueCard(
                  title: _tr(
                    context,
                    'total_income',
                    'Receita total',
                    'Total income',
                    '総収入',
                    'Ingreso total',
                  ),
                  value: _yen((data['entries'] as num).toDouble()),
                  icon: Icons.trending_up,
                  valueColor: Colors.green.shade700,
                ),
                const SizedBox(height: 12),
                _valueCard(
                  title: _tr(
                    context,
                    'total_expenses',
                    'Despesas totais',
                    'Total expenses',
                    '総支出',
                    'Gastos totales',
                  ),
                  value: _yen((data['expenses'] as num).toDouble()),
                  icon: Icons.trending_down,
                  valueColor: Colors.red.shade700,
                ),
                const SizedBox(height: 12),
                _valueCard(
                  title: _tr(
                    context,
                    'taxable_profit',
                    'Lucro tributável',
                    'Taxable profit',
                    '課税利益',
                    'Ganancia imponible',
                  ),
                  value: _yen((data['profit'] as num).toDouble()),
                  icon: Icons.account_balance_wallet_outlined,
                  valueColor: Colors.blue.shade700,
                ),
                const SizedBox(height: 18),
                _taxBox(context, data),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _tr(
                        context,
                        'generate_fiscal_pdf',
                        'Gerar PDF Fiscal',
                        'Generate Fiscal PDF',
                        '税務PDFを生成',
                        'Generar PDF Fiscal',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _generatePdf(data),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
