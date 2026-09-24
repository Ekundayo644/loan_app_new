import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loan_app_new/providers/loan_provider.dart';
import 'package:loan_app_new/models/loan.dart';
import 'package:loan_app_new/widgets/stat_card.dart';
import 'package:loan_app_new/utils/toast_utils.dart';
import 'package:loan_app_new/providers/auth_provider.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<LoanProvider>();
    await provider.fetchAllLoans();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      showToast('Logout failed: $e', isError: true);
    }
  }

  Future<void> _approveLoan(int loanId) async {
    setState(() => _isWorking = true);
    try {
      final provider = context.read<LoanProvider>();
      await provider.approveLoan(loanId);
      showToast('Loan #$loanId approved');
      await _loadData();
    } catch (e) {
      showToast('Failed to approve: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _rejectLoan(int loanId) async {
    final reason = await _askRejectionReason();
    if (reason == null) return;

    setState(() => _isWorking = true);
    try {
      final provider = context.read<LoanProvider>();
      await provider.rejectLoan(loanId, reason: reason);
      showToast('Loan #$loanId rejected');
      await _loadData();
    } catch (e) {
      showToast('Failed to reject: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _disburseLoan(int loanId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Disbursement'),
        content: Text(
            'Disburse loan #$loanId? This will mark the loan as active and the customer can start making payments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disburse'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isWorking = true);
    try {
      final provider = context.read<LoanProvider>();
      await provider.disburseLoan(loanId);
      showToast('Loan #$loanId disbursed');
      await _loadData();
    } catch (e) {
      showToast('Failed to disburse: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Loan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g., Insufficient credit history',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(context, text.isEmpty ? 'Rejected by agent' : text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _viewRepayments(Loan loan) async {
    showDialog(
      context: context,
      builder: (context) => _RepaymentsDialog(loan: loan),
    );
  }

  Future<void> _viewGuarantors(Loan loan) async {
    showDialog(
      context: context,
      builder: (context) => _GuarantorsDialog(loan: loan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/loanImg.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 32,
                    color: Colors.white,
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 20,
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Text('Agent Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Active'),
          ],
        ),
      ),
      body: Consumer<LoanProvider>(
        builder: (context, provider, child) {
          final stats = provider.getStatistics();
          final loans = provider.loans;

          final pendingLoans =
              loans.where((l) => l.status == 'pending').toList();
          final approvedLoans =
              loans.where((l) => l.status == 'approved').toList();
          final activeLoans = loans
              .where((l) =>
                  l.status == 'disbursed' ||
                  l.status == 'active' ||
                  l.status == 'completed')
              .toList();

          return RefreshIndicator(
            onRefresh: _loadData,
            child: Column(
              children: [
                if (user != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: Theme.of(context).primaryColor.withOpacity(0.05),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Agent: ${user.fullName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Total',
                          value: stats['total'] ?? 0,
                          icon: Icons.assignment,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          title: 'Pending',
                          value: stats['pending'] ?? 0,
                          icon: Icons.hourglass_empty,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          title: 'Active',
                          value: stats['active'] ?? 0,
                          icon: Icons.payment,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isWorking) const LinearProgressIndicator(),

                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLoanList(
                              pendingLoans,
                              emptyText: 'No pending loan applications',
                              actionBuilder: (loan) => Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isWorking
                                          ? null
                                          : () => _approveLoan(loan.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Approve'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isWorking
                                          ? null
                                          : () => _rejectLoan(loan.id),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                            color: Colors.red),
                                      ),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildLoanList(
                              approvedLoans,
                              emptyText: 'No approved loans waiting',
                              actionBuilder: (loan) => ElevatedButton.icon(
                                onPressed: _isWorking
                                    ? null
                                    : () => _disburseLoan(loan.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('Disburse'),
                              ),
                            ),
                            _buildLoanList(
                              activeLoans,
                              emptyText: 'No active loans',
                              actionBuilder: (loan) => Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _viewRepayments(loan),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                      ),
                                      icon: const Icon(Icons.receipt_long,
                                          size: 16),
                                      label: const Text('Repayments'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _viewGuarantors(loan),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                      ),
                                      icon: const Icon(Icons.people, size: 16),
                                      label: const Text('Guarantors'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoanList(
    List<Loan> loans, {
    required String emptyText,
    required Widget Function(Loan) actionBuilder,
  }) {
    if (loans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                emptyText,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Loan #${loan.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(loan.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        loan.status.toUpperCase(),
                        style: TextStyle(
                          color: _statusColor(loan.status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (loan.customerName != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        loan.customerName!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                _row('Amount', '₦${loan.amount.toStringAsFixed(0)}'),
                _row('Tenure', '${loan.tenure} ${loan.duration}'),
                _row(
                  'Interest',
                  '${loan.interestRate?.toStringAsFixed(1) ?? '0.0'}%',
                ),
                if (loan.totalRepayment != null)
                  _row(
                    'Total Repayment',
                    '₦${loan.totalRepayment!.toStringAsFixed(0)}',
                  ),
                if (loan.paidAmount > 0)
                  _row(
                    'Paid So Far',
                    '₦${loan.paidAmount.toStringAsFixed(0)}',
                  ),
                if (loan.totalRepayment != null)
                  _row(
                    'Outstanding',
                    '₦${(loan.totalRepayment! - loan.paidAmount).clamp(0, loan.totalRepayment!).toStringAsFixed(0)}',
                  ),
                if (loan.purpose != null && loan.purpose!.isNotEmpty)
                  _row('Purpose', loan.purpose!),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: actionBuilder(loan)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'disbursed':
        return Colors.green;
      case 'active':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================
// Repayments dialog — with confirm/reject for pending payments
// ============================================================

class _RepaymentsDialog extends StatefulWidget {
  final Loan loan;

  const _RepaymentsDialog({required this.loan});

  @override
  State<_RepaymentsDialog> createState() => _RepaymentsDialogState();
}

class _RepaymentsDialogState extends State<_RepaymentsDialog> {
  List<Map<String, dynamic>> _repayments = [];
  bool _loading = true;
  String? _error;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('repayments')
          .select()
          .eq('loan_id', widget.loan.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _repayments = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirm(Map<String, dynamic> r) async {
    setState(() => _isWorking = true);
    try {
      final provider = context.read<LoanProvider>();
      await provider.confirmRepayment(r['id'] as int);
      showToast('Payment confirmed');
      await _load();
    } catch (e) {
      showToast('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final reason = await _askReason();
    if (reason == null) return;

    setState(() => _isWorking = true);
    try {
      final provider = context.read<LoanProvider>();
      await provider.rejectRepayment(r['id'] as int, reason: reason);
      showToast('Payment rejected');
      await _load();
    } catch (e) {
      showToast('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g., No matching transfer found',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.pop(context, t.isEmpty ? 'Rejected by agent' : t);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  String _money(dynamic v) {
    return NumberFormat.currency(symbol: '₦', decimalDigits: 0)
        .format(_asDouble(v));
  }

  String _date(dynamic v) {
    final d = _asDate(v);
    if (d == null) return 'N/A';
    return DateFormat('MMM d, y HH:mm').format(d);
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;

    final confirmed = _repayments
        .where((r) => r['status'] == 'confirmed')
        .fold<double>(0, (s, r) => s + _asDouble(r['amount']));
    final pending = _repayments
        .where((r) => r['status'] == 'pending')
        .fold<double>(0, (s, r) => s + _asDouble(r['amount']));
    final totalOwed = loan.totalRepayment ?? loan.amount;
    final outstanding = (totalOwed - confirmed).clamp(0, totalOwed);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repayments — Loan #${loan.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (loan.customerName != null)
                        Text(
                          loan.customerName!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal[200]!),
              ),
              child: Column(
                children: [
                  _summaryRow('Total Loan', _money(totalOwed)),
                  _summaryRow('Confirmed', _money(confirmed),
                      color: Colors.green),
                  if (pending > 0)
                    _summaryRow('Pending confirmation', _money(pending),
                        color: Colors.orange),
                  _summaryRow(
                    'Outstanding',
                    _money(outstanding),
                    color: outstanding > 0 ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_isWorking) const LinearProgressIndicator(),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Failed to load repayments:\n$_error',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _repayments.isEmpty
                          ? Center(
                              child: Text(
                                'No repayments recorded yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _repayments.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final r = _repayments[index];
                                final status =
                                    (r['status'] ?? 'pending').toString();
                                final isPending = status == 'pending';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: _statusColor(
                                                    status)
                                                .withOpacity(0.15),
                                            child: Icon(
                                              status == 'confirmed'
                                                  ? Icons.check
                                                  : status == 'rejected'
                                                      ? Icons.close
                                                      : Icons.hourglass_empty,
                                              size: 16,
                                              color: _statusColor(status),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _money(r['amount']),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  'Method: ${r['payment_method'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  'Ref: ${r['transaction_id'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                Text(
                                                  _date(r['payment_date'] ??
                                                      r['created_at']),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status)
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isPending) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _isWorking
                                                    ? null
                                                    : () => _confirm(r),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green,
                                                ),
                                                icon: const Icon(Icons.check,
                                                    size: 16),
                                                label: const Text('Confirm'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: _isWorking
                                                    ? null
                                                    : () => _reject(r),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: const BorderSide(
                                                      color: Colors.red),
                                                ),
                                                icon: const Icon(Icons.close,
                                                    size: 16),
                                                label: const Text('Reject'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (r['rejection_reason'] != null &&
                                          r['rejection_reason']
                                              .toString()
                                              .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 6, left: 42),
                                          child: Text(
                                            'Reason: ${r['rejection_reason']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.red,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Guarantors dialog — unchanged
// ============================================================

class _GuarantorsDialog extends StatefulWidget {
  final Loan loan;

  const _GuarantorsDialog({required this.loan});

  @override
  State<_GuarantorsDialog> createState() => _GuarantorsDialogState();
}

class _GuarantorsDialogState extends State<_GuarantorsDialog> {
  List<Map<String, dynamic>> _guarantors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('guarantors')
          .select()
          .eq('loan_id', widget.loan.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _guarantors = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guarantors — Loan #${loan.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (loan.customerName != null)
                        Text(
                          loan.customerName!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Failed to load guarantors:\n$_error',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _guarantors.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined,
                                      size: 56, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No guarantors on record for this loan',
                                    style:
                                        TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _guarantors.length,
                              itemBuilder: (context, index) {
                                final g = _guarantors[index];
                                return Card(
                                  margin:
                                      const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person,
                                              size: 18,
                                              color: Colors.indigo,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                (g['full_name'] ??
                                                        'Unnamed Guarantor')
                                                    .toString(),
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _detailRow(
                                          Icons.work_outline,
                                          'Occupation',
                                          g['occupation'],
                                        ),
                                        _detailRow(
                                          Icons.phone_outlined,
                                          'Phone',
                                          g['phone_number'],
                                        ),
                                        _detailRow(
                                          Icons.people_outline,
                                          'Relationship',
                                          g['relationship'],
                                        ),
                                        _detailRow(
                                          Icons.home_outlined,
                                          'Address',
                                          g['address'],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value) {
    final text = (value == null || value.toString().isEmpty)
        ? 'N/A'
        : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}