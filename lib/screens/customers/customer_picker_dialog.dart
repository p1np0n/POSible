import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_repository.dart';

class CustomerPickerDialog extends StatefulWidget {
  const CustomerPickerDialog({super.key});

  @override
  State<CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<CustomerPickerDialog> {
  final CustomerRepository _repository = CustomerRepository();
  final _searchController = TextEditingController();
  List<Customer> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    final results = await _repository.getAll(search: value);
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir cliente'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Buscar', prefixIcon: Icon(Icons.search)),
              onChanged: _search,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final customer = _results[index];
                        return ListTile(
                          title: Text(customer.name),
                          subtitle: Text('${customer.loyaltyPoints} puntos'),
                          onTap: () => Navigator.of(context).pop(customer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
