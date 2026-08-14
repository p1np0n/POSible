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
-- Notas de seguridad: cualquiera puede LEER, AGREGAR, EDITAR y BORRAR
-- cualquier producto de este catálogo (incluso uno que cargó otra tienda),
-- sin necesidad de iniciar sesión — así se eligió a propósito, para que el
-- catálogo compartido sea fácil de mantener entre todos los negocios que
-- usan POSible. La contraparte es que, como no hay cuentas de usuario en
-- este proyecto, cualquiera con la app también podría borrar o arruinar
-- productos de otra tienda (por error o a propósito). Si en el futuro
-- quieres protegerlo, tendría que agregarse algún tipo de moderación o
-- cuenta de "colaborador".

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

drop policy if exists "editar productos" on shared_products;
create policy "editar productos" on shared_products for update using (true) with check (true);

drop policy if exists "borrar productos" on shared_products;
create policy "borrar productos" on shared_products for delete using (true);
