# POSible — Cómo tener tu app funcionando

POSible es tu propio sistema de punto de venta (como Loyverse): ventas y caja,
inventario, reportes y clientes con puntos de lealtad. Los datos se guardan
en la nube (Supabase, gratis) así no se pierden aunque cambies de celular.

La app compila sola en GitHub Actions (gratis) y te entrega un .apk para
instalar en tu Android. No necesitas instalar Flutter ni Android Studio.

## Paso 1: Crear tu base de datos en Supabase (gratis)

1. Entra a https://supabase.com y crea una cuenta gratis.
2. Crea un proyecto nuevo (elige cualquier nombre y una contraseña para la
   base de datos, guárdala por si acaso).
3. Cuando el proyecto esté listo, ve a **SQL Editor** (menú de la izquierda) →
   **New query**.
4. Abre el archivo `sql/schema.sql` de este repositorio, copia TODO su
   contenido, pégalo en el editor de Supabase y dale **Run**. Esto crea las
   tablas de productos, categorías, clientes, ventas y caja.
5. Ve a **Project Settings** (ícono de engranaje) → **API**. Vas a necesitar
   dos datos de esta pantalla en el Paso 2:
   - **Project URL**
   - **anon public** (una llave larga)

## Paso 2: Configurar la app con tus datos de Supabase

1. En este repositorio de GitHub, abre el archivo
   `lib/config/supabase_config.dart`.
2. Toca el ícono de lápiz (editar) arriba a la derecha del archivo.
3. Reemplaza `PON_AQUI_TU_SUPABASE_URL` por tu Project URL, y
   `PON_AQUI_TU_SUPABASE_ANON_KEY` por tu llave anon public.
4. Abajo, dale **Commit changes**. Esto ya deja todo guardado en el repo.

## Paso 3: Crear tu usuario para entrar a la app

La app no tiene registro público (por seguridad, para que nadie más entre
con tus datos). Tú mismo creas tu usuario:

1. En Supabase, ve a **Authentication** → **Users** → **Add user**
   → **Create new user**.
2. Pon tu correo y una contraseña, y marca la opción de "Auto Confirm User"
   si aparece (así no necesitas confirmar por correo).
3. Con ese correo y contraseña vas a entrar a la app POSible.

### Sobre el registro de empleados
A partir de la versión con "Empleados", la app SÍ permite que cualquiera
cree una cuenta desde la pantalla de inicio de sesión — pero esa cuenta
nueva no puede ver ni tocar ningún dato hasta que tú la apruebes desde
**Configuración → Empleados** dentro de la app. Por eso necesitas dejar
estas dos opciones así en tu proyecto de Supabase:
1. Ve a **Authentication** → **Sign In / Providers** → **Email**.
2. Activa **"Allow new users to sign up"** (permitir registro) — así tus
   empleados pueden crear su cuenta ellos mismos.
3. Apaga **"Confirm email"** (o "Enable email confirmations") — ya vimos
   antes que el correo de confirmación no funciona bien para esta app, así
   que mejor que no dependa de eso.
También te recomiendo mantener este repositorio de GitHub como **Privado**
(Settings → General → Danger Zone → Change visibility).

### Login rápido con PIN (cambio de cajero) — solo en el APK
Esta función es solo para el celular (Android); en el panel web siempre se
usa el formulario de correo y contraseña completo, sin PIN ni bloqueo
automático (tiene sentido: el celular pasa de mano en mano entre cajeros,
la computadora normalmente no).

