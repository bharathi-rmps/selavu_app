import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final String type; // 'cash', 'card', 'savings', etc.
  final double balance;
  final IconData icon;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'iconCodePoint': icon.codePoint,
      'iconFontFamily': icon.fontFamily,
      'iconFontPackage': icon.fontPackage,
    };
  }

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    return Account(
      id: id,
      name: map['name'] as String,
      type: map['type'] as String,
      balance: (map['balance'] as num).toDouble(),
      icon: IconData(
        map['iconCodePoint'] as int,
        fontFamily: map['iconFontFamily'] as String?,
        fontPackage: map['iconFontPackage'] as String?,
      ),
    );
  }
}
