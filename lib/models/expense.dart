class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String? userId;
  final String? userEmail;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.userId,
    this.userEmail,
  });
}

