-- POSible: esquema de base de datos para Supabase
-- Cómo usarlo: en tu proyecto de Supabase entra a "SQL Editor" -> "New query",
-- pega TODO este archivo y dale "Run". Se puede ejecutar varias veces sin problema.

create extension if not exists pgcrypto;

-- ============================================================
-- Multi-tienda: varias tiendas pueden compartir esta misma base de datos,
-- cada una viendo solo sus propios datos. "stores" guarda cada tienda y
-- qué funciones tiene activadas (las tiendas nuevas empiezan limitadas
-- hasta que el administrador principal les active más). Ver más abajo,
-- sección "MULTI-TIENDA", para el resto de las piezas (RLS, migración).
-- ============================================================
create table if not exists stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  store_code text unique,
  owner_id uuid references auth.users(id),
  owner_email text,
  feature_reports boolean not null default false,
  feature_customers boolean not null default false,
  feature_employees boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);
alter table categories add column if not exists store_id uuid references stores(id);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category_id uuid references categories(id) on delete set null,
  price numeric(12,2) not null default 0,
  cost numeric(12,2),
  sku text,
  barcode text,
  image_url text,
  stock_quantity numeric(12,2) not null default 0,
  track_stock boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table products add column if not exists image_url text;
-- Umbral de inventario bajo: si es null, ese producto no muestra alerta.
alter table products add column if not exists low_stock_threshold numeric(12,2);
alter table products add column if not exists store_id uuid references stores(id);

-- Tipo de precio: 'fixed' (normal), 'variable' (se pregunta el precio al
-- venderlo, ej. un servicio o un artículo sin precio fijo) o 'weight' (se
-- vende por peso: "price" es el precio por kilo, y se agrega al carrito
-- escaneando un código de balanza que trae el peso — ver "plu").
alter table products add column if not exists pricing_type text not null default 'fixed';
alter table products drop constraint if exists products_pricing_type_check;
alter table products add constraint products_pricing_type_check
  check (pricing_type in ('fixed', 'variable', 'weight'));
-- Código interno corto (ej. "00123") que identifica al producto dentro de
-- un código de barras de balanza (pricing_type = 'weight').
alter table products add column if not exists plu text;
-- Margen objetivo propio de este producto (%), para calcular el precio de
-- venta sugerido a partir del costo. Si es null, se usa el margen general
-- de "store_settings.default_margin_percent".
alter table products add column if not exists target_margin_percent numeric(5,2);
drop index if exists products_plu_store_idx;
create unique index products_plu_store_idx on products(store_id, plu) where plu is not null;

-- Catálogo global: UN SOLO catálogo compartido entre TODAS tus tiendas
-- (no un proyecto aparte). Se alimenta solo con lo que cada tienda agrega a
-- su propio inventario (con o sin código de barras), para sugerir nombre,
-- foto y precio (nunca copiado automáticamente) al crear un producto nuevo
-- en cualquier otra tienda.
create table if not exists product_catalog (
  barcode text primary key,
  name text not null,
  brand text,
  image_url text,
  source text not null default 'manual' check (source in ('manual', 'openfoodfacts', 'shared')),
  updated_at timestamptz not null default now()
);

-- Antes se identificaba por "barcode" (obligaba a tener código de barras
-- para poder aportar al catálogo). Ahora se identifica por "id", así
-- también entran productos sin código de barras, y guarda un precio
-- sugerido.
alter table product_catalog add column if not exists id uuid default gen_random_uuid();
update product_catalog set id = gen_random_uuid() where id is null;
alter table product_catalog alter column id set not null;
alter table product_catalog drop constraint if exists product_catalog_pkey;
alter table product_catalog add constraint product_catalog_pkey primary key (id);
alter table product_catalog alter column barcode drop not null;
alter table product_catalog drop constraint if exists product_catalog_barcode_key;
alter table product_catalog add constraint product_catalog_barcode_key unique (barcode);
alter table product_catalog add column if not exists suggested_price numeric(12,2);
alter table product_catalog drop constraint if exists product_catalog_source_check;
alter table product_catalog add constraint product_catalog_source_check
  check (source in ('manual', 'openfoodfacts', 'shared', 'store', 'store_bootstrap'));

