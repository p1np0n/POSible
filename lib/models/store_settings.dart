class StoreSettings {
  final double taxRatePercent;
  final String? lowStockNotifyEmail;

  StoreSettings({required this.taxRatePercent, this.lowStockNotifyEmail});

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        taxRatePercent: (map['tax_rate_percent'] as num).toDouble(),
        lowStockNotifyEmail: map['low_stock_notify_email'] as String?,
      );
}
