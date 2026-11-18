-- Reparación de permisos SQL de KNR para el catálogo.
-- Ejecutar en Supabase > SQL Editor con la cuenta propietaria del proyecto.
-- Es seguro ejecutarlo más de una vez. RLS continúa controlando las filas.

grant usage on schema public to authenticated;
grant usage on schema storage to authenticated;
grant select on public.admin_users to authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;

-- La cuenta autenticada solo puede consultar su propia membresía.
drop policy if exists "Admins can read their own membership" on public.admin_users;
create policy "Admins can read their own membership" on public.admin_users
for select to authenticated
using (user_id = auth.uid());
