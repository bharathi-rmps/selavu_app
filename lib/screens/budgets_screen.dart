import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

enum ViewMode { daily, weekly, monthly, threeMonths, sixMonths, yearly }

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  DateTime _selectedMonth = DateTime.now();
  ViewMode _viewMode = ViewMode.monthly;
  bool _showTotal = true;
  bool _carryOver = false;
  final TextEditingController _limitController = TextEditingController();

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

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _showSetBudgetDialog(String categoryName, IconData categoryIcon, {String? budgetId, double? currentLimit}) {
    _limitController.text = currentLimit != null ? currentLimit.toStringAsFixed(2) : '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(budgetId != null ? 'Change Budget Limit' : 'Set Budget'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon and Name
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2D2D3A),
                    child: Icon(categoryIcon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Limit Input
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limit',
                  hintText: 'Enter budget limit',
                  prefixText: '₹',
                ),
              ),
              const SizedBox(height: 16),
              // Month and Year Display
              Text(
                DateFormat('MMMM yyyy').format(_selectedMonth),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _limitController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final limitText = _limitController.text.trim();
              if (limitText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a budget limit'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final limit = double.tryParse(limitText);
              if (limit == null || limit <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid budget limit'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final userId = _authService.currentUser?.uid;
              if (userId == null) {
                Navigator.of(context).pop();
                return;
              }

              try {
                if (budgetId != null) {
                  // Update existing budget
                  await _firebaseService.updateBudgetLimit(budgetId, limit);
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget limit updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  // Create new budget
                  await _firebaseService.addBudget(
                    userId: userId,
                    categoryName: categoryName,
                    categoryIcon: categoryIcon,
                    limit: limit,
                    month: _selectedMonth.month,
                    year: _selectedMonth.year,
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget set successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(budgetId != null ? 'Update' : 'Set'),
          ),
        ],
      ),
    );
  }

  void _showBudgetMenu(BuildContext context, Map<String, dynamic> budget) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Change Limit'),
              onTap: () {
                Navigator.of(context).pop();
                _showSetBudgetDialog(
                  budget['categoryName'] as String,
                  budget['categoryIcon'] as IconData,
                  budgetId: budget['id'] as String,
                  currentLimit: budget['limit'] as double,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              title: const Text('Remove Budget', style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteBudgetConfirmation(budget);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteBudgetConfirmation(Map<String, dynamic> budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Budget'),
        content: Text('Are you sure you want to remove the budget for ${budget['categoryName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firebaseService.deleteBudget(budget['id'] as String);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Budget removed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error removing budget: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Apply'),
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
        title: const Text('Budgets'),
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
      body: Column(
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
          // Budget Cards (placeholder for now)
          if (_showTotal)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Budget Card
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
                                'Budget',
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
                                    '₹0.00',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Spent Card
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
                                'Spent',
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
                                    '₹0.00',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Remaining Card
                  Expanded(
                    child: SizedBox(
                      height: 110,
                      child: Card(
                        color: const Color(0xFF1F1F2A),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Remaining',
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
                                    '₹0.00',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Budgeted Categories and Not Budgeted Sections
          Expanded(
            child: _authService.currentUser == null
                ? const Center(child: Text('Please log in'))
                : StreamBuilder<Map<String, IconData>>(
                    stream: _firebaseService.getCategories(_authService.currentUser!.uid),
                    builder: (context, categoriesSnapshot) {
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _firebaseService.getCustomCategories(_authService.currentUser!.uid),
                        builder: (context, customCategoriesSnapshot) {
                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _firebaseService.getBudgets(
                              _authService.currentUser!.uid,
                              _selectedMonth.month,
                              _selectedMonth.year,
                            ),
                            builder: (context, budgetsSnapshot) {
                              final categories = categoriesSnapshot.data ?? {};
                              final customCategories = customCategoriesSnapshot.data ?? [];
                              // Add custom expense categories to the main categories map
                              final allCategories = Map<String, IconData>.from(categories);
                              for (final customCat in customCategories) {
                                if (customCat['categoryType'] == 'expense') {
                                  allCategories[customCat['categoryName'] as String] = 
                                      customCat['categoryIcon'] as IconData;
                                }
                              }
                              
                              final budgets = budgetsSnapshot.data ?? [];
                              // Sort budgets by category name
                              budgets.sort((a, b) {
                                final nameA = (a['categoryName'] as String).toLowerCase();
                                final nameB = (b['categoryName'] as String).toLowerCase();
                                return nameA.compareTo(nameB);
                              });
                              
                              final budgetedCategoryNames = budgets.map((b) => b['categoryName'] as String).toSet();
                              final notBudgetedCategories = allCategories.entries
                                  .where((entry) => !budgetedCategoryNames.contains(entry.key))
                                  .toList();
                              
                              // Sort not budgeted categories by name
                              notBudgetedCategories.sort((a, b) {
                                final nameA = a.key.toLowerCase();
                                final nameB = b.key.toLowerCase();
                                return nameA.compareTo(nameB);
                              });

                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Budgeted Categories Section
                                    Text(
                                      'Budgeted Categories: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (budgets.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'No Budget Added for current month',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    else
                                      ...budgets.map((budget) {
                                        return StreamBuilder<List<Map<String, dynamic>>>(
                                          stream: _firebaseService.getAllTransactions(_authService.currentUser!.uid),
                                          builder: (context, transactionsSnapshot) {
                                            final categoryName = budget['categoryName'] as String;
                                            final categoryIcon = budget['categoryIcon'] as IconData;
                                            final limit = budget['limit'] as double;
                                            
                                            // Calculate spent for this category in the selected month
                                            double spent = 0.0;
                                            if (transactionsSnapshot.hasData) {
                                              final transactions = transactionsSnapshot.data!;
                                              final monthTransactions = transactions.where((t) {
                                                if (t['type'] != 'expense') return false;
                                                if ((t['category'] as String? ?? '') != categoryName) return false;
                                                final date = t['transactionDateTime'] as DateTime;
                                                return date.year == _selectedMonth.year && 
                                                       date.month == _selectedMonth.month;
                                              }).toList();
                                              spent = monthTransactions.fold(0.0, (sum, t) => sum + (t['amount'] as double));
                                            }
                                            
                                            final remaining = limit - spent;
                                            
                                            final isOverBudget = spent > limit;
                                            
                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              child: Column(
                                                children: [
                                                  ListTile(
                                                    leading: Stack(
                                                      children: [
                                                        CircleAvatar(
                                                          backgroundColor: const Color(0xFF2D2D3A),
                                                          child: Icon(categoryIcon, color: Colors.white),
                                                        ),
                                                        if (isOverBudget)
                                                          Positioned(
                                                            right: 0,
                                                            top: 0,
                                                            child: Container(
                                                              padding: const EdgeInsets.all(2),
                                                              decoration: const BoxDecoration(
                                                                color: Color(0xFFEF4444),
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: const Icon(
                                                                Icons.warning,
                                                                size: 12,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    title: Text(
                                                      categoryName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    trailing: PopupMenuButton(
                                                      icon: const Icon(Icons.more_vert),
                                                      itemBuilder: (context) => [
                                                        const PopupMenuItem(
                                                          value: 'change',
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.edit, size: 20),
                                                              SizedBox(width: 8),
                                                              Text('Change Limit'),
                                                            ],
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'remove',
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.delete, size: 20, color: Color(0xFFEF4444)),
                                                              SizedBox(width: 8),
                                                              Text('Remove Budget', style: TextStyle(color: Color(0xFFEF4444))),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                      onSelected: (value) {
                                                        if (value == 'change') {
                                                          _showSetBudgetDialog(
                                                            categoryName,
                                                            categoryIcon,
                                                            budgetId: budget['id'] as String,
                                                            currentLimit: limit,
                                                          );
                                                        } else if (value == 'remove') {
                                                          _showDeleteBudgetConfirmation(budget);
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              'Limit:',
                                                              style: TextStyle(
                                                                color: Colors.white70,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            Text(
                                                              '₹${limit.toStringAsFixed(2)}',
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              'Spent:',
                                                              style: TextStyle(
                                                                color: Colors.white70,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            Row(
                                                              children: [
                                                                if (isOverBudget)
                                                                  const Icon(
                                                                    Icons.warning,
                                                                    size: 16,
                                                                    color: Color(0xFFEF4444),
                                                                  ),
                                                                if (isOverBudget)
                                                                  const SizedBox(width: 4),
                                                                Text(
                                                                  '₹${spent.toStringAsFixed(2)}',
                                                                  style: TextStyle(
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: isOverBudget
                                                                        ? const Color(0xFFEF4444)
                                                                        : const Color(0xFF10B981),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Text(
                                                              'Remaining:',
                                                              style: TextStyle(
                                                                color: Colors.white70,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            Text(
                                                              '₹${remaining.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                                color: remaining >= 0 
                                                                    ? const Color(0xFF10B981)
                                                                    : const Color(0xFFEF4444),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }),
                                    const SizedBox(height: 24),
                                    // Not Budgeted Section
                                    const Text(
                                      'Not Budgeted this Month',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (notBudgetedCategories.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'All categories have budgets',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    else
                                      ...notBudgetedCategories.map((entry) {
                                        final categoryName = entry.key;
                                        final categoryIcon = entry.value;
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: const Color(0xFF2D2D3A),
                                              child: Icon(categoryIcon, color: Colors.white),
                                            ),
                                            title: Text(
                                              categoryName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            trailing: ElevatedButton(
                                              onPressed: () {
                                                _showSetBudgetDialog(categoryName, categoryIcon);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF6366F1),
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Set Budget'),
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
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
}

