import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/category_repository.dart';
import '../../widgets/simple_crud_list_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = CategoryRepository();
    return SimpleCrudListScreen<Category>(
      searchLabel: 'Buscar categoría',
      emptyMessage: 'No hay categorías todavía',
      emptyIcon: Icons.category_outlined,
      infoText: 'Las categorías se comparten entre todas tus tiendas.',
      loadErrorPrefix: 'No se pudieron cargar las categorías',
      load: repository.getAll,
      titleOf: (category) => category.name,
      onAdd: (context) async {
        final name = await showDialog<String>(
          context: context,
          builder: (_) => const _CategoryNameDialog(),
        );
        if (name == null || name.trim().isEmpty) return false;
        await repository.create(name.trim());
        return true;
      },
      onDelete: (category) => repository.delete(category.id),
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog();

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva categoría'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Agregar')),
      ],
    );
  }
}
