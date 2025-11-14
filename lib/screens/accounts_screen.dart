import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../utils/account_dialog_helper.dart';
import 'profile_screen.dart';
import 'account_transactions_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        centerTitle: true,
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
          : StreamBuilder<List<Account>>(
              stream: _firebaseService.getAccounts(_authService.currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Account> accounts = snapshot.data ?? [];

                return accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 64,
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No accounts yet. Add your first account!',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF2D2D3A),
                                child: Icon(
                                  account.icon,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                              title: Text(
                                account.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                account.type,
                                style: const TextStyle(color: Colors.white60),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${account.balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: account.balance < 0
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white70),
                                    onPressed: () => AccountDialogHelper.showAddEditAccountDialog(
                                      context,
                                      account: account,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                                    onPressed: () => AccountDialogHelper.showDeleteAccountDialog(
                                      context,
                                      account: account,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AccountTransactionsScreen(
                                      account: account,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AccountDialogHelper.showAddAccountDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }
}

