// Edge Function: fill-missing-photos
//
// Una vez al día (de noche, para no competir con la app durante el
// horario de atención) revisa los productos que tienen código de barras
// pero no tienen foto, busca una imagen en internet (Open Food Facts /
// UPCitemdb — las mismas fuentes que se usan al escanear un código de
// barras dentro de la app) y la guarda ya reducida y comprimida (liviana,
// pero con calidad decente) en el bucket de fotos y en el catálogo
// global, para que quede lista sin tener que entrar producto por
// producto a mano. Corre en el servidor de Supabase, nunca en el celular
// ni en el navegador.
//
// Cómo activarla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase, ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "fill-missing-photos".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.
// 4. Ya puedes usar el botón "Buscar fotos faltantes ahora" en
//    Configuración para correrla cuando quieras.
// 5. (Opcional pero recomendado) Para que corra sola todas las noches:
//    en Supabase ve a "Database" → "Cron Jobs" → "Create a new cron
//    job", elige "HTTP Request", pon la URL de esta función, el header
//    "Authorization: Bearer <tu service_role key>" (la encuentras en
//    Project Settings → API), y un horario nocturno, ej. "0 6 * * *"
//    (6:00 UTC, de madrugada en Chile). Sin este paso, la función solo
//    corre cuando tocas el botón manual.
//
// Para usar pocos recursos y no pasarse de los límites gratuitos de las
// APIs públicas que consulta, cada corrida procesa solo una tanda chica
// (15 productos por defecto) — el resto queda para la próxima corrida
// (manual o la de la noche siguiente).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_DIMENSION = 640;
const JPEG_QUALITY = 78;
const DEFAULT_BATCH_LIMIT = 15;
const MAX_BATCH_LIMIT = 50;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface LookupResult {
  imageUrl: string;
  fromCatalog: boolean;
  name?: string;
  brand?: string;
}

async function fetchWithTimeout(url: string, ms: number): Promise<Response | null> {
  try {
    return await fetch(url, { signal: AbortSignal.timeout(ms) });
  } catch {
    return null;
  }
}

async function lookupOpenFoodFacts(barcode: string): Promise<LookupResult | null> {
  const res = await fetchWithTimeout(
    `https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=product_name,brands,image_url,status`,
    8000,
  );
  if (!res || res.status !== 200) return null;
  try {
    const data = await res.json();
    if (data.status !== 1) return null;
    const product = data.product;
    const imageUrl = product?.image_url as string | undefined;
    if (!imageUrl) return null;
    return { imageUrl, fromCatalog: false, name: product?.product_name, brand: product?.brands };
  } catch {
    return null;
  }
}

// Base de datos pública de productos en general — de mejor esfuerzo, igual
// que en la app: la cuenta gratuita tiene un límite diario de consultas, y
// si no encuentra nada simplemente se sigue con el siguiente producto.
async function lookupUpcItemDb(barcode: string): Promise<LookupResult | null> {
  const res = await fetchWithTimeout(`https://api.upcitemdb.com/prod/trial/lookup?upc=${barcode}`, 8000);
  if (!res || res.status !== 200) return null;
  try {
    const data = await res.json();
    const item = data?.items?.[0];
    const imageUrl = item?.images?.[0] as string | undefined;
    if (!imageUrl) return null;
    return { imageUrl, fromCatalog: false, name: item?.title, brand: item?.brand };
  } catch {
    return null;
  }
}

