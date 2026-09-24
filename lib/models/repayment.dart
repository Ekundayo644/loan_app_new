class Repayment {
  final int id;
  final int loanId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String transactionId;
  final String status;

  Repayment({
    required this.id,
    required this.loanId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.transactionId,
    required this.status,
  });

  factory Repayment.fromJson(Map<String, dynamic> json) {
    return Repayment(
      id: json['id'] ?? 0,
      loanId: json['loan_id'] ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'])
          : DateTime.now(),
      paymentMethod: json['payment_method'] ?? 'bank_transfer',
      transactionId: json['transaction_id'] ?? '',
      status: json['status'] ?? 'completed',
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'paystack':
        return 'Paystack';
      case 'mobile_money':
        return 'Mobile Money';
      case 'cash':
        return 'Cash';
      default:
        return paymentMethod;
    }
  }
}