-- Bucket de Storage para las fotos de productos (público para poder mostrarlas
-- en la app sin complicaciones; solo usuarios aprobados pueden subir).
insert into storage.buckets (id, name, public)
values ('product-photos', 'product-photos', true)
on conflict (id) do nothing;

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  loyalty_points integer not null default 0,
  total_spent numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);
alter table customers add column if not exists store_id uuid references stores(id);

create table if not exists cash_sessions (
  id uuid primary key default gen_random_uuid(),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  opening_amount numeric(12,2) not null default 0,
  closing_amount numeric(12,2),
  status text not null default 'open' check (status in ('open', 'closed')),
  notes text,
  user_id uuid references auth.users(id),
  user_email text
);
alter table cash_sessions add column if not exists user_email text;
alter table cash_sessions add column if not exists store_id uuid references stores(id);

-- Movimientos manuales de efectivo durante un turno (ej. depositar un
-- fondo extra en la caja, o sacar dinero para un pago/salida), para poder
-- calcular el "efectivo teórico en caja" al cerrar el turno.
create table if not exists cash_movements (
  id uuid primary key default gen_random_uuid(),
  cash_session_id uuid not null references cash_sessions(id) on delete cascade,
  type text not null check (type in ('deposit', 'withdrawal')),
  amount numeric(12,2) not null,
  note text,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users(id),
  user_email text
);
alter table cash_movements add column if not exists store_id uuid references stores(id);

create table if not exists discounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'percentage' check (type in ('percentage', 'fixed')),
  value numeric(12,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table discounts add column if not exists store_id uuid references stores(id);

-- Opciones para personalizar un producto al venderlo (ej. "Extra queso").
create table if not exists modifiers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price_adjustment numeric(12,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table modifiers add column if not exists store_id uuid references stores(id);

-- Configuración por tienda. Antes era una sola fila fija (id=1); ahora cada
-- tienda tiene la suya, identificada por "store_id" (la columna "id" queda
-- por compatibilidad, ya sin uso real).
create table if not exists store_settings (
  id integer primary key default 1 check (id = 1),
  tax_rate_percent numeric(5,2) not null default 0,
  updated_at timestamptz not null default now()
);
insert into store_settings (id) values (1) on conflict (id) do nothing;
-- Correo al que se envía la alerta de inventario bajo (ver Edge Function
-- "notify-low-stock"). Si es null, la alerta por correo está desactivada.
alter table store_settings add column if not exists low_stock_notify_email text;
-- Clave de OCR.space para leer facturas por foto (ver Inventario). Si es
-- null, se usa la clave de prueba pública "helloworld" (con límites
-- estrictos y compartida entre todo el mundo) — para uso real conviene
-- una propia, gratis en ocr.space.
alter table store_settings add column if not exists ocr_api_key text;
-- Margen general (%) que se usa para sugerir el precio de venta a partir
-- del costo cuando un producto no tiene su propio margen configurado.
alter table store_settings add column if not exists default_margin_percent numeric(5,2) not null default 30;
alter table store_settings add column if not exists store_id uuid references stores(id);
alter table store_settings drop constraint if exists store_settings_store_id_key;
alter table store_settings add constraint store_settings_store_id_key unique (store_id);

-- "id" ya no identifica nada (antes forzaba una sola fila con id=1); ahora
-- cada tienda tiene su propia fila identificada por "store_id", así que
-- "id" solo necesita ser único, no fijo en 1.
alter table store_settings drop constraint if exists store_settings_id_check;
create sequence if not exists store_settings_id_seq owned by store_settings.id;
select setval('store_settings_id_seq', greatest((select coalesce(max(id), 0) from store_settings), 1), true);
alter table store_settings alter column id set default nextval('store_settings_id_seq');

create sequence if not exists sales_receipt_seq start 1;

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  receipt_number bigint not null default nextval('sales_receipt_seq'),
  cash_session_id uuid references cash_sessions(id),
  customer_id uuid references customers(id),
  discount_id uuid references discounts(id),
  discount_amount numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  payment_method text not null default 'cash' check (payment_method in ('cash', 'card', 'other')),
  loyalty_points_earned integer not null default 0,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users(id)
);

-- Estas columnas pueden faltar si ya habías corrido este script antes de que
-- existiera Recibos/Descuentos/Impuestos: se agregan aquí de forma segura.
alter table sales add column if not exists receipt_number bigint;
alter table sales add column if not exists discount_id uuid references discounts(id);
alter table sales add column if not exists discount_amount numeric(12,2) not null default 0;
alter table sales add column if not exists tax_amount numeric(12,2) not null default 0;
update sales set receipt_number = nextval('sales_receipt_seq') where receipt_number is null;
alter table sales alter column receipt_number set not null;
alter table sales alter column receipt_number set default nextval('sales_receipt_seq');
create unique index if not exists sales_receipt_number_idx on sales(receipt_number);

-- Pago dividido: permite cobrar una venta repartida entre efectivo, tarjeta
-- y otro método (ej. mitad efectivo, mitad tarjeta). "payment_method" pasa
-- a valer 'mixed' cuando se usó más de un método.
alter table sales add column if not exists cash_amount numeric(12,2) not null default 0;
alter table sales add column if not exists card_amount numeric(12,2) not null default 0;
alter table sales add column if not exists other_amount numeric(12,2) not null default 0;
update sales set cash_amount = total
  where payment_method = 'cash' and cash_amount = 0 and card_amount = 0 and other_amount = 0;
update sales set card_amount = total
  where payment_method = 'card' and cash_amount = 0 and card_amount = 0 and other_amount = 0;
update sales set other_amount = total
  where payment_method = 'other' and cash_amount = 0 and card_amount = 0 and other_amount = 0;
alter table sales drop constraint if exists sales_payment_method_check;
alter table sales add constraint sales_payment_method_check
  check (payment_method in ('cash', 'card', 'other', 'mixed'));
alter table sales add column if not exists store_id uuid references stores(id);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  unit_price numeric(12,2) not null,
  quantity numeric(12,2) not null,
  subtotal numeric(12,2) not null,
  modifiers_summary text
);
alter table sale_items add column if not exists modifiers_summary text;
alter table sale_items add column if not exists store_id uuid references stores(id);

