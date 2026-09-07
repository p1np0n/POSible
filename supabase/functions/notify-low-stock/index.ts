// Edge Function: notify-low-stock
//
// Revisa los productos con inventario bajo (según el umbral que le pusiste
// a cada uno en Lista de artículos) y, si hay alguno, envía un correo de
// aviso usando Resend. Corre en el servidor de Supabase, nunca en la app.
//
// Cómo activarla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase (el de tu negocio), ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "notify-low-stock".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.
// 4. En "Manage secrets" (o Project Settings → Edge Functions → Secrets)
//    agrega el secreto RESEND_API_KEY con tu clave de https://resend.com.
// 5. En Configuración (panel web) pon el correo donde quieres recibir la
//    alerta, y guarda.
// 6. (Opcional pero recomendado) Para que se revise solo, todos los días:
//    en Supabase ve a "Database" → "Cron Jobs" → "Create a new cron job",
//    elige "HTTP Request", pon la URL de esta función, el header
//    "Authorization: Bearer <tu service_role key>", y el horario que
//    prefieras (ej. una vez al día).
//
// Solo un usuario ya aprobado puede llamarla manualmente desde la app, y
// solo revisa los productos de SU PROPIA tienda; una llamada programada
// (cron) se identifica porque usa el service_role key directamente, en vez
// de la sesión de un usuario, y en ese caso revisa TODAS las tiendas que
// tengan un correo de aviso configurado, mandando un correo separado por
// tienda (nunca mezclando productos de una tienda en el aviso de otra).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// El nombre del producto lo escribe cualquier empleado aprobado, así que no
// hay que confiar en que no tenga caracteres de HTML antes de meterlo en el
// correo (evita que un nombre como "<img src=x onerror=...>" quede
// incrustado tal cual).
function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

interface LowStockProduct {
  name: string;
  stock_quantity: number;
  low_stock_threshold: number;
}

async function getLowStockProducts(
  adminClient: ReturnType<typeof createClient>,
  storeId: string,
): Promise<LowStockProduct[]> {
  const { data: products, error: productsError } = await adminClient
    .from("products")
    .select("name, stock_quantity, low_stock_threshold")
    .eq("store_id", storeId)
    .eq("active", true)
    .eq("track_stock", true)
    .not("low_stock_threshold", "is", null);
  if (productsError) throw new Error(productsError.message);
  return ((products ?? []) as LowStockProduct[]).filter((p) => p.stock_quantity <= p.low_stock_threshold);
}

async function sendLowStockEmail(
  notifyEmail: string,
  resendApiKey: string,
  lowStock: LowStockProduct[],
): Promise<{ sent: boolean; error?: string }> {
  const rows = lowStock
    .map((p) => `<li>${escapeHtml(p.name)} — stock: ${p.stock_quantity} (umbral: ${p.low_stock_threshold})</li>`)
    .join("");

  const emailRes = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "POSible <onboarding@resend.dev>",
      to: [notifyEmail],
      subject: `POSible: ${lowStock.length} producto(s) con inventario bajo`,
      html: `<p>Estos productos tienen inventario bajo:</p><ul>${rows}</ul>`,
    }),
  });

  if (!emailRes.ok) {
    const detail = await emailRes.text();
    return { sent: false, error: detail };
  }
  return { sent: true };
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
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const isSystemCall = authHeader === `Bearer ${serviceRoleKey}`;

    if (isSystemCall) {
      // Una corrida programada revisa TODAS las tiendas con correo de
      // aviso configurado, una por una — nunca mezcla productos de una
      // tienda en el correo de otra.
      const { data: allSettings, error: settingsError } = await adminClient
        .from("store_settings")
        .select("store_id, low_stock_notify_email")
        .not("low_stock_notify_email", "is", null)
        .not("store_id", "is", null);
      if (settingsError) return json({ error: settingsError.message }, 500);

      let totalCount = 0;
      let sentCount = 0;
      for (const s of allSettings ?? []) {
        const storeId = s.store_id as string;
        const notifyEmail = s.low_stock_notify_email as string;
        const lowStock = await getLowStockProducts(adminClient, storeId);
        totalCount += lowStock.length;
        if (lowStock.length === 0 || !resendApiKey) continue;
        const result = await sendLowStockEmail(notifyEmail, resendApiKey, lowStock);
        if (result.sent) sentCount++;
      }
      return json({ ok: true, stores: (allSettings ?? []).length, count: totalCount, sent: sentCount });
    }

    // Llamada manual desde la app: solo la tienda de quien la toca. Mismo
    // orden y códigos de respuesta que antes, solo que ahora acotado a
    // "storeId" en vez de mirar el catálogo entero.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "No autorizado" }, 401);

    const { data: profile } = await callerClient
      .from("profiles")
      .select("approved, store_id")
      .eq("id", userData.user.id)
      .maybeSingle();
    if (!profile?.approved) {
      return json({ error: "Solo usuarios aprobados pueden hacer esto" }, 403);
    }
    const storeId = profile.store_id as string | null;
    if (!storeId) {
      return json({ error: "Tu perfil no tiene una tienda asignada" }, 400);
    }

    const { data: settings } = await adminClient
      .from("store_settings")
      .select("low_stock_notify_email")
      .eq("store_id", storeId)
      .maybeSingle();
    const notifyEmail = settings?.low_stock_notify_email as string | null | undefined;

    const lowStock = await getLowStockProducts(adminClient, storeId);

    if (lowStock.length === 0) {
      return json({ ok: true, count: 0, sent: false });
    }
    if (!notifyEmail) {
      return json({ ok: true, count: lowStock.length, sent: false });
    }
    if (!resendApiKey) {
      return json({ error: "Falta configurar el secreto RESEND_API_KEY en la función" }, 400);
    }

    const result = await sendLowStockEmail(notifyEmail, resendApiKey, lowStock);
    if (!result.sent) {
      return json({ ok: true, count: lowStock.length, sent: false, error: result.error }, 200);
    }
    return json({ ok: true, count: lowStock.length, sent: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
