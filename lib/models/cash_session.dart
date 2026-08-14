class CashSession {
  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingAmount;
  final double? closingAmount;
  final String status;
  final String? notes;
  final String? userEmail;

  CashSession({
    required this.id,
    required this.openedAt,
    this.closedAt,
    required this.openingAmount,
    this.closingAmount,
    required this.status,
    this.notes,
    this.userEmail,
  });

  bool get isOpen => status == 'open';

  factory CashSession.fromMap(Map<String, dynamic> map) => CashSession(
        id: map['id'] as String,
        openedAt: DateTime.parse(map['opened_at'] as String),
        closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at'] as String) : null,
        openingAmount: (map['opening_amount'] as num).toDouble(),
        closingAmount: (map['closing_amount'] as num?)?.toDouble(),
        status: map['status'] as String,
        notes: map['notes'] as String?,
        userEmail: map['user_email'] as String?,
      );
}