-- Tickets abiertos: una venta que el cajero deja "en espera" (ej. para
-- atender a otro cliente) y retoma más tarde. Se borra apenas se retoma o
-- se cobra; no es el registro final de la venta (eso sigue siendo "sales").
create table if not exists open_tickets (
  id uuid primary key default gen_random_uuid(),
  cash_session_id uuid references cash_sessions(id) on delete cascade,
  customer_id uuid references customers(id),
  discount_id uuid references discounts(id),
  label text,
  items_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users(id),
  user_email text
);
alter table open_tickets add column if not exists store_id uuid references stores(id);

-- Reloj de entrada/salida: cada empleado marca cuándo entra y cuándo sale.
-- "clock_out" queda en null mientras la persona sigue "marcada" (entrada
-- sin salida todavía).
create table if not exists time_clock_entries (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  user_id uuid references auth.users(id),
  user_email text,
  clock_in timestamptz not null default now(),
  clock_out timestamptz,
  created_at timestamptz not null default now()
);

-- Inventario: historial de entradas y salidas de stock (ej. recibir
-- mercadería, ajustar por pérdida/rotura), aparte de lo que ya descuenta
-- una venta. "product_name" queda guardado por si el producto se borra
-- después, para no perder el historial.
create table if not exists stock_movements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  product_id uuid references products(id) on delete set null,
  product_name text not null,
  type text not null check (type in ('in', 'out')),
  quantity numeric(12,2) not null,
  note text,
  created_at timestamptz not null default now(),
  user_id uuid references auth.users(id),
  user_email text
);
alter table stock_movements enable row level security;
drop policy if exists "solo mi tienda" on stock_movements;
create policy "solo mi tienda" on stock_movements for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());

-- Pestañas personalizadas en Ventas ("A1", "Verduras", "Promos", etc.): cada
-- tienda arma las suyas con los productos y/o categorías que quiera, para
-- tenerlos a mano sin buscar. "pos_page_items" guarda cada artículo o
-- categoría agregada a una pestaña (exactamente uno de los dos, nunca
-- ambos ni ninguno).
create table if not exists pos_pages (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  name text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table pos_pages enable row level security;
drop policy if exists "solo mi tienda" on pos_pages;
create policy "solo mi tienda" on pos_pages for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());

create table if not exists pos_page_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  page_id uuid not null references pos_pages(id) on delete cascade,
  product_id uuid references products(id) on delete cascade,
  category_id uuid references categories(id) on delete cascade,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint pos_page_items_producto_o_categoria check (
    (product_id is not null and category_id is null) or
    (product_id is null and category_id is not null)
  )
);
alter table pos_page_items enable row level security;
drop policy if exists "solo mi tienda" on pos_page_items;
create policy "solo mi tienda" on pos_page_items for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());