La primera vez que un correo inicia sesión en un celular, la app
recuerda ESE correo en ESE dispositivo (nunca la contraseña). La próxima
vez que alguien cierre sesión ahí (Configuración → "Cerrar sesión / Cambiar
de cajero"), en vez del formulario de correo y contraseña aparece una
lista de "¿quién eres?" — tocas tu nombre y escribes tu PIN en un teclado
numérico, más rápido que escribir todo de nuevo.

Por dentro, el PIN sigue siendo tu contraseña normal de Supabase — para
que funcione bien, cuando crees tu contraseña (Paso 3, o cuando un
empleado se registra) **usa 4 dígitos numéricos** (ej. `4819`) en vez de
una contraseña con letras. Si alguien usa una contraseña con letras, no
pasa nada grave: solo no le va a servir el teclado numérico, y puede
tocar "Usar otra cuenta" para entrar con el formulario normal.

⚠️ **Paso extra en Supabase para permitir contraseñas de 4 dígitos**: por
defecto, Supabase exige contraseñas de mínimo 6 caracteres, así que crear
una cuenta con una contraseña de 4 dígitos fallaría. Para permitirlo:
1. Ve a **Authentication** → **Policies** (o **Settings**, según la
   versión del panel) → busca **"Minimum password length"**.
2. Cámbialo de `6` a `4` y guarda.
Si no encuentras esta opción o prefieres no tocarla, no pasa nada: solo
usa contraseñas de 6 dígitos en vez de 4 (igual funciona el PIN, solo que
escribes 2 números más).

### Bloqueo automático (pedir el PIN de nuevo) — solo en el APK
En **Configuración → Seguridad → "Bloqueo automático"** (solo aparece en el
celular) eliges cuánto
tiempo puede estar la app en segundo plano (minimizada o con la pantalla
apagada) antes de pedir el PIN otra vez al volver a abrirla — 5, 15, 30
minutos, 1 hora, o "Nunca". No cierra la sesión: solo bloquea la pantalla
hasta que la misma persona escriba su PIN de nuevo (o toque "No soy yo /
Cerrar sesión" si le pasó el celular a otra persona).

### Gestionar empleados desde el panel web (crear, borrar, restablecer PIN)
En **Configuración → Empleados** (panel web) puedes:
- **Aprobar/rechazar** cuentas que un empleado creó solo desde el login.
- **Nuevo empleado**: crear una cuenta directamente tú, con correo y PIN —
  queda aprobada de inmediato, sin que el empleado tenga que registrarse.
- **Restablecer PIN** (ícono de llave junto a cada empleado): le pones un
  PIN nuevo en cualquier momento, por ejemplo si lo olvidó.
- **Quitar**: le saca el acceso (como ya funcionaba antes).

Estas dos primeras funciones (crear empleado y restablecer PIN) requieren
un paso extra, porque son acciones "de administrador" que, por seguridad,
la app no puede hacer directamente — necesitan pasar por una función que
corre en el servidor de Supabase (nunca en tu celular/computador ni en el
código de la app). Se activa así, **una sola vez, sin instalar nada**:

1. En tu proyecto de Supabase (el de tu negocio), ve a **Edge Functions**
   en el menú de la izquierda.
2. Dale a **Create a new function** (o "Deploy a new function").
3. Ponle el nombre exacto **`manage-employee`** y créala.
4. Abre el archivo `supabase/functions/manage-employee/index.ts` de este
   repositorio, copia TODO su contenido, pégalo reemplazando el código de
   ejemplo que trae la función, y dale **Deploy**.

Mientras no hagas esto, "Nuevo empleado" y "Restablecer PIN" van a mostrar
un mensaje de error explicando que falta este paso — el resto de la app
sigue funcionando normal. Como alternativa, siempre puedes seguir creando
usuarios y cambiando contraseñas manualmente desde **Authentication →
Users** en el panel de Supabase, sin necesidad de esta función.

## Paso 4: Ver cómo compila sola la app

1. Arriba en el repo, click en la pestaña **Actions**.
2. Como acabas de hacer un commit, ya debería estar corriendo "Build APK"
   (ícono amarillo = en progreso, verde = listo, rojo = falló).
3. Si no ves nada corriendo, entra al workflow "Build APK" y dale
   **Run workflow**.
4. Espera 3-5 minutos.

## Paso 5: Descargar el .apk

1. Click en el workflow que terminó en verde.
2. Abajo, en la sección **Artifacts**, vas a ver "posible-apk".
3. Click ahí para descargarlo (viene como .zip, adentro está el .apk).
4. Copia el .apk a tu celular Android e instálalo (puede pedirte permitir
   "instalar apps de orígenes desconocidos" — es normal, es tu propia app).
5. Abre la app y entra con el correo/contraseña que creaste en el Paso 3.

## Si el workflow sale en rojo (falló)
Click en el workflow fallido → click en el paso que tiene la X roja → copia
el texto del error y pégamelo en el chat, lo reviso contigo.

## ⚠️ Cuando actualices la app, vuelve a correr el SQL
Cada vez que agreguemos una función nueva que necesite datos (como Recibos,
Descuentos o Impuestos), `sql/schema.sql` se actualiza. **Vuelve a copiar y
pegar TODO el archivo en el SQL Editor de Supabase y dale Run de nuevo** —
está pensado para poder ejecutarse varias veces sin borrar tus datos. Si no
lo haces, la app puede fallar porque le faltan tablas o columnas nuevas.

## Qué incluye esta versión
- **Ventas y caja**: apertura/cierre de caja (Turno), carrito, descuentos,
  impuestos, pago en efectivo/tarjeta/otro o **dividido entre varios**
  (ej. mitad efectivo, mitad tarjeta), "artículo rápido" (agregar algo con
  nombre y precio libres sin que esté en tu inventario, ej. algo pesado en
  el momento o un cargo especial), "tickets abiertos" (dejar una venta en
  espera con el botón de recibo junto al buscador, para atender a otro
  cliente y retomarla después desde el mismo ícono, incluyendo el cliente
  y descuento que tenías elegidos), "anular venta" (botón rojo arriba del
  carrito para descartar todo sin cobrar) y asignar la venta a un cliente
  (botón "Elegir" junto a "Sin cliente").
- **Recibos**: historial de ventas agrupado por día, con número de recibo,
  buscador y detalle de cada venta.
- **Turno**: cada empleado abre y cierra su propia caja; hay un historial
  de turnos con quién lo hizo y cuánto se vendió en cada uno. Cambiar de
  cajero es rápido gracias al login con PIN (ver más arriba). Con "Ver
  detalle de caja" (turno abierto) o tocando un turno del historial, ves
  el desglose completo de tesorería: fondo de caja anterior, cobros en
  efectivo, depositado, pagos/salidas y el efectivo teórico que debería
  haber en la caja, más el resumen de ventas por método de pago. Desde ahí
  también puedes registrar un depósito o un retiro de efectivo durante el
  turno (ej. sacar dinero para un pago).
- **Artículos** (solo en el panel web — ver más abajo): lista de productos,
  categorías, modificadores, descuentos, control de existencias, foto por
  producto (cámara o galería), y búsqueda automática por código de barras
  (en tu catálogo, en el catálogo compartido de POSible, y en Open Food
  Facts si no lo tienen los otros dos). Si tienes modificadores activos
  (ej. "Extra queso"), al tocar un producto en Ventas te deja elegirlos
  antes de agregarlo al carrito, y quedan reflejados en el recibo.
- **Reportes**: ventas de hoy / 7 días / este mes, ticket promedio, ventas
  por método de pago, productos más vendidos.
- **Clientes y lealtad**: ficha de cliente, historial de gasto y puntos
  acumulados por compra (1 punto por cada unidad de moneda gastada).
- **Empleados** (solo en el panel web): cualquiera crea su cuenta desde la
  app, pero no ve nada hasta que la apruebas desde Empleados. También
  puedes crear empleados tú mismo con correo y PIN, y restablecer el PIN
  de cualquiera, directamente desde ahí (requiere activar una función en
  Supabase la primera vez — ver más arriba).
- **Inventario** (solo en el panel web): administra el catálogo de
  productos COMPARTIDO entre TODAS las tiendas que usan POSible (no solo
  la tuya) — buscar, agregar, editar y borrar cualquier producto. Solo
  aparece si configuraste el catálogo compartido (ver más abajo).
  ⚠️ Como ese proyecto de Supabase es público (sin cuentas de usuario),
  cualquiera con la app puede editar o borrar productos que cargó otra
  tienda distinta a la tuya — se eligió así a propósito para que sea fácil
  de mantener entre todos, pero ten en cuenta esa contraparte.
- **Configuración**: tasa de impuesto, modo oscuro, vista en lista, cerrar
  sesión.

### APK vs panel web: no son exactamente lo mismo
El **APK** (celular) se queda con lo esencial para atender en el mostrador:
Ventas, Recibos, Turno, Reportes, Clientes y Configuración. El **panel
web** además tiene todo lo de administración (back office): Artículos con
su submenú (Lista de artículos, Categorías, Modificadores, Descuentos) y
Empleados. Así el celular queda simple y rápido para vender, y la
administración más completa la haces desde la computadora.

### Diseño que se adapta a la pantalla
El menú se ve distinto según el tamaño de pantalla: en el celular es un
menú deslizable (como antes), y en una pantalla ancha (computador) se
muestra fijo al costado, como un panel de administración normal.

## Catálogo compartido entre negocios (opcional)
Además de tu catálogo propio (que ya funciona solo), POSible puede conectarse
a un catálogo de productos COMPARTIDO entre todos los negocios que usan la
app — para que si otra tienda ya cargó un producto, tú no tengas que
buscarlo de nuevo, y viceversa. Es opcional y requiere un paso tuyo, porque
implica crear un proyecto de Supabase aparte (público, no el de tu negocio):

1. Crea un proyecto NUEVO en supabase.com (distinto al de tu negocio), por
   ejemplo llamado "posible-catalogo-compartido".
2. En su SQL Editor, corre TODO el contenido de
   `sql/shared_catalog_schema.sql` de este repositorio.
3. Copia el Project URL y la llave anon/publishable de ESE proyecto (nuevo)
   y pégalas en `lib/config/shared_catalog_config.dart`, reemplazando los
   textos `PON_AQUI_...`.
4. Sube el cambio (commit) para que se recompile la app.

Mientras no hagas esto, la app funciona igual, solo que sin esa fuente
adicional (usa tu catálogo propio y Open Food Facts).

## Detalles y limitaciones conocidas

### Sobre "reembolsos" en el detalle de caja
El desglose de tesorería incluye una línea de "Reembolsos" (como en
Loyverse) pero siempre muestra $0, porque POSible todavía no tiene función
para devolver o anular una venta ya cobrada — solo puedes anular el
carrito ANTES de cobrar. Está en la lista de "Próximas mejoras" si la
necesitas.

### Sobre "Acciones de ticket"
De las 4 que pediste (anular, dividir el pago, mover a otra caja, asignar
a un cliente), ya quedaron 3: **anular** venta, **dividir el pago** y
**asignar a un cliente** (esta última ya existía como "Elegir" cliente en
el carrito). La que falta, **mover un ticket a otra caja**, no se puede
hacer todavía porque POSible no maneja varias cajas/cajeros trabajando al
mismo tiempo dentro de una misma tienda (cada quien tiene su propio turno,
pero no hay el concepto de "caja 1", "caja 2" como en tus capturas de
Loyverse). Para agregarla de verdad, antes habría que construir "Múltiples
sucursales/cajas" (ver más abajo) — dime si quieres que prioricemos eso.

## Próximas mejoras posibles (dime cuáles te sirven y las agregamos)
- Reembolsar o anular una venta ya cobrada
- Impresión de recibo por Bluetooth (impresora térmica portátil)
- Pantalla secundaria para clientes
- Permisos distintos por empleado (ej. que un cajero no vea Reportes)
- Múltiples sucursales/cajas (necesario para "mover ticket a otra caja")
- Canje de puntos de lealtad (no solo acumularlos)
- Gráficos en los reportes
- Modo sin internet con sincronización automática al recuperar señal

## Cada vez que quieras una nueva versión
Cuando yo te agregue o corrija algo y lo suba a este repositorio, solo
repites el Paso 4 (Actions compila sola) y el Paso 5 (descargar el nuevo
.apk).
