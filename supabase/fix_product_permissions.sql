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
