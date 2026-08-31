import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final CustomerRepository _repository = CustomerRepository();
  List<Customer> _customers = [];
  bool _loading = true;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customers = await _repository.getAll(search: _search);
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los clientes';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Customer? customer]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: customer)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar cliente',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _search = value;
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingIndicator()
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : _customers.isEmpty
                          ? const EmptyState(message: 'No hay clientes registrados', icon: Icons.people_outline)
                          : ListView.builder(
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            return ListTile(
                              title: Text(customer.name),
                              subtitle: Text(
                                  '${formatNumberCl(customer.loyaltyPoints)} puntos · Gastado: ${formatCurrencyCl(customer.totalSpent)}'),
                              onTap: () => _openForm(customer),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
