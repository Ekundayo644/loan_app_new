import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app_new/providers/loan_provider.dart';
import 'package:loan_app_new/providers/auth_provider.dart';
import 'package:loan_app_new/widgets/custom_button.dart';
import 'package:loan_app_new/widgets/custom_text_field.dart';
import 'package:loan_app_new/utils/toast_utils.dart';

class ApplyLoanScreen extends StatefulWidget {
  const ApplyLoanScreen({super.key});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _tenureController = TextEditingController();
  final _purposeController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bvnNinController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;

  String? _selectedBank;
  String _selectedDuration = 'days'; // default

  // List of banks in Nigeria (including fintechs and private banks)
  final List<String> _banks = [
    'Access Bank',
    'Citibank Nigeria',
    'Ecobank Nigeria',
    'Fidelity Bank',
    'First Bank of Nigeria',
    'First City Monument Bank (FCMB)',
    'Globus Bank',
    'Guaranty Trust Bank (GTBank)',
    'Heritage Bank',
    'Jaiz Bank',
    'Keystone Bank',
    'Kuda Microfinance Bank',
    'Lotus Bank',
    'Moniepoint Microfinance Bank',
    'OPay Digital Bank',
    'Optimus Bank',
    'PalmPay Limited',
    'Parallex Bank',
    'Polaris Bank',
    'Premium Trust Bank',
    'Providus Bank',
    'Stanbic IBTC Bank',
    'Standard Chartered Bank',
    'Sterling Bank',
    'SunTrust Bank',
    'Taj Bank',
    'Titan Trust Bank',
    'Union Bank of Nigeria',
    'United Bank for Africa (UBA)',
    'Unity Bank',
    'Wema Bank',
    'Zenith Bank',
  ];

  // Loan duration units
  final List<Map<String, String>> _durations = [
    {'value': 'days', 'label': 'Days'},
    {'value': 'weeks', 'label': 'Weeks'},
    {'value': 'months', 'label': 'Months'},
    {'value': 'years', 'label': 'Years'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _tenureController.dispose();
    _purposeController.dispose();
    _accountNumberController.dispose();
    _bvnNinController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _applyForLoan() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    final tenure = int.tryParse(_tenureController.text);

    if (amount == null || amount <= 0) {
      showToast('Please enter a valid amount', isError: true);
      return;
    }

    if (tenure == null || tenure <= 0) {
      showToast('Please enter a valid tenure', isError: true);
      return;
    }

    if (_selectedBank == null || _selectedBank!.isEmpty) {
      showToast('Please select your bank', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<LoanProvider>();
      await provider.applyForLoan(
        amount: amount,
        tenure: tenure,
        purpose: _purposeController.text,
        duration: _selectedDuration,
        bankName: _selectedBank!,
        accountNumber: _accountNumberController.text,
        bvnNin: _bvnNinController.text,
        phoneNumber: _phoneNumberController.text,
      );

      if (mounted) {
        showToast('Loan application submitted successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast('Application failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Get the label for the currently selected duration (singular form)
  String get _tenureLabel {
    switch (_selectedDuration) {
      case 'days':
        return 'Day(s)';
      case 'weeks':
        return 'Week(s)';
      case 'months':
        return 'Month(s)';
      case 'years':
        return 'Year(s)';
      default:
        return 'Day(s)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Loan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please fill in the details below to apply for a loan',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ============ LOAN AMOUNT ============
              CustomTextField(
                controller: _amountController,
                label: 'Loan Amount',
                hint: 'Enter amount (e.g., 50000)',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter loan amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ============ TENURE + DURATION ============
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tenure number field
                  Expanded(
                    flex: 3,
                    child: CustomTextField(
                      controller: _tenureController,
                      label: 'Tenure',
                      hint: 'e.g., 30',
                      prefixIcon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter tenure';
                        }
                        final tenure = int.tryParse(value);
                        if (tenure == null || tenure <= 0) {
                          return 'Invalid tenure';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Duration unit dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedDuration,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      isExpanded: true,
                      items: _durations.map((d) {
                        return DropdownMenuItem<String>(
                          value: d['value'],
                          child: Text(d['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedDuration = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              // Helper text showing the full tenure expression
              if (_tenureController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Loan duration: ${_tenureController.text} $_tenureLabel',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ============ PURPOSE ============
              CustomTextField(
                controller: _purposeController,
                label: 'Purpose',
                hint: 'Why do you need this loan?',
                prefixIcon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the purpose';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ============ BANK DETAILS ============
              const Text(
                'Bank Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedBank,
                decoration: InputDecoration(
                  labelText: 'Select Bank',
                  hintText: 'Choose your bank',
                  prefixIcon: const Icon(Icons.account_balance),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                isExpanded: true,
                items: _banks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank,
                    child: Text(
                      bank,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your bank';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _accountNumberController,
                label: 'Account Number',
                hint: 'Enter your 10-digit account number',
                prefixIcon: Icons.numbers,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your account number';
                  }
                  if (value.length != 10) {
                    return 'Account number must be 10 digits';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Enter a valid account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _bvnNinController,
                label: 'BVN / NIN',
                hint: 'Enter your 11-digit BVN or NIN',
                prefixIcon: Icons.badge,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your BVN or NIN';
                  }
                  if (value.length != 11) {
                    return 'BVN/NIN must be 11 digits';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Enter a valid BVN/NIN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _phoneNumberController,
                label: 'Phone Number',
                hint: 'Enter your phone number',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                onPressed: _applyForLoan,
                isLoading: _isLoading,
                text: 'Submit Application',
                icon: Icons.send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}