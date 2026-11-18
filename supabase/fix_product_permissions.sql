-- Reparación de permisos SQL de KNR (catálogo, música, banners y costos).
-- Ejecutar en Supabase > SQL Editor como propietario del proyecto.
-- Se puede ejecutar varias veces; las políticas RLS siguen controlando las filas.

grant usage on schema public to anon, authenticated;
grant usage on schema storage to anon, authenticated;
grant select on public.admin_users to authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;

-- Permisos explícitos para música y banners, incluso si una instalación antigua
-- dejó creada la tabla de música en singular.
do $grants$
declare t text;
begin
 foreach t in array array['music_tracks','music_track','store_banners','stores_banners'] loop
  if to_regclass('public.'||t) is not null then
   execute format('grant select on table public.%I to anon, authenticated',t);
   execute format('grant insert, update, delete on table public.%I to authenticated',t);
  end if;
 end loop;
end;
$grants$;

-- Permisos para las tablas de contenido. Se contemplan ambos nombres por si
-- una instalación anterior creó las tablas en singular/plural.
do $permissions$
declare table_name text;
begin
  foreach table_name in array array['music_tracks','music_track','store_banners','stores_banners'] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('grant select on table public.%I to anon, authenticated', table_name);
      execute format('grant insert, update, delete on table public.%I to authenticated', table_name);
    end if;
  end loop;
end;
$permissions$;

-- El envío se guarda por separado del costo del producto.
alter table if exists public.product_costs
  add column if not exists shipping_cost integer not null default 0
  check (shipping_cost >= 0);
grant select, insert, update, delete on public.product_costs to authenticated;

-- La cuenta autenticada solo puede consultar su propia membresía.
drop policy if exists "Admins can read their own membership" on public.admin_users;
create policy "Admins can read their own membership" on public.admin_users
for select to authenticated
using (user_id = auth.uid());


-- Visibilidad pública del catálogo KNR.
-- Los productos y banners activos se muestran a cualquier visitante, sin iniciar sesión.
-- Las altas, ediciones y eliminaciones siguen reservadas a cuentas administradoras.
grant usage on schema public to anon, authenticated;
grant select on public.products to anon, authenticated;
grant select on public.store_banners to anon, authenticated;
grant select on storage.objects to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant insert, update, delete on public.store_banners to authenticated;
grant insert, update, delete on storage.objects to authenticated;

alter table public.products enable row level security;
drop policy if exists "Public can view active KNR products" on public.products;
create policy "Public can view active KNR products" on public.products
for select to anon, authenticated
using (active = true or exists (
  select 1 from public.admin_users where user_id = auth.uid()
));

drop policy if exists "KNR admins can insert products" on public.products;
create policy "KNR admins can insert products" on public.products
for insert to authenticated with check (
  exists (select 1 from public.admin_users where user_id = auth.uid())
);
drop policy if exists "KNR admins can update products" on public.products;
create policy "KNR admins can update products" on public.products
for update to authenticated using (
  exists (select 1 from public.admin_users where user_id = auth.uid())
) with check (
  exists (select 1 from public.admin_users where user_id = auth.uid())
);
drop policy if exists "KNR admins can delete products" on public.products;
create policy "KNR admins can delete products" on public.products
for delete to authenticated using (
  exists (select 1 from public.admin_users where user_id = auth.uid())
);

alter table public.store_banners enable row level security;
drop policy if exists "Public can view active KNR banners" on public.store_banners;
create policy "Public can view active KNR banners" on public.store_banners
for select to anon, authenticated using (active = true or exists (
  select 1 from public.admin_users where user_id = auth.uid()
));
drop policy if exists "KNR admins can insert banners" on public.store_banners;
create policy "KNR admins can insert banners" on public.store_banners
for insert to authenticated with check (exists (
  select 1 from public.admin_users where user_id = auth.uid()
));
drop policy if exists "KNR admins can update banners" on public.store_banners;
create policy "KNR admins can update banners" on public.store_banners
for update to authenticated using (exists (
  select 1 from public.admin_users where user_id = auth.uid()
)) with check (exists (
  select 1 from public.admin_users where user_id = auth.uid()
));
drop policy if exists "KNR admins can delete banners" on public.store_banners;
create policy "KNR admins can delete banners" on public.store_banners
for delete to authenticated using (exists (
  select 1 from public.admin_users where user_id = auth.uid()
));

-- Las imágenes guardadas en el bucket público pueden verse desde la tienda.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-media','product-media',true,10485760,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public = true;
drop policy if exists "Public can view KNR product media" on storage.objects;
create policy "Public can view KNR product media" on storage.objects
for select to anon, authenticated using (bucket_id = 'product-media');
