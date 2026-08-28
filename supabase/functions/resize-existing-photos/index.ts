// Edge Function: resize-existing-photos
//
// Tarea de UNA SOLA VEZ (no permanente, no tiene botón en la app): recorre
// todas las fotos que ya están subidas en el bucket "product-photos" y las
// redimensiona/comprime a como quedan las fotos nuevas desde la app (máximo
// 1024px de lado más largo, JPEG calidad 80) — así las fotos viejas, más
// pesadas, quedan igual de livianas que las que se suben de ahora en
// adelante. No cambia ninguna URL (se sobrescribe cada archivo en el mismo
// lugar), así que no hace falta tocar la base de datos.
//
// Cómo correrla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase, ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "resize-existing-photos".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.
// 4. Ve a Project Settings → API y copia tu "service_role key" (la secreta,
//    no la "anon key").
// 5. En la pestaña de la función, usa "Invoke" (o un curl) con el header
//    "Authorization: Bearer <tu service_role key>" — sin nada más en el
//    cuerpo, un límite de 300 fotos por corrida alcanza para la mayoría de
//    los catálogos. Si la respuesta dice "hasMore": true, hay más fotos de
//    las que entraron en una corrida — invócala de nuevo (procesa las
//    fotos que falten, no repite las que ya redujo).
// 6. Cuando la respuesta diga "hasMore": false, ya terminó — puedes borrar
//    esta función de Supabase si quieres, no hace falta dejarla activa (a
//    diferencia de "fill-missing-photos", esta no es para correr seguido).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const BUCKET = "product-photos";
const MAX_DIMENSION = 1024;
const JPEG_QUALITY = 80;
// Si ya está dentro del tamaño de lado y pesa menos que esto, no vale la
// pena volver a comprimirla — ya está liviana.
const ALREADY_LIGHT_BYTES = 300_000;
const DEFAULT_BATCH_LIMIT = 300;
const MAX_BATCH_LIMIT = 1000;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface StorageFile {
  path: string;
  size: number;
}

// Recorre el bucket entero (incluye subcarpetas como "products/" y
// "auto/"), juntando todos los archivos con su ruta completa.
async function listAllFiles(
  client: ReturnType<typeof createClient>,
  prefix = "",
): Promise<StorageFile[]> {
  const files: StorageFile[] = [];
  const pageSize = 100;
  let offset = 0;
  while (true) {
    const { data, error } = await client.storage.from(BUCKET).list(prefix, {
      limit: pageSize,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new Error(error.message);
    if (!data || data.length === 0) break;
    for (const entry of data) {
      const fullPath = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.id === null) {
        // Es una "carpeta" (prefijo), no un archivo — se baja un nivel.
        const nested = await listAllFiles(client, fullPath);
        files.push(...nested);
      } else {
        files.push({ path: fullPath, size: (entry.metadata?.size as number | undefined) ?? 0 });
      }
    }
    if (data.length < pageSize) break;
    offset += pageSize;
  }
  return files;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization");
    if (authHeader !== `Bearer ${serviceRoleKey}`) {
      return json({ error: "Esta tarea solo se puede invocar con la service_role key" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    let limit = DEFAULT_BATCH_LIMIT;
    try {
      const body = await req.json();
      if (typeof body?.limit === "number" && body.limit > 0) {
        limit = Math.min(body.limit, MAX_BATCH_LIMIT);
      }
    } catch {
      // sin body — se usa el límite por defecto
    }

    const allFiles = await listAllFiles(adminClient);
    const toProcess = allFiles.slice(0, limit);

    let resized = 0;
    let alreadyLight = 0;
    let failed = 0;

    for (const file of toProcess) {
      try {
        const { data: blob, error: downloadError } = await adminClient.storage
          .from(BUCKET)
          .download(file.path);
        if (downloadError || !blob) {
          failed++;
          continue;
        }
        const bytes = new Uint8Array(await blob.arrayBuffer());
        const image = await Image.decode(bytes);
        const needsResize = image.width > MAX_DIMENSION || image.height > MAX_DIMENSION;
        const needsRecompress = bytes.byteLength > ALREADY_LIGHT_BYTES;
        if (!needsResize && !needsRecompress) {
          alreadyLight++;
          continue;
        }
        const resizedImage = !needsResize
          ? image
          : image.width >= image.height
            ? image.resize(MAX_DIMENSION, Image.RESIZE_AUTO)
            : image.resize(Image.RESIZE_AUTO, MAX_DIMENSION);
        const compressed = await resizedImage.encodeJPEG(JPEG_QUALITY);

        const { error: uploadError } = await adminClient.storage.from(BUCKET).upload(file.path, compressed, {
          contentType: "image/jpeg",
          upsert: true,
        });
        if (uploadError) {
          failed++;
          continue;
        }
        resized++;
      } catch {
        failed++;
      }
    }

    return json({
      ok: true,
      totalFound: allFiles.length,
      processed: toProcess.length,
      resized,
      alreadyLight,
      failed,
      hasMore: allFiles.length > toProcess.length,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
