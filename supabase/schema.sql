-- KNR: ejecutar en Supabase SQL Editor como propietario del proyecto.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
drop policy if exists "Admins can read their own membership" on public.admin_users;
create policy "Admins can read their own membership" on public.admin_users
for select to authenticated using (user_id = auth.uid());

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('Relojes','Gafas','Gorras','Perfumería','Accesorios')),
  style text not null default 'urban' check (style in ('urban','luxury')),
  price integer not null check (price >= 0),
  old_price integer check (old_price is null or old_price >= 0),
  discount integer not null default 0 check (discount between 0 and 90),
  tag text not null default 'NUEVO',
  description text not null default '',
  specs jsonb not null default '[]'::jsonb,
  image_urls jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.products enable row level security;

drop policy if exists "Public can view active KNR products" on public.products;
create policy "Public can view active KNR products"
on public.products for select to anon, authenticated
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

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('product-media','product-media',true,10485760,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do nothing;

drop policy if exists "Public can view KNR product media" on storage.objects;
create policy "Public can view KNR product media" on storage.objects
for select to anon, authenticated using (bucket_id = 'product-media');
drop policy if exists "KNR admins can upload product media" on storage.objects;
create policy "KNR admins can upload product media" on storage.objects
for insert to authenticated with check (
  bucket_id = 'product-media' and exists (select 1 from public.admin_users where user_id = auth.uid())
);
drop policy if exists "KNR admins can update product media" on storage.objects;
create policy "KNR admins can update product media" on storage.objects
for update to authenticated using (
  bucket_id = 'product-media' and exists (select 1 from public.admin_users where user_id = auth.uid())
);
drop policy if exists "KNR admins can delete product media" on storage.objects;
create policy "KNR admins can delete product media" on storage.objects
for delete to authenticated using (
  bucket_id = 'product-media' and exists (select 1 from public.admin_users where user_id = auth.uid())
);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists products_updated_at on public.products;
create trigger products_updated_at before update on public.products
for each row execute function public.set_updated_at();

-- Después de crear el usuario desde Authentication > Users, autorízalo:
-- insert into public.admin_users(user_id)
-- select id from auth.users where email = 'TU_CORREO_ADMIN';


-- Banners promocionales editables desde el panel KNR.
create table if not exists public.store_banners (
  id uuid primary key default gen_random_uuid(),
  eyebrow text not null default 'NOVEDAD KNR',
  title text not null,
  description text not null default '',
  image_url text not null,
  link_url text not null default '#coleccion',
  style text not null default 'urban' check (style in ('urban','luxury')),
  active boolean not null default true,
  priority integer not null default 0,
  created_at timestamptz not null default now()
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

-- Permite campañas universales además de campañas por ambiente.
alter table public.store_banners drop constraint if exists store_banners_style_check;
alter table public.store_banners add constraint store_banners_style_check
check (style in ('urban','luxury','all'));

-- Biblioteca de audio por ambiente. Solo se almacenan URLs que el comercio tiene derecho a reproducir.
alter table public.products add column if not exists video_url text;
alter table public.store_banners add column if not exists video_url text;
create table if not exists public.music_tracks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mood text not null default 'urban' check (mood in ('urban','luxury','all')),
  audio_url text not null,
  active boolean not null default true,
  priority integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.music_tracks enable row level security;
drop policy if exists "Public can view active KNR tracks" on public.music_tracks;
create policy "Public can view active KNR tracks" on public.music_tracks
for select to anon, authenticated using (active = true or exists (select 1 from public.admin_users where user_id=auth.uid()));
drop policy if exists "KNR admins can insert tracks" on public.music_tracks;
create policy "KNR admins can insert tracks" on public.music_tracks for insert to authenticated
with check (exists (select 1 from public.admin_users where user_id=auth.uid()));
drop policy if exists "KNR admins can update tracks" on public.music_tracks;
create policy "KNR admins can update tracks" on public.music_tracks for update to authenticated
using (exists (select 1 from public.admin_users where user_id=auth.uid()))
with check (exists (select 1 from public.admin_users where user_id=auth.uid()));
drop policy if exists "KNR admins can delete tracks" on public.music_tracks;
create policy "KNR admins can delete tracks" on public.music_tracks for delete to authenticated
using (exists (select 1 from public.admin_users where user_id=auth.uid()));

-- Inventario y pedidos con creación transaccional desde la tienda.
alter table public.products add column if not exists stock integer not null default 0 check (stock >= 0);
alter table public.products add column if not exists track_inventory boolean not null default false;
alter table public.products drop column if exists cost_price;

-- Costos de compra aislados de la tabla pública de productos.
create table if not exists public.product_costs (
  product_id uuid primary key references public.products(id) on delete cascade,
  cost_price integer not null default 0 check (cost_price >= 0),
  updated_at timestamptz not null default now()
);
alter table public.product_costs enable row level security;
grant select, insert, update, delete on public.product_costs to authenticated;
drop policy if exists "KNR admins manage product costs" on public.product_costs;
create policy "KNR admins manage product costs" on public.product_costs
for all to authenticated
using (exists (select 1 from public.admin_users where user_id=auth.uid()))
with check (exists (select 1 from public.admin_users where user_id=auth.uid()));

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'pending' check (status in ('pending','confirmed','preparing','shipped','delivered','cancelled')),
  customer_name text not null,
  customer_phone text not null,
  neighborhood text not null,
  delivery_address text not null,
  delivery_details text not null default '',
  receiver text not null default '',
  items jsonb not null default '[]'::jsonb,
  total integer not null check (total >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.orders enable row level security;
grant select, update on public.orders to authenticated;
drop policy if exists "KNR admins can read orders" on public.orders;
create policy "KNR admins can read orders" on public.orders for select to authenticated
using (exists (select 1 from public.admin_users where user_id=auth.uid()));
drop policy if exists "KNR admins can update orders" on public.orders;
create policy "KNR admins can update orders" on public.orders for update to authenticated
using (exists (select 1 from public.admin_users where user_id=auth.uid()))
with check (exists (select 1 from public.admin_users where user_id=auth.uid()));
drop trigger if exists orders_updated_at on public.orders;
create trigger orders_updated_at before update on public.orders
for each row execute function public.set_updated_at();

create or replace function public.place_order(p_customer jsonb, p_items jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_total integer := 0;
  v_order_id uuid;
  v_snapshot jsonb := '[]'::jsonb;
  v_combo_count integer := 0;
  v_combo_pct integer := 0;
  v_unit_price integer;
  v_unit_cost integer := 0;
begin
  if coalesce(trim(p_customer->>'name'),'') = ''
    or coalesce(trim(p_customer->>'phone'),'') = ''
    or coalesce(trim(p_customer->>'neighborhood'),'') = ''
    or coalesce(trim(p_customer->>'address'),'') = '' then
    raise exception 'Completa los datos obligatorios de entrega.';
  end if;
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'El formato del carrito no es válido.';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío.';
  end if;

  -- El descuento de combo se determina aquí, nunca a partir de precios enviados por el navegador.
  select count(distinct value->>'id') into v_combo_count
  from jsonb_array_elements(p_items)
  where value->>'is_combo' = 'true';

  if v_combo_count >= 2 and exists (
    select 1
    from jsonb_array_elements(p_items) item
    join public.products p on p.id = (item->>'id')::uuid
    where item->>'is_combo' = 'true' and p.active = true and p.category = 'Relojes'
  ) then
    v_combo_pct := case
      when v_combo_count >= 4 then 15
      when v_combo_count = 3 then 10
      when v_combo_count = 2 then 5
      else 0
    end;
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item->>'qty')::integer;
    if v_qty is null or v_qty < 1 or v_qty > 20 then
      raise exception 'Cantidad de producto no válida.';
    end if;
    select * into v_product from public.products
      where id = (v_item->>'id')::uuid and active = true for update;
    if not found then
      raise exception 'Uno de los productos ya no está disponible.';
    end if;
    if v_product.track_inventory and v_product.stock < v_qty then
      raise exception 'Stock insuficiente para: %', v_product.name;
    end if;

    v_unit_price := v_product.price;
    select coalesce(pc.cost_price,0) into v_unit_cost
      from (select 1) seed left join public.product_costs pc on pc.product_id=v_product.id;
    if v_combo_pct > 0 and v_item->>'is_combo' = 'true' then
      v_unit_price := round(v_product.price * (100 - v_combo_pct) / 100.0)::integer;
    end if;
    v_total := v_total + (v_unit_price * v_qty);
    v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object(
      'id',v_product.id,
      'name',v_product.name,
      'qty',v_qty,
      'unit_price',v_unit_price,
      'unit_cost',v_unit_cost,
      'list_price',v_product.price,
      'combo_discount_pct',case when v_item->>'is_combo' = 'true' then v_combo_pct else 0 end,
      'category',v_product.category,
      'style',v_product.style
    ));
    if v_product.track_inventory then
      update public.products set stock = stock - v_qty where id = v_product.id;
    end if;
  end loop;

  insert into public.orders(customer_name,customer_phone,neighborhood,delivery_address,delivery_details,receiver,items,total)
  values(trim(p_customer->>'name'),trim(p_customer->>'phone'),trim(p_customer->>'neighborhood'),
    trim(p_customer->>'address'),coalesce(p_customer->>'details',''),
    coalesce(nullif(trim(p_customer->>'receiver'),''),trim(p_customer->>'name')),v_snapshot,v_total)
  returning id into v_order_id;
  return v_order_id;
end;
$$;
revoke all on function public.place_order(jsonb,jsonb) from public;
grant execute on function public.place_order(jsonb,jsonb) to anon, authenticated;

-- Al cancelar un pedido aún no despachado, devuelve al inventario las unidades reservadas.
create or replace function public.restore_cancelled_order_stock()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_item jsonb;
begin
  if old.status = 'cancelled' and new.status <> 'cancelled' then
    raise exception 'Un pedido cancelado no puede reactivarse; crea un pedido nuevo.';
  end if;
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    if old.status in ('shipped','delivered') then
      raise exception 'Un pedido enviado o entregado requiere gestión de devolución; no se restaura el stock automáticamente.';
    end if;
    for v_item in select value from jsonb_array_elements(old.items)
    loop
      update public.products
        set stock = stock + (v_item->>'qty')::integer
        where id = (v_item->>'id')::uuid and track_inventory = true;
    end loop;
  end if;
  return new;
end;
$$;
drop trigger if exists orders_restore_stock_on_cancel on public.orders;
create trigger orders_restore_stock_on_cancel before update of status on public.orders
for each row execute function public.restore_cancelled_order_stock();


-- Gastos operativos registrados por el equipo administrativo.
create table if not exists public.operating_expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('Envio','Empaque','Publicidad','Comisiones','Operación','Otro')),
  description text not null,
  amount integer not null check (amount > 0),
  incurred_on date not null default current_date,
  created_at timestamptz not null default now()
);
alter table public.operating_expenses enable row level security;
grant select, insert, update, delete on public.operating_expenses to authenticated;
drop policy if exists "KNR admins manage operating expenses" on public.operating_expenses;
create policy "KNR admins manage operating expenses" on public.operating_expenses
for all to authenticated
using (exists (select 1 from public.admin_users where user_id=auth.uid()))
with check (exists (select 1 from public.admin_users where user_id=auth.uid()));


