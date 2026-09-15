// Edge Function: manage-employee
//
// Crea cajeros, les cambia el PIN y les activa/desactiva permisos extra —
// siempre a pedido de un administrador de tienda. Corre en el servidor de
// Supabase, nunca en la app — es el único lugar donde se usa la llave
// "service_role" (con privilegios de administrador), así la app nunca la
// necesita ni la expone.
//
// Cómo activarla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase (el de tu negocio), ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "manage-employee".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.
//
// Solo un usuario con role='admin' (según la tabla "profiles") puede
// llamar a esta función — un cajero, aunque esté aprobado, no puede crear
// otros cajeros ni tocar sus PIN o permisos.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import bcrypt from "https://esm.sh/bcryptjs@2.4.3";

// Solo se acepta CORS desde estos orígenes (tu app web) — antes cualquier
// página en internet podía pedirle esto al navegador de un usuario
// logueado. El riesgo real era bajo (igual exige un token de sesión
// válido), pero es buena práctica no dejarlo abierto a "*".
const ALLOWED_ORIGINS = ["https://p1np0n.github.io"];
function corsHeadersFor(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

// Permisos que un administrador le puede activar a un cajero. A propósito
// NO incluye nada que toque Configuración ni Empleados (crear/quitar
// gente, ver claves de API, cambiar la contraseña de otro, etc.) — eso
// queda siempre exclusivo del rol 'admin', nunca se le puede "activar" a
// un cajero.
const GRANTABLE_PERMISSIONS = ["manage_products", "view_reports", "manage_customers"];

function randomPassword(): string {
  // Contraseña real de la cuenta del cajero: nunca se le muestra a nadie
  // (el cajero solo usa su PIN) — solo tiene que ser lo bastante larga
  // para pasar cualquier política de contraseña de Supabase.
  return `${crypto.randomUUID()}${crypto.randomUUID()}`;
}

Deno.serve(async (req) => {
  const cors = corsHeadersFor(req);
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "No autorizado" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Cliente que respeta RLS, para saber quién llama y si es admin.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "No autorizado" }, 401);

    const { data: profile } = await callerClient
      .from("profiles")
      .select("approved, store_id, role, is_super_admin")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (!profile?.approved || profile.role !== "admin") {
      return json({ error: "Solo el administrador de la tienda puede gestionar empleados" }, 403);
    }

    const body = await req.json();
    const action = body.action;

    // Cliente con privilegios de administrador — solo se usa aquí, después
    // de confirmar que quien llama ya es admin.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    // Confirma que "userId" pertenece a la misma tienda que quien llama
    // (salvo el administrador principal, que puede gestionar cualquiera —
    // lo usa "Tiendas" para restablecer el PIN del dueño de otra tienda).
    async function sameStoreOrSuperAdmin(userId: string): Promise<boolean> {
      if (profile.is_super_admin) return true;
      const { data: target } = await adminClient
        .from("profiles")
        .select("store_id")
        .eq("id", userId)
        .maybeSingle();
      return !!target && target.store_id === profile.store_id;
    }

    if (action === "create") {
      const displayName = (body.display_name ?? "").trim();
      const pin = (body.pin ?? "").toString().trim();
      if (!displayName) return json({ error: "Falta el nombre del cajero" }, 400);
      if (!/^\d{4}$/.test(pin)) return json({ error: "El PIN debe tener 4 dígitos" }, 400);

      const email = ((body.email ?? "").trim() || `cajero-${crypto.randomUUID().slice(0, 8)}@posible.local`)
        .toLowerCase();

      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password: randomPassword(),
        email_confirm: true,
      });
      if (error) return json({ error: error.message }, 400);
      const newUserId = data.user!.id;

      // El cajero nuevo queda en la misma tienda que quien lo creó, con
      // rol 'cajero' y sin permisos extra hasta que el admin se los active.
      await adminClient.from("profiles").upsert({
        id: newUserId,
        email,
        display_name: displayName,
        approved: true,
        store_id: profile.store_id,
        role: "cajero",
        permissions: [],
      });

      const pinHash = await bcrypt.hash(pin, 10);
      await adminClient.from("profile_pins").upsert({ profile_id: newUserId, pin_hash: pinHash });

      return json({ ok: true });
    }

    if (action === "set_pin") {
      const userId = body.user_id;
      const pin = (body.pin ?? "").toString().trim();
      if (!userId) return json({ error: "Falta el usuario" }, 400);
      if (!/^\d{4}$/.test(pin)) return json({ error: "El PIN debe tener 4 dígitos" }, 400);
      if (!(await sameStoreOrSuperAdmin(userId))) {
        return json({ error: "No tienes permiso para cambiar el PIN de ese usuario" }, 403);
      }

      const pinHash = await bcrypt.hash(pin, 10);
      await adminClient.from("profile_pins").upsert({ profile_id: userId, pin_hash: pinHash });
      // Un PIN nuevo también desbloquea al usuario si estaba bloqueado por
      // intentos fallidos con el PIN anterior.
      await adminClient.from("pin_lockouts").delete().eq("profile_id", userId);
      return json({ ok: true });
    }

    if (action === "set_permissions") {
      const userId = body.user_id;
      const requested = Array.isArray(body.permissions) ? body.permissions : [];
      if (!userId) return json({ error: "Falta el usuario" }, 400);
      const permissions = requested.filter((p: unknown) =>
        typeof p === "string" && GRANTABLE_PERMISSIONS.includes(p)
      );
      if (!(await sameStoreOrSuperAdmin(userId))) {
        return json({ error: "No tienes permiso para cambiar los permisos de ese usuario" }, 403);
      }
      await adminClient.from("profiles").update({ permissions }).eq("id", userId);
      return json({ ok: true });
    }

    if (action === "set_password") {
      // Restablece la contraseña REAL de una cuenta (no el PIN) — para
      // cuando el administrador principal necesita ayudar al dueño de otra
      // tienda que perdió su contraseña y el correo de recuperación no le
      // llega. Exclusivo del administrador principal: ni siquiera el
      // administrador de una tienda puede resetear la contraseña de otra
      // cuenta (solo su propio PIN, con "set_pin").
      if (!profile.is_super_admin) {
        return json({ error: "Solo el administrador principal puede hacer esto" }, 403);
      }
      const userId = body.user_id;
      const password = body.password ?? "";
      if (!userId || !password) return json({ error: "Falta el usuario o la contraseña nueva" }, 400);
      const { error } = await adminClient.auth.admin.updateUserById(userId, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    if (action === "set_display_name") {
      const userId = body.user_id;
      const displayName = (body.display_name ?? "").trim();
      if (!userId || !displayName) return json({ error: "Falta el usuario o el nombre" }, 400);
      if (!(await sameStoreOrSuperAdmin(userId))) {
        return json({ error: "No tienes permiso para cambiar el nombre de ese usuario" }, 403);
      }
      await adminClient.from("profiles").update({ display_name: displayName }).eq("id", userId);
      return json({ ok: true });
    }

    return json({ error: "Acción desconocida" }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