-- Funciones para ajustar stock y puntos de lealtad de forma atómica
-- (evita perder datos si dos ventas ocurren al mismo tiempo)
create or replace function adjust_product_stock(p_id uuid, p_delta numeric)
returns void
language sql
as $$
  update products set stock_quantity = stock_quantity + p_delta where id = p_id;
$$;

create or replace function adjust_customer_loyalty(p_id uuid, p_points_delta integer, p_spend_delta numeric)
returns void
language sql
as $$
  update customers
  set loyalty_points = loyalty_points + p_points_delta,
      total_spent = total_spent + p_spend_delta
  where id = p_id;
$$;

-- ============================================================
-- Empleados: cualquiera puede crear una cuenta desde la app, pero
-- no puede ver ni tocar ningún dato hasta que un usuario ya
-- aprobado lo apruebe desde la pantalla "Empleados".
-- ============================================================

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

-- Los usuarios que ya existían antes de este cambio (los que tú creaste a
-- mano en Supabase) quedan aprobados automáticamente.
insert into profiles (id, email, approved)
select id, email, true from auth.users
on conflict (id) do nothing;

-- Multi-tienda: cada empleado pertenece a una tienda, y el administrador
-- principal (tú) puede ver y gestionar todas las tiendas.
alter table profiles add column if not exists store_id uuid references stores(id);
alter table profiles add column if not exists is_super_admin boolean not null default false;
alter table stores add column if not exists owner_email text;

-- Genera un código corto para que un empleado nuevo pueda unirse a una
-- tienda existente ("Código de tienda" en la pantalla de registro).
create or replace function public.generate_store_code()
returns text
language sql
as $$
  select upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
$$;

-- Cuando alguien crea una cuenta nueva desde la app puede pasar dos cosas,
-- según lo que se mande en el registro (auth metadata):
--  - mode = 'new_store': crea una tienda nueva (con funciones limitadas) y
--    la persona queda como dueña, aprobada de inmediato.
--  - mode = 'join_store' + store_code: se une a una tienda existente, pero
--    SIN aprobar todavía (el dueño de esa tienda la tiene que aprobar).
--  - sin metadata (o código inválido): perfil sin tienda, sin aprobar (caso
--    de compatibilidad con cuentas creadas antes de este cambio).
-- Corre con privilegios elevados (security definer) porque el usuario
-- recién creado todavía no tiene permiso para escribir en "profiles" ni
-- "stores".
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_mode text := new.raw_user_meta_data ->> 'mode';
  v_store_name text := new.raw_user_meta_data ->> 'store_name';
  v_store_code text := new.raw_user_meta_data ->> 'store_code';
  v_store_id uuid;
  v_approved boolean := false;
begin
  if v_mode = 'new_store' then
    insert into public.stores (name, owner_id, owner_email, store_code, feature_reports, feature_customers, feature_employees)
    values (coalesce(nullif(trim(v_store_name), ''), 'Mi tienda'), new.id, new.email, public.generate_store_code(), false, false, false)
    returning id into v_store_id;
    v_approved := true;
  elsif v_mode = 'join_store' and v_store_code is not null then
    select id into v_store_id from public.stores where store_code = upper(trim(v_store_code)) and active = true;
    v_approved := false;
  end if;

  insert into public.profiles (id, email, approved, store_id)
  values (new.id, new.email, v_approved, v_store_id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Función que usan las demás tablas para saber si el usuario actual ya fue
-- aprobado. security definer para poder leer "profiles" sin depender de sus
-- propias políticas (evita recursión).
create or replace function public.is_approved()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and approved = true
  );
$$;

-- A qué tienda pertenece el usuario actual (o null si no tiene). Se usa
-- para que cada tienda solo vea y modifique sus propios datos.
create or replace function public.current_store_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select store_id from public.profiles where id = auth.uid();
$$;

-- true si el usuario actual es el administrador principal (ve y gestiona
-- todas las tiendas). Se marca a mano en la base de datos, nunca desde la
-- app, para que nadie pueda dárselo a sí mismo.
create or replace function public.is_super_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select is_super_admin from public.profiles where id = auth.uid()), false);
$$;

