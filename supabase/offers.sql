-- KNR: completar la columna de ofertas y activar actualizaciones en tiempo real.
-- Ejecutar una sola vez (o volver a ejecutar sin riesgo) en Supabase > SQL Editor.
alter table public.products
  add column if not exists is_offer boolean not null default false;

grant usage on schema public to anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;

-- Los visitantes solo pueden leer productos publicados.
alter table public.products enable row level security;
-- Separar la lectura anónima de la comprobación de administrador.
-- Así los visitantes no necesitan permisos sobre admin_users para ver el catálogo.
drop policy if exists "Public can view active KNR products" on public.products;
drop policy if exists "Authenticated can view active KNR products" on public.products;
drop policy if exists "KNR admins can view all KNR products" on public.products;
create policy "Public can view active KNR products" on public.products
for select to anon using (active = true);
create policy "Authenticated can view active KNR products" on public.products
for select to authenticated using (active = true);
create policy "KNR admins can view all KNR products" on public.products
for select to authenticated using (
  exists (select 1 from public.admin_users where user_id = auth.uid())
);

-- La tienda escucha cambios para refrescar productos sin recargar la página.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'products'
  ) then
    alter publication supabase_realtime add table public.products;
  end if;
  if to_regclass('public.store_banners') is not null and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'store_banners'
  ) then
    alter publication supabase_realtime add table public.store_banners;
  end if;
end $$;

notify pgrst, 'reload schema';
