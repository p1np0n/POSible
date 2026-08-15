import 'package:flutter/material.dart';

import '../../models/open_ticket.dart';
import '../../services/open_ticket_repository.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/currency_text.dart';

/// Lista de tickets que se dejaron en espera durante el turno actual.
/// Al elegir "Retomar" se devuelve el ticket elegido; quien abre esta hoja
/// es responsable de reconstruir el carrito y borrar el registro.
class OpenTicketsSheet extends StatefulWidget {
  final String cashSessionId;

  const OpenTicketsSheet({super.key, required this.cashSessionId});

  @override
  State<OpenTicketsSheet> createState() => _OpenTicketsSheetState();
}

class _OpenTicketsSheetState extends State<OpenTicketsSheet> {
  final OpenTicketRepository _repository = OpenTicketRepository();
  List<OpenTicket> _tickets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tickets = await _repository.getForSession(widget.cashSessionId);
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _discard(OpenTicket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar ticket'),
        content: const Text('¿Seguro que quieres descartar este ticket en espera? Se pierden sus productos.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.delete(ticket.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Tickets en espera', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tickets.isEmpty
                      ? const Center(child: Text('No hay tickets en espera'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = _tickets[index];
                            return ListTile(
                              leading: const Icon(Icons.receipt_long),
                              title: Text(ticket.label ?? 'Ticket ${index + 1}'),
                              subtitle: Text(
                                '${ticket.items.length} artículo(s) · ${formatTimeEs(ticket.createdAt.toLocal())}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CurrencyText(ticket.total, bold: true),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _discard(ticket),
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.of(context).pop(ticket),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
