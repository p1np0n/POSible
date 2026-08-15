class CashMovement {
  final String id;
  final String cashSessionId;
  final String type; // 'deposit' o 'withdrawal'
  final double amount;
  final String? note;
  final DateTime createdAt;
  final String? userEmail;

  CashMovement({
    required this.id,
    required this.cashSessionId,
    required this.type,
    required this.amount,
    this.note,
    required this.createdAt,
    this.userEmail,
  });

  bool get isDeposit => type == 'deposit';

  factory CashMovement.fromMap(Map<String, dynamic> map) => CashMovement(
        id: map['id'] as String,
        cashSessionId: map['cash_session_id'] as String,
        type: map['type'] as String,
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        userEmail: map['user_email'] as String?,
      );
}
