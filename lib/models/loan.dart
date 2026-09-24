class Loan {
  final int id;
  final String userId;
  final double amount;
  final int tenure;
  final String duration;
  final int? productId;
  final String? purpose;
  final String status;
  final double paidAmount;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? disbursedAt;
  final DateTime? createdAt;
  final String? customerName;
  final String? productName;
  final double? interestRate;
  final double? totalRepayment;
  final DateTime? applicationDate;

  Loan({
    required this.id,
    required this.userId,
    required this.amount,
    required this.tenure,
    required this.duration,
    this.productId,
    this.purpose,
    required this.status,
    this.paidAmount = 0,
    this.approvedBy,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.disbursedAt,
    this.createdAt,
    this.customerName,
    this.productName,
    this.interestRate,
    this.totalRepayment,
    this.applicationDate,
  });

  // ============= STATUS DISPLAY =============
  String get statusDisplay {
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'disbursed':
        return 'Disbursed';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'defaulted':
        return 'Defaulted';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  // ============= STATUS COLOR (hex string) =============
  String get statusColor {
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'pending':
        return '#FFA500'; // Orange
      case 'approved':
        return '#4CAF50'; // Green
      case 'rejected':
        return '#F44336'; // Red
      case 'disbursed':
        return '#2196F3'; // Blue
      case 'active':
        return '#9C27B0'; // Purple
      case 'completed':
        return '#4CAF50'; // Green
      default:
        return '#757575'; // Grey
    }
  }

  // ============= PROGRESS =============
  double get progress {
    if (amount == 0) return 0;
    return (paidAmount / amount).clamp(0.0, 1.0);
  }

  // ============= REMAINING AMOUNT =============
  double get remainingAmount {
    return amount - paidAmount;
  }

  // ============= SAFE PARSERS =============
  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Safely extracts the customer name from a joined `users` field.
  /// Supabase can return this as a Map, a List of Maps, or not at all.
  static String? _extractCustomerName(Map<String, dynamic> json) {
    final users = json['users'];

    if (users is Map) {
      final name = users['full_name'];
      if (name is String && name.isNotEmpty) return name;
    }

    if (users is List && users.isNotEmpty) {
      final first = users.first;
      if (first is Map) {
        final name = first['full_name'];
        if (name is String && name.isNotEmpty) return name;
      }
    }

    final fallback = json['customer_name'];
    if (fallback is String && fallback.isNotEmpty) return fallback;

    return null;
  }

  // ============= FACTORY METHODS =============
  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: _toInt(json['id']),
      userId: json['user_id']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      tenure: _toInt(json['tenure']),
      duration: (json['duration'] ?? 'monthly').toString(),
      productId: _toIntOrNull(json['product_id']),
      purpose: json['purpose']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      paidAmount: _toDouble(json['paid_amount']),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: _toDate(json['approved_at']),
      rejectedAt: _toDate(json['rejected_at']),
      rejectionReason: json['rejection_reason']?.toString(),
      disbursedAt: _toDate(json['disbursed_at']),
      createdAt: _toDate(json['created_at']),
      customerName: _extractCustomerName(json),
      productName: json['product_name']?.toString(),
      interestRate: _toDoubleOrNull(json['interest_rate']),
      totalRepayment: _toDoubleOrNull(json['total_repayment']),
      applicationDate: _toDate(json['application_date']) ?? _toDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'tenure': tenure,
      'duration': duration,
      'product_id': productId,
      'purpose': purpose,
      'status': status,
      'paid_amount': paidAmount,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'disbursed_at': disbursedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'customer_name': customerName,
      'product_name': productName,
      'interest_rate': interestRate,
      'total_repayment': totalRepayment,
      'application_date': applicationDate?.toIso8601String(),
    };
  }

  Loan copyWith({
    int? id,
    String? userId,
    double? amount,
    int? tenure,
    String? duration,
    int? productId,
    String? purpose,
    String? status,
    double? paidAmount,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? rejectionReason,
    DateTime? disbursedAt,
    DateTime? createdAt,
    String? customerName,
    String? productName,
    double? interestRate,
    double? totalRepayment,
    DateTime? applicationDate,
  }) {
    return Loan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      tenure: tenure ?? this.tenure,
      duration: duration ?? this.duration,
      productId: productId ?? this.productId,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      disbursedAt: disbursedAt ?? this.disbursedAt,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      productName: productName ?? this.productName,
      interestRate: interestRate ?? this.interestRate,
      totalRepayment: totalRepayment ?? this.totalRepayment,
      applicationDate: applicationDate ?? this.applicationDate,
    );
  }
}