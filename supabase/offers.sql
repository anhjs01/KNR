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


-- PARCHE DEFINITIVO DE POLÍTICAS RLS KNR
-- Verificación administrativa segura: SECURITY DEFINER evita que RLS/GRANT
-- de admin_users bloquee consultas públicas a products y store_banners.
create or replace function public.is_knr_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = auth.uid()
  );
$$;
revoke all on function public.is_knr_admin() from public, anon;
grant execute on function public.is_knr_admin() to authenticated;

-- Reiniciar las políticas de products para eliminar reglas antiguas que
-- consultaban admin_users directamente bajo el rol anónimo.
do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname='public' and tablename='products'
  loop
    execute format('drop policy if exists %I on public.products', p.policyname);
  end loop;
end $$;
alter table public.products enable row level security;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
create policy "KNR public read active products" on public.products
for select to anon using (active = true);
create policy "KNR authenticated read products" on public.products
for select to authenticated using (active = true or public.is_knr_admin());
create policy "KNR admin insert products" on public.products
for insert to authenticated with check (public.is_knr_admin());
create policy "KNR admin update products" on public.products
for update to authenticated using (public.is_knr_admin()) with check (public.is_knr_admin());
create policy "KNR admin delete products" on public.products
for delete to authenticated using (public.is_knr_admin());

-- Repetir el mismo esquema para banners cuando exista la tabla.
do $$
declare p record;
begin
  if to_regclass('public.store_banners') is not null then
    for p in select policyname from pg_policies
             where schemaname='public' and tablename='store_banners'
    loop
      execute format('drop policy if exists %I on public.store_banners', p.policyname);
    end loop;
    alter table public.store_banners enable row level security;
    grant select on public.store_banners to anon, authenticated;
    grant insert, update, delete on public.store_banners to authenticated;
    create policy "KNR public read active banners" on public.store_banners
      for select to anon using (active = true);
    create policy "KNR authenticated read banners" on public.store_banners
      for select to authenticated using (active = true or public.is_knr_admin());
    create policy "KNR admin insert banners" on public.store_banners
      for insert to authenticated with check (public.is_knr_admin());
    create policy "KNR admin update banners" on public.store_banners
      for update to authenticated using (public.is_knr_admin()) with check (public.is_knr_admin());
    create policy "KNR admin delete banners" on public.store_banners
      for delete to authenticated using (public.is_knr_admin());
  end if;
end $$;

notify pgrst, 'reload schema';
