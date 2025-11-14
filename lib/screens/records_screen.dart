import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'add_expense_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

enum ViewMode { daily, weekly, monthly, threeMonths, sixMonths, yearly }

class _RecordsScreenState extends State<RecordsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  DateTime _selectedMonth = DateTime.now();
  ViewMode _viewMode = ViewMode.monthly;
  bool _showTotal = true;
  bool _carryOver = false;

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

  double _getTotalExpenses(List<Map<String, dynamic>> transactions) {
    return transactions.where((t) => t['type'] == 'expense').fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  double _getTotalIncome(List<Map<String, dynamic>> transactions) {
    return transactions.where((t) => t['type'] == 'income').fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  List<Map<String, dynamic>> _filterTransactionsByViewMode(List<Map<String, dynamic>> transactions, DateTime selectedDate) {
    switch (_viewMode) {
      case ViewMode.daily:
        return transactions.where((transaction) {
          final date = transaction['transactionDateTime'] as DateTime;
          return date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
        }).toList();
      case ViewMode.weekly:
        final weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return transactions.where((transaction) {
          final date = transaction['transactionDateTime'] as DateTime;
          return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              date.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
      case ViewMode.monthly:
        return transactions.where((transaction) {
          final date = transaction['transactionDateTime'] as DateTime;
          return date.year == selectedDate.year &&
              date.month == selectedDate.month;
        }).toList();
      case ViewMode.threeMonths:
        final startDate = DateTime(selectedDate.year, selectedDate.month - 2, 1);
        final endDate = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        return transactions.where((transaction) {
          final date = transaction['transactionDateTime'] as DateTime;
          return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(endDate.add(const Duration(days: 1)));
        }).toList();
      case ViewMode.sixMonths:
        final startDate = DateTime(selectedDate.year, selectedDate.month - 5, 1);
        final endDate = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        return transactions.where((transaction) {
          final date = transaction['transactionDateTime'] as DateTime;
          return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(endDate.add(const Duration(days: 1)));
        }).toList();
      case ViewMode.yearly:
        return transactions.where((transaction) {
          final date = transaction['transactionDateTime'] as DateTime;
          return date.year == selectedDate.year;
        }).toList();
    }
  }

  String _getViewModeTitle() {
    switch (_viewMode) {
      case ViewMode.daily:
        return DateFormat('MMM dd, yyyy').format(_selectedMonth);
      case ViewMode.weekly:
        final weekStart = _selectedMonth.subtract(Duration(days: _selectedMonth.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd, yyyy').format(weekEnd)}';
      case ViewMode.monthly:
        return DateFormat('MMMM yyyy').format(_selectedMonth);
      case ViewMode.threeMonths:
        final startDate = DateTime(_selectedMonth.year, _selectedMonth.month - 2, 1);
        return '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM yyyy').format(_selectedMonth)}';
      case ViewMode.sixMonths:
        final startDate = DateTime(_selectedMonth.year, _selectedMonth.month - 5, 1);
        return '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM yyyy').format(_selectedMonth)}';
      case ViewMode.yearly:
        return _selectedMonth.year.toString();
    }
  }

  double _calculateCarryOverExpenses(List<Map<String, dynamic>> allTransactions, DateTime currentPeriodStart) {
    if (!_carryOver) return 0.0;
    
    // Calculate total expenses from previous month
    final previousMonth = DateTime(currentPeriodStart.year, currentPeriodStart.month - 1);
    final previousMonthTransactions = allTransactions.where((transaction) {
      final date = transaction['transactionDateTime'] as DateTime;
      return transaction['type'] == 'expense' &&
          date.year == previousMonth.year &&
          date.month == previousMonth.month;
    }).toList();
    
    return _getTotalExpenses(previousMonthTransactions);
  }

  // Group transactions by date
  Map<DateTime, List<Map<String, dynamic>>> _groupTransactionsByDate(List<Map<String, dynamic>> transactions) {
    final grouped = <DateTime, List<Map<String, dynamic>>>{};
    
    for (final transaction in transactions) {
      final date = transaction['transactionDateTime'] as DateTime;
      // Normalize to date only (remove time)
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      if (!grouped.containsKey(dateOnly)) {
        grouped[dateOnly] = [];
      }
      grouped[dateOnly]!.add(transaction);
    }
    
    // Sort dates in descending order (newest first)
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
      // transfer
      transactionType = 'Transfer';
      final fromAccount = transaction['fromAccount'] as String? ?? 'N/A';
      final toAccount = transaction['toAccount'] as String? ?? 'N/A';
      accountInfo = '$fromAccount → $toAccount';
      category = null; // No category for transfers
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

  Widget _buildEnhancedDetailRow(IconData icon, String label, String value, {bool isNotes = false}) {
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

  void _previousPeriod() {
    setState(() {
      switch (_viewMode) {
        case ViewMode.daily:
          _selectedMonth = _selectedMonth.subtract(const Duration(days: 1));
          break;
        case ViewMode.weekly:
          _selectedMonth = _selectedMonth.subtract(const Duration(days: 7));
          break;
        case ViewMode.monthly:
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
          break;
        case ViewMode.threeMonths:
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 3);
          break;
        case ViewMode.sixMonths:
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 6);
          break;
        case ViewMode.yearly:
          _selectedMonth = DateTime(_selectedMonth.year - 1, _selectedMonth.month);
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_viewMode) {
        case ViewMode.daily:
          _selectedMonth = _selectedMonth.add(const Duration(days: 1));
          break;
        case ViewMode.weekly:
          _selectedMonth = _selectedMonth.add(const Duration(days: 7));
          break;
        case ViewMode.monthly:
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
          break;
        case ViewMode.threeMonths:
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 3);
          break;
        case ViewMode.sixMonths:
          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 6);
          break;
        case ViewMode.yearly:
          _selectedMonth = DateTime(_selectedMonth.year + 1, _selectedMonth.month);
          break;
      }
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // View Mode
                  const Text(
                    'View mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ViewMode.values.map((mode) {
                      final labels = {
                        ViewMode.daily: 'Daily',
                        ViewMode.weekly: 'Weekly',
                        ViewMode.monthly: 'Monthly',
                        ViewMode.threeMonths: '3 Months',
                        ViewMode.sixMonths: '6 Months',
                        ViewMode.yearly: 'Yearly',
                      };
                      final isSelected = _viewMode == mode;
                      return FilterChip(
                        label: Text(labels[mode]!),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            _viewMode = mode;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Show Total
                  const Text(
                    'Show total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Yes'),
                        selected: _showTotal,
                        onSelected: (selected) {
                          setDialogState(() {
                            _showTotal = true;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('No'),
                        selected: !_showTotal,
                        onSelected: (selected) {
                          setDialogState(() {
                            _showTotal = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Carry Over
                  const Text(
                    'Carry over',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('On'),
                        selected: _carryOver,
                        onSelected: (selected) {
                          setDialogState(() {
                            _carryOver = true;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      ChoiceChip(
                        label: const Text('Off'),
                        selected: !_carryOver,
                        onSelected: (selected) {
                          setDialogState(() {
                            _carryOver = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterDialog,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _authService.currentUser == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.getAllTransactions(_authService.currentUser!.uid),
              builder: (context, transactionsSnapshot) {
                if (transactionsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (transactionsSnapshot.hasError) {
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
                          'Error: ${transactionsSnapshot.error}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Nested StreamBuilder for income from accounts
                return StreamBuilder<double>(
                  stream: _firebaseService.getTotalIncomeStream(_authService.currentUser!.uid),
                  builder: (context, incomeSnapshot) {
                    final currentUserId = _authService.currentUser!.uid;
                    final allTransactions = (transactionsSnapshot.data ?? [])
                        .where((transaction) => transaction['userId'] == currentUserId)
                        .toList();
                    final filteredTransactions = _filterTransactionsByViewMode(allTransactions, _selectedMonth);
                    final periodExpenseTotal = _getTotalExpenses(filteredTransactions);
                    final periodIncomeTotal = _getTotalIncome(filteredTransactions);
                    // Get total income from all account balances
                    final totalAccountBalance = incomeSnapshot.data ?? 0.0;
          
              // Calculate period start for carry over
              DateTime periodStart;
              switch (_viewMode) {
                case ViewMode.daily:
                  periodStart = DateTime(_selectedMonth.year, _selectedMonth.month, _selectedMonth.day);
                  break;
                case ViewMode.weekly:
                  periodStart = _selectedMonth.subtract(Duration(days: _selectedMonth.weekday - 1));
                  break;
                case ViewMode.monthly:
                  periodStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
                  break;
                case ViewMode.threeMonths:
                  periodStart = DateTime(_selectedMonth.year, _selectedMonth.month - 2, 1);
                  break;
                case ViewMode.sixMonths:
                  periodStart = DateTime(_selectedMonth.year, _selectedMonth.month - 5, 1);
                  break;
                case ViewMode.yearly:
                  periodStart = DateTime(_selectedMonth.year, 1, 1);
                  break;
              }
              
                    // Calculate carry over expenses from previous month
                    final carryOverExpenses = _calculateCarryOverExpenses(allTransactions, periodStart);
                    final totalExpensesWithCarryOver = periodExpenseTotal + carryOverExpenses;
                    final periodBalance = totalAccountBalance - totalExpensesWithCarryOver;

                    return Column(
            children: [
              // Month Navigation
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _previousPeriod,
                      icon: const Icon(Icons.chevron_left),
                      iconSize: 32,
                    ),
                    Text(
                      _getViewModeTitle(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _nextPeriod,
                      icon: const Icon(Icons.chevron_right),
                      iconSize: 32,
                    ),
                  ],
                ),
              ),
              // Expense, Income, Balance Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Expense Card
                    Expanded(
                      child: SizedBox(
                        height: 110,
                        child: Card(
                          color: const Color(0xFF2A1F1F),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Expense',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹${totalExpensesWithCarryOver.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEF4444),
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: _carryOver && carryOverExpenses > 0 ? 4 : 0,
                                ),
                                if (_carryOver && carryOverExpenses > 0)
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '(+${carryOverExpenses.toStringAsFixed(2)})',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFF87171),
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Income Card
                    Expanded(
                      child: SizedBox(
                        height: 110,
                        child: Card(
                          color: const Color(0xFF1F2A1F),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Income',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '₹${periodIncomeTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Balance Card (shown only if _showTotal is true)
                    if (_showTotal) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 110,
                          child: Card(
                            color: periodBalance >= 0 
                                ? const Color(0xFF1F1F2A)
                                : const Color(0xFF2A1F1F),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Balance',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '₹${periodBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: periodBalance >= 0 
                                              ? const Color(0xFF6366F1)
                                              : const Color(0xFFF59E0B),
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
                    // Transactions List grouped by date
                    Expanded(
                      child: filteredTransactions.isEmpty
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
                                    'No transactions for this period',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tap the + button to add a transaction',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Builder(
                              builder: (context) {
                                final groupedTransactions = _groupTransactionsByDate(filteredTransactions);
                                final dates = groupedTransactions.keys.toList();
                                
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: dates.length,
                                  itemBuilder: (context, dateIndex) {
                                    final date = dates[dateIndex];
                                    final transactionsForDate = groupedTransactions[date]!;
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Date header
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
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
                                        // Transactions for this date
                                        ...transactionsForDate.map((transaction) {
                                          final type = transaction['type'] as String;
                                          final amount = transaction['amount'] as double;
                                          final transactionDate = transaction['transactionDateTime'] as DateTime;
                                          
                                          // Build title based on type
                                          String title;
                                          IconData icon;
                                          Color amountColor;
                                          
                                          if (type == 'income') {
                                            title = transaction['category'] as String? ?? 'Income';
                                            icon = Icons.trending_up;
                                            amountColor = const Color(0xFF10B981);
                                          } else if (type == 'expense') {
                                            title = transaction['category'] as String? ?? 'Expense';
                                            icon = Icons.trending_down;
                                            amountColor = const Color(0xFFEF4444);
                                          } else {
                                            // transfer
                                            title = '${transaction['fromAccount']} → ${transaction['toAccount']}';
                                            icon = Icons.swap_horiz;
                                            amountColor = const Color(0xFF6366F1);
                                          }
                                          
                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: const Color(0xFF2D2D3A),
                                                child: Icon(
                                                  icon,
                                                  color: amountColor,
                                                ),
                                              ),
                                              title: Text(
                                                title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Text(
                                                DateFormat('hh:mm a').format(transactionDate),
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                ),
                                              ),
                                              trailing: Text(
                                                '${type == 'expense' ? '-' : type == 'income' ? '+' : ''}₹${amount.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: amountColor,
                                                ),
                                              ),
                                              onTap: () {
                                                _showTransactionDetails(transaction);
                                              },
                                              onLongPress: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Delete Transaction'),
                                                    content: Text(
                                                        'Are you sure you want to delete this ${type} transaction?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(context).pop(),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                          _deleteTransaction(type, transaction['id'] as String);
                                                        },
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: Colors.red,
                                                        ),
                                                        child: const Text('Delete'),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddExpenseScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

