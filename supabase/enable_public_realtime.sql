-- KNR: habilita eventos en tiempo real para el contenido público de la tienda.
-- Ejecutar una sola vez en Supabase > SQL Editor.
-- Los visitantes siguen leyendo únicamente filas activas mediante las políticas RLS.

do $$
declare
  table_name text;
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    raise notice 'No existe la publicación supabase_realtime en este proyecto.';
    return;
  end if;

  foreach table_name in array array['products','store_banners','music_tracks'] loop
    if to_regclass('public.' || table_name) is not null
      and not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      )
    then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;

-- Confirma qué tablas están publicadas para Realtime.
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('products','store_banners','music_tracks')
order by tablename;
