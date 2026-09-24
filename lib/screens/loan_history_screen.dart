import 'package:loan_app_new/screens/loan_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loan_app_new/providers/loan_provider.dart';
import 'package:loan_app_new/models/loan.dart';
import 'package:loan_app_new/widgets/loan_card.dart';
import 'package:loan_app_new/widgets/repayment_dialog.dart';

class LoanHistoryScreen extends StatefulWidget {
  const LoanHistoryScreen({super.key});

  @override
  State<LoanHistoryScreen> createState() => _LoanHistoryScreenState();
}

class _LoanHistoryScreenState extends State<LoanHistoryScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Approved',
    'Disbursed',
    'Completed',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<LoanProvider>();
    await provider.fetchLoans();
  }

  List<Loan> _getFilteredLoans(List<Loan> loans) {
    if (_selectedFilter == 'All') {
      return loans;
    }
    return loans.where((loan) => loan.status == _selectedFilter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: StadiumBorder(
                        side: isSelected
                            ? BorderSide(color: Theme.of(context).primaryColor)
                            : BorderSide.none,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Summary stats
          Consumer<LoanProvider>(
            builder: (context, provider, child) {
              final stats = provider.getStatistics();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildStatItem('Total', stats['total'] ?? 0, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatItem('Active', stats['active'] ?? 0, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatItem('Pending', stats['pending'] ?? 0, Colors.orange),
                    const SizedBox(width: 16),
                    _buildStatItem('Completed', stats['completed'] ?? 0, Colors.green),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          // Loan list
          Expanded(
            child: Consumer<LoanProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredLoans = _getFilteredLoans(provider.loans);

                if (filteredLoans.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No loans found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFilter == 'All'
                              ? 'You haven\'t applied for any loans yet'
                              : 'No $_selectedFilter loans found',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredLoans.length,
                  itemBuilder: (context, index) {
                    final loan = filteredLoans[index];
                    return LoanCard(
                      loan: loan,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoanDetailsScreen(
                              loanId: loan.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
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
        ),
      ),
    );
  }
}