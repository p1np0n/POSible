class PosPage {
  final String id;
  final String name;
  final int sortOrder;

  PosPage({required this.id, required this.name, required this.sortOrder});

  factory PosPage.fromMap(Map<String, dynamic> map) => PosPage(
        id: map['id'] as String,
        name: map['name'] as String,
        sortOrder: map['sort_order'] as int? ?? 0,
      );
}
