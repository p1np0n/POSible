// Edge Function: generate-thumbnails
//
// Genera una versión chica (máximo 220px de lado, JPEG liviano) de la foto
// de cada producto, y la guarda en products.thumbnail_url. El mosaico de
// Ventas, Lista de artículos y los avatares usan esa miniatura en vez de
// la foto completa (hasta 1024px) — bajan mucho menos peso cada vez que se
// pinta un ícono chico, lo que ahorra ancho de banda de Supabase con cada
// turno y con cada tienda nueva. Corre en el servidor, nunca en el celular
// ni en el navegador.
//
// Dos modos, según el cuerpo de la petición:
// - Sin "productId": modo backfill — busca productos con foto pero sin
//   miniatura todavía (una tanda por corrida, "limit" productos) y se la
//   genera. Pensado para correr una vez (o varias, hasta que "hasMore" dé
//   false) sobre el catálogo que ya tenías antes de este cambio.
// - Con "productId": genera (o regenera) la miniatura de ese único
//   producto ahora mismo, sin importar si ya tenía una — la llama la app
//   automáticamente justo después de subir una foto nueva.
//
// Cómo activarla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase, ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "generate-thumbnails".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.
// 4. Ya puedes usar el botón "Generar miniaturas de fotos existentes" en
//    Configuración para rellenar las miniaturas de tu catálogo actual
//    (tócalo varias veces si dice que quedan más pendientes). Las fotos
//    nuevas que subas desde la app de ahora en adelante generan su
//    miniatura solas, sin tocar nada.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const BUCKET = "product-photos";
const MAX_DIMENSION = 220;
const JPEG_QUALITY = 72;
const DEFAULT_BATCH_LIMIT = 200;
const MAX_BATCH_LIMIT = 500;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface ProductRow {
  id: string;
  image_url: string;
}

async function makeThumbnail(
  adminClient: ReturnType<typeof createClient>,
  product: ProductRow,
): Promise<string | null> {
  const response = await fetch(product.image_url);
  if (!response.ok) return null;
  const bytes = new Uint8Array(await response.arrayBuffer());
  const image = await Image.decode(bytes);
  const resized = image.width >= image.height
    ? image.resize(MAX_DIMENSION, Image.RESIZE_AUTO)
    : image.resize(Image.RESIZE_AUTO, MAX_DIMENSION);
  const compressed = await resized.encodeJPEG(JPEG_QUALITY);

  const path = `thumbnails/${product.id}.jpg`;
  const { error: uploadError } = await adminClient.storage.from(BUCKET).upload(path, compressed, {
    contentType: "image/jpeg",
    upsert: true,
  });
  if (uploadError) throw new Error(uploadError.message);

  const { data } = adminClient.storage.from(BUCKET).getPublicUrl(path);
  return data.publicUrl;
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
    let productId: string | null = null;
    try {
      const body = await req.json();
      if (typeof body?.limit === "number" && body.limit > 0) {
        limit = Math.min(body.limit, MAX_BATCH_LIMIT);
      }
      if (typeof body?.productId === "string" && body.productId.trim() !== "") {
        productId = body.productId.trim();
      }
    } catch {
      // sin body — modo backfill con el límite por defecto
    }

    let products: ProductRow[];
    if (productId !== null) {
      const { data, error } = await adminClient
        .from("products")
        .select("id, image_url")
        .eq("id", productId)
        .not("image_url", "is", null)
        .limit(1);
      if (error) throw new Error(error.message);
      products = (data ?? []) as ProductRow[];
    } else {
      const { data, error } = await adminClient
        .from("products")
        .select("id, image_url")
        .not("image_url", "is", null)
        .is("thumbnail_url", null)
        .limit(limit);
      if (error) throw new Error(error.message);
      products = (data ?? []) as ProductRow[];
    }

    let updated = 0;
    let failed = 0;
    for (const product of products) {
      try {
        const thumbnailUrl = await makeThumbnail(adminClient, product);
        if (thumbnailUrl === null) {
          failed++;
          continue;
        }
        const { error: updateError } = await adminClient
          .from("products")
          .update({ thumbnail_url: thumbnailUrl })
          .eq("id", product.id);
        if (updateError) throw new Error(updateError.message);
        updated++;
      } catch {
        failed++;
      }
    }

    const hasMore = productId === null && products.length >= limit;
    return json({ ok: true, processed: products.length, updated, failed, hasMore });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
