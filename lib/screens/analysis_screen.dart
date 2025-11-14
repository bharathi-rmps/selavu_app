import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';
import 'category_expenses_screen.dart';

enum ViewMode { daily, weekly, monthly, threeMonths, sixMonths, yearly }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

enum ChartType { expenses, income }

class _AnalysisScreenState extends State<AnalysisScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  DateTime _selectedMonth = DateTime.now();
  ViewMode _viewMode = ViewMode.monthly;
  bool _showTotal = true;
  bool _carryOver = false;
  int? _touchedIndex;
  OverlayEntry? _tooltipOverlay;
  ChartType _selectedChartType = ChartType.expenses;

  double _getTotalExpenses(List<Map<String, dynamic>> transactions) {
    return transactions.where((t) => t['type'] == 'expense').fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  double _getTotalIncome(List<Map<String, dynamic>> transactions) {
    return transactions.where((t) => t['type'] == 'income').fold(0.0, (sum, t) => sum + (t['amount'] as double));
  }

  // Group expenses by category
  Map<String, double> _groupExpensesByCategory(List<Map<String, dynamic>> transactions) {
    final categoryMap = <String, double>{};
    
    for (final transaction in transactions) {
      if (transaction['type'] == 'expense') {
        final category = transaction['category'] as String? ?? 'Other';
        final amount = transaction['amount'] as double;
        categoryMap[category] = (categoryMap[category] ?? 0.0) + amount;
      }
    }
    
    return categoryMap;
  }

  // Group income by category
  Map<String, double> _groupIncomeByCategory(List<Map<String, dynamic>> transactions) {
    final categoryMap = <String, double>{};
    
    for (final transaction in transactions) {
      if (transaction['type'] == 'income') {
        final category = transaction['category'] as String? ?? 'Other';
        final amount = transaction['amount'] as double;
        categoryMap[category] = (categoryMap[category] ?? 0.0) + amount;
      }
    }
    
    return categoryMap;
  }

  // Get color for category (based on index) - Dark theme friendly colors
  Color _getCategoryColor(int index) {
    final colors = [
      const Color(0xFFEF4444), // Red (expense theme)
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Green
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF97316), // Orange
      const Color(0xFF84CC16), // Lime
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFA855F7), // Violet
      const Color(0xFF06B6D4), // Sky
      const Color(0xFF22C55E), // Emerald
      const Color(0xFFEAB308), // Yellow
    ];
    return colors[index % colors.length];
  }

  // Show tooltip for pie chart
  void _showPieChartTooltip(BuildContext context, String category, double percentage, FlTouchEvent event, GlobalKey pieChartKey) {
    // Remove existing tooltip if any
    _removeTooltip();
    
    final overlay = Overlay.of(context);
    
    // Get touch position from event
    final localPosition = event.localPosition;
    if (localPosition == null) return;
    
    // Get the pie chart widget's position
    final RenderBox? renderBox = pieChartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final pieChartPosition = renderBox.localToGlobal(Offset.zero);
    final pieChartSize = renderBox.size;
    
    // Calculate position relative to pie chart center
    final pieChartCenterX = pieChartPosition.dx + (pieChartSize.width / 2);
    final pieChartCenterY = pieChartPosition.dy + (pieChartSize.height / 2);
    
    // Calculate angle from center to touch point
    final dx = localPosition.dx - (pieChartSize.width / 2);
    final dy = localPosition.dy - (pieChartSize.height / 2);
    final angle = (math.atan2(dy, dx) * 180 / math.pi) + 90; // Convert to degrees, adjust for top origin
    
    // Calculate tooltip position above the touch point
    const tooltipWidth = 160.0;
    const tooltipHeight = 70.0;
    const offsetDistance = 120.0; // Distance from pie chart center
    
    // Calculate position based on angle
    final radians = (angle - 90) * math.pi / 180;
    final tooltipX = pieChartCenterX + (offsetDistance * math.cos(radians)) - (tooltipWidth / 2);
    final tooltipY = pieChartCenterY + (offsetDistance * math.sin(radians)) - tooltipHeight - 20;
    
    final screenSize = MediaQuery.of(context).size;
    
    // Ensure tooltip stays within screen bounds horizontally
    double left = tooltipX;
    if (left < 10) left = 10;
    if (left > screenSize.width - tooltipWidth - 10) {
      left = screenSize.width - tooltipWidth - 10;
    }
    
    // Ensure tooltip stays within screen bounds vertically
    double top = tooltipY;
    if (top < 10) {
      // If not enough space above, show below instead
      top = pieChartCenterY + (offsetDistance * math.sin(radians)) + 20;
    }
    if (top > screenSize.height - tooltipHeight - 10) {
      top = screenSize.height - tooltipHeight - 10;
    }

    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2D2D3A),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_tooltipOverlay!);

    // Remove tooltip after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _removeTooltip();
    });
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
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
    
    final previousMonth = DateTime(currentPeriodStart.year, currentPeriodStart.month - 1);
    final previousMonthTransactions = allTransactions.where((transaction) {
      final date = transaction['transactionDateTime'] as DateTime;
      return transaction['type'] == 'expense' &&
          date.year == previousMonth.year &&
          date.month == previousMonth.month;
    }).toList();
    
    return _getTotalExpenses(previousMonthTransactions);
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
        title: const Text('Analysis'),
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
                      ],
                    ),
                  );
                }

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

                    final carryOverExpenses = _calculateCarryOverExpenses(allTransactions, periodStart);
                    final totalExpensesWithCarryOver = periodExpenseTotal + carryOverExpenses;
                    final periodBalance = totalAccountBalance - totalExpensesWithCarryOver;

                    // Group transactions by category based on selected chart type
                    final categoryData = _selectedChartType == ChartType.expenses
                        ? _groupExpensesByCategory(filteredTransactions.where((t) => t['type'] == 'expense').toList())
                        : _groupIncomeByCategory(filteredTransactions.where((t) => t['type'] == 'income').toList());
                    final sortedCategories = categoryData.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final totalAmount = _selectedChartType == ChartType.expenses
                        ? periodExpenseTotal
                        : periodIncomeTotal;

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
                        const SizedBox(height: 16),
                        // Pie Chart Section
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Pie Chart Title with Dropdown
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _selectedChartType == ChartType.expenses
                                            ? 'Expenses by Category'
                                            : 'Income by Category',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2D2D3A),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF3D3D4A),
                                            width: 1,
                                          ),
                                        ),
                                        child: DropdownButton<ChartType>(
                                          value: _selectedChartType,
                                          underline: const SizedBox(),
                                          dropdownColor: const Color(0xFF1E1E2E),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: ChartType.expenses,
                                              child: Text('Expenses Overview'),
                                            ),
                                            DropdownMenuItem(
                                              value: ChartType.income,
                                              child: Text('Income Overview'),
                                            ),
                                          ],
                                          onChanged: (ChartType? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                _selectedChartType = newValue;
                                                _touchedIndex = null;
                                                _removeTooltip();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Pie Chart
                                categoryData.isEmpty
                                    ? Container(
                                        height: 250,
                                        margin: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E2E),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFF2D2D3A),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.pie_chart_outline,
                                                size: 64,
                                                color: Colors.white30,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No chart to display',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Builder(
                                        builder: (context) {
                                          final pieChartKey = GlobalKey();
                                          
                                          return SizedBox(
                                            key: pieChartKey,
                                            height: 250,
                                            child: PieChart(
                                              PieChartData(
                                                sectionsSpace: 2,
                                                centerSpaceRadius: 40,
                                                pieTouchData: PieTouchData(
                                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                                    if (!event.isInterestedForInteractions ||
                                                        pieTouchResponse == null ||
                                                        pieTouchResponse.touchedSection == null) {
                                                      setState(() {
                                                        _touchedIndex = null;
                                                      });
                                                      _removeTooltip();
                                                      return;
                                                    }
                                                    
                                                    final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                                    setState(() {
                                                      _touchedIndex = touchedIndex;
                                                    });
                                                    
                                                    // Show tooltip
                                                    final categoryEntry = sortedCategories[touchedIndex];
                                                    final category = categoryEntry.key;
                                                    final amount = categoryEntry.value;
                                                    final percentage = totalAmount > 0
                                                        ? (amount / totalAmount * 100)
                                                        : 0.0;
                                                    
                                                    _showPieChartTooltip(context, category, percentage, event, pieChartKey);
                                                  },
                                                ),
                                                sections: sortedCategories.asMap().entries.map((entry) {
                                                  final index = entry.key;
                                                  final categoryEntry = entry.value;
                                                  final category = categoryEntry.key;
                                                  final amount = categoryEntry.value;
                                                  final percentage = totalAmount > 0
                                                      ? (amount / totalAmount * 100)
                                                      : 0.0;
                                                  
                                                  final isTouched = index == _touchedIndex;
                                                  final radius = isTouched ? 90.0 : 80.0;
                                                  
                                                  return PieChartSectionData(
                                                    value: amount,
                                                    title: '',
                                                    color: _getCategoryColor(index),
                                                    radius: radius,
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                const SizedBox(height: 16),
                                // Category Breakdown Section
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Category Breakdown',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      categoryData.isEmpty
                                          ? Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E1E2E),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: const Color(0xFF2D2D3A),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Center(
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      Icons.receipt_long,
                                                      size: 48,
                                                      color: Colors.white30,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      _selectedChartType == ChartType.expenses
                                                          ? 'No expenses to analyze'
                                                          : 'No income to analyze',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white60,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Column(
                                              children: sortedCategories.asMap().entries.map((entry) {
                                              final index = entry.key;
                                              final categoryEntry = entry.value;
                                              final category = categoryEntry.key;
                                              final amount = categoryEntry.value;
                                              final percentage = totalAmount > 0
                                                  ? (amount / totalAmount * 100)
                                                  : 0.0;
                                              final color = _getCategoryColor(index);
                                              
                                              return InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          CategoryExpensesScreen(
                                                        categoryName: category,
                                                        categoryTotal: amount,
                                                        overallTotal: totalAmount,
                                                        transactionType: _selectedChartType == ChartType.expenses
                                                            ? 'expense'
                                                            : 'income',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 12),
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF1E1E2E),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                      color: const Color(
                                                          0xFF2D2D3A),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      // Color indicator
                                                      Container(
                                                        width: 16,
                                                        height: 16,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: color,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          width: 12),
                                                      // Category name
                                                      Expanded(
                                                        child: Text(
                                                          category,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      // Percentage
                                                      Text(
                                                        '${percentage.toStringAsFixed(1)}%',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Amount
                                                      Text(
                                                        '₹${amount.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors.white70,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(
                                                        Icons.chevron_right,
                                                        color: Colors.white54,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
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