// Descarga la imagen encontrada, la reduce a un máximo de 640px de lado
// más largo y la comprime como JPEG de calidad 78 — queda liviana (unos
// pocos KB, no varios MB de la foto original) pero todavía nítida en la
// app.
async function downloadAndCompress(imageUrl: string): Promise<Uint8Array | null> {
  const res = await fetchWithTimeout(imageUrl, 10000);
  if (!res || !res.ok) return null;
  try {
    const bytes = new Uint8Array(await res.arrayBuffer());
    const image = await Image.decode(bytes);
    const needsResize = image.width > MAX_DIMENSION || image.height > MAX_DIMENSION;
    const resized = !needsResize
      ? image
      : image.width >= image.height
        ? image.resize(MAX_DIMENSION, Image.RESIZE_AUTO)
        : image.resize(Image.RESIZE_AUTO, MAX_DIMENSION);
    return await resized.encodeJPEG(JPEG_QUALITY);
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "No autorizado" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Una llamada programada (cron) se identifica porque usa el
    // service_role key directamente, en vez de la sesión de un usuario —
    // esa corre para TODAS las tiendas. Una llamada manual (botón en
    // Configuración) solo procesa la tienda del usuario que la tocó.
    const isSystemCall = authHeader === `Bearer ${serviceRoleKey}`;
    let storeId: string | null = null;

    if (!isSystemCall) {
      const callerClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userError } = await callerClient.auth.getUser();
      if (userError || !userData.user) return json({ error: "No autorizado" }, 401);

      const { data: profile } = await adminClient
        .from("profiles")
        .select("approved, store_id")
        .eq("id", userData.user.id)
        .maybeSingle();
      if (!profile?.approved) {
        return json({ error: "Solo usuarios aprobados pueden hacer esto" }, 403);
      }
      storeId = (profile.store_id as string | null) ?? null;
    }

    let limit = DEFAULT_BATCH_LIMIT;
    try {
      const body = await req.json();
      if (typeof body?.limit === "number" && body.limit > 0) {
        limit = Math.min(body.limit, MAX_BATCH_LIMIT);
      }
    } catch {
      // sin body (ej. la llamada del cron), se usa el límite por defecto
    }

    let query = adminClient
      .from("products")
      .select("id, barcode")
      .eq("active", true)
      .is("image_url", null)
      .not("barcode", "is", null)
      .order("created_at", { ascending: true })
      .limit(limit);
    if (storeId) query = query.eq("store_id", storeId);

    const { data: candidates, error: candidatesError } = await query;
    if (candidatesError) return json({ error: candidatesError.message }, 500);

    let updated = 0;
    let skipped = 0;
    let failed = 0;

    for (const product of candidates ?? []) {
      const barcode = product.barcode as string;
      try {
        let found: LookupResult | null = null;

        const { data: cached } = await adminClient
          .from("product_catalog")
          .select("image_url")
          .eq("barcode", barcode)
          .maybeSingle();
        if (cached?.image_url) {
          found = { imageUrl: cached.image_url as string, fromCatalog: true };
        } else {
          found = (await lookupOpenFoodFacts(barcode)) ?? (await lookupUpcItemDb(barcode));
        }

        if (!found) {
          skipped++;
          continue;
        }

        const compressed = await downloadAndCompress(found.imageUrl);
        if (!compressed) {
          failed++;
          continue;
        }

        const path = `auto/${barcode}.jpg`;
        const { error: uploadError } = await adminClient.storage
          .from("product-photos")
          .upload(path, compressed, { contentType: "image/jpeg", upsert: true });
        if (uploadError) {
          failed++;
          continue;
        }

        const { data: publicUrlData } = adminClient.storage.from("product-photos").getPublicUrl(path);
        const publicUrl = publicUrlData.publicUrl;

        const { error: updateError } = await adminClient
          .from("products")
          .update({ image_url: publicUrl })
          .eq("id", product.id);
        if (updateError) {
          failed++;
          continue;
        }

        if (!found.fromCatalog) {
          await adminClient.from("product_catalog").upsert(
            {
              barcode,
              name: found.name && found.name.trim() ? found.name.trim() : barcode,
              brand: found.brand ?? null,
              image_url: publicUrl,
              source: "openfoodfacts",
              updated_at: new Date().toISOString(),
            },
            { onConflict: "barcode" },
          );
        }

        updated++;
      } catch {
        failed++;
      }
    }

    return json({ ok: true, scanned: candidates?.length ?? 0, updated, skipped, failed });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
