import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

class CategoryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Category>> getAll() async {
    final data = await _client.from('categories').select().order('name');
    return (data as List).map((e) => Category.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Category> create(String name) async {
    final data = await _client.from('categories').insert({'name': name}).select().single();
    return Category.fromMap(data);
  }

  Future<void> update(String id, String name) async {
    await _client.from('categories').update({'name': name}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
