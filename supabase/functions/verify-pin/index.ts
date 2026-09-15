// Edge Function: verify-pin
//
// Verifica el PIN de 4 dígitos de un usuario (administrador o cajero) y,
// si es correcto, le devuelve un "magic link" para iniciar sesión —
// así la app nunca necesita la contraseña real de la cuenta para el
// acceso rápido (que puede ser una contraseña fuerte de verdad, separada
// del PIN). Corre en el servidor, nunca en la app — es el único lugar
// donde se usa la llave "service_role".
//
// A diferencia de las demás funciones, esta se llama ANTES de iniciar
// sesión (todavía no hay ningún usuario autenticado) — por diseño, no
// exige un token de sesión de usuario. La app igual manda la llave
// pública (anon) como autorización, que ya alcanza para pasar el chequeo
// de la plataforma; no hace falta desactivar "Enforce JWT Verification"
// al crear esta función.
//
// Cómo activarla (una sola vez, sin instalar nada):
// 1. En tu proyecto de Supabase (el de tu negocio), ve a "Edge Functions".
// 2. Crea una función nueva llamada exactamente "verify-pin".
// 3. Pega TODO el contenido de este archivo en el editor y dale Deploy.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import bcrypt from "https://esm.sh/bcryptjs@2.4.3";

const ALLOWED_ORIGINS = ["https://p1np0n.github.io"];
function corsHeadersFor(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

// Un PIN de 4 dígitos son solo 10.000 combinaciones — sin un límite de
// intentos, alguien podría ir probando códigos al azar hasta acertar.
// Tras MAX_ATTEMPTS intentos fallidos seguidos, ese usuario queda
// bloqueado por LOCKOUT_MINUTES minutos (sigue pudiendo entrar con su
// correo y contraseña completos mientras tanto, si los tiene).
const MAX_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 15;

Deno.serve(async (req) => {
  const cors = corsHeadersFor(req);
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  // Mismo mensaje para "no existe", "no aprobado" o "PIN incorrecto" — así
  // no se puede usar esta función para averiguar qué correos existen.
  const genericError = "PIN incorrecto";

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const email = (body.email ?? "").toString().trim().toLowerCase();
    const pin = (body.pin ?? "").toString().trim();
    if (!email || !pin) return json({ error: "Falta el correo o el PIN" }, 400);

    const { data: profile } = await adminClient
      .from("profiles")
      .select("id, email, approved")
      .ilike("email", email)
      .maybeSingle();
    if (!profile || !profile.approved) return json({ error: genericError }, 401);

    const { data: lockout } = await adminClient
      .from("pin_lockouts")
      .select("failed_attempts, locked_until")
      .eq("profile_id", profile.id)
      .maybeSingle();
    if (lockout?.locked_until && new Date(lockout.locked_until).getTime() > Date.now()) {
      const minutesLeft = Math.ceil((new Date(lockout.locked_until).getTime() - Date.now()) / 60000);
      return json({ error: `Demasiados intentos. Espera ${minutesLeft} minuto(s) e intenta de nuevo.` }, 429);
    }

    const { data: pinRow } = await adminClient
      .from("profile_pins")
      .select("pin_hash")
      .eq("profile_id", profile.id)
      .maybeSingle();
    if (!pinRow) return json({ error: "no_pin_set" }, 404);

    const matches = await bcrypt.compare(pin, pinRow.pin_hash);
    if (!matches) {
      const attempts = (lockout?.failed_attempts ?? 0) + 1;
      const locked = attempts >= MAX_ATTEMPTS;
      await adminClient.from("pin_lockouts").upsert({
        profile_id: profile.id,
        failed_attempts: locked ? 0 : attempts,
        locked_until: locked ? new Date(Date.now() + LOCKOUT_MINUTES * 60000).toISOString() : null,
      });
      return json(
        { error: locked ? `Demasiados intentos. Espera ${LOCKOUT_MINUTES} minutos e intenta de nuevo.` : genericError },
        401,
      );
    }

    // PIN correcto: limpia el contador de intentos fallidos y genera el
    // enlace de acceso que la app canjea por una sesión real.
    await adminClient.from("pin_lockouts").delete().eq("profile_id", profile.id);

    const { data: linkData, error: linkError } = await adminClient.auth.admin.generateLink({
      type: "magiclink",
      email: profile.email,
    });
    if (linkError || !linkData) return json({ error: "No se pudo iniciar sesión. Intenta de nuevo." }, 500);

    return json({ ok: true, email: profile.email, tokenHash: linkData.properties.hashed_token });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
