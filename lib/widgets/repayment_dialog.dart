import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loan_app_new/providers/loan_provider.dart';
import 'package:loan_app_new/providers/auth_provider.dart';
import 'package:loan_app_new/widgets/custom_button.dart';
import 'package:loan_app_new/widgets/custom_text_field.dart';
import 'package:loan_app_new/utils/toast_utils.dart';

class RepaymentDialog extends StatefulWidget {
  final int loanId;
  final double totalAmount;
  final double outstandingAmount;
  final VoidCallback onSuccess;

  const RepaymentDialog({
    super.key,
    required this.loanId,
    required this.totalAmount,
    required this.outstandingAmount,
    required this.onSuccess,
  });

  @override
  State<RepaymentDialog> createState() => _RepaymentDialogState();
}

class _RepaymentDialogState extends State<RepaymentDialog>
    with SingleTickerProviderStateMixin {
  // ====== COMPANY BANK DETAILS ======
  static const String _bankName = 'First Bank of Nigeria';
  static const String _accountName = 'Loan App Limited';
  static const String _accountNumber = '1234567890';

  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  bool _isLoading = false;

  String _generateReference() {
    final now = DateTime.now();
    final rand = (now.microsecondsSinceEpoch % 100000)
        .toString()
        .padLeft(5, '0');
    final ymd = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return 'LN-$ymd-$rand';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _amountController.text = widget.outstandingAmount.toStringAsFixed(0);
    _referenceController.text = _generateReference();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  double? _validateAmount() {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) {
      showToast('Please enter the amount you want to pay', isError: true);
      return null;
    }
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      showToast('Please enter a valid amount', isError: true);
      return null;
    }
    if (amount > widget.outstandingAmount) {
      showToast(
        'Amount cannot exceed the outstanding balance of ₦${widget.outstandingAmount.toStringAsFixed(0)}',
        isError: true,
      );
      return null;
    }
    return amount;
  }

  // ============================================================
  // BANK TRANSFER SUBMIT
  // ============================================================
  Future<void> _submitBankTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _validateAmount();
    if (amount == null) return;

    final navigator = Navigator.of(context);
    final messengerContext = context;

    setState(() => _isLoading = true);

    try {
      final provider = messengerContext.read<LoanProvider>();
      await provider.submitPendingRepayment(
        loanId: widget.loanId,
        amount: amount,
        paymentMethod: 'bank_transfer',
        transactionId: _referenceController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      widget.onSuccess();
      navigator.pop();
      showToast('Transfer recorded. Waiting for agent confirmation.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString();
      if (msg.contains('already been used')) {
        showToast('This reference has already been used.', isError: true);
      } else {
        showToast('Failed to submit: $msg', isError: true);
      }
    }
  }

  // ============================================================
  // PAYSTACK SUBMIT
  // ============================================================
  Future<void> _submitPaystack() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _validateAmount();
    if (amount == null) return;

    final authProvider = context.read<AuthProvider>();
    final email = authProvider.email;
    if (email == null || email.isEmpty) {
      showToast('No email on your account. Contact support.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<LoanProvider>();
      final result = await provider.initializePaystackPayment(
        loanId: widget.loanId,
        amount: amount,
        email: email,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // The backend returns the Paystack authorization URL.
      final authUrl = result['authorization_url']?.toString() ??
          result['authorizationUrl']?.toString() ??
          result['data']?['authorization_url']?.toString();

      if (authUrl == null || authUrl.isEmpty) {
        showToast('Could not get payment link from Paystack.', isError: true);
        return;
      }

      final uri = Uri.parse(authUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched) {
        showToast('Could not open Paystack checkout.', isError: true);
        return;
      }

      // Once the user returns, verify the payment status.
      // Give them a moment to complete the payment.
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final reference = result['reference']?.toString() ??
          result['data']?['reference']?.toString();

      if (reference != null && reference.isNotEmpty) {
        try {
          await provider.verifyPaystackPayment(reference);
          if (!mounted) return;
          widget.onSuccess();
          Navigator.pop(context);
          showToast('Payment verified successfully.');
        } catch (e) {
          if (!mounted) return;
          showToast(
            'Payment not verified yet. It will be updated once Paystack confirms.',
            isError: true,
          );
        }
      } else {
        if (!mounted) return;
        widget.onSuccess();
        Navigator.pop(context);
        showToast('Payment initiated. Awaiting confirmation.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showToast('Paystack error: ${e.toString()}', isError: true);
    }
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    showToast('$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.outstandingAmount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ==================== HEADER ====================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.payments_outlined,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make Repayment',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Loan #${widget.loanId}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
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
            ),

            // ==================== TABS ====================
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(
                  icon: Icon(Icons.account_balance, size: 20),
                  text: 'Bank Transfer',
                ),
                Tab(
                  icon: Icon(Icons.credit_card, size: 20),
                  text: 'Pay with Paystack',
                ),
              ],
            ),

            const Divider(height: 1),

            // ==================== TAB CONTENT ====================
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------- BALANCE BOX (shared) ----------
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outstanding Balance',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₦${outstanding.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo[900],
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Loan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₦${widget.totalAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------- AMOUNT (shared) ----------
                      CustomTextField(
                        controller: _amountController,
                        label: 'Amount to Pay',
                        hint: 'Enter amount',
                        prefixIcon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Enter a valid amount';
                          }
                          if (amount > outstanding) {
                            return 'Cannot exceed ₦${outstanding.toStringAsFixed(0)}';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // ---------- QUICK CHIPS (shared) ----------
                      Row(
                        children: [
                          ActionChip(
                            label: const Text('Pay Full'),
                            onPressed: () => setState(() =>
                                _amountController.text =
                                    outstanding.toStringAsFixed(0)),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Half'),
                            onPressed: () => setState(() =>
                                _amountController.text =
                                    (outstanding / 2).toStringAsFixed(0)),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('25%'),
                            onPressed: () => setState(() =>
                                _amountController.text =
                                    (outstanding * 0.25).toStringAsFixed(0)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==================== TAB VIEW ====================
                      SizedBox(
                        height: 420, // enough for either tab's content
                        child: TabBarView(
                          controller: _tabController,
                          physics:
                              const NeverScrollableScrollPhysics(), // use TabBar to switch
                          children: [
                            // ---------------- BANK TRANSFER TAB ----------------
                            _buildBankTransferTab(),
                            // ---------------- PAYSTACK TAB ----------------
                            _buildPaystackTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BANK TRANSFER TAB CONTENT
  // ============================================================
  Widget _buildBankTransferTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Transfer to this account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _bankRow('Bank Name', _bankName),
              const SizedBox(height: 8),
              _bankRow('Account Name', _accountName),
              const SizedBox(height: 8),
              _bankRow('Account Number', _accountNumber),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Narration / Reference',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _referenceController.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copy(
                        _referenceController.text, 'Reference'),
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy reference',
                  ),
                  IconButton(
                    onPressed: () => setState(() =>
                        _referenceController.text = _generateReference()),
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Regenerate',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Include this reference in your transfer narration so the agent can match your payment.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PENDING WARNING
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.hourglass_empty,
                  color: Colors.orange[800], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your payment will show as PENDING until an agent confirms receipt. '
                  'Your loan balance will update after confirmation.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        CustomButton(
          onPressed: _isLoading ? null : _submitBankTransfer,
          isLoading: _isLoading,
          text: 'I Have Made This Transfer',
          icon: Icons.check_circle_outline,
        ),
        const SizedBox(height: 12),
        Text(
          'Tap the button above only after you have completed the transfer.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAYSTACK TAB CONTENT
  // ============================================================
  Widget _buildPaystackTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flash_on, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Instant confirmation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Pay directly with your card, bank, or USSD. '
                'Your loan balance updates automatically once the payment succeeds — no need to wait for an agent.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green[900],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _paystackLogoBadge('Card'),
                  const SizedBox(width: 8),
                  _paystackLogoBadge('Bank'),
                  const SizedBox(width: 8),
                  _paystackLogoBadge('USSD'),
                  const SizedBox(width: 8),
                  _paystackLogoBadge('Transfer'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You will be redirected to Paystack\'s secure checkout to complete payment. '
                  'Card details are never stored on our servers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        CustomButton(
          onPressed: _isLoading ? null : _submitPaystack,
          isLoading: _isLoading,
          text: 'Pay with Paystack',
          icon: Icons.open_in_new,
        ),
        const SizedBox(height: 12),
        Text(
          'You will leave the app briefly to complete the payment. '
          'Come back once done — we\'ll verify automatically.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _paystackLogoBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.green[800],
        ),
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _copy(value, label),
          icon: const Icon(Icons.copy, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Copy',
        ),
      ],
    );
  }
}