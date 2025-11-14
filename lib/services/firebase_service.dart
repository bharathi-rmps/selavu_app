import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/account.dart';

class FirebaseService {
  FirebaseFirestore? _firestore;
  final String _collectionName = 'expenses';

  FirebaseService() {
    // Only initialize Firestore if Firebase is initialized
    try {
      if (Firebase.apps.isNotEmpty) {
        _firestore = FirebaseFirestore.instance;
      }
    } catch (e) {
      // Firebase not initialized, _firestore will remain null
    }
  }

  bool get isInitialized => _firestore != null;

  // Check if display name is unique (case-insensitive)
  Future<bool> isDisplayNameUnique(String displayName) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Query users collection to check if display name exists (case-insensitive)
      // We store displayNameLowercase for efficient case-insensitive queries
      final querySnapshot = await _firestore!
          .collection('users')
          .where('displayNameLowercase', isEqualTo: displayName.trim().toLowerCase())
          .limit(1)
          .get();
      
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      throw Exception('Error checking display name uniqueness: $e');
    }
  }

  // Create user document with email, display name, default cash account, and default categories
  Future<void> createUserDocument(String userId, String email, String displayName) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Create default cash account
      final defaultCashAccount = {
        'id': 'cash',
        'name': 'Cash',
        'type': 'cash',
        'balance': 0.0,
        'iconCodePoint': Icons.money.codePoint,
        'iconFontFamily': Icons.money.fontFamily,
        'iconFontPackage': Icons.money.fontPackage,
      };

      // Create default categories
      final defaultCategories = {
        'Bills': {
          'name': 'Bills',
          'iconCodePoint': Icons.receipt_long.codePoint,
          'iconFontFamily': Icons.receipt_long.fontFamily,
          'iconFontPackage': Icons.receipt_long.fontPackage,
        },
        'Clothing': {
          'name': 'Clothing',
          'iconCodePoint': Icons.checkroom.codePoint,
          'iconFontFamily': Icons.checkroom.fontFamily,
          'iconFontPackage': Icons.checkroom.fontPackage,
        },
        'Food': {
          'name': 'Food',
          'iconCodePoint': Icons.restaurant.codePoint,
          'iconFontFamily': Icons.restaurant.fontFamily,
          'iconFontPackage': Icons.restaurant.fontPackage,
        },
        'Entertainment': {
          'name': 'Entertainment',
          'iconCodePoint': Icons.movie.codePoint,
          'iconFontFamily': Icons.movie.fontFamily,
          'iconFontPackage': Icons.movie.fontPackage,
        },
        'Home': {
          'name': 'Home',
          'iconCodePoint': Icons.home.codePoint,
          'iconFontFamily': Icons.home.fontFamily,
          'iconFontPackage': Icons.home.fontPackage,
        },
        'Shopping': {
          'name': 'Shopping',
          'iconCodePoint': Icons.shopping_bag.codePoint,
          'iconFontFamily': Icons.shopping_bag.fontFamily,
          'iconFontPackage': Icons.shopping_bag.fontPackage,
        },
        'Withdrawal': {
          'name': 'Withdrawal',
          'iconCodePoint': Icons.account_balance_wallet.codePoint,
          'iconFontFamily': Icons.account_balance_wallet.fontFamily,
          'iconFontPackage': Icons.account_balance_wallet.fontPackage,
        },
      };

      await _firestore!.collection('users').doc(userId).set({
        'email': email,
        'displayName': displayName,
        'displayNameLowercase': displayName.toLowerCase(), // For case-insensitive queries
        'createdAt': FieldValue.serverTimestamp(),
        'accounts': {
          'cash': defaultCashAccount,
        },
        'categories': defaultCategories,
      });
    } catch (e) {
      throw Exception('Error creating user document: $e');
    }
  }

  // Add expense to Firestore (legacy method - kept for backward compatibility)
  Future<void> addExpense(Expense expense) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final expenseData = <String, dynamic>{
        'title': expense.title,
        'amount': expense.amount,
        'date': Timestamp.fromDate(expense.date),
      };
      
      // Add user info if available
      if (expense.userId != null) {
        expenseData['userId'] = expense.userId!;
      }
      if (expense.userEmail != null) {
        expenseData['userEmail'] = expense.userEmail!;
      }
      
      await _firestore!.collection(_collectionName).doc(expense.id).set(expenseData);
    } catch (e) {
      throw Exception('Error adding expense: $e');
    }
  }

  // Helper method to update account balance
  Future<void> _updateAccountBalance(String userId, String accountName, double amountChange) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final accountKey = _sanitizeAccountName(accountName);
      
      // Use FieldValue.increment for atomic updates
      await _firestore!.collection('users').doc(userId).update({
        'accounts.$accountKey.balance': FieldValue.increment(amountChange),
      });
    } catch (e) {
      // If account doesn't exist, try to find it by name match
      try {
        final userDoc = await _firestore!.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final accountsMap = data?['accounts'] as Map<String, dynamic>?;
          if (accountsMap != null) {
            // Try to find account by matching name (case-insensitive)
            String? foundKey;
            for (final entry in accountsMap.entries) {
              final accountData = entry.value as Map<String, dynamic>;
              final accountNameInFirebase = accountData['name'] as String? ?? '';
              if (accountNameInFirebase.toLowerCase() == accountName.toLowerCase()) {
                foundKey = entry.key;
                break;
              }
            }
            if (foundKey != null) {
              await _firestore!.collection('users').doc(userId).update({
                'accounts.$foundKey.balance': FieldValue.increment(amountChange),
              });
              return;
            }
          }
        }
      } catch (_) {
        // Fall through to throw original error
      }
      throw Exception('Error updating account balance: $e');
    }
  }

  // Add income to Firestore (saves to transactions collection)
  Future<void> addIncome({
    required String userId,
    required String userEmail,
    required double amount,
    required String category,
    required String notes,
    required DateTime transactionDateTime,
    required String accountName,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final transactionId = _firestore!.collection('transactions').doc().id;
      final transactionData = <String, dynamic>{
        'userUniqueId': userId,
        'transactionType': 'income',
        'amount': amount,
        'fromAccount': accountName,
        'category': category,
        'notes': notes,
        'transactionTime': Timestamp.fromDate(transactionDateTime),
        'addedTime': FieldValue.serverTimestamp(),
      };
      await _firestore!.collection('transactions').doc(transactionId).set(transactionData);
      // Update account balance (add amount)
      await _updateAccountBalance(userId, accountName, amount);
    } catch (e) {
      throw Exception('Error adding income: $e');
    }
  }

  // Add expense to Firestore (saves to transactions collection)
  Future<void> addExpenseRecord({
    required String userId,
    required String userEmail,
    required double amount,
    required String category,
    required String notes,
    required DateTime transactionDateTime,
    required String accountName,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final transactionId = _firestore!.collection('transactions').doc().id;
      final transactionData = <String, dynamic>{
        'userUniqueId': userId,
        'transactionType': 'expense',
        'amount': amount,
        'fromAccount': accountName,
        'category': category,
        'notes': notes,
        'transactionTime': Timestamp.fromDate(transactionDateTime),
        'addedTime': FieldValue.serverTimestamp(),
      };
      await _firestore!.collection('transactions').doc(transactionId).set(transactionData);
      // Update account balance (subtract amount, can go negative)
      await _updateAccountBalance(userId, accountName, -amount);
    } catch (e) {
      throw Exception('Error adding expense: $e');
    }
  }

  // Add transfer to Firestore (saves to transactions collection)
  Future<void> addTransfer({
    required String userId,
    required String userEmail,
    required String fromAccount,
    required String toAccount,
    required double amount,
    required String notes,
    required DateTime transactionDateTime,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final transactionId = _firestore!.collection('transactions').doc().id;
      final transactionData = <String, dynamic>{
        'userUniqueId': userId,
        'transactionType': 'transfer',
        'amount': amount,
        'fromAccount': fromAccount,
        'toAccount': toAccount,
        'notes': notes,
        'transactionTime': Timestamp.fromDate(transactionDateTime),
        'addedTime': FieldValue.serverTimestamp(),
      };
      await _firestore!.collection('transactions').doc(transactionId).set(transactionData);
      // Update account balances: subtract from fromAccount, add to toAccount
      await _updateAccountBalance(userId, fromAccount, -amount);
      await _updateAccountBalance(userId, toAccount, amount);
    } catch (e) {
      throw Exception('Error adding transfer: $e');
    }
  }

  // Update income transaction
  Future<void> updateIncome({
    required String transactionId,
    required String userId,
    required double oldAmount,
    required String oldAccountName,
    required double amount,
    required String category,
    required String notes,
    required DateTime transactionDateTime,
    required String accountName,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Revert old balance changes
      await _updateAccountBalance(userId, oldAccountName, -oldAmount);
      
      // Update transaction
      final transactionData = <String, dynamic>{
        'userUniqueId': userId,
        'transactionType': 'income',
        'amount': amount,
        'fromAccount': accountName,
        'category': category,
        'notes': notes,
        'transactionTime': Timestamp.fromDate(transactionDateTime),
      };
      await _firestore!.collection('transactions').doc(transactionId).update(transactionData);
      
      // Apply new balance changes
      await _updateAccountBalance(userId, accountName, amount);
    } catch (e) {
      throw Exception('Error updating income: $e');
    }
  }

  // Update expense transaction
  Future<void> updateExpense({
    required String transactionId,
    required String userId,
    required double oldAmount,
    required String oldAccountName,
    required double amount,
    required String category,
    required String notes,
    required DateTime transactionDateTime,
    required String accountName,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Revert old balance changes
      await _updateAccountBalance(userId, oldAccountName, oldAmount);
      
      // Update transaction
      final transactionData = <String, dynamic>{
        'userUniqueId': userId,
        'transactionType': 'expense',
        'amount': amount,
        'fromAccount': accountName,
        'category': category,
        'notes': notes,
        'transactionTime': Timestamp.fromDate(transactionDateTime),
      };
      await _firestore!.collection('transactions').doc(transactionId).update(transactionData);
      
      // Apply new balance changes
      await _updateAccountBalance(userId, accountName, -amount);
    } catch (e) {
      throw Exception('Error updating expense: $e');
    }
  }

  // Update transfer transaction
  Future<void> updateTransfer({
    required String transactionId,
    required String userId,
    required double oldAmount,
    required String oldFromAccount,
    required String oldToAccount,
    required String fromAccount,
    required String toAccount,
    required double amount,
    required String notes,
    required DateTime transactionDateTime,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Revert old balance changes
      await _updateAccountBalance(userId, oldFromAccount, oldAmount);
      await _updateAccountBalance(userId, oldToAccount, -oldAmount);
      
      // Update transaction
      final transactionData = <String, dynamic>{
        'userUniqueId': userId,
        'transactionType': 'transfer',
        'amount': amount,
        'fromAccount': fromAccount,
        'toAccount': toAccount,
        'notes': notes,
        'transactionTime': Timestamp.fromDate(transactionDateTime),
      };
      await _firestore!.collection('transactions').doc(transactionId).update(transactionData);
      
      // Apply new balance changes
      await _updateAccountBalance(userId, fromAccount, -amount);
      await _updateAccountBalance(userId, toAccount, amount);
    } catch (e) {
      throw Exception('Error updating transfer: $e');
    }
  }

  // Get transaction by ID (for editing)
  Future<Map<String, dynamic>?> getTransactionById(String transactionId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final doc = await _firestore!.collection('transactions').doc(transactionId).get();
      if (!doc.exists) {
        return null;
      }
      final data = doc.data()!;
      final type = data['transactionType'] as String;
      final transaction = {
        'id': doc.id,
        'type': type,
        'amount': (data['amount'] as num).toDouble(),
        'transactionDateTime': (data['transactionTime'] as Timestamp).toDate(),
        'notes': data['notes'] as String? ?? '',
        'userId': data['userUniqueId'] as String?,
      };
      
      if (type == 'income' || type == 'expense') {
        transaction['category'] = data['category'] as String? ?? '';
        transaction['accountName'] = data['fromAccount'] as String? ?? '';
      } else if (type == 'transfer') {
        transaction['fromAccount'] = data['fromAccount'] as String? ?? '';
        transaction['toAccount'] = data['toAccount'] as String? ?? '';
      }
      
      return transaction;
    } catch (e) {
      throw Exception('Error getting transaction: $e');
    }
  }

  // Delete expense from Firestore (legacy method)
  Future<void> deleteExpense(String id) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      await _firestore!.collection(_collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting expense: $e');
    }
  }

  // Delete income transaction (reverts account balance)
  Future<void> deleteIncome(String id, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Get transaction data before deleting
      final doc = await _firestore!.collection('transactions').doc(id).get();
      if (!doc.exists) {
        throw Exception('Transaction not found');
      }
      final data = doc.data()!;
      final amount = (data['amount'] as num).toDouble();
      final accountName = data['fromAccount'] as String? ?? '';
      
      // Delete transaction
      await _firestore!.collection('transactions').doc(id).delete();
      
      // Revert account balance (subtract the income amount)
      if (accountName.isNotEmpty) {
        await _updateAccountBalance(userId, accountName, -amount);
      }
    } catch (e) {
      throw Exception('Error deleting income: $e');
    }
  }

  // Delete expense transaction (reverts account balance)
  Future<void> deleteExpenseTransaction(String id, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Get transaction data before deleting
      final doc = await _firestore!.collection('transactions').doc(id).get();
      if (!doc.exists) {
        throw Exception('Transaction not found');
      }
      final data = doc.data()!;
      final amount = (data['amount'] as num).toDouble();
      final accountName = data['fromAccount'] as String? ?? '';
      
      // Delete transaction
      await _firestore!.collection('transactions').doc(id).delete();
      
      // Revert account balance (add back the expense amount)
      if (accountName.isNotEmpty) {
        await _updateAccountBalance(userId, accountName, amount);
      }
    } catch (e) {
      throw Exception('Error deleting expense: $e');
    }
  }

  // Delete transfer transaction (reverts account balances)
  Future<void> deleteTransfer(String id, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Get transaction data before deleting
      final doc = await _firestore!.collection('transactions').doc(id).get();
      if (!doc.exists) {
        throw Exception('Transaction not found');
      }
      final data = doc.data()!;
      final amount = (data['amount'] as num).toDouble();
      final fromAccount = data['fromAccount'] as String? ?? '';
      final toAccount = data['toAccount'] as String? ?? '';
      
      // Delete transaction
      await _firestore!.collection('transactions').doc(id).delete();
      
      // Revert account balances
      // Add back to fromAccount (revert the subtraction)
      if (fromAccount.isNotEmpty) {
        await _updateAccountBalance(userId, fromAccount, amount);
      }
      // Subtract from toAccount (revert the addition)
      if (toAccount.isNotEmpty) {
        await _updateAccountBalance(userId, toAccount, -amount);
      }
    } catch (e) {
      throw Exception('Error deleting transfer: $e');
    }
  }

  // Delete transaction by type and id (reverts account balances)
  Future<void> deleteTransaction(String type, String id, String userId) async {
    switch (type) {
      case 'income':
        await deleteIncome(id, userId);
        break;
      case 'expense':
        await deleteExpenseTransaction(id, userId);
        break;
      case 'transfer':
        await deleteTransfer(id, userId);
        break;
      default:
        throw Exception('Unknown transaction type: $type');
    }
  }

  // Get all expenses as a stream (legacy - kept for backward compatibility)
  Stream<List<Expense>> getExpenses() {
    if (_firestore == null) {
      // Return empty stream if Firebase is not initialized
      return Stream.value([]);
    }
    return _firestore!
        .collection(_collectionName)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Expense(
          id: doc.id,
          title: data['title'] as String,
          amount: (data['amount'] as num).toDouble(),
          date: (data['date'] as Timestamp).toDate(),
          userId: data['userId'] as String?,
          userEmail: data['userEmail'] as String?,
        );
      }).toList();
    });
  }

  // Get all income transactions for a user
  Stream<List<Map<String, dynamic>>> getIncomeTransactions(String userId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('transactions')
        .where('userUniqueId', isEqualTo: userId)
        .where('transactionType', isEqualTo: 'income')
        .orderBy('transactionTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'income',
          'amount': (data['amount'] as num).toDouble(),
          'category': data['category'] as String? ?? '',
          'notes': data['notes'] as String? ?? '',
          'accountName': data['fromAccount'] as String? ?? '',
          'transactionDateTime': (data['transactionTime'] as Timestamp).toDate(),
          'recordAddedDateTime': data['addedTime'] != null
              ? (data['addedTime'] as Timestamp).toDate()
              : null,
          'userId': data['userUniqueId'] as String?,
        };
      }).toList();
    });
  }

  // Get all expense transactions for a user
  Stream<List<Map<String, dynamic>>> getExpenseTransactions(String userId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('transactions')
        .where('userUniqueId', isEqualTo: userId)
        .where('transactionType', isEqualTo: 'expense')
        .orderBy('transactionTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'expense',
          'amount': (data['amount'] as num).toDouble(),
          'category': data['category'] as String? ?? '',
          'notes': data['notes'] as String? ?? '',
          'accountName': data['fromAccount'] as String? ?? '',
          'transactionDateTime': (data['transactionTime'] as Timestamp).toDate(),
          'recordAddedDateTime': data['addedTime'] != null
              ? (data['addedTime'] as Timestamp).toDate()
              : null,
          'userId': data['userUniqueId'] as String?,
        };
      }).toList();
    });
  }

  // Get all transfer transactions for a user
  Stream<List<Map<String, dynamic>>> getTransferTransactions(String userId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('transactions')
        .where('userUniqueId', isEqualTo: userId)
        .where('transactionType', isEqualTo: 'transfer')
        .orderBy('transactionTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': 'transfer',
          'amount': (data['amount'] as num).toDouble(),
          'fromAccount': data['fromAccount'] as String? ?? '',
          'toAccount': data['toAccount'] as String? ?? '',
          'notes': data['notes'] as String? ?? '',
          'transactionDateTime': (data['transactionTime'] as Timestamp).toDate(),
          'recordAddedDateTime': data['addedTime'] != null
              ? (data['addedTime'] as Timestamp).toDate()
              : null,
          'userId': data['userUniqueId'] as String?,
        };
      }).toList();
    });
  }

  // Get all transactions (income, expense, transfer) combined for a user
  // More efficient: directly queries transactions collection
  // Note: Sorting in memory to avoid requiring a composite index
  Stream<List<Map<String, dynamic>>> getAllTransactions(String userId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('transactions')
        .where('userUniqueId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        final type = data['transactionType'] as String;
        final transaction = {
          'id': doc.id,
          'type': type,
          'amount': (data['amount'] as num).toDouble(),
          'transactionDateTime': (data['transactionTime'] as Timestamp).toDate(),
          'recordAddedDateTime': data['addedTime'] != null
              ? (data['addedTime'] as Timestamp).toDate()
              : null,
          'userId': data['userUniqueId'] as String?,
        };
        
        // Add type-specific fields
        if (type == 'income' || type == 'expense') {
          transaction['category'] = data['category'] as String? ?? '';
          transaction['accountName'] = data['fromAccount'] as String? ?? '';
        } else if (type == 'transfer') {
          transaction['fromAccount'] = data['fromAccount'] as String? ?? '';
          transaction['toAccount'] = data['toAccount'] as String? ?? '';
        }
        
        transaction['notes'] = data['notes'] as String? ?? '';
        
        return transaction;
      }).toList();
      
      // Sort by transactionDateTime descending (newest first)
      transactions.sort((a, b) {
        final dateA = a['transactionDateTime'] as DateTime;
        final dateB = b['transactionDateTime'] as DateTime;
        return dateB.compareTo(dateA);
      });
      
      return transactions;
    });
  }

  // Get total expenses
  Future<double> getTotalExpenses() async {
    if (_firestore == null) {
      return 0.0;
    }
    try {
      final snapshot = await _firestore!.collection(_collectionName).get();
      return snapshot.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        return sum + ((data['amount'] as num).toDouble());
      });
    } catch (e) {
      throw Exception('Error calculating total: $e');
    }
  }

  // Helper method to sanitize account name for use as Firebase key
  String _sanitizeAccountName(String name) {
    // Replace spaces and special characters with underscores
    // Keep only alphanumeric characters and underscores
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_') // Replace multiple underscores with single
        .replaceAll(RegExp(r'^_|_$'), ''); // Remove leading/trailing underscores
  }

  // Account methods - user-specific
  Future<void> addAccount(Account account, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final accountData = account.toMap();
      // Use sanitized account name as the key
      final accountKey = _sanitizeAccountName(account.name);
      accountData['id'] = accountKey;
      
      await _firestore!
          .collection('users')
          .doc(userId)
          .update({
        'accounts.$accountKey': accountData,
      });
    } catch (e) {
      throw Exception('Error adding account: $e');
    }
  }

  Future<void> updateAccount(Account account, String userId, {String? oldAccountName}) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final accountData = account.toMap();
      final newAccountKey = _sanitizeAccountName(account.name);
      accountData['id'] = newAccountKey;
      
      // If account name changed, we need to delete the old key and create a new one
      if (oldAccountName != null && oldAccountName != account.name) {
        final oldAccountKey = _sanitizeAccountName(oldAccountName);
        await _firestore!
            .collection('users')
            .doc(userId)
            .update({
          'accounts.$oldAccountKey': FieldValue.delete(),
          'accounts.$newAccountKey': accountData,
        });
      } else {
        // Name didn't change, just update the existing account
        final accountKey = _sanitizeAccountName(account.name);
        await _firestore!
            .collection('users')
            .doc(userId)
            .update({
          'accounts.$accountKey': accountData,
        });
      }
    } catch (e) {
      throw Exception('Error updating account: $e');
    }
  }

  Future<void> deleteAccount(String accountName, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final accountKey = _sanitizeAccountName(accountName);
      await _firestore!
          .collection('users')
          .doc(userId)
          .update({
        'accounts.$accountKey': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Error deleting account: $e');
    }
  }

  Stream<List<Account>> getAccounts(String userId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return <Account>[];
      }
      final data = snapshot.data();
      final accountsMap = data?['accounts'] as Map<String, dynamic>?;
      if (accountsMap == null) {
        return <Account>[];
      }
      final accounts = accountsMap.entries.map((entry) {
        final accountData = entry.value as Map<String, dynamic>;
        return Account.fromMap(entry.key, accountData);
      }).toList();
      // Sort by name locally
      accounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return accounts;
    });
  }

  // Category methods - user-specific
  Future<void> addCategory(String categoryName, IconData icon, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final categoryData = {
        'name': categoryName,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'iconFontPackage': icon.fontPackage,
      };
      
      await _firestore!
          .collection('users')
          .doc(userId)
          .update({
        'categories.$categoryName': categoryData,
      });
    } catch (e) {
      throw Exception('Error adding category: $e');
    }
  }

  Future<void> deleteCategory(String categoryName, String userId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .update({
        'categories.$categoryName': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Error deleting category: $e');
    }
  }

  Stream<Map<String, IconData>> getCategories(String userId) {
    if (_firestore == null) {
      return Stream.value({});
    }
    return _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return <String, IconData>{};
      }
      final data = snapshot.data();
      final categoriesMap = data?['categories'] as Map<String, dynamic>?;
      if (categoriesMap == null) {
        return <String, IconData>{};
      }
      final categories = <String, IconData>{};
      categoriesMap.forEach((categoryName, categoryData) {
        final catData = categoryData as Map<String, dynamic>;
        categories[categoryName] = IconData(
          catData['iconCodePoint'] as int,
          fontFamily: catData['iconFontFamily'] as String?,
          fontPackage: catData['iconFontPackage'] as String?,
        );
      });
      return categories;
    });
  }

  // Get total income from all account balances
  Future<double> getTotalIncome() async {
    if (_firestore == null) {
      return 0.0;
    }
    try {
      final snapshot = await _firestore!.collection('accounts').get();
      return snapshot.docs.fold<double>(0.0, (sum, doc) {
        final data = doc.data();
        return sum + ((data['balance'] as num).toDouble());
      });
    } catch (e) {
      throw Exception('Error calculating total income: $e');
    }
  }

  // Get total income as a stream (for reactive updates) - from user's accounts
  Stream<double> getTotalIncomeStream(String userId) {
    if (_firestore == null) {
      return Stream.value(0.0);
    }
    return _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return 0.0;
      }
      final data = snapshot.data();
      final accountsMap = data?['accounts'] as Map<String, dynamic>?;
      if (accountsMap == null) {
        return 0.0;
      }
      return accountsMap.values.fold<double>(0.0, (sum, accountData) {
        final account = accountData as Map<String, dynamic>;
        return sum + ((account['balance'] as num).toDouble());
      });
    });
  }

  // Custom Category methods - stored as array field in user document
  Future<void> addCustomCategory({
    required String userId,
    required String categoryName,
    required IconData categoryIcon,
    required String categoryType, // 'income' or 'expense'
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Check if category already exists
      final userDoc = await _firestore!
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        final customCategories = data?['customCategories'] as List<dynamic>?;
        
        if (customCategories != null) {
          // Check for duplicate category name and type
          final duplicate = customCategories.any((category) {
            final cat = category as Map<String, dynamic>;
            return cat['categoryName'] == categoryName && 
                   cat['categoryType'] == categoryType;
          });
          
          if (duplicate) {
            throw Exception('Category "$categoryName" already exists for $categoryType');
          }
        }
      }
      
      // Generate unique ID for the category using timestamp and random
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 100000).toString().padLeft(5, '0');
      final categoryId = 'cat_${timestamp}_$random';

      final categoryData = {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'categoryIcon': {
          'iconCodePoint': categoryIcon.codePoint,
          'iconFontFamily': categoryIcon.fontFamily,
          'iconFontPackage': categoryIcon.fontPackage,
        },
        'categoryType': categoryType,
      };

      // Add to customCategories array field in user document
      await _firestore!
          .collection('users')
          .doc(userId)
          .update({
        'customCategories': FieldValue.arrayUnion([categoryData]),
      });
    } catch (e) {
      throw Exception('Error adding custom category: $e');
    }
  }

  // Get custom categories for a user
  Stream<List<Map<String, dynamic>>> getCustomCategories(String userId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    return _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return <Map<String, dynamic>>[];
      }
      final data = snapshot.data();
      final customCategories = data?['customCategories'] as List<dynamic>?;
      if (customCategories == null || customCategories.isEmpty) {
        return <Map<String, dynamic>>[];
      }
      return customCategories.map((categoryData) {
        final category = categoryData as Map<String, dynamic>;
        final iconData = category['categoryIcon'] as Map<String, dynamic>;
        return {
          'categoryId': category['categoryId'] as String,
          'categoryName': category['categoryName'] as String,
          'categoryIcon': IconData(
            iconData['iconCodePoint'] as int,
            fontFamily: iconData['iconFontFamily'] as String?,
            fontPackage: iconData['iconFontPackage'] as String?,
          ),
          'categoryType': category['categoryType'] as String,
        };
      }).toList();
    });
  }

  // Budget methods
  // Structure: budgets/{budgetUniqueId}
  // userUniqueId is stored as a field inside the document for filtering
  Future<void> addBudget({
    required String userId,
    required String categoryName,
    required IconData categoryIcon,
    required double limit,
    required int month,
    required int year,
  }) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Generate unique budget ID
      final budgetId = _firestore!
          .collection('budgets')
          .doc()
          .id;

      final budgetData = {
        'userUniqueId': userId, // Store userUniqueId as a field for filtering
        'categoryName': categoryName,
        'categoryIcon': {
          'iconCodePoint': categoryIcon.codePoint,
          'iconFontFamily': categoryIcon.fontFamily,
          'iconFontPackage': categoryIcon.fontPackage,
        },
        'limit': limit,
        'month': month,
        'year': year,
        'addedDateTime': FieldValue.serverTimestamp(),
      };

      // Save budget: budgets/{budgetUniqueId}
      await _firestore!
          .collection('budgets')
          .doc(budgetId)
          .set(budgetData);
    } catch (e) {
      throw Exception('Error adding budget: $e');
    }
  }

  // Get budgets for a user filtered by month and year
  // Structure: budgets/{budgetUniqueId} with userUniqueId field
  Stream<List<Map<String, dynamic>>> getBudgets(String userId, int month, int year) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    // Query budgets collection, filter by userUniqueId, month, and year
    return _firestore!
        .collection('budgets')
        .where('userUniqueId', isEqualTo: userId)
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final iconData = data['categoryIcon'] as Map<String, dynamic>;
        return {
          'id': doc.id, // budgetUniqueId
          'categoryName': data['categoryName'] as String,
          'categoryIcon': IconData(
            iconData['iconCodePoint'] as int,
            fontFamily: iconData['iconFontFamily'] as String?,
            fontPackage: iconData['iconFontPackage'] as String?,
          ),
          'limit': (data['limit'] as num).toDouble(),
          'month': data['month'] as int,
          'year': data['year'] as int,
          'addedDateTime': data['addedDateTime'] != null
              ? (data['addedDateTime'] as Timestamp).toDate()
              : null,
        };
      }).toList();
    });
  }

  // Update budget limit
  Future<void> updateBudgetLimit(String budgetId, double newLimit) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      await _firestore!
          .collection('budgets')
          .doc(budgetId)
          .update({
        'limit': newLimit,
      });
    } catch (e) {
      throw Exception('Error updating budget limit: $e');
    }
  }

  // Delete budget
  Future<void> deleteBudget(String budgetId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      await _firestore!
          .collection('budgets')
          .doc(budgetId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting budget: $e');
    }
  }

  // Delete custom category
  Future<void> deleteCustomCategory(String userId, String categoryId) async {
    if (_firestore == null) {
      throw Exception('Firebase is not initialized');
    }
    try {
      // Get the current user document to find the category to remove
      final userDoc = await _firestore!
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }
      
      final data = userDoc.data();
      final customCategories = data?['customCategories'] as List<dynamic>?;
      
      if (customCategories == null || customCategories.isEmpty) {
        throw Exception('No custom categories found');
      }
      
      // Find and remove the category with matching categoryId
      final updatedCategories = customCategories.where((category) {
        final cat = category as Map<String, dynamic>;
        return cat['categoryId'] as String != categoryId;
      }).toList();
      
      // Update the document with the filtered array
      await _firestore!
          .collection('users')
          .doc(userId)
          .update({
        'customCategories': updatedCategories,
      });
    } catch (e) {
      throw Exception('Error deleting custom category: $e');
    }
  }
}

