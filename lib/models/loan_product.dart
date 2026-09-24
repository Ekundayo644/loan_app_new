class LoanProduct {
  final int id;
  final String name;
  final String? description;
  final double minAmount;
  final double maxAmount;
  final double interestRate;
  final double processingFee;
  final int minTenure;
  final int maxTenure;
  final bool isActive;

  LoanProduct({
    required this.id,
    required this.name,
    this.description,
    required this.minAmount,
    required this.maxAmount,
    required this.interestRate,
    required this.processingFee,
    required this.minTenure,
    required this.maxTenure,
    required this.isActive,
  });

  factory LoanProduct.fromJson(Map<String, dynamic> json) {
    return LoanProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      minAmount: double.tryParse(json['min_amount']?.toString() ?? '0') ?? 0,
      maxAmount: double.tryParse(json['max_amount']?.toString() ?? '0') ?? 0,
      interestRate: double.tryParse(json['interest_rate']?.toString() ?? '0') ?? 0,
      processingFee: double.tryParse(json['processing_fee']?.toString() ?? '0') ?? 0,
      minTenure: json['min_tenure'] ?? 0,
      maxTenure: json['max_tenure'] ?? 0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}