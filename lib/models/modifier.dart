class Modifier {
  final String id;
  final String name;
  final double priceAdjustment;
  final bool active;

  Modifier({
    required this.id,
    required this.name,
    required this.priceAdjustment,
    required this.active,
  });

  factory Modifier.fromMap(Map<String, dynamic> map) => Modifier(
        id: map['id'] as String,
        name: map['name'] as String,
        priceAdjustment: (map['price_adjustment'] as num).toDouble(),
        active: map['active'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'price_adjustment': priceAdjustment,
        'active': active,
      };
}
