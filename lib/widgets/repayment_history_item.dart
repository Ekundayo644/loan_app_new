import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RepaymentHistoryItem extends StatelessWidget {
  final Map<String, dynamic> repayment;

  const RepaymentHistoryItem({
    super.key,
    required this.repayment,
  });

  @override
  Widget build(BuildContext context) {
    final amount = repayment['amount'] as double? ?? 0;
    final method = repayment['payment_method'] ?? 'N/A';
    final status = repayment['status'] ?? 'completed';
    final date = repayment['payment_date'] != null
        ? DateTime.parse(repayment['payment_date'])
        : DateTime.now();
    final transactionId = repayment['transaction_id'] ?? 'N/A';

    final statusColors = {
      'completed': Colors.green,
      'pending': Colors.orange,
      'failed': Colors.red,
    };

    final statusIcons = {
      'completed': Icons.check_circle,
      'pending': Icons.hourglass_empty,
      'failed': Icons.error,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColors[status]?.withOpacity(0.1),
        child: Icon(
          statusIcons[status] ?? Icons.payment,
          size: 20,
          color: statusColors[status],
        ),
      ),
      title: Row(
        children: [
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColors[status]?.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColors[status],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Method: $method',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            'Ref: $transactionId',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      trailing: Text(
        _formatDate(date),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    ).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y HH:mm').format(date);
  }
}