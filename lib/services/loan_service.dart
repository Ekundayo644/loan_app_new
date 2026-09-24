import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loan_app_new/models/loan.dart';
import 'package:loan_app_new/models/transaction.dart';

class LoanService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============= APPLY FOR LOAN =============
  Future<Map<String, dynamic>> applyForLoan({
    required double amount,
    required int tenure,
    required String duration,
    required String bankName,
    required String accountNumber,
    required String bvnNin,
    required String phoneNumber,
    int? productId,
    String? purpose,
    double interestRate = 10.0,
    double processingFee = 0.0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final interest = amount * interestRate / 100.0;
      final totalRepayment = amount + interest + processingFee;

      final data = {
        'user_id': user.id,
        'amount': amount,
        'tenure': tenure,
        'duration': duration,
        'bank_name': bankName,
        'account_number': accountNumber,
        'bvn_nin': bvnNin,
        'phone_number': phoneNumber,
        'product_id': productId,
        'purpose': purpose ?? '',
        'status': 'pending',
        'interest_rate': interestRate,
        'processing_fee': processingFee,
        'total_repayment': totalRepayment,
        'paid_amount': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('loans')
          .insert(data)
          .select()
          .single();

      return {'success': true, 'loan': response};
    } catch (e) {
      throw Exception('Application failed: $e');
    }
  }

  // ============= GET USER LOANS =============
  Future<List<Loan>> getLoans() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('loans')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Loan.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch loans: $e');
    }
  }

  // ============= GET SINGLE LOAN DETAILS =============
  Future<Map<String, dynamic>> getLoanDetails(int loanId) async {
    try {
      final response = await _supabase
          .from('loans')
          .select('*, repayments(*)')
          .eq('id', loanId)
          .single();

      final Map<String, dynamic> loan = Map<String, dynamic>.from(response);
      final repayments = loan.remove('repayments') ?? [];

      return {
        'loan': loan,
        'repayments': repayments,
      };
    } catch (e) {
      throw Exception('Failed to fetch loan details: $e');
    }
  }

  // ============= APPROVE LOAN (Agent/Admin) =============
  Future<Map<String, dynamic>> approveLoan(int loanId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userData = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      if (userData['role'] != 'admin' && userData['role'] != 'agent') {
        throw Exception('Unauthorized: Only admins and agents can approve loans');
      }

      final response = await _supabase
          .from('loans')
          .update({
            'status': 'approved',
            'approved_by': user.id,
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', loanId)
          .select()
          .single();

      return {'success': true, 'loan': response};
    } catch (e) {
      throw Exception('Approval failed: $e');
    }
  }

  // ============= REJECT LOAN (Agent/Admin) =============
  Future<Map<String, dynamic>> rejectLoan(int loanId,
      {String reason = ''}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final response = await _supabase
          .from('loans')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'rejected_at': DateTime.now().toIso8601String(),
          })
          .eq('id', loanId)
          .select()
          .single();

      return {'success': true, 'loan': response};
    } catch (e) {
      throw Exception('Rejection failed: $e');
    }
  }

  // ============= DISBURSE LOAN =============
  Future<Map<String, dynamic>> disburseLoan(int loanId) async {
    try {
      final response = await _supabase
          .from('loans')
          .update({
            'status': 'disbursed',
            'disbursed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', loanId)
          .select()
          .single();

      return {'success': true, 'loan': response};
    } catch (e) {
      throw Exception('Disbursement failed: $e');
    }
  }

  // ============= CUSTOMER: SUBMIT PENDING REPAYMENT =============
  // Customer says "I made the transfer." Creates a pending repayment
  // that the agent must confirm before it counts.
  Future<Map<String, dynamic>> submitPendingRepayment({
    required int loanId,
    required double amount,
    required String paymentMethod,
    required String transactionId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Early duplicate check — better UX than a raw DB constraint error
      final existing = await _supabase
          .from('repayments')
          .select('id')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('This reference has already been used.');
      }

      final now = DateTime.now().toIso8601String();
      final row = {
        'loan_id': loanId,
        'amount': amount,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'user_id': user.id,
        'status': 'pending',
        'payment_date': now,
        'created_at': now,
      };

      final response = await _supabase
          .from('repayments')
          .insert(row)
          .select()
          .single();

      return {'success': true, 'repayment': response};
    } catch (e) {
      throw Exception('Submission failed: $e');
    }
  }

  // ============= AGENT: CONFIRM REPAYMENT =============
  // Flips a pending repayment to 'confirmed' and recomputes the loan's
  // paid_amount from ALL confirmed repayments.
  Future<Map<String, dynamic>> confirmRepayment(int repaymentId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final repayment = await _supabase
          .from('repayments')
          .select()
          .eq('id', repaymentId)
          .single();

      if (repayment['status'] == 'confirmed') {
        throw Exception('Repayment already confirmed');
      }

      await _supabase.from('repayments').update({
        'status': 'confirmed',
        'confirmed_by': user.id,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', repaymentId);

      // Recalculate paid_amount from ALL confirmed repayments for this loan
      final loanId = repayment['loan_id'] as int;
      final allConfirmed = await _supabase
          .from('repayments')
          .select('amount')
          .eq('loan_id', loanId)
          .eq('status', 'confirmed');

      final totalPaid = (allConfirmed as List).fold<double>(
        0.0,
        (sum, r) => sum + ((r['amount'] ?? 0) as num).toDouble(),
      );

      final loan = await _supabase
          .from('loans')
          .select('total_repayment, amount')
          .eq('id', loanId)
          .single();

      final totalOwed =
          ((loan['total_repayment'] ?? loan['amount'] ?? 0) as num).toDouble();

      await _supabase.from('loans').update({
        'paid_amount': totalPaid,
        'status': totalPaid >= totalOwed ? 'completed' : 'active',
      }).eq('id', loanId);

      return {'success': true};
    } catch (e) {
      throw Exception('Confirmation failed: $e');
    }
  }

  // ============= AGENT: REJECT REPAYMENT =============
  Future<Map<String, dynamic>> rejectRepayment(
    int repaymentId, {
    String reason = '',
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _supabase.from('repayments').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'confirmed_by': user.id,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', repaymentId);

      return {'success': true};
    } catch (e) {
      throw Exception('Rejection failed: $e');
    }
  }

  // ============= GET REPAYMENT HISTORY =============
  Future<List<Map<String, dynamic>>> getRepaymentHistory(int loanId) async {
    try {
      final response = await _supabase
          .from('repayments')
          .select()
          .eq('loan_id', loanId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch repayment history: $e');
    }
  }

  // ============= GET REPAYMENT SUMMARY =============
  Future<Map<String, dynamic>> getRepaymentSummary(int loanId) async {
    try {
      final loan = await _supabase
          .from('loans')
          .select()
          .eq('id', loanId)
          .single();

      // Only count CONFIRMED repayments
      final repayments = await _supabase
          .from('repayments')
          .select('amount')
          .eq('loan_id', loanId)
          .eq('status', 'confirmed');

      final totalPaid = (repayments as List).fold<double>(
        0.0,
        (sum, item) => sum + ((item['amount'] ?? 0) as num).toDouble(),
      );

      final totalAmount =
          ((loan['total_repayment'] ?? loan['amount'] ?? 0) as num).toDouble();

      return {
        'loan_id': loanId,
        'total_amount': totalAmount,
        'total_paid': totalPaid,
        'remaining': totalAmount - totalPaid,
        'status': loan['status'],
        'repayment_count': repayments.length,
      };
    } catch (e) {
      throw Exception('Failed to fetch repayment summary: $e');
    }
  }

  // ============= PAYSTACK PAYMENT INTEGRATION =============
  Future<Map<String, dynamic>> initializePaystackPayment({
    required int loanId,
    required double amount,
    required String email,
    String? reference,
  }) async {
    try {
      final paymentData = {
        'loan_id': loanId,
        'amount': amount,
        'email': email,
        'reference':
            reference ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      return {
        'success': true,
        'data': response,
        'authorization_url':
            'https://paystack.com/pay/${response['reference']}',
        'reference': response['reference'],
      };
    } catch (e) {
      throw Exception('Payment initialization failed: $e');
    }
  }

  Future<Map<String, dynamic>> verifyPaystackPayment(String reference) async {
    try {
      final response = await _supabase
          .from('payments')
          .select()
          .eq('reference', reference)
          .single();

      return {
        'success': true,
        'data': response,
        'status': 'success',
      };
    } catch (e) {
      throw Exception('Payment verification failed: $e');
    }
  }

  // ============= TRANSACTION HISTORY =============
  Future<List<Transaction>> getTransactionHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  Future<Map<String, dynamic>> getTransactionDetails(
      String transactionId) async {
    try {
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch transaction details: $e');
    }
  }

  // ============= LOAN PRODUCTS =============
  Future<List<Map<String, dynamic>>> getLoanProducts() async {
    try {
      final response = await _supabase
          .from('loan_products')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch loan products: $e');
    }
  }

  // ============= NOTIFICATIONS =============
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .select()
          .single();

      return {'success': true, 'data': response};
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // ============= GET ALL LOANS (Admin/Agent) =============
  Future<List<Loan>> getAllLoans() async {
    try {
      final response = await _supabase
          .from('loans')
          .select('*, users!loans_user_id_fkey(full_name, email)')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Loan.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch loans: $e');
    }
  }

  // ============= GET DASHBOARD STATS =============
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userData = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      final isAdmin =
          userData['role'] == 'admin' || userData['role'] == 'agent';

      var query = _supabase.from('loans').select();
      if (!isAdmin) {
        query = query.eq('user_id', user.id);
      }

      final loans = await query;

      final totalLoans = loans.length;
      final pendingLoans =
          loans.where((l) => l['status'] == 'pending').length;
      final approvedLoans =
          loans.where((l) => l['status'] == 'approved').length;
      final completedLoans =
          loans.where((l) => l['status'] == 'completed').length;
      final rejectedLoans =
          loans.where((l) => l['status'] == 'rejected').length;

      final totalAmount = loans.fold<double>(
        0.0,
        (sum, loan) => sum + ((loan['amount'] ?? 0) as num).toDouble(),
      );

      final paidAmount = loans.fold<double>(
        0.0,
        (sum, loan) => sum + ((loan['paid_amount'] ?? 0) as num).toDouble(),
      );

      return {
        'total_loans': totalLoans,
        'pending_loans': pendingLoans,
        'approved_loans': approvedLoans,
        'completed_loans': completedLoans,
        'rejected_loans': rejectedLoans,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'outstanding_amount': totalAmount - paidAmount,
        'role': userData['role'],
      };
    } catch (e) {
      throw Exception('Failed to fetch dashboard stats: $e');
    }
  }

  // ============= GET ALL CUSTOMERS (Admin/Agent) =============
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'customer')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch customers: $e');
    }
  }

  // ============= GET CUSTOMER DETAILS =============
  Future<Map<String, dynamic>> getCustomerDetails(String customerId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*, loans(*)')
          .eq('id', customerId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch customer details: $e');
    }
  }
}