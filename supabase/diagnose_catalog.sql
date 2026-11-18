-- Diagnóstico de solo lectura para el catálogo KNR.
-- Ejecutar en Supabase > SQL Editor y compartir el resultado JSON.
-- No modifica tablas ni muestra claves o datos personales.

select jsonb_pretty(jsonb_build_object(
  'products_total', (select count(*) from public.products),
  'products_active', (select count(*) from public.products where active = true),
  'admin_users_total', (select count(*) from public.admin_users),
  'product_costs_total', (select count(*) from public.product_costs),
  'product_media_bucket_exists', exists (
    select 1 from storage.buckets where id = 'product-media'
  ),
  'products_rls_enabled', (
    select c.relrowsecurity
    from pg_class c
    where c.oid = 'public.products'::regclass
  ),
  'products_policies', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', policyname,
      'command', cmd,
      'roles', roles,
      'using', qual,
      'with_check', with_check
    ))
    from pg_policies
    where schemaname = 'public' and tablename = 'products'
  ), '[]'::jsonb),
  'storage_policies', coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', policyname,
      'command', cmd,
      'roles', roles,
      'using', qual,
      'with_check', with_check
    ))
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (qual ilike '%product-media%' or with_check ilike '%product-media%')
  ), '[]'::jsonb),
  'products_grants', coalesce((
    select jsonb_agg(jsonb_build_object(
      'grantee', grantee,
      'privilege', privilege_type
    ))
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'products'
      and grantee in ('anon', 'authenticated')
  ), '[]'::jsonb),
  'product_costs_grants', coalesce((
    select jsonb_agg(jsonb_build_object(
      'grantee', grantee,
      'privilege', privilege_type
    ))
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'product_costs'
      and grantee = 'authenticated'
  ), '[]'::jsonb)
)) as knr_catalog_diagnostic;
