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
nueva no empiece sin ninguna para organizar sus artículos. Además, la
tienda nueva se crea con **una copia de todos los artículos activos de tu
tienda principal** (mismo nombre, precio, costo, código de barras, SKU,
categoría, etc., pero con inventario en 0 — no copia tu stock, solo el
catálogo), para que la Lista de artículos no empiece vacía; de ahí en
adelante cada tienda administra su copia por separado (editar/eliminar un
artículo en una no afecta a la otra). Esto pasa una sola vez, al crear la
tienda — **requiere volver a correr `sql/schema.sql`**. También es
**retroactivo**: al correrlo, cualquier tienda que ya existía y hoy no
tiene ningún artículo propio recibe esa misma copia (si una tienda ya
tiene aunque sea un artículo, no se le toca nada).

**Cómo le activas funciones a una tienda**: entra a **Tiendas** en el menú
(solo la ves tú, como administrador principal) y prende los interruptores
de Reportes / Clientes / Empleados para la tienda que quieras. Si tienes
varias tiendas, arriba hay un **buscador** por nombre o código para
encontrar la que necesitas rápido, y cada tarjeta muestra de un vistazo si
le falta administrador (etiqueta naranja "Sin administrador"). Tocando el
código de la tienda (junto al ícono de copiar) lo copias al portapapeles,
listo para pasárselo a un empleado nuevo.

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
empleado se registra) **usa 8 dígitos numéricos** (ej. `48192736`) en vez
de una contraseña con letras. Si alguien usa una contraseña con letras, no
pasa nada grave: solo no le va a servir el teclado numérico, y puede
tocar "Usar otra cuenta" para entrar con el formulario normal.

El PIN es de **8 dígitos** (no 4) a propósito: Supabase exige por defecto
contraseñas de mínimo 6 caracteres, y ese mínimo no se puede bajar más
allá de cierto punto desde el panel en algunos proyectos — 8 queda
cómodamente por encima, así que **no hace falta tocar ninguna
configuración de Supabase** para que funcione. Si tu proyecto sí te deja
bajar el mínimo y prefieres un PIN más corto, puedes cambiar `pinLength`
en `lib/widgets/pin_pad.dart` (un solo lugar, se aplica a toda la app).

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
  PIN nuevo en cualquier momento, por ejemplo si lo olvidó. Se elige con el
  teclado numérico propio de la app (igual al de "Login rápido"), no con el
  teclado del dispositivo — así el popup siempre se ve completo y centrado,
  sin que el teclado lo empuje fuera de lugar.
- **Quitar**: le saca el acceso (como ya funcionaba antes).

