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

### Muy importante — seguridad
Por defecto, Supabase permite que cualquiera con tu link de proyecto se
registre como usuario nuevo. Para evitarlo:
1. Ve a **Authentication** → **Sign In / Providers** → **Email**.
2. Apaga la opción **"Allow new users to sign up"** (permitir registro).
Así solo pueden entrar los usuarios que tú creas manualmente en el Paso 3.
También te recomiendo mantener este repositorio de GitHub como **Privado**
(Settings → General → Danger Zone → Change visibility).

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
  impuestos, pago en efectivo, tarjeta u otro método.
- **Recibos**: historial de ventas agrupado por día, con número de recibo,
  buscador y detalle de cada venta.
- **Inventario (Artículos)**: productos, categorías, descuentos, control de
  existencias (el stock baja solo con cada venta).
- **Reportes**: ventas de hoy / 7 días / este mes, ticket promedio, ventas
  por método de pago, productos más vendidos.
- **Clientes y lealtad**: ficha de cliente, historial de gasto y puntos
  acumulados por compra (1 punto por cada unidad de moneda gastada).
- **Configuración**: tasa de impuesto y cierre de sesión.
- **Menú lateral** (como Loyverse) para navegar entre todas las secciones.
- **Panel web**: la misma app corriendo en el navegador, publicada en
  GitHub Pages.

## Próximas mejoras posibles (dime cuáles te sirven y las agregamos)
- Modificadores de productos (personalizar una venta, ej. tamaño/extras)
- Escanear código de barras con la cámara
- Modo oscuro
- Vista en lista de productos (además de la cuadrícula)
- Impresión de recibo por Bluetooth (impresora térmica portátil)
- Pantalla secundaria para clientes
- Múltiples usuarios/empleados con permisos distintos
- Múltiples sucursales
- Canje de puntos de lealtad (no solo acumularlos)
- Gráficos en los reportes
- Modo sin internet con sincronización automática al recuperar señal

## Cada vez que quieras una nueva versión
Cuando yo te agregue o corrija algo y lo suba a este repositorio, solo
repites el Paso 4 (Actions compila sola) y el Paso 5 (descargar el nuevo
.apk).
