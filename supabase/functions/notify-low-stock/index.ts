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
// Solo un usuario ya aprobado puede llamarla manualmente desde la app; una
// llamada programada (cron) se identifica porque usa el service_role key
// directamente, en vez de la sesión de un usuario.

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

    const isSystemCall = authHeader === `Bearer ${serviceRoleKey}`;
    if (!isSystemCall) {
      const callerClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userError } = await callerClient.auth.getUser();
      if (userError || !userData.user) return json({ error: "No autorizado" }, 401);

      const { data: profile } = await callerClient
        .from("profiles")
        .select("approved")
        .eq("id", userData.user.id)
        .maybeSingle();
      if (!profile?.approved) {
        return json({ error: "Solo usuarios aprobados pueden hacer esto" }, 403);
      }
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: settings } = await adminClient
      .from("store_settings")
      .select("low_stock_notify_email")
      .eq("id", 1)
      .maybeSingle();
    const notifyEmail = settings?.low_stock_notify_email as string | null | undefined;

    const { data: products, error: productsError } = await adminClient
      .from("products")
      .select("name, stock_quantity, low_stock_threshold")
      .eq("active", true)
      .eq("track_stock", true)
      .not("low_stock_threshold", "is", null);
    if (productsError) return json({ error: productsError.message }, 500);

    const lowStock = (products ?? []).filter(
      (p: { stock_quantity: number; low_stock_threshold: number }) =>
        p.stock_quantity <= p.low_stock_threshold,
    );

    if (lowStock.length === 0) {
      return json({ ok: true, count: 0, sent: false });
    }

    if (!notifyEmail) {
      return json({ ok: true, count: lowStock.length, sent: false });
    }

    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (!resendApiKey) {
      return json({ error: "Falta configurar el secreto RESEND_API_KEY en la función" }, 400);
    }

    const rows = lowStock
      .map(
        (p: { name: string; stock_quantity: number; low_stock_threshold: number }) =>
          `<li>${p.name} — stock: ${p.stock_quantity} (umbral: ${p.low_stock_threshold})</li>`,
      )
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
      return json({ ok: true, count: lowStock.length, sent: false, error: detail }, 200);
    }

    return json({ ok: true, count: lowStock.length, sent: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
