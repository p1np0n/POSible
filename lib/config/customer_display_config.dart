/// Puerto que usa el servidor local de "Pantalla para el cliente" (ver
/// lib/services/customer_display_server.dart, del lado de la caja) — el
/// mismo número lo usa "Info ScreenClone" (lib/main_customer_display.dart)
/// para saber a qué puerto conectarse dentro de la misma red WiFi. No pasa
/// por internet ni por Supabase.
const customerDisplayPort = 8790;