-- Reporte histórico agregado: no depende de la página visible en el panel.
-- Solo administradores pueden consultar los datos comerciales y de pedidos.
-- Reporte histórico agregado: métricas, ranking y evolución mensual.
-- Solo administradores pueden consultar datos comerciales y de pedidos.
create or replace function public.admin_order_report(
  p_status text default null,
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_report jsonb;
begin
  if not exists (select 1 from public.admin_users where user_id = auth.uid()) then
    raise exception 'No autorizado para consultar reportes.';
  end if;

  with filtered as (
    select o.* from public.orders o
    where (p_status is null or o.status = p_status)
      and (p_from is null or o.created_at >= p_from)
      and (p_to is null or o.created_at <= p_to)
  ),
  product_lines as (
    select
      coalesce(item.value->>'id', item.value->>'name') as product_id,
      coalesce(item.value->>'name','Producto') as product_name,
      coalesce((item.value->>'qty')::integer,0) as qty,
      coalesce((item.value->>'unit_price')::numeric,0) as unit_price,
      coalesce((item.value->>'unit_cost')::numeric,0) as unit_cost
    from filtered f
    cross join lateral jsonb_array_elements(f.items) as item(value)
    where f.status <> 'cancelled'
  ),
  ranking as (
    select product_id, product_name,
      sum(qty)::integer as qty,
      sum(qty * unit_price)::numeric as revenue,
      sum(qty * unit_cost)::numeric as cost,
      sum(qty * (unit_price-unit_cost))::numeric as profit
    from product_lines
    group by product_id, product_name
    order by sum(qty * (unit_price-unit_cost)) desc, sum(qty * unit_price) desc
    limit 5
  ),
  months as (
    select generate_series(
      date_trunc('month',current_date)-interval '11 months',
      date_trunc('month',current_date),
      interval '1 month'
    )::date as month_start
  ),
  monthly as (
    select
      date_trunc('month',f.created_at)::date as month_start,
      count(*)::integer as order_count,
      coalesce(sum(f.total) filter (where f.status='delivered'),0)::numeric as delivered_revenue
    from filtered f
    group by date_trunc('month',f.created_at)::date
  )
  select jsonb_build_object(
    'total_orders',(select count(*) from filtered),
    'pending_count',(select count(*) from filtered where status='pending'),
    'delivered_revenue',(select coalesce(sum(total),0) from filtered where status='delivered'),
    'delivered_cost',(select coalesce(sum((item.value->>'qty')::numeric*coalesce((item.value->>'unit_cost')::numeric,0)),0) from filtered f cross join lateral jsonb_array_elements(f.items) item(value) where f.status='delivered'),
    'delivered_profit',(select coalesce(sum((item.value->>'qty')::numeric*((item.value->>'unit_price')::numeric-coalesce((item.value->>'unit_cost')::numeric,0))),0) from filtered f cross join lateral jsonb_array_elements(f.items) item(value) where f.status='delivered'),
    'operating_expenses',(select coalesce(sum(e.amount),0) from public.operating_expenses e
      where (p_from is null or e.incurred_on >= p_from::date)
        and (p_to is null or e.incurred_on <= p_to::date)),
    'net_profit',
      (select coalesce(sum((item.value->>'qty')::numeric*((item.value->>'unit_price')::numeric-coalesce((item.value->>'unit_cost')::numeric,0))),0)
       from filtered f cross join lateral jsonb_array_elements(f.items) item(value) where f.status='delivered')
      - (select coalesce(sum(e.amount),0) from public.operating_expenses e
         where (p_from is null or e.incurred_on >= p_from::date)
           and (p_to is null or e.incurred_on <= p_to::date)),
    'net_margin_pct',
      case when (select coalesce(sum(total),0) from filtered where status='delivered') > 0 then
        (((select coalesce(sum((item.value->>'qty')::numeric*((item.value->>'unit_price')::numeric-coalesce((item.value->>'unit_cost')::numeric,0))),0)
           from filtered f cross join lateral jsonb_array_elements(f.items) item(value) where f.status='delivered')
          - (select coalesce(sum(e.amount),0) from public.operating_expenses e
             where (p_from is null or e.incurred_on >= p_from::date)
               and (p_to is null or e.incurred_on <= p_to::date)))
         / (select coalesce(sum(total),0) from filtered where status='delivered')) * 100
      else 0 end,
    'top_products',coalesce((select jsonb_agg(jsonb_build_object(
      'id',product_id,'name',product_name,'qty',qty,'revenue',revenue,'cost',cost,'profit',profit
    ) order by qty desc,revenue desc) from ranking),'[]'::jsonb),
    'monthly_sales',coalesce((
      select jsonb_agg(jsonb_build_object(
        'month',to_char(m.month_start,'YYYY-MM'),
        'label',to_char(m.month_start,'Mon YY'),
        'orders',coalesce(x.order_count,0),
        'delivered_revenue',coalesce(x.delivered_revenue,0)
      ) order by m.month_start)
      from months m left join monthly x on x.month_start=m.month_start
    ),'[]'::jsonb)
  ) into v_report;

  return v_report;
end;
$$;
revoke all on function public.admin_order_report(text,timestamptz,timestamptz) from public;
grant execute on function public.admin_order_report(text,timestamptz,timestamptz) to authenticated;


