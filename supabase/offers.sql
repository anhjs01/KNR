-- KNR: activa la selección manual de ofertas en el catálogo.
-- Ejecutar en Supabase SQL Editor; se puede ejecutar varias veces.
alter table public.products add column if not exists is_offer boolean not null default false;
grant select on public.products to anon, authenticated;
grant update on public.products to authenticated;
notify pgrst, 'reload schema';
