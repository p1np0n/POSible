-- POSible: esquema de base de datos para Supabase
-- Cómo usarlo: en tu proyecto de Supabase entra a "SQL Editor" -> "New query",
-- pega TODO este archivo y dale "Run". Se puede ejecutar varias veces sin problema.

create extension if not exists pgcrypto;

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

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

-- Catálogo propio: productos ya buscados (por internet o ingresados a mano),
-- para no tener que volver a buscarlos la próxima vez que agregues el mismo
-- código de barras. Es una tabla aparte de "products" (que es tu inventario
-- para vender).
create table if not exists product_catalog (
  barcode text primary key,
  name text not null,
  brand text,
  image_url text,
  source text not null default 'manual' check (source in ('manual', 'openfoodfacts')),
  updated_at timestamptz not null default now()
);

-- Bucket de Storage para las fotos de productos (público para poder mostrarlas
-- en la app sin complicaciones; solo usuarios logueados pueden subir).
insert into storage.buckets (id, name, public)
values ('product-photos', 'product-photos', true)
on conflict (id) do nothing;

drop policy if exists "product photos public read" on storage.objects;
create policy "product photos public read" on storage.objects
  for select using (bucket_id = 'product-photos');

drop policy if exists "product photos auth upload" on storage.objects;
create policy "product photos auth upload" on storage.objects
  for insert with check (bucket_id = 'product-photos' and auth.role() = 'authenticated');

drop policy if exists "product photos auth update" on storage.objects;
create policy "product photos auth update" on storage.objects
  for update using (bucket_id = 'product-photos' and auth.role() = 'authenticated');

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  loyalty_points integer not null default 0,
  total_spent numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists cash_sessions (
  id uuid primary key default gen_random_uuid(),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  opening_amount numeric(12,2) not null default 0,
  closing_amount numeric(12,2),
  status text not null default 'open' check (status in ('open', 'closed')),
  notes text,
  user_id uuid references auth.users(id)
);

create table if not exists discounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null default 'percentage' check (type in ('percentage', 'fixed')),
  value numeric(12,2) not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists store_settings (
  id integer primary key default 1 check (id = 1),
  tax_rate_percent numeric(5,2) not null default 0,
  updated_at timestamptz not null default now()
);
insert into store_settings (id) values (1) on conflict (id) do nothing;

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

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  unit_price numeric(12,2) not null,
  quantity numeric(12,2) not null,
  subtotal numeric(12,2) not null
);

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

-- Seguridad: solo usuarios que iniciaron sesión (los que tú creas) pueden
-- leer/escribir datos. Ver LEEME.md: además debes desactivar el registro
-- público de cuentas nuevas en Supabase para que nadie más pueda entrar.
alter table categories enable row level security;
alter table products enable row level security;
alter table customers enable row level security;
alter table cash_sessions enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table discounts enable row level security;
alter table store_settings enable row level security;
alter table product_catalog enable row level security;

drop policy if exists "auth full access" on categories;
drop policy if exists "auth full access" on products;
drop policy if exists "auth full access" on customers;
drop policy if exists "auth full access" on cash_sessions;
drop policy if exists "auth full access" on sales;
drop policy if exists "auth full access" on sale_items;
drop policy if exists "auth full access" on discounts;
drop policy if exists "auth full access" on store_settings;
drop policy if exists "auth full access" on product_catalog;

create policy "auth full access" on categories for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on products for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on customers for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on cash_sessions for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on sales for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on sale_items for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on discounts for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on store_settings for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "auth full access" on product_catalog for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
