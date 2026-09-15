import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/store_provider.dart';

/// Se muestra en vez de la app cuando el administrador principal pausó
/// esta tienda (ej. mientras se pone al día con el pago del servicio) —
/// nadie de la tienda puede seguir usándola hasta que la reactive. El
/// administrador principal nunca ve esta pantalla, así que siempre puede
/// entrar a reactivarla.
class StorePausedScreen extends StatelessWidget {
  const StorePausedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storeName = context.watch<StoreProvider>().myStore?.name ?? 'Tu tienda';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause_circle_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                '$storeName está pausada',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Nadie puede usar la app mientras esté así. Contacta a quien te da el '
                'servicio de POSible para reactivarla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFF616161)),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<StoreProvider>().reset();
                  Supabase.instance.client.auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
