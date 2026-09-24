import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:loan_app_new/providers/loan_provider.dart';
import 'package:loan_app_new/widgets/repayment_dialog.dart';
import 'package:loan_app_new/widgets/custom_button.dart';
import 'package:loan_app_new/widgets/repayment_history_item.dart';
import 'package:loan_app_new/utils/toast_utils.dart';

class LoanDetailsScreen extends StatefulWidget {
  final int loanId;

  const LoanDetailsScreen({
    super.key,
    required this.loanId,
  });

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  Map<String, dynamic>? _loanDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoanDetails();
  }

  Future<void> _loadLoanDetails() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<LoanProvider>();
      final details = await provider.getLoanDetails(widget.loanId);
      setState(() {
        _loanDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      showToast('Failed to load loan details: $e', isError: true);
    }
  }

  // ============= SAFE ACCESSORS =============

  /// Returns the loan map, or an empty map if missing.
  Map<String, dynamic> _getLoan() {
    final details = _loanDetails;
    if (details == null) return {};
    final loan = details['loan'];
    if (loan is Map<String, dynamic>) return loan;
    if (loan is Map) return Map<String, dynamic>.from(loan);
    return {};
  }

  /// Returns the repayments list, or an empty list if missing.
  List _getRepayments() {
    final details = _loanDetails;
    if (details == null) return const [];
    final reps = details['repayments'];
    if (reps is List) return reps;
    return const [];
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final loan = _getLoan();
    final hasLoan = loan.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoanDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasLoan
              ? const Center(child: Text('No loan details found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildLoanSummary(),
                      const SizedBox(height: 16),
                      _buildRepaymentSchedule(),
                      const SizedBox(height: 16),
                      _buildRepaymentHistory(),
                      const SizedBox(height: 16),
                      if (loan['status'] == 'disbursed' ||
                          loan['status'] == 'approved' ||
                          loan['status'] == 'active')
                        _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final loan = _getLoan();
    final status = (loan['status'] ?? 'pending').toString();
    final statusColors = <String, Color>{
      'pending': Colors.orange,
      'approved': Colors.blue,
      'disbursed': Colors.green,
      'completed': Colors.green,
      'rejected': Colors.red,
      'defaulted': Colors.red,
      'active': Colors.purple,
    };

    final statusColor = statusColors[status] ?? Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Loan #${loan['id'] ?? widget.loanId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  'Amount',
                  _formatCurrency(_asDouble(loan['amount'])),
                  Icons.attach_money,
                ),
                _buildInfoItem(
                  'Tenure',
                  '${_asInt(loan['tenure'])} ${loan['duration'] ?? 'days'}',
                  Icons.calendar_today,
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  'Interest',
                  '${_asDouble(loan['interest_rate']).toStringAsFixed(1)}%',
                  Icons.percent,
                ),
                _buildInfoItem(
                  'Total',
                  _formatCurrency(_asDouble(loan['total_repayment'])),
                  Icons.calculate,
                ),
              ],
            ),
            if (loan['monthly_installment'] != null) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoItem(
                    'Monthly Installment',
                    _formatCurrency(_asDouble(loan['monthly_installment'])),
                    Icons.calendar_month,
                  ),
                  _buildInfoItem(
                    'Due Date',
                    _formatDate(_asDate(loan['due_date'])),
                    Icons.event,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanSummary() {
    final loan = _getLoan();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Product', loan['product_name'] ?? 'N/A'),
            _buildSummaryRow('Purpose', loan['purpose'] ?? 'Not specified'),
            _buildSummaryRow(
              'Application Date',
              _formatDate(_asDate(loan['application_date']) ??
                  _asDate(loan['created_at'])),
            ),
            if (loan['approved_at'] != null || loan['approval_date'] != null)
              _buildSummaryRow(
                'Approval Date',
                _formatDate(_asDate(loan['approved_at']) ??
                    _asDate(loan['approval_date'])),
              ),
            if (loan['disbursed_at'] != null || loan['disbursement_date'] != null)
              _buildSummaryRow(
                'Disbursement Date',
                _formatDate(_asDate(loan['disbursed_at']) ??
                    _asDate(loan['disbursement_date'])),
              ),
            if (loan['rejection_reason'] != null &&
                loan['rejection_reason'].toString().isNotEmpty)
              _buildSummaryRow(
                'Rejection Reason',
                loan['rejection_reason'].toString(),
                isError: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isError ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentSchedule() {
    final loan = _getLoan();
    final amount = _asDouble(loan['amount']);
    final interestRate = _asDouble(loan['interest_rate']);
    final tenure = _asInt(loan['tenure']);
    final duration = (loan['duration'] ?? 'days').toString();

    // Interest and total
    final interest = amount * interestRate / 100;
    final total = amount + interest;

    // Normalize tenure to months for the installment calculation.
    // Prevents div-by-zero and nonsensical values when duration is weeks/years.
    double months = tenure.toDouble();
    switch (duration.toLowerCase()) {
      case 'days':
        months = tenure / 30.0;
        break;
      case 'weeks':
        months = (tenure * 7) / 30.0;
        break;
      case 'months':
      case 'monthly':
        months = tenure.toDouble();
        break;
      case 'years':
      case 'yearly':
        months = tenure * 12.0;
        break;
      default:
        months = tenure.toDouble();
    }

    final installment = months > 0 ? total / months : total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Repayment Schedule',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildScheduleRow('Principal Amount', _formatCurrency(amount)),
            _buildScheduleRow(
              'Interest (${interestRate.toStringAsFixed(1)}%)',
              _formatCurrency(interest),
            ),
            _buildScheduleRow(
              'Processing Fee',
              _formatCurrency(_asDouble(loan['processing_fee'])),
            ),
            const Divider(),
            _buildScheduleRow(
              'Total Repayment',
              _formatCurrency(total),
              isBold: true,
            ),
            const SizedBox(height: 8),
            _buildScheduleRow(
              'Monthly Installment',
              _formatCurrency(installment),
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentHistory() {
    final repayments = _getRepayments();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Repayment History',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${repayments.length} payments',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (repayments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No repayments recorded yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: repayments.length > 5 ? 5 : repayments.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final repayment = repayments[index];
                  return RepaymentHistoryItem(repayment: repayment);
                },
              ),
            if (repayments.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => _showAllRepayments(repayments),
                  child: Text('View all ${repayments.length} payments'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllRepayments(List repayments) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Repayments'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: repayments.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final repayment = repayments[index];
              return ListTile(
                title: Text(_formatCurrency(_asDouble(repayment['amount']))),
                subtitle: Text((repayment['payment_method'] ?? 'N/A').toString()),
                trailing: Text(
                  _formatDate(_asDate(repayment['payment_date']) ??
                      _asDate(repayment['created_at'])),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final loan = _getLoan();
    final status = loan['status'] as String?;
    final canMakePayment = status == 'disbursed' || status == 'active';
    final canDisburse = status == 'approved';

    return Column(
      children: [
        if (canMakePayment)
          CustomButton(
            onPressed: () {
              // ✅ Compute outstanding balance: total owed minus what's paid
              final totalRepayment = _asDouble(loan['total_repayment']);
              final paidAmount = _asDouble(loan['paid_amount']);
              final outstanding =
                  (totalRepayment - paidAmount).clamp(0.0, totalRepayment);

              showDialog(
                context: context,
                builder: (context) => RepaymentDialog(
                  loanId: widget.loanId,
                  totalAmount: totalRepayment,
                  outstandingAmount: outstanding,
                  onSuccess: () {
                    _loadLoanDetails();
                  },
                ),
              );
            },
            text: 'Make Payment',
            icon: Icons.payment,
          ),
        if (canDisburse) ...[
          const SizedBox(height: 12),
          CustomButton(
            onPressed: () => _showDisbursementConfirmation(),
            text: 'Accept & Get Disbursed',
            icon: Icons.check_circle,
          ),
        ]
      ],
    );
  }

  void _showDisbursementConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Disbursement'),
        content: const Text(
          'By confirming, you agree to the loan terms and conditions. '
          'The funds will be disbursed to your account immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final provider = context.read<LoanProvider>();
                await provider.disburseLoan(widget.loanId);
                showToast('Loan disbursed successfully!');
                _loadLoanDetails();
              } catch (e) {
                showToast('Failed to disburse loan: $e', isError: true);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    final value = _asDouble(amount);
    return NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(value);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM d, y HH:mm').format(date);
  }
}