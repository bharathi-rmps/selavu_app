import 'package:flutter/material.dart';
import 'records_screen.dart';
import 'analysis_screen.dart';
import 'budgets_screen.dart';
import 'accounts_screen.dart';
import 'bill_splits_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const RecordsScreen(),
    const AnalysisScreen(),
    const BudgetsScreen(),
    const BillSplitsScreen(),
    const AccountsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.people),
            label: 'Bill Splits',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }
}