-- Los perfiles y la aprobación de empleados quedan limitados a la propia
-- tienda: un dueño de tienda no puede ver ni aprobar empleados de otra.
alter table profiles enable row level security;
drop policy if exists "ver mi perfil o si estoy aprobado" on profiles;
drop policy if exists "ver perfiles de mi tienda" on profiles;
create policy "ver perfiles de mi tienda" on profiles
  for select using (
    id = auth.uid()
    or (public.is_approved() and store_id is not distinct from public.current_store_id())
  );
drop policy if exists "aprobados pueden aprobar" on profiles;
drop policy if exists "aprobados pueden aprobar en mi tienda" on profiles;
create policy "aprobados pueden aprobar en mi tienda" on profiles
  for update
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
drop policy if exists "aprobados pueden quitar empleados" on profiles;
drop policy if exists "aprobados pueden quitar empleados de mi tienda" on profiles;
create policy "aprobados pueden quitar empleados de mi tienda" on profiles
  for delete using (public.is_approved() and store_id is not distinct from public.current_store_id());

-- La tabla "stores": cada tienda ve su propia fila; el administrador
-- principal las ve y las edita todas (para activarles funciones).
alter table stores enable row level security;
drop policy if exists "ver mi tienda o todas si soy admin" on stores;
create policy "ver mi tienda o todas si soy admin" on stores
  for select using (public.is_super_admin() or id = public.current_store_id());
drop policy if exists "super admin actualiza tiendas" on stores;
create policy "super admin actualiza tiendas" on stores
  for update using (public.is_super_admin()) with check (public.is_super_admin());

-- Seguridad: solo usuarios aprobados, y solo de su propia tienda, pueden
-- leer/escribir los datos del negocio. "product_catalog" y "categories"
-- son la excepción: se dejan compartidas entre todas las tiendas a
-- propósito (nada sensible, y evita que una tienda nueva empiece sin
-- categorías o sin poder aprovechar lo que ya cargó otra tienda).
alter table categories enable row level security;
alter table products enable row level security;
alter table customers enable row level security;
alter table cash_sessions enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table discounts enable row level security;
alter table modifiers enable row level security;
alter table store_settings enable row level security;
alter table product_catalog enable row level security;
alter table open_tickets enable row level security;
alter table cash_movements enable row level security;
alter table time_clock_entries enable row level security;

drop policy if exists "auth full access" on categories;
drop policy if exists "auth full access" on products;
drop policy if exists "auth full access" on customers;
drop policy if exists "auth full access" on cash_sessions;
drop policy if exists "auth full access" on sales;
drop policy if exists "auth full access" on sale_items;
drop policy if exists "auth full access" on discounts;
drop policy if exists "auth full access" on store_settings;
drop policy if exists "auth full access" on product_catalog;
drop policy if exists "solo aprobados" on categories;
drop policy if exists "solo aprobados" on products;
drop policy if exists "solo aprobados" on customers;
drop policy if exists "solo aprobados" on cash_sessions;
drop policy if exists "solo aprobados" on sales;
drop policy if exists "solo aprobados" on sale_items;
drop policy if exists "solo aprobados" on discounts;
drop policy if exists "solo aprobados" on modifiers;
drop policy if exists "solo aprobados" on store_settings;
drop policy if exists "solo aprobados" on product_catalog;
drop policy if exists "solo aprobados" on open_tickets;
drop policy if exists "solo aprobados" on cash_movements;
drop policy if exists "solo mi tienda" on categories;
drop policy if exists "solo aprobados" on categories;
drop policy if exists "solo mi tienda" on products;
drop policy if exists "solo mi tienda" on customers;
drop policy if exists "solo mi tienda" on cash_sessions;
drop policy if exists "solo mi tienda" on sales;
drop policy if exists "solo mi tienda" on sale_items;
drop policy if exists "solo mi tienda" on discounts;
drop policy if exists "solo mi tienda" on modifiers;
drop policy if exists "solo mi tienda" on store_settings;
drop policy if exists "solo mi tienda" on open_tickets;
drop policy if exists "solo mi tienda" on cash_movements;

