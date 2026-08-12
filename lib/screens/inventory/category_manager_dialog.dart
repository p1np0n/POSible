import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/category_repository.dart';

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final CategoryRepository _repository = CategoryRepository();
  final _newCategoryController = TextEditingController();
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final categories = await _repository.getAll();
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    _newCategoryController.clear();
    await _repository.create(name);
    _load();
  }

  Future<void> _delete(Category category) async {
    await _repository.delete(category.id);
    _load();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Categorías'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(labelText: 'Nueva categoría'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _add),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return ListTile(
                          title: Text(category.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(category),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}
