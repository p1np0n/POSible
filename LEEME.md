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

### Recuperar u olvidar la contraseña
En la pantalla de inicio de sesión hay un enlace **"¿Olvidaste tu
contraseña?"** que pide el correo y manda un enlace para elegir una
contraseña nueva (funciona tanto en el panel web como en el APK — el
enlace siempre abre el panel web, ahí se define la contraseña nueva y
después puedes volver a entrar, también desde el APK, con esa contraseña).
Cualquier usuario que ya inició sesión también puede cambiar su contraseña
en cualquier momento desde **Configuración → Cambiar contraseña**, sin
depender del correo.

Para que el enlace de recuperación funcione, hay que autorizarlo una vez en
Supabase:
1. Ve a **Authentication** → **URL Configuration**.
2. En **Redirect URLs**, agrega la URL de tu panel publicado, por ejemplo
   `https://TU-USUARIO.github.io/POSible/` (con el `/` final, y con tu
   usuario/nombre de repositorio reales).
3. Guarda. Si no haces este paso, Supabase rechaza el enlace de
   recuperación con un error de "redirect not allowed".

### Multi-tienda: varias tiendas compartiendo la misma app
POSible ahora soporta varias tiendas usando la misma app y la misma base de
datos, cada una viendo **solo sus propios datos** (productos, ventas,
clientes, etc. — nunca los de otra tienda). Tú (`ivan.rojas2@gmail.com`)
eres el **administrador principal**: tu cuenta ve y administra todas las
tiendas, y tu tienda actual pasó a llamarse automáticamente "Tienda 1" con
todas las funciones activas al correr `sql/schema.sql` con este cambio (no
se pierde ni se mueve ningún dato, solo se le puso una etiqueta de tienda a
lo que ya tenías).

**Cómo se registra una tienda nueva**: en la pantalla de inicio de sesión,
el enlace **"¿Vas a abrir una tienda nueva? Créala aquí"** pide nombre de la
tienda, correo y contraseña del dueño. La tienda queda activa de inmediato,
pero **empieza limitada**: tiene Ventas, Recibos, Turno, Lista de artículos,
Categorías, Modificadores, Descuentos, Inventario y Configuración — pero
**no** Reportes, Clientes ni Empleados, hasta que tú se los actives. Las
categorías (a diferencia de modificadores y descuentos) se comparten entre
todas tus tiendas — igual que el catálogo global — para que una tienda
nueva no empiece sin ninguna para organizar sus artículos.

**Cómo le activas funciones a una tienda**: entra a **Tiendas** en el menú
(solo la ves tú, como administrador principal) y prende los interruptores
de Reportes / Clientes / Empleados para la tienda que quieras.

**Cómo un empleado se une a una tienda que ya existe**: usa el botón
"¿Eres empleado nuevo? Crea tu cuenta" de siempre, pero ahora pide además
un **"Código de tienda"** — es el código corto que cada tienda tiene (lo
puedes ver, como administrador, en la pantalla Tiendas). La cuenta nueva
queda pendiente de aprobación del dueño de esa tienda, igual que antes —
con la diferencia de que esa función de aprobar empleados (Empleados) tiene
que estar activada para esa tienda.

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