-- Las categorías, a diferencia de products/customers/etc., se comparten
-- entre todas tus tiendas (igual que el catálogo global): una tienda nueva
-- no debería empezar sin ninguna categoría para organizar sus artículos.
create policy "solo aprobados" on categories for all using (public.is_approved()) with check (public.is_approved());
create policy "solo mi tienda" on products for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on customers for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on cash_sessions for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on sales for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on sale_items for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on discounts for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on modifiers for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on store_settings for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo aprobados" on product_catalog for all using (public.is_approved()) with check (public.is_approved());
create policy "solo mi tienda" on open_tickets for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
create policy "solo mi tienda" on cash_movements for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());
drop policy if exists "solo mi tienda" on time_clock_entries;
create policy "solo mi tienda" on time_clock_entries for all
  using (public.is_approved() and store_id is not distinct from public.current_store_id())
  with check (public.is_approved() and store_id is not distinct from public.current_store_id());

drop policy if exists "product photos public read" on storage.objects;
create policy "product photos public read" on storage.objects
  for select using (bucket_id = 'product-photos');

drop policy if exists "product photos auth upload" on storage.objects;
drop policy if exists "product photos aprobados upload" on storage.objects;
create policy "product photos aprobados upload" on storage.objects
  for insert with check (bucket_id = 'product-photos' and public.is_approved());

drop policy if exists "product photos auth update" on storage.objects;
drop policy if exists "product photos aprobados update" on storage.objects;
create policy "product photos aprobados update" on storage.objects
  for update using (bucket_id = 'product-photos' and public.is_approved());

-- ============================================================
-- MULTI-TIENDA: migración de los datos que ya tenías (de antes de que
-- existiera este sistema de varias tiendas) a una tienda "Tienda 1", con
-- todas las funciones activas. Solo se ejecuta la primera vez que corres
-- este script después de este cambio (si ya existe alguna tienda, no hace
-- nada) — es seguro volver a correr el archivo completo después.
-- ============================================================
do $$
declare
  v_store_id uuid;
begin
  if not exists (select 1 from stores) then
    insert into stores (name, store_code, feature_reports, feature_customers, feature_employees)
    values ('Tienda 1', public.generate_store_code(), true, true, true)
    returning id into v_store_id;

    update categories set store_id = v_store_id where store_id is null;
    update products set store_id = v_store_id where store_id is null;
    update customers set store_id = v_store_id where store_id is null;
    update cash_sessions set store_id = v_store_id where store_id is null;
    update cash_movements set store_id = v_store_id where store_id is null;
    update discounts set store_id = v_store_id where store_id is null;
    update modifiers set store_id = v_store_id where store_id is null;
    update store_settings set store_id = v_store_id where store_id is null;
    update sales set store_id = v_store_id where store_id is null;
    update sale_items set store_id = v_store_id where store_id is null;
    update open_tickets set store_id = v_store_id where store_id is null;
    update profiles set store_id = v_store_id where store_id is null;

    update stores set owner_id = (select id from profiles where email = 'ivan.rojas2@gmail.com' limit 1),
      owner_email = 'ivan.rojas2@gmail.com'
    where id = v_store_id;
  end if;
end $$;

-- El administrador principal de POSible: ve y gestiona todas las tiendas.
update profiles set is_super_admin = true, approved = true
where email = 'ivan.rojas2@gmail.com';

-- Completa "owner_email" en tiendas que ya tenían "owner_id" pero se
-- crearon antes de que existiera esta columna.
update stores set owner_email = (select email from auth.users where id = stores.owner_id)
where owner_email is null and owner_id is not null;

-- ============================================================
-- CATÁLOGO GLOBAL: copia, una sola vez, los productos activos de la tienda
-- principal (la del administrador principal) hacia el catálogo global, para
-- que las tiendas nuevas ya encuentren artículos al buscar. De ahí en
-- adelante el catálogo se sigue alimentando solo, con lo que cada tienda
-- va agregando (ver product_form_screen.dart). Solo corre la primera vez.
-- ============================================================
do $$
declare
  v_main_store_id uuid;
begin
  if not exists (select 1 from product_catalog where source = 'store_bootstrap') then
    select store_id into v_main_store_id from profiles where is_super_admin = true limit 1;
    if v_main_store_id is not null then
      insert into product_catalog (barcode, name, image_url, suggested_price, source)
      select p.barcode, p.name, p.image_url, p.price, 'store_bootstrap'
      from products p
      where p.store_id = v_main_store_id and p.active = true
      on conflict (barcode) do nothing;
    end if;
  end if;
end $$;
