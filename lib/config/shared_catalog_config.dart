// Catálogo de productos COMPARTIDO entre todos los negocios que usan
// POSible. Es opcional: si no lo configuras, la app simplemente no lo usa
// (sigue funcionando con tu catálogo propio y Open Food Facts).
//
// Cómo activarlo:
// 1. Crea un proyecto de Supabase NUEVO Y APARTE del de tu negocio.
// 2. Corre ahí el script sql/shared_catalog_schema.sql (ver ese archivo).
// 3. Pega abajo el Project URL y la llave anon/publishable de ESE proyecto.
class SharedCatalogConfig {
  static const String supabaseUrl = 'PON_AQUI_LA_URL_DEL_CATALOGO_COMPARTIDO';
  static const String supabaseAnonKey = 'PON_AQUI_LA_LLAVE_DEL_CATALOGO_COMPARTIDO';

  static bool get isConfigured =>
      supabaseUrl != 'PON_AQUI_LA_URL_DEL_CATALOGO_COMPARTIDO' &&
      supabaseAnonKey != 'PON_AQUI_LA_LLAVE_DEL_CATALOGO_COMPARTIDO' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
