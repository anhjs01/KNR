-- KNR: publicación en tiempo real del contenido visible de la tienda.
-- Ejecutar una sola vez (o volver a ejecutar sin riesgo) en Supabase > SQL Editor.
-- La lectura pública continúa limitada por las políticas RLS a contenido activo.
grant usage on schema public to anon, authenticated;
grant select on public.products, public.store_banners, public.music_tracks to anon, authenticated;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['products','store_banners','music_tracks'] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
