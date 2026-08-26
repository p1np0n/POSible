class StoreSettings {
  final double taxRatePercent;
  final String? lowStockNotifyEmail;
  final String? ocrApiKey;
  final String? googleSearchApiKey;
  final String? googleSearchEngineId;

  /// Margen general (%) que se usa para sugerir el precio de venta a partir
  /// del costo, cuando un producto no tiene su propio margen configurado.
  final double defaultMarginPercent;

  StoreSettings({
    required this.taxRatePercent,
    this.lowStockNotifyEmail,
    this.ocrApiKey,
    this.googleSearchApiKey,
    this.googleSearchEngineId,
    this.defaultMarginPercent = 30,
  });

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        taxRatePercent: (map['tax_rate_percent'] as num).toDouble(),
        lowStockNotifyEmail: map['low_stock_notify_email'] as String?,
        ocrApiKey: map['ocr_api_key'] as String?,
        googleSearchApiKey: map['google_search_api_key'] as String?,
        googleSearchEngineId: map['google_search_engine_id'] as String?,
        defaultMarginPercent: (map['default_margin_percent'] as num?)?.toDouble() ?? 30,
      );
}
