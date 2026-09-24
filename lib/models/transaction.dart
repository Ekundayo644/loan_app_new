class Transaction {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'loan', 'repayment', 'fee'
  final String status;
  final String? loanId;
  final String? reference;
  final DateTime? createdAt;
  final String? paymentMethod;
  final String? paymentMethodDisplay;
  final String? statusDisplay;

  Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.status,
    this.loanId,
    this.reference,
    this.createdAt,
    this.paymentMethod,
    this.paymentMethodDisplay,
    this.statusDisplay,
  });

  // ============= TYPE DISPLAY =============
  String get typeDisplay {
    switch (type.toLowerCase()) {
      case 'loan':
        return 'Loan Disbursement';
      case 'repayment':
        return 'Loan Repayment';
      case 'fee':
        return 'Service Fee';
      default:
        return type;
    }
  }

  // ============= TYPE COLOR =============
  String get typeColor {
    switch (type.toLowerCase()) {
      case 'loan':
        return '#4CAF50'; // Green
      case 'repayment':
        return '#2196F3'; // Blue
      case 'fee':
        return '#FF9800'; // Orange
      default:
        return '#757575'; // Grey
    }
  }

  // ============= SIGNED AMOUNT (positive for incoming, negative for outgoing) =============
  double get signedAmount {
    switch (type.toLowerCase()) {
      case 'loan':
        return amount; // Positive (received)
      case 'repayment':
        return -amount; // Negative (paid)
      case 'fee':
        return -amount; // Negative (fee)
      default:
        return amount;
    }
  }

  // ============= FACTORY METHODS =============
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final type = json['type'] ?? 'unknown';
    final status = json['status'] ?? 'pending';

    String? statusDisplayValue;
    switch (status.toLowerCase()) {
      case 'pending':
        statusDisplayValue = 'Pending';
        break;
      case 'success':
      case 'completed':
        statusDisplayValue = 'Completed';
        break;
      case 'failed':
        statusDisplayValue = 'Failed';
        break;
      default:
        statusDisplayValue = status;
    }

    String? paymentMethodDisplayValue;
    final paymentMethod = json['payment_method']?.toString();
    if (paymentMethod != null) {
      switch (paymentMethod.toLowerCase()) {
        case 'bank_transfer':
          paymentMethodDisplayValue = 'Bank Transfer';
          break;
        case 'card':
          paymentMethodDisplayValue = 'Card Payment';
          break;
        case 'paystack':
          paymentMethodDisplayValue = 'Paystack';
          break;
        default:
          paymentMethodDisplayValue = paymentMethod;
      }
    }

    return Transaction(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: type,
      status: status,
      loanId: json['loan_id']?.toString(),
      reference: json['reference'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      paymentMethod: paymentMethod,
      paymentMethodDisplay: paymentMethodDisplayValue,
      statusDisplay: statusDisplayValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'status': status,
      'loan_id': loanId,
      'reference': reference,
      'created_at': createdAt?.toIso8601String(),
      'payment_method': paymentMethod,
    };
  }

  Transaction copyWith({
    String? id,
    String? userId,
    double? amount,
    String? type,
    String? status,
    String? loanId,
    String? reference,
    DateTime? createdAt,
    String? paymentMethod,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      loanId: loanId ?? this.loanId,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}