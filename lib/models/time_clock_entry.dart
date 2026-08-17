class TimeClockEntry {
  final String id;
  final String? userEmail;
  final DateTime clockIn;
  final DateTime? clockOut;

  TimeClockEntry({
    required this.id,
    this.userEmail,
    required this.clockIn,
    this.clockOut,
  });

  bool get isOpen => clockOut == null;

  Duration get duration => (clockOut ?? DateTime.now()).difference(clockIn);

  factory TimeClockEntry.fromMap(Map<String, dynamic> map) => TimeClockEntry(
        id: map['id'] as String,
        userEmail: map['user_email'] as String?,
        clockIn: DateTime.parse(map['clock_in'] as String).toLocal(),
        clockOut: map['clock_out'] != null ? DateTime.parse(map['clock_out'] as String).toLocal() : null,
      );
}
