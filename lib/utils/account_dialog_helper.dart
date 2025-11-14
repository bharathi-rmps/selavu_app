import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';

class AccountDialogHelper {
  // Shared account icons list
  static final List<Map<String, dynamic>> accountIcons = [
    {'icon': Icons.money, 'label': 'Cash', 'type': 'cash'},
    {'icon': Icons.credit_card, 'label': 'Card', 'type': 'card'},
    {'icon': Icons.account_balance, 'label': 'Bank', 'type': 'bank'},
    {'icon': Icons.savings, 'label': 'Savings', 'type': 'savings'},
    {'icon': Icons.wallet, 'label': 'Wallet', 'type': 'wallet'},
    {'icon': Icons.payment, 'label': 'Payment', 'type': 'payment'},
  ];

  // Decimal input formatter for balance
  static final TextInputFormatter decimalFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'));

  // Show add account dialog - convenience method
  static Future<void> showAddAccountDialog(
    BuildContext context, {
    VoidCallback? onAccountAdded,
  }) {
    return showAddEditAccountDialog(context, account: null, onAccountAdded: onAccountAdded);
  }

  // Show add/edit account dialog - reusable function
  static Future<void> showAddEditAccountDialog(
    BuildContext context, {
    Account? account,
    VoidCallback? onAccountAdded,
  }) async {
    final firebaseService = FirebaseService();
    final authService = AuthService();
    
    final userId = authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in')),
      );
      return;
    }

    final nameController = TextEditingController(text: account?.name ?? '');
    final balanceController = TextEditingController(
      text: account?.balance.toString() ?? '0.0',
    );
    IconData selectedIcon = account?.icon ?? Icons.money;
    String selectedType = account?.type ?? 'cash';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) => AlertDialog(
            title: Text(account == null ? 'Add Account' : 'Edit Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Account Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: balanceController,
                    decoration: InputDecoration(
                      labelText: account == null ? 'Initial Balance' : 'Adjust Balance',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [decimalFormatter],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Account Icon',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: accountIcons.map((iconData) {
                          final icon = iconData['icon'] as IconData;
                          final isSelected = selectedIcon.codePoint == icon.codePoint;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedIcon = icon;
                                selectedType = iconData['type'] as String;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
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
                                size: 32,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final balanceText = balanceController.text.trim();

                  // Validate account name
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(builderContext).showSnackBar(
                      const SnackBar(content: Text('Please enter an account name')),
                    );
                    return;
                  }

                  // Validate balance
                  if (balanceText.isEmpty) {
                    ScaffoldMessenger.of(builderContext).showSnackBar(
                      SnackBar(content: Text(account == null 
                          ? 'Please enter an initial balance'
                          : 'Please enter a balance amount')),
                    );
                    return;
                  }

                  final balance = double.tryParse(balanceText);
                  if (balance == null) {
                    ScaffoldMessenger.of(builderContext).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid balance amount')),
                    );
                    return;
                  }

                  try {
                    // Use sanitized account name as the id
                    final accountId = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
                    final accountToSave = Account(
                      id: accountId,
                      name: name,
                      type: selectedType,
                      balance: balance,
                      icon: selectedIcon,
                    );

                    if (account == null) {
                      await firebaseService.addAccount(accountToSave, userId);
                    } else {
                      // Pass old account name to handle name changes
                      await firebaseService.updateAccount(
                        accountToSave,
                        userId,
                        oldAccountName: account.name,
                      );
                    }

                    Navigator.of(dialogContext).pop();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(account == null
                              ? 'Account added successfully'
                              : 'Account updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }

                    // Call callback if provided
                    if (onAccountAdded != null) {
                      onAccountAdded();
                    }
                  } catch (e) {
                    if (builderContext.mounted) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: Text(account == null ? 'Add' : 'Update'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show delete account confirmation dialog - reusable function
  static Future<void> showDeleteAccountDialog(
    BuildContext context, {
    required Account account,
    VoidCallback? onAccountDeleted,
  }) async {
    final firebaseService = FirebaseService();
    final authService = AuthService();
    
    final userId = authService.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to delete "${account.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Use account name instead of account.id for deletion
        await firebaseService.deleteAccount(account.name, userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Call callback if provided
        if (onAccountDeleted != null) {
          onAccountDeleted();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting account: $e')),
          );
        }
      }
    }
  }
}

