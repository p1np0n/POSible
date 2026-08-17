// Edge Function: manage-employee
//
// Crea empleados y restablece PIN (contraseña) desde el panel web de
// POSible. Corre en el servidor de Supabase, nunca en la app — es el
// único lugar donde se usa la llave "service_role" (con privilegios de
// administrador), así la app nunca la necesita ni la expone.
//
// Cómo activarla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase (el de tu negocio), ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "manage-employee".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.
//
// Solo un usuario ya aprobado (según la tabla "profiles") puede llamar a
// esta función — cualquier otro intento se rechaza.

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

    // Cliente que respeta RLS, para saber quién llama y si está aprobado.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "No autorizado" }, 401);

    const { data: profile } = await callerClient
      .from("profiles")
      .select("approved, store_id, is_super_admin")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (!profile?.approved) {
      return json({ error: "Solo usuarios aprobados pueden gestionar empleados" }, 403);
    }

    const body = await req.json();
    const action = body.action;

    // Cliente con privilegios de administrador — solo se usa aquí, después
    // de confirmar que quien llama ya está aprobado.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    if (action === "create") {
      const email = (body.email ?? "").trim();
      const password = body.password ?? "";
      if (!email || !password) return json({ error: "Falta correo o PIN" }, 400);

      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });
      if (error) return json({ error: error.message }, 400);

      // El empleado nuevo queda en la misma tienda que quien lo creó.
      await adminClient
        .from("profiles")
        .upsert({ id: data.user!.id, email, approved: true, store_id: profile.store_id });
      return json({ ok: true });
    }

    if (action === "reset_password") {
      const userId = body.user_id;
      const password = body.password ?? "";
      if (!userId || !password) return json({ error: "Falta el usuario o el PIN nuevo" }, 400);

      // Solo el administrador principal puede restablecer la contraseña de
      // alguien de OTRA tienda (por ejemplo, la del dueño de esa tienda,
      // desde la pantalla "Tiendas"). Cualquier otro usuario aprobado solo
      // puede restablecer contraseñas dentro de su propia tienda.
      if (!profile.is_super_admin) {
        const { data: targetProfile } = await adminClient
          .from("profiles")
          .select("store_id")
          .eq("id", userId)
          .maybeSingle();
        if (!targetProfile || targetProfile.store_id !== profile.store_id) {
          return json({ error: "No tienes permiso para restablecer la contraseña de ese usuario" }, 403);
        }
      }

      const { error } = await adminClient.auth.admin.updateUserById(userId, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Acción desconocida" }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
