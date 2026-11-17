-- KNR: ejecutar en Supabase SQL Editor como propietario del proyecto.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('Relojes','Gafas','Gorras','Perfumería','Accesorios')),
  style text not null default 'urban' check (style in ('urban','luxury')),
  price integer not null check (price >= 0),
  old_price integer check (old_price is null or old_price >= 0),
  discount integer not null default 0 check (discount between 0 and 90),
  tag text not null default 'NUEVO',
  description text not null default '',
  specs jsonb not null default '[]'::jsonb,
  image_urls jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products enable row level security;

drop policy if exists "Public can view active KNR products" on public.products;
create policy "Public can view active KNR products"
on public.products for select to anon, authenticated
using (active = true or (auth.uid() is not null and exists (
  select 1 from public.admin_users where user_id = auth.uid()
)));

drop policy if exists "KNR admins can manage products" on public.products;
create policy "KNR admins can manage products"
on public.products for all to authenticated
using (exists (select 1 from public.admin_users where user_id = auth.uid()))
with check (exists (select 1 from public.admin_users where user_id = auth.uid()));

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
-- No se crea una política pública de lectura/escritura para admin_users.
-- El propietario agrega administradores desde SQL Editor:
-- insert into public.admin_users(user_id)
-- select id from auth.users where email = 'TU_CORREO_ADMIN';

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-media','product-media',true,10485760,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do nothing;

drop policy if exists "Public can view KNR product media" on storage.objects;
create policy "Public can view KNR product media" on storage.objects
for select to anon, authenticated using (bucket_id = 'product-media');

drop policy if exists "KNR admins can upload product media" on storage.objects;
create policy "KNR admins can upload product media" on storage.objects
for insert to authenticated with check (
  bucket_id = 'product-media' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  )
);
drop policy if exists "KNR admins can update product media" on storage.objects;
create policy "KNR admins can update product media" on storage.objects
for update to authenticated using (
  bucket_id = 'product-media' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  )
);
drop policy if exists "KNR admins can delete product media" on storage.objects;
create policy "KNR admins can delete product media" on storage.objects
for delete to authenticated using (
  bucket_id = 'product-media' and exists (
    select 1 from public.admin_users where user_id = auth.uid()
  )
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists products_updated_at on public.products;
create trigger products_updated_at before update on public.products
for each row execute function public.set_updated_at();
