class Discount {
  final String id;
  final String name;
  final String type;
  final double value;
  final bool active;

  Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.active,
  });

  // Marcador especial para "quitar el descuento seleccionado" en el diálogo
  // de selección, distinto de "cancelar" (que no cambia nada).
  static final Discount none = Discount(id: '__none__', name: 'Sin descuento', type: 'fixed', value: 0, active: true);

  bool get isNone => id == '__none__';

  bool get isPercentage => type == 'percentage';

  double amountFor(double subtotal) {
    final raw = isPercentage ? subtotal * value / 100 : value;
    return raw > subtotal ? subtotal : raw;
  }

  factory Discount.fromMap(Map<String, dynamic> map) => Discount(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        value: (map['value'] as num).toDouble(),
        active: map['active'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'value': value,
        'active': active,
      };
}