Como administrador principal, en **Tiendas** también puedes **restablecer
la contraseña del administrador de cada tienda** (botón "Restablecer
contraseña del administrador" en la tarjeta de cada tienda) — útil si el
dueño de una tienda distinta a la tuya olvidó su contraseña. Solo funciona
para tiendas creadas después de correr `sql/schema.sql` con este cambio (o
para tiendas más antiguas, una vez que lo corras, se completa solo con el
correo del administrador que ya tenían guardado).

También puedes **ver y restablecer el PIN de cualquier empleado de
cualquier tienda** (no solo del administrador): botón **"Ver empleados"**
en la tarjeta de esa tienda — se abre la lista con un ícono de llave junto
a cada uno para restablecerle el PIN. No te deja aprobar ni quitar
empleados de una tienda que no es la tuya, eso sigue siendo solo del
dueño de esa tienda.

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

### Fotos automáticas para productos sin foto (opcional)
Los artículos que tienen código de barras pero no tienen foto pueden
completarse solos: una vez activada esta función, cada noche revisa una
tanda de esos productos, les busca una foto en internet (las mismas
fuentes que usa la app al escanear un código de barras) y la guarda ya
reducida y comprimida — pesa poco, pero se ve nítida — así no hay que
entrar producto por producto a agregarla a mano.

1. En tu proyecto de Supabase, ve a **Edge Functions** → **Create a new
   function**, ponle el nombre exacto **`fill-missing-photos`**, pega
   TODO el contenido de `supabase/functions/fill-missing-photos/index.ts`
   de este repositorio y dale **Deploy**.
2. Ya puedes usar el botón **"Buscar fotos faltantes ahora"** en
   Configuración para correrla cuando quieras (revisa hasta 15 productos
   de tu tienda por corrida, para no demorarse ni gastar de más en las
   APIs gratuitas que consulta — si tienes más de 15 pendientes, corre el
   botón de nuevo o espera a la siguiente noche).
3. Opcional pero recomendado — para que corra sola todas las noches: en
   Supabase ve a **Database → Cron Jobs → Create a new cron job**, tipo
   **HTTP Request**, con la URL de la función `fill-missing-photos`, el
   header `Authorization: Bearer <tu service_role key>`, y un horario
   nocturno (ej. `0 6 * * *`, que es 6:00 UTC — de madrugada en Chile).
   Corriendo así, revisa los productos de todas tus tiendas, no solo la
   tuya.

Mientras no actives esta función, el botón va a mostrar un mensaje de
error explicando que falta este paso — el resto de la app sigue
funcionando normal, y siempre puedes seguir agregando la foto a mano
desde el formulario de cada producto.

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

## APK aparte: "Info Admin"

Además del APK completo de POSible, hay un **segundo APK**, más chico, para
consultar desde el celular sin exponer todo el punto de venta: **Info
Admin**. Usa el mismo correo/contraseña que ya tienes (es la misma cuenta,
la misma base de datos), pero solo muestra 3 secciones elegidas con un menú
abajo:

- **Inventario**: la misma pantalla completa de movimientos de stock del
  panel — escanear, registrar entradas/salidas, todo igual que en POSible.
- **Reportes**: el total vendido **hoy**, hasta el momento en que tocas
  "Actualizar", más el desglose por **método de pago** (efectivo/tarjeta/
  otro) y por **categoría** — un vistazo rápido de cómo va el día. Con el
  ícono de arriba (📊 "Ver reporte completo") se abre el mismo reporte del
  panel web: rangos **Hoy / 7 días / Este mes / Este año** (o un rango
  personalizado), gráfico de ventas por día (o por mes en el rango
  anual, con el mes de mejores ventas y el promedio mensual), y el
  desglose completo por método de pago, productos más vendidos, categoría,
  empleado y modificador.
- **Lista de artículos**: la misma pantalla completa del catálogo — crear,
  editar, borrar, escanear, selección múltiple, exportar, todo igual que en
  POSible.

Para compilarlo: pestaña **Actions** → **"Build APK Info Admin"** → **Run
workflow**, igual que el APK normal. El artifact se llama **info-admin-apk**.
Como usa un identificador de app distinto (`...posible.infoadmin`), puedes
instalar los dos APK en el mismo celular sin que uno reemplace al otro.

## ⚠️ Si instalas un APK nuevo y no ves los cambios
Se corrigió un problema en los workflows de compilación (`build.yml` y
`build_info_admin.yml`): cada vez que se compilaba, Android firmaba el APK
con una clave distinta (porque la carpeta `android/` se genera de cero en
cada corrida y no había una clave de firma fija guardada). Cuando la clave
de firma cambia, Android puede rechazar en silencio la actualización sobre
la versión anterior en vez de avisar con un error claro — se queda con la
app vieja aunque la instalación "parezca" haber funcionado. Ya se corrigió
guardando la clave entre compilaciones, pero **la próxima vez que instales
un APK nuevo vas a tener que desinstalar primero la versión que ya
tienes** (una sola vez); de ahí en adelante las actualizaciones deberían
instalarse encima sin problema.

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
  buscador y, al elegir uno, queda agregado ahí mismo. Dentro de una
  pestaña, el buscador de arriba solo muestra lo que ya agregaste a mano
  mientras está vacío — pero en cuanto escribes algo, busca en todo tu
  catálogo (no solo en la pestaña), para poder vender cualquier producto
  sin tener que agregarlo antes a la pestaña.
- **Botones de venta rápida con nombre y precio propios**: al agregar un
  producto a una pestaña (desde "Agregar producto" en el mosaico o desde
  el ícono de engranaje de la pestaña), puedes ponerle un nombre y un
  precio propios al botón (ej. "Huevos 5x1000"), distintos del nombre y
  precio real del producto en el catálogo — igual que en Loyverse. Podés
  agregar el mismo producto varias veces con nombres/precios distintos.
  El botón sigue sumando stock/ventas al producto real de siempre; solo
  cambia lo que se ve y lo que se cobra en ese botón. Para editar el
  nombre/precio de un botón ya agregado, entra al ícono de engranaje de la
  pestaña y toca el lápiz junto a ese ítem. **Requiere volver a correr
  `sql/schema.sql`** (agrega las columnas `custom_name`/`custom_price` a
  `pos_page_items`).
- Puedes seguir prefiriendo la vista en lista clásica desde
  **Configuración → Vista en lista de artículos** (ahí las pestañas
  personalizadas solo se pueden editar desde el ícono de engranaje, no
  agregar con mantener presionado).
- **Ventas y caja**: apertura/cierre de caja (Turno), carrito, descuentos,
  IVA (la tasa que pongas en Configuración se descuenta del precio que ya
  cargaste — **no se suma aparte**, porque el precio de tus artículos ya lo
  incluye — y solo sirve para mostrar el desglose en la venta y el ticket),
  pago en efectivo/tarjeta/otro o **dividido entre varios**
  (ej. mitad efectivo, mitad tarjeta). Con "Efectivo" elegido (y sin
  dividir el pago), aparece "Recibe en efectivo" con montos rápidos
  (+$2.000, +$5.000, +$10.000, +$20.000 — se van sumando si tocas más de
  uno) y calcula el **vuelto** a entregar (o cuánto falta, en rojo, si el
  efectivo ingresado es menor al total). Es solo una ayuda para el
  cajero: no cambia lo que se registra en la venta, que siempre cobra el
  total exacto. También hay "tickets abiertos" (dejar una venta en
  espera con el botón de recibo junto al buscador, para atender a otro
  cliente y retomarla después desde el mismo ícono, incluyendo el cliente
  y descuento que tenías elegidos), "anular venta" (botón rojo arriba del
  carrito para descartar todo sin cobrar) y asignar la venta a un cliente
  (botón "Elegir" junto a "Sin cliente"). Si escaneas el código de barras
  de un producto en el buscador de Ventas y presionas Enter (o lo escaneas
  con la cámara), se agrega solo al carrito, sin tener que buscarlo ni
  tocarlo.
- **Se puede vender sin stock disponible**: un producto marcado "Agotado"
  (stock en 0 o negativo) se puede seguir tocando/escaneando para
  agregarlo al carrito igual que cualquier otro — la etiqueta "Agotado" es
  solo informativa. Al cobrar, si algún artículo del carrito queda con más
  cantidad de la que hay en stock, se pide confirmar antes ("¿Vender
  igual?"); si confirmas, el stock de ese producto queda en negativo.
- **Números del carrito más grandes**: la cantidad, el precio unitario y
  el subtotal de cada artículo, y el resumen Subtotal/IVA/Total de arriba
  del carrito, se ven en un tamaño de letra más grande — antes eran
  chicos y costaba leerlos de un vistazo. Además, el **Total** (al final
  del desglose de pago) ahora es el número principal: grande, centrado, y
  se achica solo si el monto tiene muchos dígitos para que nunca se corte
  en una pantalla angosta — Subtotal/Descuento/IVA quedan chicos debajo,
  como apoyo.
- **Carrito simplificado + ventana de Cobrar**: el carrito ahora solo
  muestra la lista de artículos agregados (con sus botones +/- y el botón
  Anular arriba). Elegir cliente, elegir descuento, forma de pago (con
  división de pago), efectivo recibido/vuelto y el desglose
  Subtotal/Descuento/IVA/Total se movieron a una ventana que se abre al
  presionar **Cobrar**, junto con el botón final para confirmar la venta.
  Cliente y descuento elegidos se mantienen igual que antes (por ejemplo,
  al retomar un ticket en espera). Al confirmar el cobro, esa misma
  ventana muestra "Venta registrada" con el total cobrado y un botón
  **Nueva venta** para volver a Ventas y empezar el siguiente cliente,
  en vez de cerrarse sola.
- **Total del carrito y stock editable desde Ventas**: debajo de "Carrito"
  (junto a la cantidad de artículos, en celular) ahora se ve el total de la
  venta en curso, en letra grande. En el popup de Cobrar, cuando pagas en
  efectivo y escribes el monto recibido, el Vuelto (o Falta) se muestra al
  lado del Total, en el mismo tamaño de letra. Además, cada mosaico de
  producto que controla inventario muestra ahora su stock disponible (junto
  al precio) — tócalo para editarlo ahí mismo desde un popup, sin salir de
  Ventas ni ir a Lista de artículos.
- **Pestañas rápidas más grandes y cuadradas**: "Más vendidos" y cada
  pestaña personalizada, en la barra de abajo del mosaico, ahora son
  botones cuadrados (esquinas apenas redondeadas) más grandes, en vez de
  las píldoras chicas de antes — más fáciles de tocar y de leer mientras
  vendes.
- **Se corrigió: el lector de código de barras USB dejaba de agregar solo
  después de usar Cobrar**: al abrir el popup de Cobrar (una ventana
  modal) se le quitaba el foco al buscador invisible que recibe lo que
  escanea el lector, y no se le devolvía al cerrarse — así que después de
  la primera venta, escanear ya no agregaba nada hasta tocar la pantalla a
  mano. Ahora el foco vuelve solo apenas se cierra el popup, se haya
  completado la venta o no. Además, se agregó un chequeo cada 400ms que
  recupera el foco del buscador solo si se pierde sin que nada más lo esté
  usando a propósito — así el lector USB no se puede quedar "roto" en
  silencio por algún otro caso que se nos haya escapado.
- **Se corrigió: había que tocar el buscador para que el lector USB
  empezara a funcionar**: el campo invisible que recibe el escaneo cuando
  el buscador está colapsado tenía tamaño 0x0 — en la app web, un tamaño
  cero puede impedir que ese campo realmente reciba el foco del teclado, y
  el lector solo empezaba a agregar solo después de tocar el buscador una
  vez (lo que sí crea un campo de tamaño normal). Ahora ese campo invisible
  usa un tamaño chico pero real (sigue sin verse, oculto con transparencia)
  para que el foco funcione desde que entras a Ventas, sin tocar nada.
- **El buscador se limpia solo al agregar un producto**: al tocar un
  artículo del mosaico (o de la lista, o escanearlo) para agregarlo al
  carrito, el buscador queda listo para el siguiente — antes había que
  borrar a mano lo que buscaste para encontrarlo antes de poder buscar el
  próximo.
- **Artículo no encontrado al escanear en Ventas**: si el código escaneado
  (o tecleado en el buscador) tiene forma de código de barras pero no
  coincide con ningún producto, ahora avisa "Artículo no encontrado" con un
  botón para agregarlo al toque — pide nombre y precio, guarda el código
  escaneado como su código de barras y lo agrega de inmediato al carrito,
  sin tener que ir a Lista de artículos ni escanear una segunda vez.
- **Teclado numérico propio en vez del teclado del dispositivo**: en Ventas,
  cualquier campo donde se escribe un número (precio de un artículo de
  precio variable, editar stock desde el mosaico, agregar un producto
  nuevo al escanear un código no encontrado, montos del popup de Cobrar —
  efectivo/tarjeta/otro y "Recibe en efectivo", abrir/cerrar caja, depósito
  o retiro de un turno, y el precio de un botón de venta rápida) ahora abre
  un teclado numérico propio de la app en vez del teclado del celular — el
  teclado del dispositivo podía tapar el resto del popup o de la pantalla;
  este teclado siempre queda visible completo, sin importar el tamaño de
  pantalla.
- **Barra de arriba en Ventas**: menú (celular) y buscador conviven en una
  sola línea, sobre el mismo fondo naranja (no hay un AppBar aparte para
  esta pantalla). El buscador queda escondido detrás de un ícono de lupa
  (toca para desplegarlo) para que la pantalla se vea limpia por defecto,
  y el ícono de menú (celular) siempre queda visible — incluso con el
  lector de código de barras USB activado (Configuración): el buscador ya
  no se fuerza a quedar desplegado por eso, así que nunca tapa el acceso a
  las demás secciones. Los demás accesos (escanear con cámara, tickets en
  espera, **agregar producto**) son íconos sueltos, todos a la vista.
- **Pestañas de venta rápida abajo, separadas del filtro de categoría**:
  la barra de pestañas (Más vendidos + tus pestañas personalizadas) vive
  al final de la pantalla, con ancho completo. Son **solo** para lo que
  agregues a mano — nunca se mezclan con las categorías reales del
  catálogo, para no confundir una cosa con la otra. Si quieres ver todos
  los productos de una categoría (sin haberlos agregado antes a una
  pestaña), usa el desplegable "Categoría" que está arriba del mosaico de
  productos — es un filtro aparte, no una pestaña.
- **Búsqueda sin distinguir tildes en toda la app**: buscar "cafe"
  encuentra "Café" y viceversa, en cualquier buscador (Ventas, Lista de
  artículos, pestañas personalizadas, Catálogo global, Clientes,
  Categorías/Descuentos/Modificadores, movimientos de inventario). Las
  búsquedas que consultan la base de datos directo (Lista de artículos,
  Catálogo global, Clientes) usan una columna calculada con la extensión
  de Postgres `unaccent` — **requiere volver a correr `sql/schema.sql`**
  (agrega `create extension unaccent` y las funciones
  `products_search_text`/`product_catalog_search_text`/`customers_search_text`).
- **Escanear con la cámara, mucho más confiable**: se actualizó el paquete
  que lee los códigos (`mobile_scanner`) de la versión 5 a la 7, que trae
  mejoras de fondo que antes no existían:
  - **En la web, usa la cámara nativa del navegador** (`BarcodeDetector`,
    disponible en Chrome/Edge 83+ y Safari 17+) en vez de una librería de
    terceros — no depende de ningún servidor externo, y lee códigos de
    barra mucho mejor (es el mismo motor de detección del sistema, no uno
    hecho en JavaScript). En navegadores sin esa API (Firefox, versiones
    viejas) cae automático a una librería de respaldo (`zxing-wasm`,
    cargada desde jsDelivr — ese caso puntual sí depende de esa red).
  - **Enfoque, exposición y balance de blancos automáticos** en la web
    cuando el navegador lo permite (antes la cámara arrancaba sin pedir
    ningún ajuste, a veces quedando desenfocada).
  - El escáner tiene un límite de espera: si la cámara no responde en 12
    segundos (cualquiera sea la causa), muestra un mensaje claro con botón
    "Reintentar" en vez de quedarse en pantalla negra para siempre.
  - Recuadro guía con borde rojo — acerca el código hasta que quede
    adentro — y ahora si funciona como filtro real (antes en la web era
    solo decorativo). Suena un beep al leer un código con éxito.
  - Solo reconoce los formatos que usa la tienda (EAN-13/EAN-8/UPC-A/
    UPC-E/Code128/Code39/ITF y QR) en vez de todos los que existen —
    menos formatos por probar en cada cuadro significa más intentos por
    segundo.
  - Si el dispositivo tiene linterna, aparece un ícono para prenderla/
    apagarla (solo en la app instalada — la web no deja controlar el
    flash).
  - Si aun así un código sigue sin leer bien por cámara, la alternativa
    más confiable para el mostrador es un lector de código de barras
    USB/Bluetooth físico (Configuración → "Uso un lector de código de
    barras USB"), que no depende de ninguna cámara.
- **Carrito plegable en pantallas angostas** (celular, tablet en vertical):
  el carrito se docka arriba, justo debajo del buscador, mostrando solo el
  total y los botones **Guardar**/**Cobrar** — toca la flechita para
  desplegar la lista de artículos, cliente/descuento y la forma de pago
  (ocupa casi toda la pantalla mientras está desplegado), y para plegarla
  de nuevo. Así el mosaico aprovecha casi toda la pantalla mientras
  vendes, en vez de perder espacio fijo aunque el carrito esté vacío o
  casi. En pantallas anchas (tablet horizontal, computador) el carrito
  sigue al lado derecho, siempre completo, sin plegar. Los mosaicos de
  producto también son más chicos que antes, para ver más de una vez sin
  desplazarte.
- **Lector de código de barras USB**: si usas uno (funciona como un
  teclado que escribe el código y presiona Enter), activa **Configuración
  → "Uso un lector de código de barras USB en Ventas"**. Con esto, hay un
  campo invisible que recupera el foco solo después de cada acción (agregar
  un producto, cerrar un cuadro de diálogo, cambiar de categoría, etc.), así
  el lector siempre tiene dónde escribir y agrega el producto al carrito
  solo, sin que el cajero tenga que tocar la pantalla ni abrir el buscador
  entre un escaneo y otro — y sin tapar el menú de navegación, que se
  mantiene visible todo el tiempo. Queda apagado por defecto porque en una
  pantalla táctil sin ese lector esto abriría el teclado en pantalla de
  más — solo actívalo si realmente usas un lector físico.
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
- **Inventario**: tiene dos pestañas arriba.
  - **Artículos**: la lista completa de productos con su stock actual,
    filtrable por categoría (dropdown) y con buscador. Toca cualquier
    artículo para registrarle una entrada o salida de stock ahí mismo — es
    el mismo popup de siempre (elegir "Entrada"/"Salida", cantidad y motivo
    opcional). Si el producto no controla inventario, se muestra "No
    controla stock" en vez de un número; si tiene el stock bajo el umbral
    configurado, el número aparece en naranja.
  - **Movimientos**: el historial de entradas/salidas registradas aparte de
    las ventas (ej. recibir mercadería de un proveedor, o descontar por
    pérdida o rotura), con quién, cuándo y por qué (motivo opcional), y con
    su propio buscador (por producto, motivo o quién lo registró). Al
    registrar un movimiento hay una tercera opción, **"Uso propio"**, para
    cuando el dueño toma mercadería para sí mismo (no es una venta ni una
    pérdida): baja el stock igual que una salida, y además guarda el costo
    de ese momento para sumarlo a un total — arriba de la pestaña
    Movimientos se ve **"Uso propio del dueño (total histórico)"** con la
    suma de todo lo que se ha llevado a ese precio de costo. El
    ícono de escanear junto a "Importar factura (foto)" busca el producto
    por su código y abre el mismo popup de entrada/salida; si el código no
    existe, te ofrece crear el producto ahí mismo. El botón **"Importar
    factura (foto)"** le toma una foto (o elige un archivo PDF) a una
    factura o boleta, lee el texto (OCR) y trata de reconocer artículos y
    cantidades — es aproximado (depende de qué tan clara sea la foto y el
    formato de la factura), así que siempre te deja revisar y corregir cada
    línea antes de confirmar: para cada una eliges si suma stock a un
    producto que ya existe o si crea uno nuevo (con precio \$0 — hay que
    ponerle el precio después en Lista de artículos). Usa una clave de
    prueba compartida por defecto (con límites); en Configuración puedes
    poner tu propia clave gratuita de [ocr.space](https://ocr.space/ocrapi)
    para que sea confiable.
  - **Se corrigió: un producto creado al escanear un código no encontrado
    (desde Inventario) podía no aparecer al buscarlo después**: si tenías
    algo escrito en el buscador o un filtro de categoría activo antes de
    escanear, ese filtro seguía puesto después de crear el producto y lo
    escondía de la lista aunque ya estuviera guardado. Ahora, apenas creas
    un producto así, se limpian el buscador y el filtro de categoría de la
    pestaña Artículos, para que se vea de inmediato.
  - **Se corrigió (más a fondo): productos recién agregados podían seguir
    sin aparecer en Inventario aunque ya estuvieran en Lista de
    artículos**: la carga de la pestaña Artículos/Movimientos no tenía
    manejo de errores ni límite de tiempo en dos de sus tres consultas, así
    que si una tardaba demasiado o fallaba, la pantalla se quedaba
    "cargando" para siempre sin avisar — lo que se veía igual que "el
    producto no está". Ahora esas consultas tienen un límite de tiempo, y
    si algo falla se muestra un error con botón "Reintentar" en vez de
    quedarse pegado en blanco.
  - **Se corrigió (causa raíz real): la lista de Inventario podía mostrar
    menos productos que Lista de artículos en tiendas con catálogos
    grandes**: Inventario pedía todo el catálogo en una sola consulta, y
    Supabase recorta en silencio cualquier consulta a un máximo de filas
    configurado en el proyecto (1000 por defecto) sin avisar que el
    resultado quedó incompleto — a diferencia de Lista de artículos, que ya
    pedía los productos por páginas y por eso siempre traía todo. Ahora
    Inventario también pide el catálogo por bloques internamente, así que
    trae el catálogo completo sin importar cuántos productos tenga la
    tienda.
- **Artículos** (en el APK y en el panel web): lista de productos,
  categorías, modificadores, descuentos, control de existencias, foto por
  producto (cámara o galería, comprimida automáticamente a un tamaño
  máximo de 1024px para que cargue rápido y pese lo menos posible), y
  búsqueda automática por código de barras
  al escanear o crear un producto — revisa, en orden, el catálogo global,
  Open Food Facts, Open Beauty Facts, Open Products Facts y UPCitemdb (las
  cuatro últimas gratis y sin configurar nada), y si ninguna encuentra
  foto, Google Custom Search como último recurso (si pusiste tu propia
  clave en Configuración). Al crear un producto también puedes buscarlo
  por nombre en el catálogo global (ícono de lupa junto a "Nombre") para
  reutilizar lo que ya cargó otra de tus tiendas — nunca copia el precio
  automáticamente, solo lo muestra como precio sugerido. Si el nombre
  está vacío cuando subes una foto, la app también intenta reconocer el
  texto de la foto (mismo OCR que "Importar factura" en Inventario) y
  sugiere como nombre la línea más legible que encuentra en el empaque —
  es solo una sugerencia editable, y si no encuentra nada legible no pasa
  nada. Si tienes
  modificadores activos (ej. "Extra queso"), al tocar un producto en
  Ventas te deja elegirlos antes de agregarlo al carrito, y quedan
  reflejados en el recibo. En Lista de artículos, el precio se ve más
  grande en cada fila para que sea fácil de leer de un vistazo; el filtro
  "Categoría" tiene una opción "Sin categoría" para encontrar los
  artículos que todavía no tienen una asignada; y tocando la categoría de
  cualquier artículo (ícono de lápiz al lado) puedes cambiarla ahí mismo,
  sin tener que abrir el producto.
- **Reportes**: ventas de hoy / 7 días / este mes / **este año** (o un rango
  personalizado), ticket promedio, ventas por método de pago, productos más
  vendidos. En el rango de hoy/7 días/mes el gráfico es por día; en el
  rango anual se agrupa por mes, con el mes de mejores ventas y el
  promedio mensual como dato adicional.
  - **Se corrigió: la pantalla podía quedar completamente en blanco (sin
    tarjetas, sin gráfico, sin ningún error) si alguna de las consultas
    fallaba o tardaba demasiado**: varias consultas secundarias (productos
    más vendidos, por categoría, por empleado, por modificador) no tenían
    límite de tiempo, y si la pantalla terminaba de cargar sin datos por
    cualquier motivo, no había ningún mensaje de reserva — se veía como si
    el reporte "no existiera". Ahora esas consultas también tienen límite
    de tiempo, y si por algún motivo no hay datos para mostrar, aparece un
    mensaje de error con botón "Reintentar" en vez de quedar en blanco.
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
  puedes además agregar, editar o borrar entradas a mano. El botón
  **"Buscar fotos por código de barras"** (ícono de lupa sobre una foto)
  revisa todas las entradas del catálogo que tienen código de barras pero
  no tienen foto todavía, y les busca la foto automáticamente (catálogo
  global, Open Food Facts, Open Beauty Facts, Open Products Facts,
  UPCitemdb y, si la configuraste, Google) — así no hace falta entrar
  entrada por entrada. Nunca toca el nombre ni la marca ya guardados, solo
  llena la foto si estaba vacía. Es de mejor esfuerzo: no todos los
  códigos de barras tienen foto disponible en esas bases de datos.
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
El **APK** (celular) tiene lo esencial para atender en el mostrador y
mantener el catálogo al día: Ventas, Recibos, Turno, Inventario, Clientes
(si tu tienda lo tiene activado), el menú **Artículos** completo (Lista de
artículos, Categorías, Modificadores, Descuentos), más una Configuración
reducida (impuestos, margen, apariencia, cámara, lector USB, bloqueo
automático y cerrar sesión). El **panel web** además tiene todo lo de
administración (back office) que no hace falta desde el mostrador:
Reportes, Empleados, Catálogo global, Tiendas, y en Configuración también
"Cambiar contraseña" y "Alertas de inventario bajo". Así el celular queda
simple y rápido para vender y mantener el catálogo, y la administración
más completa la haces desde la computadora (si un cajero necesita cambiar
su contraseña desde el celular, puede usar "¿Olvidaste tu contraseña?" en
la pantalla de inicio de sesión).

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

## Arreglos recientes: Reportes colgado, menú y carrito

- **Reportes se quedaba cargando para siempre**: a la tabla de ventas le
  faltaba un índice para buscar por tienda y fecha — con historial grande
  la consulta se volvía tan lenta que nunca terminaba. Se agregó el
  índice, un límite de 15 segundos por consulta (si algo tarda de más, se
  ve un error con botón "Reintentar" en vez de quedar colgado para
  siempre) y ese mismo mensaje de error+reintentar en Recibos, Clientes,
  Empleados, Reloj de entrada/salida, Catálogo global, Descuentos,
  Modificadores y Turno. **Hace falta volver a correr `sql/schema.sql`**
  en el editor SQL de Supabase para que se cree el índice nuevo (no borra
  nada).
- **Menú lateral no llegaba a "Configuración"**: se le agregó una barra de
  desplazamiento visible, por si antes se podía bajar con el mouse pero no
  se notaba.
- **El botón "-" en un producto por peso o precio variable borraba la
  línea del carrito sin avisar**: ahora pide confirmación antes de
  quitarla (los productos normales se quitan igual que siempre, sin
  preguntar).
- **Un producto de precio variable se sumaba a la misma línea del
  carrito**: al agregarlo una segunda vez con un precio distinto, se
  combinaba con la línea anterior y se perdía el precio nuevo (quedaba
  todo cobrado al primer precio). Ahora cada vez que agregas un producto
  de precio variable se crea una línea nueva en el carrito, con su propio
  precio — igual que ya pasaba con los productos por peso.

## Arreglos recientes: Reportes, Ventas, Lista de artículos y Categorías

- **Reportes seguía sin mostrar nada**, pese al arreglo anterior. No se
  encontró ningún error real al revisar el código de nuevo a fondo — así
  que, para no seguir adivinando a ciegas, ahora el mensaje de error
  muestra el texto exacto de lo que falló (antes decía siempre "No se
  pudieron cargar los reportes", sin más detalle). Si vuelve a pasar,
  copia y pégame ese mensaje completo — con eso sí voy a poder encontrar
  la causa real en vez de tantear. También se agregó un límite de tiempo
  extra de 15 segundos a la carga completa, además del que ya tenía cada
  consulta por separado.
- **Ventas (la pantalla principal) podía quedarse cargando para siempre
  sin avisar** si fallaba algo al traer el catálogo, las categorías o las
  pestañas personalizadas — no tenía ningún manejo de error. Ahora, si
  falla, se ve un mensaje de error con botón "Reintentar" en vez de la
  rueda de carga sin parar nunca.
- Mismo arreglo (mensaje de error + "Reintentar" en vez de quedar
  colgado o en blanco) en **Lista de artículos** y en **Categorías**, que
  tampoco lo tenían.
- No se tocó nada más de lo que ya funcionaba — no hizo falta ningún
  cambio en `sql/schema.sql` ni en ninguna Edge Function para este grupo
  de arreglos.

## Reportes: gráficos con librería de verdad (fl_chart)

Los gráficos de barras de Reportes (por día y por mes) se rehicieron con
`fl_chart`, una librería de gráficos gratuita y muy usada en Flutter, en
vez de las barras hechas a mano — ahora tienen grilla de fondo, se
animan al cambiar de rango, y al tocar una barra aparece el monto exacto
de ese día/mes. Además, "Por método de pago" y "Por categoría" ahora
también muestran un **gráfico de torta** con leyenda de colores, arriba
de la lista de siempre (la lista se mantiene igual, con los montos
exactos). No hace falta correr nada en Supabase para esto — es solo un
cambio visual dentro de la app.

## Reportes: corrección de zona horaria en "Hoy" / "7 días" / etc.

Los rangos de fecha de Reportes se calculaban en tu hora local (Chile),
pero se enviaban a Supabase sin avisarle la zona horaria — así que
Postgres los tomaba como si fueran UTC, y el límite de "medianoche de
hoy" en realidad quedaba varias horas antes (cerca de las 8-9pm de
ayer). Por eso podían aparecer ventas del turno de ayer dentro del
reporte de "Hoy" incluso sin haber abierto caja todavía. Ya está
corregido. No hace falta correr nada en Supabase para esto.

## Cinco mejoras nuevas: ofertas, gasto en mercadería, redondeo, orden A-Z y archivado

**Importante: esta vez sí hay que volver a correr `sql/schema.sql`** en el
editor SQL de Supabase (Paso 1 de este mismo documento) — agrega columnas
nuevas y una función que se ejecuta sola todos los días. No borra nada de
lo que ya tienes.

- **Oferta temporal por producto**: al crear o editar un artículo con
  precio normal (no aplica a precio variable ni por peso), puedes activar
  "Oferta temporal", poner un precio de oferta y elegir desde/hasta cuándo
  dura. Mientras esté vigente, ese es el precio que se cobra en Ventas
  (se muestra el precio normal tachado arriba del precio de oferta, tanto
  en Ventas como en Lista de artículos) — pasada la fecha, vuelve solo al
  precio normal, sin que tengas que acordarte de sacarla.
- **Cuánto gastas en mercadería**: cada vez que registras una entrada de
  stock (recibir mercadería, sea a mano desde Inventario o escaneando una
  factura), se guarda el costo de ese producto en ese momento. Reportes
  ahora tiene una tarjeta "Gastado en mercadería (entradas de stock)" que
  suma cantidad × costo de todas las entradas dentro del rango de fechas
  elegido (Hoy, 7 días, este mes, este año, o tu rango).
- **Calculadora de precios (costo + margen)**: el precio sugerido que
  calcula ahora redondea a la decena más cercana usando 6 como punto de
  corte en vez del 5 de siempre — si el último dígito es 6 o más sube a
  la decena de arriba, si es 5 o menos baja a la de abajo (ej. termina en
  5 → baja; termina en 6 → sube).
- **Listas de artículos siempre de la A a la Z**: se revisó Ventas, Lista
  de artículos y Catálogo global — ya estaban ordenados así casi en todos
  lados, salvo un caso en Ventas donde un producto recién creado (o
  encontrado al buscar) se agregaba al final de la lista en memoria en
  vez de en su lugar alfabético hasta la próxima vez que entraras a
  Ventas. Ya corregido. (Las pestañas personalizadas que tú armas a mano
  en Ventas, y "Más vendidos", mantienen su propio orden a propósito —
  ahí el orden significa algo, no es solo alfabético.)
- **Archivar artículos**: en Lista de artículos, cada producto tiene ahora
  un ícono de archivo — al archivarlo, deja de aparecer en Ventas y en
  esta misma lista (no se borra, ni afecta el Catálogo global). Hay una
  nueva sección **"Artículos archivados"** (ícono junto a "Exportar a
  CSV", o dentro de "Más acciones" en pantalla angosta) donde puedes
  verlos todos y desarchivarlos cuando quieras. Subir stock a un producto
  archivado (recibir mercadería) también lo desarchiva solo. Además, una
  vez al día la base de datos revisa sola si algún producto lleva 1 mes
  sin venderse (o 1 mes creado sin haberse vendido nunca) y lo archiva
  automáticamente, para que no acumules artículos viejos sin darte cuenta.
  - Este archivado automático diario necesita la extensión **pg_cron**
    activada en tu proyecto de Supabase. Si tu plan no la tiene activada
    por defecto, ve a **Database → Extensions** en el panel de Supabase y
    actívala buscando "pg_cron" — si no la activas, todo lo demás
    (archivar/desarchivar a mano, la sección de archivados, subir stock
    para desarchivar) funciona igual, solo no se archivará nada
    automáticamente por inactividad.

## 2026-09-01: vencimiento de stock, tickets en espera entre turnos, búsqueda en Más vendidos y más gráficos en Reportes

**Importante: esta vez también hay que volver a correr `sql/schema.sql`**
en el editor SQL de Supabase (Paso 1 de este documento) — agrega una
columna nueva. No borra nada de lo que ya tienes.

- **Fecha de vencimiento del stock**: al registrar una entrada de stock
  (recibir mercadería) desde Inventario → Movimientos de stock, ahora
  puedes poner una fecha de vencimiento opcional. Desde 7 días antes y
  hasta el mismo día del vencimiento, Lista de artículos y Ventas
  muestran un aviso ("Por vencer") y el precio de venta baja solo al
  precio de costo (tachado el precio normal arriba, igual que con una
  oferta temporal) — así el producto tiene más chance de venderse antes
  de vencer, sin que tengas que acordarte de rebajarlo a mano. Si pasa la
  fecha sin venderse, Lista de artículos lo marca como "Vencido" (el
  precio ya no baja solo, para que lo revises tú). Puedes quitar o
  cambiar la fecha en cualquier momento desde la misma pantalla de
  Movimientos de stock.
- **Los tickets en espera ya no se borran al cerrar el turno**: antes,
  un ticket dejado en espera quedaba inaccesible en la app apenas se
  cerraba la caja (seguía en la base de datos, pero ninguna pantalla lo
  volvía a mostrar). Ahora la lista de "Tickets en espera" muestra todos,
  sin importar en qué turno se dejaron, hasta que alguien los retome o
  los borre a mano — se agregó la fecha además de la hora en la lista
  para no confundirlos entre turnos distintos.
- **Buscar en "Más vendidos" ahora busca en todo el catálogo**: igual que
  ya pasaba en las pestañas personalizadas, si estás en la pestaña "Más
  vendidos" de Ventas y escribes algo en el buscador, ahora busca en
  todo el catálogo (no solo entre los productos más vendidos), para
  poder vender cualquier producto sin tener que cambiar de pestaña.
- **Más gráficos en Reportes**: se agregó una comparación "Hoy vs. ayer",
  y dos listas nuevas con la situación del inventario ahora mismo:
  "Productos sin stock" y "Productos con stock bajo" (estas dos no
  dependen del rango de fechas elegido arriba, siempre muestran el
  estado actual).

## Ahorro de ancho de banda: miniaturas de fotos + buscador de Ventas más liviano

Si Supabase te avisó que te estás acercando al límite de ancho de banda
mensual (5GB en el plan free), esto ayuda bastante: las fotos de producto
son, con diferencia, lo que más pesa de la app, y hasta ahora se mostraba
la foto completa (hasta 1024px) hasta en el ícono chico de una lista.

- **Miniaturas de fotos**: hay una Edge Function nueva, "generate-thumbnails"
  (activarla en Supabase → Edge Functions, igual que las demás — ver más
  abajo), que genera una versión chica (220px, liviana) de cada foto. Las
  fotos que subas de ahora en adelante generan su miniatura solas, sin que
  hagas nada. Para las que ya tenías antes de este cambio, ve a
  **Configuración → "Generar miniaturas de fotos existentes"** y toca el
  botón (si dice que quedan más pendientes, tócalo de nuevo hasta que
  diga que no queda ninguna). El mosaico de Ventas, Lista de artículos y
  los demás lugares donde se ve una foto chica ya usan la miniatura en vez
  de la foto completa — la foto completa se sigue guardando igual, por si
  la necesitas en el futuro.
  - **Cómo activar la función**: en tu proyecto de Supabase, ve a "Edge
    Functions", crea una función nueva llamada exactamente
    "generate-thumbnails", pega todo el contenido de
    `supabase/functions/generate-thumbnails/index.ts` y dale Deploy.
  - **También hay que volver a correr `sql/schema.sql`** en el editor SQL
    de Supabase — agrega la columna `thumbnail_url` a `products`. No borra
    nada existente.
- **El buscador de Ventas ya no manda una consulta por cada letra**: antes,
  escribir "coca cola" en el buscador de Ventas mandaba 9 consultas al
  servidor (una por letra); ahora espera un instante después de que dejas
  de escribir antes de sincronizar con el servidor — el filtro local (lo
  que ya ves mientras escribes) sigue siendo instantáneo, esto solo afecta
  a una sincronización de respaldo que corre por detrás.
- **El catálogo de productos ya no se vuelve a descargar completo cada vez
  que cambias de pestaña**: antes, Ventas y Movimientos de stock pedían
  el catálogo entero cada vez que se entraba a esas pantallas — cambiar
  de Ventas a Turno y volver, varias veces por turno, bajaba todo el
  catálogo de nuevo cada vez. Ahora se pide una sola vez por sesión y se
  comparte entre esas dos pantallas; **deslizar hacia abajo para
  refrescar** ("pull to refresh", el mismo gesto de siempre) sí vuelve a
  pedirlo completo — úsalo si sabes que otro dispositivo cambió algo y
  quieres verlo ya. Crear o editar un producto completo, ajustar stock, o
  importar una factura también actualizan el catálogo solos, sin que
  tengas que hacer nada.

## Seguridad: arreglo de un problema serio (cualquier empleado podía volverse administrador principal)

Una auditoría de seguridad encontró que la regla que protege la tabla de
empleados (`profiles`) en Supabase revisaba que la persona estuviera
aprobada, pero **no revisaba qué campos podía cambiar** — así que un
empleado cualquiera, aprobado, podía (llamando directo a la API de
Supabase, no desde la app) marcarse a sí mismo como "administrador
principal". Eso es grave porque el administrador principal puede
restablecer la contraseña de cualquier usuario de cualquier tienda desde
"Tiendas" — o sea, en el peor caso alguien podía terminar con acceso a
cuentas de otros negocios.

**Ya está arreglado**: se agregó una regla en la base de datos (un
"trigger") que bloquea cualquier intento de cambiar quién es
administrador principal o a qué tienda pertenece un perfil, a menos que
quien lo haga ya sea administrador principal. No afecta nada de lo que
ya usas — aprobar, quitar o crear empleados sigue funcionando exactamente
igual.

**Tienes que volver a correr `sql/schema.sql`** en el editor SQL de
Supabase para que quede aplicado (ya lo apliqué directamente en tu
proyecto real también, así que en principio ya está activo — correrlo de
nuevo no hace daño, es idempotente). No hace falta redeployar ninguna
Edge Function para esto.

## Seguridad: el aviso de inventario bajo ya no mezcla productos de otras tiendas

La función "notify-low-stock" (el aviso por correo cuando algo se queda con
poco stock) revisaba el inventario de **todas las tiendas juntas** en vez de
solo la tuya, y siempre mandaba el correo a la dirección configurada en la
primera tienda que se creó — sin importar cuál tienda lo disparara. Ya está
arreglado: cada tienda revisa y recibe solo lo suyo. De paso, si el nombre
de un producto tuviera caracteres raros de HTML, ya no quedan sin escapar
en el correo.

**No hace falta que hagas nada** — ya redesplegué la función en tu proyecto
real. Si la activaste con un cron diario (Database → Cron Jobs), sigue
funcionando igual, ahora revisando cada tienda con correo configurado por
separado.

## Seguridad: las fotos ya no se descargan de cualquier sitio, y las funciones ya no aceptan pedidos de cualquier página

Dos arreglos más de la misma auditoría de seguridad:

- **Miniaturas y búsqueda automática de fotos ("generate-thumbnails" y
  "fill-missing-photos")**: estas funciones descargan la foto de un
  producto para generarle una miniatura o guardarla ya reducida. El
  problema es que `image_url` (la dirección de la foto) se puede escribir
  llamando directo a la API de Supabase, sin pasar por la app, así que en
  teoría alguien podía poner ahí una dirección que no fuera una foto real
  y hacer que el servidor de Supabase le hiciera una petición a algún
  lugar interno. Ya está arreglado: ahora solo se descargan fotos de
  direcciones conocidas (tu propio almacenamiento de Supabase y las
  fuentes de fotos que ya usa la app — Open Food/Beauty/Products Facts).
  Fotos que vinieran de otras fuentes (por ejemplo, resultados de Google)
  simplemente no reciben miniatura automática — la foto completa se sigue
  viendo igual, esto no borra ni oculta nada.
- **Las 5 funciones (Edge Functions) ya no aceptan pedidos desde cualquier
  página de internet**: antes cualquier sitio web podía intentar
  pedirle algo a estas funciones usando el navegador de un usuario que
  tuviera la app abierta en otra pestaña (el riesgo real era bajo, porque
  de todas formas exigían una sesión válida, pero no era buena práctica
  dejarlo así). Ahora solo se aceptan pedidos que vengan de tu propia app
  web.

**No hace falta que hagas nada** — ya redesplegué "generate-thumbnails",
"fill-missing-photos", "manage-employee" y "notify-low-stock" en tu
proyecto real. ("resize-existing-photos" no está activa, así que solo se
actualizó el archivo en el repositorio por si alguna vez la vuelves a
desplegar). No hace falta volver a correr `sql/schema.sql` para esto.

## Nota: hoy todos los empleados aprobados tienen los mismos permisos dentro de su tienda

Otra observación de la auditoría: por ahora POSible no distingue entre
"dueño de la tienda" y "empleado normal" — cualquier perfil aprobado puede
crear o quitar otros empleados, restablecer contraseñas (PIN) dentro de su
tienda, y ver/cambiar las claves guardadas en Configuración (por ejemplo,
las de búsqueda de fotos por Google). Esto no es un error, es una
limitación conocida — permisos distintos por tipo de empleado queda como
mejora pendiente para más adelante.

## Limpieza: consultas más rápidas (índices) y con límite de tiempo consistente

Dos mejoras de rendimiento de la misma auditoría, sin cambiar nada de lo que ya ves en la app:

- **Índices nuevos en la base de datos**: además del que ya existía para
  Reportes, se agregaron índices por tienda a `customers`, `cash_sessions`,
  `cash_movements`, `discounts`, `modifiers`, `open_tickets`,
  `time_clock_entries`, `stock_movements`, `store_settings`, y a
  `sale_items` (por venta y por tienda). Sin esto, a medida que crece el
  historial de una tienda, esas consultas iban a ir cada vez más lentas.
- **Límite de tiempo consistente en las consultas**: la mayoría de las
  consultas a Supabase ya tenían un límite de 15 segundos para no quedarse
  "cargando" para siempre si la conexión falla — ahora lo tienen todas las
  demás pantallas también (caja, clientes, descuentos, modificadores,
  tickets en espera, fotos, pestañas de Ventas, catálogo global, empleados,
  recibos, ventas, configuración, tiendas y reloj de entrada/salida).

**Ya apliqué los índices directamente en tu proyecto real de Supabase.**
También tienes que volver a correr `sql/schema.sql` en el editor SQL de
Supabase para que quede igual en el archivo (no hace daño, es idempotente).
No hace falta redeployar ninguna Edge Function para esto.

## Arreglo urgente: Ventas no cargaba el catálogo ("Bad Request") con muchas ventas en el mes

Con más de 500 ventas en los últimos 30 días, la pantalla de Ventas dejó de
poder cargar (mostraba "No se pudo cargar el catálogo de Ventas:
PostgrestException... Bad Request"). La causa: para armar la pestaña "Más
vendidos" se pedía el detalle de TODAS esas ventas en una sola consulta,
metiendo los cientos de IDs en la dirección (URL) de la petición — con
suficientes ventas esa dirección se volvía demasiado larga y Supabase la
rechazaba. Pasaba también en Reportes (resumen, por categoría y por
modificador), aunque ahí no se había notado todavía.

**Ya está arreglado**: esas mismas consultas ahora se piden en tandas más
chicas en vez de todas de una vez, así que no importa cuántas ventas tenga
el mes. No hace falta que hagas nada — no es un cambio de base de datos, y
ya redesplegué la versión nueva (se actualiza sola en el panel web al
mergear este cambio).

## Nuevo: teclado propio de la app en el buscador de Ventas (para no depender del teclado de Android)

El buscador de Ventas ya no depende del teclado que trae el celular —
ahora, al tocarlo, aparece un teclado propio y simple (números y letras
minúsculas, sin tildes ni "ñ", que no hacen falta porque la búsqueda ya
las ignora) pegado abajo de la pantalla, en vez del de Android.

Un primer intento de este cambio (probado por el usuario) usaba una
configuración que además le pedía a Android que nunca abriera su teclado
en el campo invisible que mantiene listo el lector USB — pero eso rompía
el auto-agregado del lector mientras el buscador estaba colapsado (había
que tocar el buscador primero para que el escaneo volviera a agregar
productos solos). **Ya está corregido**: ese campo invisible volvió a su
configuración original (a veces puede hacer que Android intente abrir su
teclado solo, ya que no se puede evitar sin arriesgar el escaneo — pero
como el campo es invisible, en la práctica no debería notarse casi
nunca). El campo visible del buscador, en cambio, sigue mostrando el
teclado propio en vez del de Android al tocarlo (se le pide a Android que
esconda el suyo apenas se abre el propio).

**El lector de código de barras USB vuelve a funcionar exactamente
igual que siempre** — no se tocó nada de cómo recibe lo que escanea.

De paso, también se corrigió que escanear un código hacía que el mosaico
de productos se viera "buscando" de a poco (letra por letra del código)
antes de agregar el producto, lo que se sentía lento — ahora esa
actualización visual espera una fracción de segundo antes de recalcularse,
así que un escaneo completo la recalcula una sola vez en vez de una por
cada dígito. Buscar a mano no se nota distinto (la espera es demasiado
corta para notarla escribiendo).

No hace falta correr nada en Supabase ni en `sql/schema.sql` — es un
cambio solo de la app. Se aplica por ahora solo al buscador de Ventas (el
que más se usa con el lector); si te sirve, extiendo el mismo teclado a
los demás buscadores (Lista de artículos, Clientes, Catálogo global) y a
los campos numéricos que todavía abren el teclado de Android (precio,
costo, cantidad, etc. — para esos ya existe un teclado numérico propio en
Caja/Cobrar, falta usarlo en el resto de la app).

## Nuevo: el catálogo de Ventas queda guardado en el celular (funciona sin internet)

El catálogo de productos ya no vive solo en la memoria de la sesión — ahora
también queda guardado en el propio celular. La primera vez que entras a
Ventas, la app muestra de inmediato lo último que había guardado (aunque
todavía no haya internet) y, apenas la conexión esté disponible, lo
actualiza sola de fondo con lo que haya cambiado. Si justo no hay internet
en ese momento, la app sigue funcionando con el catálogo guardado en vez
de mostrar un error.

Es un cambio solo de la app (no hace falta correr nada en Supabase). Por
ahora cubre el catálogo de productos, que es lo que más se usa en Ventas —
si te sirve, hago lo mismo con categorías y clientes más adelante.

**Nota**: esto es el catálogo (leer productos), no vender sin internet —
crear una venta todavía necesita conexión, porque el número de recibo, el
turno de caja y el stock se validan en el servidor. Eso es un cambio más
grande y hay que decidir con cuidado qué pasa si dos celulares venden lo
mismo estando ambos sin conexión; queda pendiente si más adelante quieres
avanzar en esa dirección.

## Nuevo: pantalla para el cliente ("Info ScreenClone") — sin internet

Hay un APK nuevo, aparte: **Info ScreenClone**. Se instala en un segundo
celular o tablet (el que mira el cliente, en el mostrador) y muestra en
vivo lo que se va agregando al carrito en Ventas — artículo, cantidad,
precio y el total — sin tocar nada en ese segundo dispositivo.

**No usa internet ni Supabase**: los dos celulares se conectan directo
entre sí por la misma red WiFi de la tienda. El de la caja abre un
servidor chico (parte de la propia app) que avisa cada vez que el carrito
cambia; "Info ScreenClone" se conecta a la dirección de ese celular y va
mostrando los cambios al toque.

**Cómo activarlo:**
1. En el celular de la caja (la app normal, POSible): Configuración →
   activa "Activar pantalla para el cliente". Ahí aparece una dirección
   (algo como `192.168.1.5:8790`).
2. Instala el nuevo APK **Info ScreenClone** en el otro celular/tablet —
   tiene que estar conectado a la misma red WiFi que el de la caja (no
   hace falta que esa red tenga internet, solo que los dos estén en la
   misma).
3. Abre Info ScreenClone, toca la pantalla y escribe la dirección que
   viste en el paso 1. Se conecta solo, y si se corta (WiFi, o cierras la
   app de la caja) reintenta cada pocos segundos sin que tengas que hacer
   nada.

Queda apagado por defecto en Configuración (no vale la pena tener el
servidor prendido si no vas a usar la pantalla del cliente). No hace falta
correr nada en Supabase ni en `sql/schema.sql` — es un cambio solo de la
app, y solo del APK de Android (el panel web no lo muestra, ese modo no
existe ahí).
