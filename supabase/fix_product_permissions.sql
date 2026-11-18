-- Permisos SQL de KNR para el catálogo.
-- Ejecutar en Supabase > SQL Editor. Es seguro ejecutarlo más de una vez.
-- Las políticas RLS siguen limitando las operaciones a las filas permitidas.

grant select on public.admin_users to authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on storage.objects to anon, authenticated;
grant insert, update, delete on storage.objects to authenticated;