Como administrador principal, en **Tiendas** también puedes **restablecer
la contraseña del administrador de cada tienda** (botón "Restablecer
contraseña del administrador" en la tarjeta de cada tienda) — útil si el
dueño de una tienda distinta a la tuya olvidó su contraseña. Solo funciona
para tiendas creadas después de correr `sql/schema.sql` con este cambio (o
para tiendas más antiguas, una vez que lo corras, se completa solo con el
correo del administrador que ya tenían guardado).

Estas funciones (crear empleado, restablecer PIN/contraseña) requieren un
paso extra, porque son acciones "de administrador" que, por seguridad, la
app no puede hacer directamente — necesitan pasar por una función que
corre en el servidor de Supabase (nunca en tu celular/computador ni en el
código de la app). Se activa así, **una sola vez, sin instalar nada**:

1. En tu proyecto de Supabase (el de tu negocio), ve a **Edge Functions**
   en el menú de la izquierda.
2. Dale a **Create a new function** (o "Deploy a new function").
3. Ponle el nombre exacto **`manage-employee`** y créala.
4. Abre el archivo `supabase/functions/manage-employee/index.ts` de este
   repositorio, copia TODO su contenido, pégalo reemplazando el código de
   ejemplo que trae la función, y dale **Deploy**.

⚠️ **Si ya la habías activado antes**: esta versión le agregó a
`manage-employee` el permiso para que el administrador principal
restablezca contraseñas de otras tiendas (antes solo dejaba dentro de tu
propia tienda). Tienes que **volver a pegar el contenido actualizado del
archivo y darle Deploy de nuevo** — si no, "Restablecer contraseña del
administrador" en Tiendas va a fallar con un error de permiso.

Mientras no actives (o actualices) esta función, esas opciones van a
mostrar un mensaje de error explicando que falta este paso — el resto de
la app sigue funcionando normal. Como alternativa, siempre puedes seguir
creando usuarios y cambiando contraseñas manualmente desde
**Authentication → Users** en el panel de Supabase, sin necesidad de esta
función.

### Alerta de inventario bajo por correo (opcional)
En **Configuración** (panel web) puedes poner un correo para que te avise
cuando algún producto llegue al umbral de "inventario bajo" que le pusiste
en Lista de artículos. Como con los empleados, esto necesita otra función
de servidor y una cuenta gratis en [Resend](https://resend.com) (el
servicio que realmente envía el correo):

1. Crea una cuenta gratis en resend.com y copia tu **API key** (empieza
   con `re_`).
2. En tu proyecto de Supabase, ve a **Edge Functions** → **Create a new
   function**, ponle el nombre exacto **`notify-low-stock`**, pega TODO
   el contenido de `supabase/functions/notify-low-stock/index.ts` de este
   repositorio y dale **Deploy**.
3. Dentro de esa función, busca **Manage secrets** (o **Project Settings
   → Edge Functions → Secrets**) y agrega el secreto `RESEND_API_KEY` con
   la clave que copiaste.
4. En **Configuración** (panel web), escribe el correo donde quieres
   recibir la alerta y dale **Guardar**. Puedes probar de inmediato con el
   botón **"Enviar prueba ahora"**.
5. Nota de Resend: mientras no verifiques un dominio propio, solo puedes
   recibir en el correo con el que te registraste ahí — es una limitación
   de su plan gratuito, no de POSible.
6. Opcional — para que se revise solo todos los días sin que tengas que
   entrar tú: en Supabase ve a **Database → Cron Jobs → Create a new cron
   job**, tipo **HTTP Request**, con la URL de la función
   `notify-low-stock`, el header `Authorization: Bearer <tu service_role
   key>` (lo encuentras en Project Settings → API), y el horario que
   prefieras.

## Paso 4: Compilar el APK cuando lo necesites

El panel web (`https://<tu-usuario>.github.io/<tu-repo>/`) sí se actualiza
solo con cada cambio. El **APK** ya no — para ahorrar minutos de compilación
mientras seguimos mejorando la app seguido, el APK se genera solo cuando tú
lo pides, no en cada cambio.

1. Arriba en el repo, click en la pestaña **Actions**.
2. En la lista de la izquierda, click en **"Build APK"**.
3. Click en **Run workflow** (botón a la derecha) → **Run workflow** de nuevo
   para confirmar.
4. Espera 3-5 minutos (ícono amarillo = en progreso, verde = listo).

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
- **Ventas — mosaico de fotos y pestañas personalizadas**: los productos se
  muestran como mosaicos con foto (como una vitrina) — foto de fondo con el
  precio arriba y el nombre superpuesto abajo si tiene, o un círculo gris
  con precio y nombre si todavía no tiene foto. La cantidad de columnas se
  ajusta sola al ancho de la pantalla (unas 5 en una tablet ancha, menos en
  un celular). El botón **"Más vendidos"** (junto al buscador) muestra de
  inmediato los productos más vendidos en los últimos 30 días. El botón
  **"+"** de al lado crea una **pestaña personalizada** (ej. "Promos",
  "Verduras") a la que le agregas los productos o categorías completas que
  quieras, desde el ícono de engranaje que aparece cuando esa pestaña está
  elegida (ahí también la renombras o la eliminas). Para agregar rápido un
  producto sin abrir esa pantalla: mantén presionado en cualquier parte del
  mosaico, o toca el último mosaico "Agregar producto" — se abre un
  buscador y, al elegir uno, queda agregado ahí mismo. El menú desplegable
  de categorías sigue sirviendo para filtrar por una categoría real del
  catálogo. Puedes seguir prefiriendo la vista en lista clásica desde
  **Configuración → Vista en lista de artículos** (ahí las pestañas
  personalizadas solo se pueden editar desde el ícono de engranaje, no
  agregar con mantener presionado).
- **Ventas y caja**: apertura/cierre de caja (Turno), carrito, descuentos,
  IVA (la tasa que pongas en Configuración se descuenta del precio que ya
  cargaste — **no se suma aparte**, porque el precio de tus artículos ya lo
  incluye — y solo sirve para mostrar el desglose en la venta y el ticket),
  pago en efectivo/tarjeta/otro o **dividido entre varios**
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
- **Inventario**: entradas y salidas de stock aparte de las ventas (ej.
  recibir mercadería de un proveedor, o descontar por pérdida o rotura).
  Busca o escanea el producto, elige "Entrada" o "Salida" y la cantidad —
  queda un historial con quién, cuándo y por qué (motivo opcional). Si
  escaneas un código que no existe, te ofrece crear el producto ahí mismo.
  El botón **"Importar factura (foto)"** le toma una foto (o elige un
  archivo PDF) a una factura o boleta, lee el texto (OCR) y trata de
  reconocer artículos y cantidades —
  es aproximado (depende de qué tan clara sea la foto y el formato de la
  factura), así que siempre te deja revisar y corregir cada línea antes de
  confirmar: para cada una eliges si suma stock a un producto que ya
  existe o si crea uno nuevo (con precio \$0 — hay que ponerle el precio
  después en Lista de artículos). Usa una clave de prueba compartida por
  defecto (con límites); en Configuración puedes poner tu propia clave
  gratuita de [ocr.space](https://ocr.space/ocrapi) para que sea confiable.
- **Artículos** (solo en el panel web — ver más abajo): lista de productos,
  categorías, modificadores, descuentos, control de existencias, foto por
  producto (cámara o galería), y búsqueda automática por código de barras
  (en el catálogo global y en Open Food Facts si no lo tiene). El botón
  **"Buscar fotos por código de barras"** (ícono de lupa sobre una foto, en
  Lista de artículos) revisa todos los productos que tienen código de
  barras pero no tienen foto todavía, y les busca la foto automáticamente
  (mismas fuentes: catálogo global, Open Food Facts, UPCitemdb) — así no
  hace falta entrar producto por producto. Es de mejor esfuerzo: no todos
  los códigos de barras tienen foto disponible en esas bases de datos. Al
  crear un producto también puedes buscarlo por nombre en el catálogo global (ícono
  de lupa junto a "Nombre") para reutilizar lo que ya cargó otra de tus
  tiendas — nunca copia el precio automáticamente, solo lo muestra como
  precio sugerido. Si tienes modificadores activos (ej. "Extra queso"), al
  tocar un producto en Ventas te deja elegirlos antes de agregarlo al
  carrito, y quedan reflejados en el recibo.
- **Reportes**: ventas de hoy / 7 días / este mes, ticket promedio, ventas
  por método de pago, productos más vendidos.
- **Clientes y lealtad**: ficha de cliente, historial de gasto y puntos
  acumulados por compra (1 punto por cada unidad de moneda gastada).
- **Empleados** (solo en el panel web): cualquiera crea su cuenta desde la
  app, pero no ve nada hasta que la apruebas desde Empleados. También
  puedes crear empleados tú mismo con correo y PIN, y restablecer el PIN
  de cualquiera, directamente desde ahí (requiere activar una función en
  Supabase la primera vez — ver más arriba).
- **Catálogo global** (solo el administrador principal, panel web): revisa
  y cura el catálogo global — el mismo que se usa para sugerir nombre, foto
  y precio al crear un producto nuevo en cualquiera de tus tiendas. Se
  alimenta solo, automáticamente, con cada producto que cualquier tienda
  agrega a su propio inventario (con o sin código de barras); desde aquí
  puedes además agregar, editar o borrar entradas a mano.
- **Configuración**: tasa de impuesto, margen general de venta, modo
  oscuro, vista en lista, cerrar sesión.

### Inventario bajo y margen (en Lista de artículos)
Al editar un producto puedes poner un número en "Alertar cuando el stock
llegue a" (opcional). Si el stock del producto baja a ese número o menos,
en Lista de artículos aparece la etiqueta naranja "Inventario bajo" y
puedes filtrar por "Inventario" (Todos / Inventario bajo / Sin stock) igual
que por categoría. Si le pones costo al producto, la lista también muestra
el margen (%) calculado automáticamente. El ícono de lápiz en cada fila
abre un cuadro rápido para cambiar solo precio y costo sin entrar al
formulario completo.

### Margen de venta y calculadora de IVA (al crear/editar un producto)
En Configuración hay un campo **"Margen general (%)"** (por defecto 30%)
que se usa para sugerir el precio de venta a partir del costo, en
cualquier artículo que no tenga su propio margen configurado. En el
formulario de cada producto (debajo de Precio y Costo) hay un campo
**"Margen de este producto (%)"**, que si lo llenas reemplaza al margen
general solo para ese artículo (vacío = usa el general). Con el botón
**"Calcular precio"** se calcula el precio de venta sugerido a partir del
costo y ese margen, y lo pone en el campo Precio (no lo hace solo, hay que
tocar el botón, para no pisar un precio que estés editando a mano).
El campo "Precio" siempre es **con IVA incluido**: justo debajo aparece,
solo informativo, el desglose Neto/IVA calculado con la tasa de impuesto
de Configuración.

### Tipo de precio: fijo, variable o por peso
Al crear o editar un producto puedes elegir "Tipo de precio":
- **Fijo** (el normal): el precio del catálogo es el que se cobra.
- **Variable**: no tiene un precio fijo — en Ventas, cada vez que lo
  agregas al carrito, te pregunta el precio antes de agregarlo (sirve para
  servicios o artículos sin precio estándar).
- **Por peso**: se vende por kilo (el "Precio" es el precio por kilo) y se
  agrega al carrito escaneando un código de balanza — un código de barras
  de 13 dígitos que empieza en "2" y trae el peso pesado. Para esto tienes
  que ponerle al producto el mismo "Código PLU" (5 dígitos) que configuraste
  en tu balanza. Al escanearlo (o leerlo con un lector de código de barras),
  la app calcula solo la cantidad en kilos y el precio, sin buscarlo como
  texto.

### APK vs panel web: no son exactamente lo mismo
El **APK** (celular) se queda con lo esencial para atender en el mostrador:
Ventas, Recibos, Turno, Inventario y Clientes (si tu tienda lo tiene
activado), más una Configuración reducida (impuestos, apariencia, cámara,
bloqueo automático y cerrar sesión). El **panel web** además tiene todo lo
de administración (back office): Reportes, Artículos con su submenú (Lista
de artículos, Categorías, Modificadores, Descuentos), Empleados, Catálogo
global, Tiendas, y en Configuración también "Cambiar contraseña" y
"Alertas de inventario bajo". Así el celular queda simple y rápido para
vender, y la administración más completa la haces desde la computadora (si
un cajero necesita cambiar su contraseña desde el celular, puede usar
"¿Olvidaste tu contraseña?" en la pantalla de inicio de sesión).

### Diseño que se adapta a la pantalla
El menú se ve distinto según el tamaño de pantalla: en el celular es un
menú deslizable (como antes), y en una pantalla ancha (computador) se
muestra fijo al costado, como un panel de administración normal.

## Catálogo global (entre tus tiendas)

Es UN SOLO catálogo, compartido entre todas tus tiendas (vive en la misma
base de datos de tu negocio, no en un proyecto aparte) y no requiere ningún
paso de configuración. Se alimenta solo: cada vez que cualquiera de tus
tiendas agrega un producto (tenga o no código de barras), ese nombre, foto
y precio quedan guardados ahí como sugerencia para las demás. Al crear un
producto nuevo, cualquier tienda puede buscar en él por código de barras o
por nombre (ícono de lupa junto a "Nombre") — el precio nunca se copia
automáticamente, solo se muestra como "precio sugerido" para que cada
tienda decida el suyo. Solo el administrador principal puede revisarlo y
editarlo a mano completo, desde el menú "Catálogo global".

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
