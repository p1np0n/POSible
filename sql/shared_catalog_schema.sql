-- POSible: catálogo de productos COMPARTIDO entre todos los negocios que
-- usan POSible.
--
-- IMPORTANTE: este script NO va en el mismo proyecto de Supabase de tu
-- negocio. Va en un proyecto de Supabase APARTE, nuevo, dedicado solo a
-- este catálogo público. Así, si algún día muchas tiendas usan POSible,
-- todas se benefician de los productos que los demás ya buscaron o
-- cargaron.
--
-- Cómo usarlo:
-- 1. Crea un proyecto nuevo en https://supabase.com (distinto al de tu
--    negocio), por ejemplo "posible-catalogo-compartido".
-- 2. En SQL Editor, pega TODO este archivo y dale Run.
-- 3. Copia el Project URL y la llave "anon public"/"publishable" de ESTE
--    proyecto y pégalas en lib/config/shared_catalog_config.dart.
--
-- Notas de seguridad: cualquiera puede LEER este catálogo (no hace falta
-- iniciar sesión) y cualquiera puede AGREGAR productos nuevos. Nadie puede
-- editar ni borrar un producto que ya existe (para que no se pueda dañar
-- información ya cargada) — eso solo se puede hacer entrando directamente
-- al panel de Supabase de este proyecto.

create extension if not exists pgcrypto;

create table if not exists shared_products (
  barcode text primary key,
  name text not null,
  brand text,
  image_url text,
  contributed_at timestamptz not null default now()
);

alter table shared_products enable row level security;

drop policy if exists "lectura publica" on shared_products;
create policy "lectura publica" on shared_products for select using (true);

drop policy if exists "agregar productos nuevos" on shared_products;
create policy "agregar productos nuevos" on shared_products for insert with check (true);
