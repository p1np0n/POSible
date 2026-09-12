import 'package:flutter/material.dart';

import 'screens/customer_display/customer_display_screen.dart';

/// Punto de entrada de "Info ScreenClone": un APK aparte y liviano, sin
/// login ni Supabase — se conecta directo, por la misma red WiFi de la
/// tienda (sin internet), al celular de la caja para mostrarle al cliente
/// lo que está comprando y el total en vivo (ver
/// lib/services/customer_display_server.dart, del lado de la caja, y
/// lib/screens/customer_display/customer_display_screen.dart, esta
/// pantalla). Se compila con
/// `flutter build apk -t lib/main_customer_display.dart` (ver
/// .github/workflows/build_customer_display.yml).
void main() {
  runApp(const MaterialApp(
    title: 'Info ScreenClone',
    debugShowCheckedModeBanner: false,
    home: CustomerDisplayScreen(),
  ));
}
