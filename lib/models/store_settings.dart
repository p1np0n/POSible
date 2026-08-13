class StoreSettings {
  final double taxRatePercent;

  StoreSettings({required this.taxRatePercent});

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        taxRatePercent: (map['tax_rate_percent'] as num).toDouble(),
      );
}
