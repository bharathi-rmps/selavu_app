import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/account.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../utils/account_dialog_helper.dart';

enum TransactionType { income, expense, transfer }

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? transactionToEdit;
  
  const AddExpenseScreen({super.key, this.transactionToEdit});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  TransactionType _selectedType = TransactionType.expense;
  String _amount = '0';
  String _notes = '';
  Account? _selectedAccount;
  Account? _fromAccount; // For transfer
  Account? _toAccount; // For transfer
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _editingTransactionId; // ID of transaction being edited
  StreamSubscription? _customCategoriesSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    if (widget.transactionToEdit != null) {
      _initializeFromTransaction(widget.transactionToEdit!);
    }
  }

  @override
  void dispose() {
    _customCategoriesSubscription?.cancel();
    super.dispose();
  }

  // Load custom categories from Firebase
  void _loadCustomCategories() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    _customCategoriesSubscription = _firebaseService
        .getCustomCategories(userId)
        .listen((customCategories) {
      if (mounted) {
        setState(() {
          // Store default categories to preserve them
          final defaultIncomeCategories = {
            'Salary': Icons.work,
            'Freelance': Icons.computer,
            'Investment': Icons.trending_up,
            'Gift': Icons.card_giftcard,
            'Bonus': Icons.stars,
            'Rental': Icons.home,
            'Business': Icons.business,
            'Other': Icons.category,
          };
          final defaultExpenseCategories = {
            'Bills': Icons.receipt_long,
            'Clothing': Icons.checkroom,
            'Food': Icons.restaurant,
            'Entertainment': Icons.movie,
            'Home': Icons.home,
            'Shopping': Icons.shopping_bag,
            'Withdrawal': Icons.account_balance_wallet,
          };

          // Rebuild income categories with defaults first
          _incomeCategoryIcons.clear();
          _incomeCategoryIcons.addAll(defaultIncomeCategories);
          
          // Rebuild expense categories with defaults first
          _expenseCategoryIcons.clear();
          _expenseCategoryIcons.addAll(defaultExpenseCategories);

          // Add custom categories from Firebase
          for (final category in customCategories) {
            final categoryName = category['categoryName'] as String;
            final categoryType = category['categoryType'] as String;
            final categoryIcon = category['categoryIcon'] as IconData;

            if (categoryType == 'income') {
              _incomeCategoryIcons[categoryName] = categoryIcon;
            } else if (categoryType == 'expense') {
              _expenseCategoryIcons[categoryName] = categoryIcon;
            }
          }
        });
      }
    });
  }
  
  Future<void> _initializeFromTransaction(Map<String, dynamic> transaction) async {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as double;
    final date = transaction['transactionDateTime'] as DateTime;
    final notes = transaction['notes'] as String? ?? '';
    _editingTransactionId = transaction['id'] as String?;
    
    // Set transaction type
    if (type == 'income') {
      _selectedType = TransactionType.income;
    } else if (type == 'expense') {
      _selectedType = TransactionType.expense;
    } else {
      _selectedType = TransactionType.transfer;
    }
    
    // Set amount
    _amount = amount.toStringAsFixed(2);
    
    // Set notes
    _notes = notes;
    
    // Set date and time
    _selectedDate = date;
    _selectedTime = TimeOfDay.fromDateTime(date);
    
    // Set category (for income/expense)
    if (type == 'income' || type == 'expense') {
      _selectedCategory = transaction['category'] as String?;
    }
    
    // Set accounts
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      final accounts = await _firebaseService.getAccounts(userId).first;
      
      if (type == 'transfer') {
        final fromAccountName = transaction['fromAccount'] as String?;
        final toAccountName = transaction['toAccount'] as String?;
        if (fromAccountName != null && fromAccountName.isNotEmpty) {
          try {
            _fromAccount = accounts.firstWhere((acc) => acc.name == fromAccountName);
          } catch (e) {
            // Try case-insensitive match
            try {
              _fromAccount = accounts.firstWhere(
                (acc) => acc.name.toLowerCase() == fromAccountName.toLowerCase(),
              );
            } catch (e2) {
              // Account not found, leave as null
            }
          }
        }
        if (toAccountName != null && toAccountName.isNotEmpty) {
          try {
            _toAccount = accounts.firstWhere((acc) => acc.name == toAccountName);
          } catch (e) {
            // Try case-insensitive match
            try {
              _toAccount = accounts.firstWhere(
                (acc) => acc.name.toLowerCase() == toAccountName.toLowerCase(),
              );
            } catch (e2) {
              // Account not found, leave as null
            }
          }
        }
      } else {
        // For income/expense, try both accountName and fromAccount
        final accountName = transaction['accountName'] as String? ?? transaction['fromAccount'] as String?;
        if (accountName != null && accountName.isNotEmpty) {
          // Try exact match first
          try {
            _selectedAccount = accounts.firstWhere((acc) => acc.name == accountName);
          } catch (e) {
            // Try case-insensitive match
            try {
              _selectedAccount = accounts.firstWhere(
                (acc) => acc.name.toLowerCase() == accountName.toLowerCase(),
              );
            } catch (e2) {
              // Account not found, leave as null
              // Print available accounts for debugging
              debugPrint('Account not found: $accountName');
              debugPrint('Available accounts: ${accounts.map((a) => a.name).toList()}');
            }
          }
        } else {
          debugPrint('Account name is null or empty in transaction: $transaction');
        }
      }
    }
    
    if (mounted) {
      setState(() {});
    }
  }
  
  // Calculator state
  double? _operand1;
  String? _operator;
  bool _shouldResetDisplay = false;

  // Available expense categories with icons - defaults
  Map<String, IconData> _expenseCategoryIcons = {
    'Bills': Icons.receipt_long,
    'Clothing': Icons.checkroom,
    'Food': Icons.restaurant,
    'Entertainment': Icons.movie,
    'Home': Icons.home,
    'Shopping': Icons.shopping_bag,
    'Withdrawal': Icons.account_balance_wallet,
  };

  // Available income categories with icons - defaults
  Map<String, IconData> _incomeCategoryIcons = {
    'Salary': Icons.work,
    'Freelance': Icons.computer,
    'Investment': Icons.trending_up,
    'Gift': Icons.card_giftcard,
    'Bonus': Icons.stars,
    'Rental': Icons.home,
    'Business': Icons.business,
    'Other': Icons.category,
  };

  // Available income category icons for selection
  final List<Map<String, dynamic>> _incomeCategoryIconOptions = [
    {'icon': Icons.work, 'label': 'Salary'},
    {'icon': Icons.computer, 'label': 'Freelance'},
    {'icon': Icons.trending_up, 'label': 'Investment'},
    {'icon': Icons.business, 'label': 'Business'},
    {'icon': Icons.home, 'label': 'Rental'},
    {'icon': Icons.card_giftcard, 'label': 'Gift'},
    {'icon': Icons.stars, 'label': 'Bonus'},
    {'icon': Icons.account_balance, 'label': 'Bank Interest'},
    {'icon': Icons.savings, 'label': 'Savings'},
    {'icon': Icons.payments, 'label': 'Payment'},
    {'icon': Icons.monetization_on, 'label': 'Money'},
    {'icon': Icons.account_balance_wallet, 'label': 'Wallet'},
    {'icon': Icons.attach_money, 'label': 'Cash'},
    {'icon': Icons.currency_rupee, 'label': 'Currency'},
    {'icon': Icons.credit_card, 'label': 'Credit'},
    {'icon': Icons.receipt, 'label': 'Refund'},
    {'icon': Icons.arrow_downward, 'label': 'Income'},
    {'icon': Icons.trending_flat, 'label': 'Dividend'},
    {'icon': Icons.local_atm, 'label': 'ATM'},
    {'icon': Icons.account_circle, 'label': 'Personal'},
    {'icon': Icons.handshake, 'label': 'Partnership'},
    {'icon': Icons.store, 'label': 'Sales'},
    {'icon': Icons.sell, 'label': 'Sell'},
    {'icon': Icons.currency_exchange, 'label': 'Exchange'},
    {'icon': Icons.request_quote, 'label': 'Invoice'},
    {'icon': Icons.description, 'label': 'Document'},
    {'icon': Icons.folder, 'label': 'Project'},
    {'icon': Icons.assignment, 'label': 'Contract'},
    {'icon': Icons.verified, 'label': 'Verified'},
    {'icon': Icons.check_circle, 'label': 'Completed'},
    {'icon': Icons.thumb_up, 'label': 'Approved'},
    {'icon': Icons.celebration, 'label': 'Reward'},
    {'icon': Icons.emoji_events, 'label': 'Prize'},
    {'icon': Icons.diamond, 'label': 'Premium'},
    {'icon': Icons.category, 'label': 'Other'},
  ];

  // Available expense category icons for selection
  final List<Map<String, dynamic>> _expenseCategoryIconOptions = [
    {'icon': Icons.receipt_long, 'label': 'Bills'},
    {'icon': Icons.checkroom, 'label': 'Clothing'},
    {'icon': Icons.restaurant, 'label': 'Food'},
    {'icon': Icons.movie, 'label': 'Entertainment'},
    {'icon': Icons.home, 'label': 'Home'},
    {'icon': Icons.shopping_bag, 'label': 'Shopping'},
    {'icon': Icons.account_balance_wallet, 'label': 'Wallet'},
    {'icon': Icons.local_gas_station, 'label': 'Gas'},
    {'icon': Icons.directions_car, 'label': 'Transport'},
    {'icon': Icons.medical_services, 'label': 'Health'},
    {'icon': Icons.school, 'label': 'Education'},
    {'icon': Icons.sports_esports, 'label': 'Gaming'},
    {'icon': Icons.fitness_center, 'label': 'Fitness'},
    {'icon': Icons.local_cafe, 'label': 'Coffee'},
    {'icon': Icons.flight, 'label': 'Travel'},
    {'icon': Icons.hotel, 'label': 'Hotel'},
    {'icon': Icons.phone, 'label': 'Phone'},
    {'icon': Icons.wifi, 'label': 'Internet'},
    {'icon': Icons.electric_bolt, 'label': 'Electricity'},
    {'icon': Icons.water_drop, 'label': 'Water'},
    {'icon': Icons.local_pharmacy, 'label': 'Pharmacy'},
    {'icon': Icons.pets, 'label': 'Pets'},
    {'icon': Icons.child_care, 'label': 'Childcare'},
    {'icon': Icons.cleaning_services, 'label': 'Cleaning'},
    {'icon': Icons.build, 'label': 'Repair'},
    {'icon': Icons.eco, 'label': 'Garden'},
    {'icon': Icons.book, 'label': 'Books'},
    {'icon': Icons.music_note, 'label': 'Music'},
    {'icon': Icons.sports_soccer, 'label': 'Sports'},
    {'icon': Icons.cake, 'label': 'Celebration'},
    {'icon': Icons.card_giftcard, 'label': 'Gift'},
    {'icon': Icons.local_dining, 'label': 'Dining'},
    {'icon': Icons.local_bar, 'label': 'Drinks'},
    {'icon': Icons.shopping_cart, 'label': 'Groceries'},
    {'icon': Icons.local_mall, 'label': 'Mall'},
    {'icon': Icons.restaurant_menu, 'label': 'Restaurant'},
    {'icon': Icons.fastfood, 'label': 'Fast Food'},
    {'icon': Icons.lunch_dining, 'label': 'Lunch'},
    {'icon': Icons.dinner_dining, 'label': 'Dinner'},
    {'icon': Icons.breakfast_dining, 'label': 'Breakfast'},
    {'icon': Icons.local_pizza, 'label': 'Pizza'},
    {'icon': Icons.icecream, 'label': 'Ice Cream'},
    {'icon': Icons.local_drink, 'label': 'Beverages'},
    {'icon': Icons.shopping_cart_checkout, 'label': 'Checkout'},
    {'icon': Icons.storefront, 'label': 'Store'},
    {'icon': Icons.store_mall_directory, 'label': 'Mall Store'},
    {'icon': Icons.directions_bus, 'label': 'Bus'},
    {'icon': Icons.train, 'label': 'Train'},
    {'icon': Icons.flight_takeoff, 'label': 'Flight'},
    {'icon': Icons.directions_car_filled, 'label': 'Car'},
    {'icon': Icons.two_wheeler, 'label': 'Bike'},
    {'icon': Icons.electric_car, 'label': 'Electric Car'},
    {'icon': Icons.local_taxi, 'label': 'Taxi'},
    {'icon': Icons.subway, 'label': 'Subway'},
    {'icon': Icons.directions_boat, 'label': 'Boat'},
    {'icon': Icons.healing, 'label': 'Medicine'},
    {'icon': Icons.local_hospital, 'label': 'Hospital'},
    {'icon': Icons.medical_information, 'label': 'Medical Info'},
    {'icon': Icons.vaccines, 'label': 'Vaccine'},
    {'icon': Icons.face, 'label': 'Beauty'},
    {'icon': Icons.content_cut, 'label': 'Haircut'},
    {'icon': Icons.spa, 'label': 'Spa'},
    {'icon': Icons.pool, 'label': 'Swimming'},
    {'icon': Icons.sports_basketball, 'label': 'Basketball'},
    {'icon': Icons.sports_tennis, 'label': 'Tennis'},
    {'icon': Icons.sports_baseball, 'label': 'Baseball'},
    {'icon': Icons.sports_football, 'label': 'Football'},
    {'icon': Icons.sports_volleyball, 'label': 'Volleyball'},
    {'icon': Icons.sports_golf, 'label': 'Golf'},
    {'icon': Icons.sports_motorsports, 'label': 'Motorsports'},
    {'icon': Icons.sports_handball, 'label': 'Handball'},
    {'icon': Icons.sports_kabaddi, 'label': 'Kabaddi'},
    {'icon': Icons.sports_mma, 'label': 'MMA'},
    {'icon': Icons.sports_cricket, 'label': 'Cricket'},
    {'icon': Icons.sports_hockey, 'label': 'Hockey'},
    {'icon': Icons.movie_creation, 'label': 'Movies'},
    {'icon': Icons.theater_comedy, 'label': 'Theater'},
    {'icon': Icons.music_video, 'label': 'Music Video'},
    {'icon': Icons.library_music, 'label': 'Library Music'},
    {'icon': Icons.headphones, 'label': 'Headphones'},
    {'icon': Icons.radio, 'label': 'Radio'},
    {'icon': Icons.tv, 'label': 'TV'},
    {'icon': Icons.videogame_asset, 'label': 'Video Game'},
    {'icon': Icons.casino, 'label': 'Casino'},
    {'icon': Icons.school, 'label': 'School'},
    {'icon': Icons.menu_book, 'label': 'Textbook'},
    {'icon': Icons.library_books, 'label': 'Library'},
    {'icon': Icons.calculate, 'label': 'Calculator'},
    {'icon': Icons.computer, 'label': 'Computer'},
    {'icon': Icons.laptop, 'label': 'Laptop'},
    {'icon': Icons.tablet, 'label': 'Tablet'},
    {'icon': Icons.phone_android, 'label': 'Mobile'},
    {'icon': Icons.watch, 'label': 'Watch'},
    {'icon': Icons.camera_alt, 'label': 'Camera'},
    {'icon': Icons.headset, 'label': 'Headset'},
    {'icon': Icons.keyboard, 'label': 'Keyboard'},
    {'icon': Icons.mouse, 'label': 'Mouse'},
    {'icon': Icons.print, 'label': 'Print'},
    {'icon': Icons.scanner, 'label': 'Scanner'},
    {'icon': Icons.home_repair_service, 'label': 'Home Repair'},
    {'icon': Icons.construction, 'label': 'Construction'},
    {'icon': Icons.plumbing, 'label': 'Plumbing'},
    {'icon': Icons.electrical_services, 'label': 'Electrical'},
    {'icon': Icons.hvac, 'label': 'HVAC'},
    {'icon': Icons.pest_control, 'label': 'Pest Control'},
    {'icon': Icons.cleaning_services, 'label': 'Cleaning'},
    {'icon': Icons.local_laundry_service, 'label': 'Laundry'},
    {'icon': Icons.dry_cleaning, 'label': 'Dry Cleaning'},
    {'icon': Icons.cut, 'label': 'Cutting'},
    {'icon': Icons.park, 'label': 'Park'},
    {'icon': Icons.forest, 'label': 'Forest'},
    {'icon': Icons.agriculture, 'label': 'Agriculture'},
    {'icon': Icons.grass, 'label': 'Grass'},
    {'icon': Icons.air, 'label': 'Air'},
    {'icon': Icons.water, 'label': 'Water'},
    {'icon': Icons.fire_extinguisher, 'label': 'Fire Safety'},
    {'icon': Icons.security, 'label': 'Security'},
    {'icon': Icons.lock, 'label': 'Lock'},
    {'icon': Icons.vpn_key, 'label': 'Key'},
    {'icon': Icons.credit_card_off, 'label': 'Card Off'},
    {'icon': Icons.payment, 'label': 'Payment'},
    {'icon': Icons.receipt, 'label': 'Receipt'},
    {'icon': Icons.description, 'label': 'Document'},
    {'icon': Icons.folder, 'label': 'Folder'},
    {'icon': Icons.attach_file, 'label': 'Attachment'},
    {'icon': Icons.arrow_upward, 'label': 'Expense'},
    {'icon': Icons.remove_circle, 'label': 'Deduction'},
    {'icon': Icons.category, 'label': 'Other'},
  ];

  // Category icons mapping
  IconData _getCategoryIcon(String category) {
    // Check both income and expense categories
    if (_incomeCategoryIcons.containsKey(category)) {
      return _incomeCategoryIcons[category]!;
    }
    if (_expenseCategoryIcons.containsKey(category)) {
      return _expenseCategoryIcons[category]!;
    }
    return Icons.category;
  }

  // Get sorted categories based on transaction type
  List<String> get _sortedCategories {
    Map<String, IconData> categoryMap;
    if (_selectedType == TransactionType.income) {
      categoryMap = _incomeCategoryIcons;
    } else {
      categoryMap = _expenseCategoryIcons;
    }
    final sorted = List<String>.from(categoryMap.keys);
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_shouldResetDisplay) {
        _amount = number;
        _shouldResetDisplay = false;
      } else if (_amount == '0') {
        _amount = number;
      } else {
        _amount += number;
      }
    });
  }

  void _onDecimalPressed() {
    setState(() {
      if (_shouldResetDisplay) {
        _amount = '0.';
        _shouldResetDisplay = false;
      } else if (!_amount.contains('.')) {
        _amount += '.';
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_shouldResetDisplay) {
        _amount = '0';
        _shouldResetDisplay = false;
      } else if (_amount.length > 1) {
        _amount = _amount.substring(0, _amount.length - 1);
      } else {
        _amount = '0';
      }
    });
  }

  void _onOperatorPressed(String operator) {
    setState(() {
      final currentValue = double.tryParse(_amount) ?? 0.0;
      
      if (_operand1 == null) {
        // First operand
        _operand1 = currentValue;
        _operator = operator;
        _shouldResetDisplay = true;
      } else if (_operator != null) {
        // Calculate previous operation if exists
        final result = _calculate(_operand1!, currentValue, _operator!);
        _amount = _formatNumber(result);
        _operand1 = result;
        _operator = operator;
        _shouldResetDisplay = true;
      }
    });
  }

  void _onEqualsPressed() {
    setState(() {
      if (_operand1 != null && _operator != null) {
        final currentValue = double.tryParse(_amount) ?? 0.0;
        final result = _calculate(_operand1!, currentValue, _operator!);
        _amount = _formatNumber(result);
        _operand1 = null;
        _operator = null;
        _shouldResetDisplay = true;
      }
    });
  }

  double _calculate(double a, double b, String operator) {
    switch (operator) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b != 0 ? a / b : 0;
      default:
        return b;
    }
  }

  String _formatNumber(double number) {
    // Remove trailing zeros and decimal point if not needed
    if (number % 1 == 0) {
      return number.toInt().toString();
    } else {
      return number.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
  }

  Future<void> _selectAccount() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    final accounts = await _firebaseService.getAccounts(userId).first;
    final sortedAccounts = List<Account>.from(accounts)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    final selected = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _AccountSelectionModal(
        accounts: sortedAccounts,
        onAccountSelected: (account) => Navigator.of(context).pop(account),
        onAddNew: () async {
          Navigator.of(context).pop(); // Close selection modal
          await _showAddAccountDialog();
          // Reopen selection modal after adding
          if (mounted) {
            _selectAccount();
          }
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedAccount = selected;
      });
    }
  }

  Future<void> _showAddAccountDialog() async {
    await AccountDialogHelper.showAddAccountDialog(
      context,
      onAccountAdded: () {
        // Account was added, refresh the account list if needed
      },
    );
  }

  Future<void> _selectFromAccount() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    final accounts = await _firebaseService.getAccounts(userId).first;
    final filteredAccounts = accounts.where((account) => account.id != _toAccount?.id).toList();
    final sortedAccounts = List<Account>.from(filteredAccounts)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selected = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _AccountSelectionModal(
        accounts: sortedAccounts,
        title: 'Select From Account',
        onAccountSelected: (account) => Navigator.of(context).pop(account),
        onAddNew: () async {
          Navigator.of(context).pop();
          await _showAddAccountDialog();
          if (mounted) {
            _selectFromAccount();
          }
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _fromAccount = selected;
      });
    }
  }

  Future<void> _selectToAccount() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return;
    final accounts = await _firebaseService.getAccounts(userId).first;
    final filteredAccounts = accounts.where((account) => account.id != _fromAccount?.id).toList();
    final sortedAccounts = List<Account>.from(filteredAccounts)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selected = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _AccountSelectionModal(
        accounts: sortedAccounts,
        title: 'Select To Account',
        onAccountSelected: (account) => Navigator.of(context).pop(account),
        onAddNew: () async {
          Navigator.of(context).pop();
          await _showAddAccountDialog();
          if (mounted) {
            _selectToAccount();
          }
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _toAccount = selected;
      });
    }
  }

  Future<void> _selectCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _CategorySelectionModal(
        categories: _sortedCategories,
        selectedCategory: _selectedCategory,
        onCategorySelected: (category) => Navigator.of(context).pop(category),
        getCategoryIcon: _getCategoryIcon,
        onAddNew: () async {
          Navigator.of(context).pop();
          await _showAddCategoryDialog();
          if (mounted) {
            _selectCategory();
          }
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedCategory = selected;
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final categoryController = TextEditingController();
    IconData selectedIcon = Icons.category;
    String selectedType = _selectedType == TransactionType.income ? 'income' : 'expense';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) => AlertDialog(
            title: const Text('Add Category'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                        hintText: 'Enter category name',
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Category Type',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedType = 'income';
                                selectedIcon = Icons.category; // Reset icon when switching type
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedType == 'income'
                                    ? const Color(0xFF6366F1).withOpacity(0.2)
                                    : const Color(0xFF2D2D3A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedType == 'income'
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF2D2D3A),
                                  width: 1.5,
                                ),
                              ),
                              child: const Text(
                                'Income',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedType = 'expense';
                                selectedIcon = Icons.category; // Reset icon when switching type
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedType == 'expense'
                                    ? const Color(0xFF6366F1).withOpacity(0.2)
                                    : const Color(0xFF2D2D3A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedType == 'expense'
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF2D2D3A),
                                  width: 1.5,
                                ),
                              ),
                              child: const Text(
                                'Expense',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Select Category Icon',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: (selectedType == 'income' 
                              ? _incomeCategoryIconOptions 
                              : _expenseCategoryIconOptions).map((iconData) {
                            final icon = iconData['icon'] as IconData;
                            final isSelected = selectedIcon == icon;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedIcon = icon;
                                });
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF2D2D3A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF2D2D3A),
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final categoryName = categoryController.text.trim();
                  if (categoryName.isNotEmpty) {
                    final userId = _authService.currentUser?.uid;
                    if (userId != null) {
                      try {
                        // Save to Firebase - the stream will automatically update the UI
                        await _firebaseService.addCustomCategory(
                          userId: userId,
                          categoryName: categoryName,
                          categoryIcon: selectedIcon,
                          categoryType: selectedType,
                        );
                        
                        // Don't update local state here - let Firebase stream handle it
                        // This ensures categories only appear if they're actually in Firebase
                        
                        if (mounted) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Category added successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding category: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User not logged in'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amount);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Validation based on transaction type
    if (_selectedType == TransactionType.transfer) {
      final missingFields = <String>[];
      if (_fromAccount == null) {
        missingFields.add('From Account');
      }
      if (_toAccount == null) {
        missingFields.add('To Account');
      }
      
      if (missingFields.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              missingFields.length == 1
                  ? 'Please select ${missingFields.first}'
                  : 'Please select: ${missingFields.join(' and ')}',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      
      if (_fromAccount!.id == _toAccount!.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('From and To accounts must be different'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    } else {
      final missingFields = <String>[];
      if (_selectedAccount == null) {
        missingFields.add('Account');
      }
      if (_selectedCategory == null) {
        missingFields.add('Category');
      }
      
      if (missingFields.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              missingFields.length == 1
                  ? 'Please select ${missingFields.first}'
                  : 'Please select: ${missingFields.join(' and ')}',
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Combine date and time
    final transactionDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Get current user info
    final authService = AuthService();
    final currentUser = authService.currentUser;
    final userId = currentUser?.uid;
    final userEmail = currentUser?.email;

    if (userId == null || userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save transactions'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      if (_editingTransactionId != null && widget.transactionToEdit != null) {
        // Update existing transaction
        final oldTransaction = widget.transactionToEdit!;
        final oldAmount = oldTransaction['amount'] as double;
        
        if (_selectedType == TransactionType.income) {
          final oldAccountName = oldTransaction['accountName'] as String? ?? '';
          await _firebaseService.updateIncome(
            transactionId: _editingTransactionId!,
            userId: userId,
            oldAmount: oldAmount,
            oldAccountName: oldAccountName,
            amount: amount,
            category: _selectedCategory!,
            notes: _notes,
            transactionDateTime: transactionDateTime,
            accountName: _selectedAccount!.name,
          );
        } else if (_selectedType == TransactionType.expense) {
          final oldAccountName = oldTransaction['accountName'] as String? ?? '';
          await _firebaseService.updateExpense(
            transactionId: _editingTransactionId!,
            userId: userId,
            oldAmount: oldAmount,
            oldAccountName: oldAccountName,
            amount: amount,
            category: _selectedCategory!,
            notes: _notes,
            transactionDateTime: transactionDateTime,
            accountName: _selectedAccount!.name,
          );
        } else if (_selectedType == TransactionType.transfer) {
          final oldFromAccount = oldTransaction['fromAccount'] as String? ?? '';
          final oldToAccount = oldTransaction['toAccount'] as String? ?? '';
          await _firebaseService.updateTransfer(
            transactionId: _editingTransactionId!,
            userId: userId,
            oldAmount: oldAmount,
            oldFromAccount: oldFromAccount,
            oldToAccount: oldToAccount,
            fromAccount: _fromAccount!.name,
            toAccount: _toAccount!.name,
            amount: amount,
            notes: _notes,
            transactionDateTime: transactionDateTime,
          );
        }
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Add new transaction
        if (_selectedType == TransactionType.income) {
          await _firebaseService.addIncome(
            userId: userId,
            userEmail: userEmail,
            amount: amount,
            category: _selectedCategory!,
            notes: _notes,
            transactionDateTime: transactionDateTime,
            accountName: _selectedAccount!.name,
          );
        } else if (_selectedType == TransactionType.expense) {
          await _firebaseService.addExpenseRecord(
            userId: userId,
            userEmail: userEmail,
            amount: amount,
            category: _selectedCategory!,
            notes: _notes,
            transactionDateTime: transactionDateTime,
            accountName: _selectedAccount!.name,
          );
        } else if (_selectedType == TransactionType.transfer) {
          await _firebaseService.addTransfer(
            userId: userId,
            userEmail: userEmail,
            fromAccount: _fromAccount!.name,
            toAccount: _toAccount!.name,
            amount: amount,
            notes: _notes,
            transactionDateTime: transactionDateTime,
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${_editingTransactionId != null ? 'updating' : 'adding'} transaction: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close,
            color: Color(0xFF6366F1),
            size: 20,
          ),
          label: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _saveExpense,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.check, color: Color(0xFF6366F1), size: 20),
              label: const Text(
                'SAVE',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Transaction Type Selector
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D2D3A), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      'INCOME',
                      TransactionType.income,
                      Icons.trending_up,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFF2D2D3A),
                  ),
                  Expanded(
                    child: _buildTypeButton(
                      'EXPENSE',
                      TransactionType.expense,
                      Icons.trending_down,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFF2D2D3A),
                  ),
                  Expanded(
                    child: _buildTypeButton(
                      'TRANSFER',
                      TransactionType.transfer,
                      Icons.swap_horiz,
                    ),
                  ),
                ],
              ),
            ),

            // Input Fields Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Show different fields based on transaction type
                  if (_selectedType == TransactionType.transfer) ...[
                    // Transfer: Two account selectors
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectionButton(
                            label: 'Account',
                            icon: Icons.account_balance_wallet,
                            value: _fromAccount?.name,
                            onTap: _selectFromAccount,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSelectionButton(
                            label: 'Account',
                            icon: Icons.account_balance,
                            value: _toAccount?.name,
                            onTap: _selectToAccount,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Income/Expense: Account and Category
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectionButton(
                            label: 'Account',
                            icon: Icons.account_balance_wallet,
                            value: _selectedAccount?.name,
                            onTap: _selectAccount,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSelectionButton(
                            label: 'Category',
                            icon: Icons.category,
                            value: _selectedCategory,
                            onTap: _selectCategory,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Notes Field
                  _buildNotesField(),
                  const SizedBox(height: 18),
                  // Amount Display
                  _buildAmountDisplay(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Calculator Keypad
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildCalculatorKeypad(),
              ),
            ),

            // Date and Time Pickers
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                border: Border(
                  top: BorderSide(color: const Color(0xFF2D2D3A), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDateTimeButton(
                      label: formattedDate,
                      onTap: _selectDate,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFF2D2D3A),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _buildDateTimeButton(
                      label: formattedTime,
                      onTap: _selectTime,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, TransactionType type, IconData icon) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
          // Clear fields when switching types
          if (type == TransactionType.transfer) {
            _selectedAccount = null;
            _selectedCategory = null;
          } else {
            _fromAccount = null;
            _toAccount = null;
            // Clear category if it doesn't belong to the new type
            if (_selectedCategory != null) {
              if (type == TransactionType.income && !_incomeCategoryIcons.containsKey(_selectedCategory)) {
                _selectedCategory = null;
              } else if (type == TransactionType.expense && !_expenseCategoryIcons.containsKey(_selectedCategory)) {
                _selectedCategory = null;
              }
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF6366F1) : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6366F1) : Colors.white54,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionButton({
    required String label,
    required IconData icon,
    required String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (value != null && value.isNotEmpty) 
                ? const Color(0xFF6366F1).withOpacity(0.3)
                : const Color(0xFF2D2D3A),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: (value != null && value.isNotEmpty)
                  ? const Color(0xFF6366F1)
                  : Colors.white54,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value?.isNotEmpty == true ? value! : label,
                style: TextStyle(
                  color: (value != null && value.isNotEmpty) ? Colors.white : Colors.white38,
                  fontSize: 15,
                  fontWeight: (value != null && value.isNotEmpty) ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 14),
            Icon(
              Icons.arrow_drop_down,
              color: (value != null && value.isNotEmpty) ? const Color(0xFF6366F1) : Colors.white54,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _notes.isNotEmpty
              ? const Color(0xFF6366F1).withOpacity(0.3)
              : const Color(0xFF2D2D3A),
          width: 1.5,
        ),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _notes = value),
        decoration: const InputDecoration(
          hintText: 'Add notes (optional)',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        maxLines: 2,
        minLines: 1,
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '₹ $_amount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _onBackspace,
              icon: const Icon(Icons.backspace_outlined, color: Color(0xFF6366F1)),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorKeypad() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Operators Column
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Expanded(
                child: _buildKeypadButton(
                  '+',
                  isOperator: true,
                  onTap: () => _onOperatorPressed('+'),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildKeypadButton(
                  '-',
                  isOperator: true,
                  onTap: () => _onOperatorPressed('-'),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildKeypadButton(
                  '×',
                  isOperator: true,
                  onTap: () => _onOperatorPressed('×'),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildKeypadButton(
                  '÷',
                  isOperator: true,
                  onTap: () => _onOperatorPressed('÷'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Numbers Column
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildKeypadButton('7', onTap: () => _onNumberPressed('7')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('8', onTap: () => _onNumberPressed('8')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('9', onTap: () => _onNumberPressed('9')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildKeypadButton('4', onTap: () => _onNumberPressed('4')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('5', onTap: () => _onNumberPressed('5')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('6', onTap: () => _onNumberPressed('6')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildKeypadButton('1', onTap: () => _onNumberPressed('1')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('2', onTap: () => _onNumberPressed('2')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('3', onTap: () => _onNumberPressed('3')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildKeypadButton('0', onTap: () => _onNumberPressed('0')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('.', onTap: _onDecimalPressed),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKeypadButton('=', isOperator: true, onTap: _onEqualsPressed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadButton(
    String label, {
    required VoidCallback onTap,
    bool isOperator = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isOperator
              ? const Color(0xFF6366F1)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
          border: isOperator
              ? null
              : Border.all(
                  color: const Color(0xFF2D2D3A),
                  width: 1.5,
                ),
          boxShadow: isOperator
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: isOperator ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Account Selection Modal Widget
class _AccountSelectionModal extends StatelessWidget {
  final List<Account> accounts;
  final String title;
  final Function(Account) onAccountSelected;
  final VoidCallback onAddNew;

  const _AccountSelectionModal({
    required this.accounts,
    this.title = 'Select Account',
    required this.onAccountSelected,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No accounts available',
                style: TextStyle(color: Colors.white60),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return ListTile(
                    leading: Icon(account.icon, color: const Color(0xFF6366F1), size: 28),
                    title: Text(
                      account.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Text(
                      '₹ ${account.balance.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    onTap: () => onAccountSelected(account),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add),
                label: const Text('Add New Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Category Selection Modal Widget
class _CategorySelectionModal extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final Function(String) onCategorySelected;
  final VoidCallback onAddNew;
  final IconData Function(String) getCategoryIcon;

  const _CategorySelectionModal({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onAddNew,
    required this.getCategoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Select Category',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category;
              final categoryIcon = getCategoryIcon(category);
              return InkWell(
                onTap: () => onCategorySelected(category),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF2D2D3A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF2D2D3A),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        categoryIcon,
                        color: isSelected ? Colors.white : const Color(0xFF6366F1),
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddNew,
              icon: const Icon(Icons.add),
              label: const Text('Add New Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}


