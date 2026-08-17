/// Guarda el id de la tienda del usuario actual, para que los repositorios
/// lo incluyan al crear filas nuevas. No es la barrera de seguridad (eso lo
/// hacen las políticas de la base de datos, que rechazan cualquier fila con
/// una tienda que no sea la tuya) — esto solo evita mandarlas vacías.
class CurrentStore {
  static String? id;
}
