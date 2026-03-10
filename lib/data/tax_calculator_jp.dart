class TaxResultJP {
  final int totalIncome;
  final int deductibleExpenses;
  final int businessProfit;

  final int basicDeduction;
  final int blueReturnDeduction;

  final int taxableIncome;
  final int estimatedTax;

  const TaxResultJP({
    required this.totalIncome,
    required this.deductibleExpenses,
    required this.businessProfit,
    required this.basicDeduction,
    required this.blueReturnDeduction,
    required this.taxableIncome,
    required this.estimatedTax,
  });
}

class TaxCalculatorJP {
  static const int basicDeduction = 480000;
  static const int blueReturnDeduction = 650000;

  static TaxResultJP calculate({
    required int totalIncome,
    required int deductibleExpenses,
    required bool blueReturn,
  }) {
    final int businessProfit = totalIncome - deductibleExpenses;

    final int blueDeduction = blueReturn ? blueReturnDeduction : 0;

    int taxable =
        businessProfit - basicDeduction - blueDeduction;

    if (taxable < 0) {
      taxable = 0;
    }

    final int tax = _calculateIncomeTax(taxable);

    return TaxResultJP(
      totalIncome: totalIncome,
      deductibleExpenses: deductibleExpenses,
      businessProfit: businessProfit,
      basicDeduction: basicDeduction,
      blueReturnDeduction: blueDeduction,
      taxableIncome: taxable,
      estimatedTax: tax,
    );
  }

  static int _calculateIncomeTax(int taxableIncome) {
    int tax = 0;

    if (taxableIncome <= 1950000) {
      tax = (taxableIncome * 0.05).round();
    } 
    else if (taxableIncome <= 3300000) {
      tax = (taxableIncome * 0.10 - 97500).round();
    } 
    else if (taxableIncome <= 6950000) {
      tax = (taxableIncome * 0.20 - 427500).round();
    } 
    else if (taxableIncome <= 9000000) {
      tax = (taxableIncome * 0.23 - 636000).round();
    } 
    else if (taxableIncome <= 18000000) {
      tax = (taxableIncome * 0.33 - 1536000).round();
    } 
    else if (taxableIncome <= 40000000) {
      tax = (taxableIncome * 0.40 - 2796000).round();
    } 
    else {
      tax = (taxableIncome * 0.45 - 4796000).round();
    }

    if (tax < 0) tax = 0;

    return tax;
  }
}
