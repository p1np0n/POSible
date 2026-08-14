import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../services/category_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(labelText: 'Nueva categoría', border: OutlineInputBorder()),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(icon: const Icon(Icons.add), onPressed: _add),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_categories.isEmpty)
            const Text('No hay categorías todavía')
          else
            ..._categories.map((category) => Card(
                  child: ListTile(
                    title: Text(category.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(category),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
