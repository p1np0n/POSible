import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/customer_display_config.dart';
import '../../utils/currency_format_cl.dart';

/// Pantalla completa (sin menú, sin login) que muestra lo que el cliente
/// está comprando: se conecta por WebSocket al celular de la caja, dentro
/// de la misma red WiFi de la tienda — no usa internet ni Supabase. Si se
/// corta la conexión (WiFi, o la caja se cerró), reintenta sola cada pocos
/// segundos.
class CustomerDisplayScreen extends StatefulWidget {
  const CustomerDisplayScreen({super.key});

  @override
  State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
  static const _ipPrefsKey = 'customer_display_register_ip';

  String? _ip;
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _connected = false;
  List<Map<String, dynamic>> _items = [];
  double _subtotal = 0;
  double _discount = 0;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _loadIpAndConnect();
  }

  Future<void> _loadIpAndConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_ipPrefsKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _ip = saved);
      _connect();
    }
  }

  Future<void> _saveIpAndConnect(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipPrefsKey, ip);
    _reconnectTimer?.cancel();
    _socket?.close();
    if (!mounted) return;
    setState(() {
      _ip = ip;
      _connected = false;
      _items = [];
    });
    _connect();
  }

  void _connect() {
    final ip = _ip;
    if (ip == null) return;
    WebSocket.connect('ws://$ip:$customerDisplayPort').then((socket) {
      if (!mounted) {
        socket.close();
        return;
      }
      _socket = socket;
      setState(() => _connected = true);
      socket.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    }).catchError((_) => _scheduleReconnect());
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    setState(() => _connected = false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _items = items;
        _subtotal = (data['subtotal'] as num).toDouble();
        _discount = (data['discount'] as num).toDouble();
        _total = (data['total'] as num).toDouble();
      });
    } catch (_) {
      // Mensaje que no se pudo leer — se ignora, se sigue esperando el
      // próximo (no vale la pena cortar la conexión por esto).
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.close();
    super.dispose();
  }

  Future<void> _editIp() async {
    final controller = TextEditingController(text: _ip ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IP del celular de caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En el celular de la caja: Configuración → "Activar pantalla para el '
              'cliente" — ahí aparece esta dirección.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'ej. 192.168.1.5', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) _saveIpAndConnect(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onLongPress: _editIp,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: _ip == null
                ? _buildSetupPrompt()
                : _items.isEmpty
                    ? _buildIdle()
                    : _buildCart(),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_tethering, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Conecta con el celular de la caja',
            style: TextStyle(color: Colors.white, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _editIp, child: const Text('Configurar')),
        ],
      ),
    );
  }

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '¡Bienvenido!',
            style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _connected ? 'Esperando tu compra…' : 'Conectando con la caja…',
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCart() {
    return Column(
      children: [
        if (!_connected)
          Container(
            width: double.infinity,
            color: Colors.red.shade900,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Text(
              'Sin conexión con la caja — reintentando…',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final qty = (item['quantity'] as num).toDouble();
              final qtyLabel = qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(3);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$qtyLabel x ${item['name']}',
                        style: const TextStyle(color: Colors.white, fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatCurrencyCl(item['subtotal'] as num),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white24))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_discount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    Text(formatCurrencyCl(_subtotal), style: const TextStyle(color: Colors.white54, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Descuento', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    Text('-${formatCurrencyCl(_discount)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  Text(
                    formatCurrencyCl(_total),
                    style: const TextStyle(color: Colors.orange, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
