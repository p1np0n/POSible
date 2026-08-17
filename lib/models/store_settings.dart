class StoreSettings {
  final double taxRatePercent;
  final String? lowStockNotifyEmail;
  final String? ocrApiKey;

  StoreSettings({required this.taxRatePercent, this.lowStockNotifyEmail, this.ocrApiKey});

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        taxRatePercent: (map['tax_rate_percent'] as num).toDouble(),
        lowStockNotifyEmail: map['low_stock_notify_email'] as String?,
        ocrApiKey: map['ocr_api_key'] as String?,
      );
}
