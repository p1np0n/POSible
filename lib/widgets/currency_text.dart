import 'package:flutter/material.dart';

import '../config/app_config.dart';

class CurrencyText extends StatelessWidget {
  final double amount;
  final bool bold;
  final TextStyle? style;

  const CurrencyText(this.amount, {super.key, this.bold = false, this.style});

  @override
  Widget build(BuildContext context) {
    final text = '${AppConfig.currencySymbol}${amount.toStringAsFixed(2)}';
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontWeight: bold ? FontWeight.bold : null,
      ),
    );
  }
}
