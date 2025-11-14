import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'add_expense_screen.dart';

class CategoryExpensesScreen extends StatefulWidget {
  final String categoryName;
  final double categoryTotal;
  final double overallTotal;
  final String transactionType; // 'expense' or 'income'

  const CategoryExpensesScreen({
    super.key,
    required this.categoryName,
    required this.categoryTotal,
    required this.overallTotal,
    this.transactionType = 'expense', // Default to expense for backward compatibility
  });

  @override
  State<CategoryExpensesScreen> createState() => _CategoryExpensesScreenState();
}

class _CategoryExpensesScreenState extends State<CategoryExpensesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  Future<void> _deleteTransaction(String type, String id) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _firebaseService.deleteTransaction(type, id, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Group transactions by date
  Map<DateTime, List<Map<String, dynamic>>> _groupTransactionsByDate(
      List<Map<String, dynamic>> transactions) {
    final grouped = <DateTime, List<Map<String, dynamic>>>{};

    for (final transaction in transactions) {
      final date = transaction['transactionDateTime'] as DateTime;
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (!grouped.containsKey(dateOnly)) {
        grouped[dateOnly] = [];
      }
      grouped[dateOnly]!.add(transaction);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedGrouped = <DateTime, List<Map<String, dynamic>>>{};
    for (final date in sortedDates) {
      sortedGrouped[date] = grouped[date]!;
    }

    return sortedGrouped;
  }

  // Format date header: "Month Date, Day" (e.g., "January 15, Monday")
  String _formatDateHeader(DateTime date) {
    final monthName = DateFormat('MMMM').format(date);
    final dayOfMonth = date.day;
    final dayName = DateFormat('EEEE').format(date);
    return '$monthName $dayOfMonth, $dayName';
  }

  // Show transaction details popup
  void _showTransactionDetails(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as double;
    final date = transaction['transactionDateTime'] as DateTime;
    final notes = transaction['notes'] as String? ?? '';

    String transactionType;
    String accountInfo;
    String? category;
    Color typeColor;
    IconData typeIcon;
    Color backgroundColor;

    if (type == 'income') {
      transactionType = 'Income';
      accountInfo = transaction['accountName'] as String? ?? 'N/A';
      category = transaction['category'] as String? ?? 'N/A';
      typeColor = const Color(0xFF10B981);
      typeIcon = Icons.trending_up;
      backgroundColor = const Color(0xFF10B981).withOpacity(0.1);
    } else if (type == 'expense') {
      transactionType = 'Expense';
      accountInfo = transaction['accountName'] as String? ?? 'N/A';
      category = transaction['category'] as String? ?? 'N/A';
      typeColor = const Color(0xFFEF4444);
      typeIcon = Icons.trending_down;
      backgroundColor = const Color(0xFFEF4444).withOpacity(0.1);
    } else {
      transactionType = 'Transfer';
      final fromAccount = transaction['fromAccount'] as String? ?? 'N/A';
      final toAccount = transaction['toAccount'] as String? ?? 'N/A';
      accountInfo = '$fromAccount → $toAccount';
      category = null;
      typeColor = const Color(0xFF6366F1);
      typeIcon = Icons.swap_horiz;
      backgroundColor = const Color(0xFF6366F1).withOpacity(0.1);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with transaction type
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        typeIcon,
                        color: typeColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transactionType,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              // Details section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEnhancedDetailRow(
                      Icons.access_time,
                      'Transaction Time',
                      DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                    ),
                    const SizedBox(height: 20),
                    _buildEnhancedDetailRow(
                      Icons.account_balance_wallet,
                      'Account',
                      accountInfo,
                    ),
                    if (category != null) ...[
                      const SizedBox(height: 20),
                      _buildEnhancedDetailRow(
                        Icons.category,
                        'Category',
                        category!,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildEnhancedDetailRow(
                      Icons.note,
                      'Notes',
                      notes.isEmpty ? 'No notes' : notes,
                      isNotes: true,
                    ),
                  ],
                ),
              ),
              // Edit and Delete buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close details dialog
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AddExpenseScreen(
                                transactionToEdit: transaction,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: typeColor,
                          side: BorderSide(color: typeColor, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E2E),
                              title: const Text(
                                'Delete Transaction',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Are you sure you want to delete this transaction? This action cannot be undone.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(); // Close confirmation dialog
                                    Navigator.of(context).pop(); // Close details dialog
                                    _deleteTransaction(
                                      transaction['type'] as String,
                                      transaction['id'] as String,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedDetailRow(
      IconData icon, String label, String value,
      {bool isNotes = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D3A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isNotes ? 14 : 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: isNotes ? 1.4 : 1.2,
                  ),
                  maxLines: isNotes ? null : 2,
                  overflow: isNotes ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get color for category - Dark theme friendly color
  Color _getCategoryColor() {
    return widget.transactionType == 'expense'
        ? const Color(0xFFEF4444) // Red for expenses
        : const Color(0xFF10B981); // Green for income
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.overallTotal > 0
        ? (widget.categoryTotal / widget.overallTotal * 100)
        : 0.0;
    final remainingPercentage = 100.0 - percentage;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: true,
        elevation: 0,
      ),
      body: _authService.currentUser == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.getAllTransactions(
                  _authService.currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final allTransactions = snapshot.data ?? [];
                final currentUserId = _authService.currentUser!.uid;
                final userTransactions = allTransactions
                    .where((transaction) =>
                        transaction['userId'] == currentUserId)
                    .toList();

                // Filter transactions for this category
                final categoryTransactions = userTransactions
                    .where((transaction) =>
                        transaction['type'] == widget.transactionType &&
                        (transaction['category'] as String? ?? '') ==
                            widget.categoryName)
                    .toList();

                return Column(
                  children: [
                    // Pie Chart and Total Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2D2D3A),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Pie Chart
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 50,
                                sections: [
                                  PieChartSectionData(
                                    value: widget.categoryTotal,
                                    title: '${percentage.toStringAsFixed(1)}%',
                                    color: _getCategoryColor(),
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: widget.overallTotal -
                                        widget.categoryTotal,
                                    title: '',
                                    color: const Color(0xFF2D2D3A),
                                    radius: 60,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Total Expenses Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2D3A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.transactionType == 'expense'
                                      ? 'Total Expenses: '
                                      : 'Total Income: ',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${widget.categoryTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: widget.transactionType == 'expense'
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Transactions List
                    Expanded(
                      child: categoryTransactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 64,
                                    color: Colors.white30,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No transactions for this category',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final groupedTransactions =
                                    _groupTransactionsByDate(
                                        categoryTransactions);
                                final dates = groupedTransactions.keys.toList();

                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: dates.length,
                                  itemBuilder: (context, dateIndex) {
                                    final date = dates[dateIndex];
                                    final transactionsForDate =
                                        groupedTransactions[date]!;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 16, bottom: 8, left: 4),
                                          child: Text(
                                            _formatDateHeader(date),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white70,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        ...transactionsForDate.map(
                                            (transaction) {
                                          final amount = transaction['amount']
                                              as double;
                                          final transactionDate =
                                              transaction['transactionDateTime']
                                                  as DateTime;

                                          return Card(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor:
                                                    const Color(0xFF2D2D3A),
                                                child: Icon(
                                                  widget.transactionType == 'expense'
                                                      ? Icons.trending_down
                                                      : Icons.trending_up,
                                                  color: widget.transactionType == 'expense'
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF10B981),
                                                ),
                                              ),
                                              title: Text(
                                                transaction['accountName'] as String? ?? 
                                                transaction['fromAccount'] as String? ?? 
                                                'N/A',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Text(
                                                DateFormat('hh:mm a')
                                                    .format(transactionDate),
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                ),
                                              ),
                                              trailing: Text(
                                                '${widget.transactionType == 'expense' ? '-' : '+'}₹${amount.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: widget.transactionType == 'expense'
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF10B981),
                                                ),
                                              ),
                                              onTap: () {
                                                _showTransactionDetails(
                                                    transaction);
                                              },
                                              onLongPress: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Delete Transaction'),
                                                    content: Text(
                                                        'Are you sure you want to delete this expense transaction?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(),
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(
                                                                  context)
                                                              .pop();
                                                          _deleteTransaction(
                                                            'expense',
                                                            transaction['id']
                                                                as String,
                                                          );
                                                        },
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              Colors.red,
                                                        ),
                                                        child: const Text(
                                                            'Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

