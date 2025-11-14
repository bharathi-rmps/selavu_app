import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'add_expense_screen.dart';

class AccountTransactionsScreen extends StatefulWidget {
  final Account account;

  const AccountTransactionsScreen({
    super.key,
    required this.account,
  });

  @override
  State<AccountTransactionsScreen> createState() => _AccountTransactionsScreenState();
}

class _AccountTransactionsScreenState extends State<AccountTransactionsScreen> {
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

  // Filter transactions for this account
  List<Map<String, dynamic>> _filterTransactionsForAccount(
    List<Map<String, dynamic>> allTransactions,
    String accountName,
  ) {
    return allTransactions.where((transaction) {
      final type = transaction['type'] as String;
      if (type == 'transfer') {
        final fromAccount = transaction['fromAccount'] as String? ?? '';
        final toAccount = transaction['toAccount'] as String? ?? '';
        return fromAccount == accountName || toAccount == accountName;
      } else {
        final account = transaction['accountName'] as String? ?? '';
        return account == accountName;
      }
    }).toList();
  }

  // Group transactions by date
  Map<DateTime, List<Map<String, dynamic>>> _groupTransactionsByDate(List<Map<String, dynamic>> transactions) {
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
                  ],
                ),
              ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
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
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Transactions'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _authService.currentUser == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<List<Account>>(
              stream: _firebaseService.getAccounts(_authService.currentUser!.uid),
              builder: (context, accountsSnapshot) {
                // Get current account with latest balance
                Account? currentAccount;
                if (accountsSnapshot.hasData) {
                  try {
                    currentAccount = accountsSnapshot.data!.firstWhere(
                      (acc) => acc.name == widget.account.name,
                    );
                  } catch (e) {
                    currentAccount = widget.account;
                  }
                } else {
                  currentAccount = widget.account;
                }

                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firebaseService.getAllTransactions(_authService.currentUser!.uid),
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
                    final accountTransactions = _filterTransactionsForAccount(
                      allTransactions,
                      widget.account.name,
                    );

                    return Column(
                      children: [
                        // Account Details Card
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
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D2D3A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  currentAccount?.icon ?? widget.account.icon,
                                  color: const Color(0xFF6366F1),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentAccount?.name ?? widget.account.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Balance: ${(currentAccount?.balance ?? widget.account.balance) < 0 ? '-' : ''}₹${(currentAccount?.balance ?? widget.account.balance).abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: (currentAccount?.balance ?? widget.account.balance) < 0
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total Records: ${accountTransactions.length}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white60,
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
                      child: accountTransactions.isEmpty
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
                                    'No transactions for this account',
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
                                final groupedTransactions = _groupTransactionsByDate(accountTransactions);
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
                                        ...transactionsForDate.map((transaction) {
                                          final type = transaction['type'] as String;
                                          final amount = transaction['amount'] as double;
                                          final transactionDate = transaction['transactionDateTime'] as DateTime;
                                          
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
                                            final fromAccount = transaction['fromAccount'] as String? ?? '';
                                            final toAccount = transaction['toAccount'] as String? ?? '';
                                            if (fromAccount == widget.account.name) {
                                              title = 'To $toAccount';
                                            } else {
                                              title = 'From $fromAccount';
                                            }
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
    );
  }
}

