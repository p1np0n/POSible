# POS Retail — Cómo obtener el .apk sin instalar nada

Esta app compila sola en la nube usando GitHub Actions (gratis). Solo tienes
que subir estos archivos a GitHub una vez. No necesitas instalar Flutter,
Android Studio, ni saber programar.

## Paso 1: Crear cuenta en GitHub (si no tienes)
Entra a https://github.com y crea una cuenta gratis.

## Paso 2: Crear un repositorio nuevo
1. Arriba a la derecha, toca el "+" → "New repository"
2. Ponle un nombre, por ejemplo `pos-retail`
3. Déjalo en "Public" o "Private" (cualquiera funciona)
4. NO marques "Add a README" (para evitar conflictos)
5. Click "Create repository"

## Paso 3: Subir los archivos (arrastrando, sin usar terminal)
1. En la página del repo recién creado, busca el link que dice
   "uploading an existing file"
2. Descomprime el `pos_app.zip` que te di en tu computador
3. Arrastra TODO el contenido de la carpeta `pos_app` (incluyendo la carpeta
   oculta `.github`, el archivo `pubspec.yaml`, y la carpeta `lib`) a la zona
   de subida de GitHub
   - Importante: sube el CONTENIDO de la carpeta, no la carpeta `pos_app`
     completa como una sola cosa. Es decir, `lib/`, `.github/`, `pubspec.yaml`
     y `LEEME.md` deben quedar directamente en la raíz del repositorio.
   - Si tu explorador de archivos no muestra la carpeta `.github` (a veces
     las carpetas que empiezan con punto están ocultas), actívala:
     - Windows: en el Explorador, vista → "Elementos ocultos"
     - Mac: Cmd+Shift+. en Finder
4. Abajo, click "Commit changes"

## Paso 4: Ver cómo compila sola
1. Arriba en el repo, click en la pestaña "Actions"
2. Vas a ver "Build APK" corriendo (ícono amarillo = en progreso,
   verde = listo, rojo = falló)
3. Espera 3-5 minutos

## Paso 5: Descargar el .apk
1. Click en el workflow que terminó en verde
2. Abajo, en la sección "Artifacts", vas a ver "pos-retail-apk"
3. Click ahí para descargarlo (viene como .zip, adentro está el .apk)
4. Copia el .apk a tu celular Android e instálalo (puede pedirte permitir
   "instalar apps de orígenes desconocidos" — es normal, es tu propia app)

## Si el workflow sale en rojo (falló)
1. Click en el workflow fallido → click en el paso que tiene la X roja
2. Copia el texto del error y pégamelo en el chat — lo reviso contigo

## Cada vez que quieras una nueva versión
Cuando yo te pase archivos nuevos o corregidos, solo repites el Paso 3
(subir/reemplazar archivos) y GitHub compila automáticamente de nuevo.

## Próximos pasos posibles (dime cuál te sirve y lo agregamos)
- Impresión de boleta/ticket por Bluetooth (impresora térmica portátil)
- Categorías de productos
- Reporte semanal/mensual, no solo diario
- Respaldo/exportar ventas a un archivo (por si cambias de teléfono)
- Código de barras (usando la cámara para buscar productos)
