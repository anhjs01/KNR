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
alter table public.products add column if not exists reorder_level integer not null default 5 check (reorder_level >= 0);
alter table public.products add column if not exists reorder_quantity integer not null default 10 check (reorder_quantity > 0);
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
-- Costos de compra aislados de la tabla pública de productos.
create table if not exists public.product_costs (
  product_id uuid primary key references public.products(id) on delete cascade,
  cost_price integer not null default 0 check (cost_price >= 0),
  updated_at timestamptz not null default now()
);
-- Conserva los costos que pudieran haberse guardado en una versión anterior.
do $migrate$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='products' and column_name='cost_price'
  ) then
    execute 'insert into public.product_costs(product_id,cost_price)
      select id,cost_price from public.products
      on conflict(product_id) do update set cost_price=excluded.cost_price';
    alter table public.products drop column cost_price;
  end if;
end $migrate$;
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

  with comparison_bounds as (
    select
      coalesce(p_from::date,date_trunc('month',current_date)::date) as start_date,
      greatest(coalesce(p_from::date,date_trunc('month',current_date)::date),
        coalesce(p_to::date,current_date)) as end_date
  ),
  comparison_current as (
    select
      count(distinct o.id)::integer as orders,
      count(distinct o.id) filter (where o.status='delivered')::integer as delivered_orders,
      coalesce(sum(o.total) filter (where o.status='delivered'),0)::numeric as revenue,
      coalesce(sum((item.value->>'qty')::numeric*coalesce((item.value->>'unit_cost')::numeric,0))
        filter (where o.status='delivered'),0)::numeric as cost,
      coalesce(sum((item.value->>'qty')::numeric*((item.value->>'unit_price')::numeric-coalesce((item.value->>'unit_cost')::numeric,0)))
        filter (where o.status='delivered'),0)::numeric as profit
    from public.orders o
    cross join comparison_bounds b
    left join lateral jsonb_array_elements(o.items) item(value) on true
    where o.created_at >= b.start_date
      and o.created_at < b.end_date + interval '1 day'
      and (p_status is null or o.status=p_status)
  ),
  comparison_previous as (
    select
      count(*)::integer as orders,
      count(*) filter (where o.status='delivered')::integer as delivered_orders,
      coalesce(sum(o.total) filter (where o.status='delivered'),0)::numeric as revenue,
      coalesce(sum((item.value->>'qty')::numeric*coalesce((item.value->>'unit_cost')::numeric,0))
        filter (where o.status='delivered'),0)::numeric as cost,
      coalesce(sum((item.value->>'qty')::numeric*((item.value->>'unit_price')::numeric-coalesce((item.value->>'unit_cost')::numeric,0)))
        filter (where o.status='delivered'),0)::numeric as profit
    from public.orders o
    cross join comparison_bounds b
    left join lateral jsonb_array_elements(o.items) item(value) on true
    where o.created_at >= b.start_date - (b.end_date-b.start_date+1)
      and o.created_at < b.start_date
      and (p_status is null or o.status=p_status)
  ),
  comparison_expenses as (
    select
      coalesce(sum(e.amount) filter (where e.incurred_on between b.start_date and b.end_date),0)::numeric as current_expenses,
      coalesce(sum(e.amount) filter (where e.incurred_on >= b.start_date-(b.end_date-b.start_date+1) and e.incurred_on < b.start_date),0)::numeric as previous_expenses
    from public.operating_expenses e cross join comparison_bounds b
  ),
  filtered as (
    select o.* from public.orders o
    where (p_status is null or o.status = p_status)
      and (p_from is null or o.created_at >= p_from)
      and (p_to is null or o.created_at <= p_to)
  ),
  product_lines as (
    select
      coalesce(item.value->>'id', item.value->>'name') as product_id,
      coalesce(item.value->>'name','Producto') as product_name,
      coalesce(item.value->>'category','Sin categoría') as category,
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
  category_ranking as (
    select coalesce(item.value->>'category','Sin categoría') as category,
      sum(coalesce((item.value->>'qty')::integer,0))::integer as qty,
      sum(coalesce((item.value->>'qty')::numeric,0)*coalesce((item.value->>'unit_price')::numeric,0))::numeric as revenue,
      sum(coalesce((item.value->>'qty')::numeric,0)*coalesce((item.value->>'unit_cost')::numeric,0))::numeric as cost,
      sum(coalesce((item.value->>'qty')::numeric,0)*(coalesce((item.value->>'unit_price')::numeric,0)-coalesce((item.value->>'unit_cost')::numeric,0)))::numeric as profit
    from filtered f
    cross join lateral jsonb_array_elements(f.items) as item(value)
    where f.status='delivered'
    group by coalesce(item.value->>'category','Sin categoría')
  ),
  bottom_ranking as (
    select product_id,product_name,sum(qty)::integer as qty,
      sum(qty*unit_price)::numeric as revenue,
      sum(qty*unit_cost)::numeric as cost,
      sum(qty*(unit_price-unit_cost))::numeric as profit
    from product_lines
    group by product_id,product_name
    having sum(qty)>0
    order by sum(qty*(unit_price-unit_cost)) asc,sum(qty*unit_price) asc
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
    'period_comparison',(
      select jsonb_build_object(
        'start_date',b.start_date,'end_date',b.end_date,
        'previous_start_date',b.start_date-(b.end_date-b.start_date+1),
        'previous_end_date',b.start_date-1,
        'current',jsonb_build_object('orders',c.orders,'delivered_orders',c.delivered_orders,
          'revenue',c.revenue,'cost',c.cost,'gross_profit',c.profit,
          'expenses',e.current_expenses,'net_profit',c.profit-e.current_expenses),
        'previous',jsonb_build_object('orders',p.orders,'delivered_orders',p.delivered_orders,
          'revenue',p.revenue,'cost',p.cost,'gross_profit',p.profit,
          'expenses',e.previous_expenses,'net_profit',p.profit-e.previous_expenses),
        'change_pct',jsonb_build_object(
          'orders',case when p.orders=0 then null else round((c.orders-p.orders)::numeric/abs(p.orders)*100,1) end,
          'revenue',case when p.revenue=0 then null else round((c.revenue-p.revenue)/abs(p.revenue)*100,1) end,
          'gross_profit',case when p.profit=0 then null else round((c.profit-p.profit)/abs(p.profit)*100,1) end,
          'expenses',case when e.previous_expenses=0 then null else round((e.current_expenses-e.previous_expenses)/abs(e.previous_expenses)*100,1) end,
          'net_profit',case when p.profit-e.previous_expenses=0 then null else round(((c.profit-e.current_expenses)-(p.profit-e.previous_expenses))/abs(p.profit-e.previous_expenses)*100,1) end
        )
      )
      from comparison_bounds b cross join comparison_current c
      cross join comparison_previous p cross join comparison_expenses e
    ),
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
    ) order by profit desc,revenue desc) from ranking),'[]'::jsonb),
    'category_performance',coalesce((select jsonb_agg(jsonb_build_object(
      'category',category,'qty',qty,'revenue',revenue,'cost',cost,'profit',profit,
      'margin_pct',case when revenue>0 then round(profit/revenue*100,1) else 0 end
    ) order by revenue desc) from category_ranking),'[]'::jsonb),
    'bottom_products',coalesce((select jsonb_agg(jsonb_build_object(
      'id',product_id,'name',product_name,'qty',qty,'revenue',revenue,'cost',cost,'profit',profit,
      'margin_pct',case when revenue>0 then round(profit/revenue*100,1) else 0 end
    ) order by profit asc,revenue asc) from bottom_ranking),'[]'::jsonb),
    'monthly_sales',coalesce((
      select jsonb_agg(jsonb_build_object(
        'month',to_char(m.month_start,'YYYY-MM'),
        'label',to_char(m.month_start,'Mon YY'),
        'orders',coalesce(x.order_count,0),
        'delivered_revenue',coalesce(x.delivered_revenue,0)
      ) order by m.month_start)
      from months m left join monthly x on x.month_start=m.month_start
    ),'[]'::jsonb)
,    'inventory_forecast',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',forecast.id,'name',forecast.name,'category',forecast.category,
        'stock',forecast.stock,'units_sold_30d',forecast.units_sold_30d,
        'average_daily_sales',round(forecast.units_sold_30d/30.0,2),
        'days_until_stockout',case when forecast.units_sold_30d>0 then ceil(forecast.stock/(forecast.units_sold_30d/30.0))::integer else null end,
        'reorder_level',forecast.reorder_level,'reorder_quantity',forecast.reorder_quantity,
        'needs_restock',(forecast.stock<=forecast.reorder_level or (forecast.units_sold_30d>0 and forecast.stock/(forecast.units_sold_30d/30.0)<=14)),
        'suggested_reorder',greatest(forecast.reorder_quantity,ceil(forecast.units_sold_30d)-forecast.stock,0)
      ) order by (forecast.stock<=forecast.reorder_level or (forecast.units_sold_30d>0 and forecast.stock/(forecast.units_sold_30d/30.0)<=14)) desc,
        case when forecast.units_sold_30d>0 then forecast.stock/(forecast.units_sold_30d/30.0) else 999999 end asc)
      from (
        select p.id,p.name,p.category,p.stock,p.reorder_level,p.reorder_quantity,
          coalesce(s.units_sold,0)::numeric as units_sold_30d
        from public.products p
        left join lateral (
          select sum(coalesce((line.value->>'qty')::numeric,0)) as units_sold
          from public.orders o
          cross join lateral jsonb_array_elements(o.items) as line(value)
          where o.status='delivered' and o.created_at>=now()-interval '30 days'
            and line.value->>'id'=p.id::text
        ) s on true
        where p.active=true and p.track_inventory=true
      ) forecast
    ),'[]'::jsonb)
  ) into v_report;

  return v_report;
end;
$$;
revoke all on function public.admin_order_report(text,timestamptz,timestamptz) from public;
grant execute on function public.admin_order_report(text,timestamptz,timestamptz) to authenticated;




-- Proveedores y órdenes de compra: privados para administradores.
create table if not exists public.suppliers (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 contact_name text not null default '',
 phone text not null default '',
 email text not null default '',
 notes text not null default '',
 created_at timestamptz not null default now()
);
create table if not exists public.purchase_orders (
 id uuid primary key default gen_random_uuid(),
 supplier_id uuid not null references public.suppliers(id) on delete restrict,
 status text not null default 'pending' check(status in ('pending','received','cancelled')),
 notes text not null default '',
 total_amount bigint not null default 0 check(total_amount>=0),
 created_at timestamptz not null default now(),
 received_at timestamptz
);
create table if not exists public.purchase_order_items (
 id uuid primary key default gen_random_uuid(),
 purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete restrict,
 quantity integer not null check(quantity>0),
 unit_cost integer not null check(unit_cost>=0),
 line_total bigint generated always as (quantity::bigint*unit_cost::bigint) stored
);
alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_items enable row level security;
grant select,insert,update,delete on public.suppliers,public.purchase_orders,public.purchase_order_items to authenticated;
drop policy if exists "KNR admins manage suppliers" on public.suppliers;
create policy "KNR admins manage suppliers" on public.suppliers for all to authenticated
using(exists(select 1 from public.admin_users where user_id=auth.uid()))
with check(exists(select 1 from public.admin_users where user_id=auth.uid()));
drop policy if exists "KNR admins manage purchase orders" on public.purchase_orders;
create policy "KNR admins manage purchase orders" on public.purchase_orders for all to authenticated
using(exists(select 1 from public.admin_users where user_id=auth.uid()))
with check(exists(select 1 from public.admin_users where user_id=auth.uid()));
drop policy if exists "KNR admins manage purchase items" on public.purchase_order_items;
create policy "KNR admins manage purchase items" on public.purchase_order_items for all to authenticated
using(exists(select 1 from public.admin_users where user_id=auth.uid()))
with check(exists(select 1 from public.admin_users where user_id=auth.uid()));

create or replace function public.create_purchase_order(p_supplier_id uuid,p_notes text,p_items jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_order_id uuid; v_item jsonb; v_product_id uuid; v_qty integer; v_cost integer; v_total bigint:=0;
begin
 if not exists(select 1 from public.admin_users where user_id=auth.uid()) then raise exception 'No autorizado.'; end if;
 if not exists(select 1 from public.suppliers where id=p_supplier_id) then raise exception 'Proveedor no válido.'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Agrega al menos un producto.'; end if;
 insert into public.purchase_orders(supplier_id,notes) values(p_supplier_id,coalesce(p_notes,'')) returning id into v_order_id;
 for v_item in select value from jsonb_array_elements(p_items) loop
  v_product_id:=(v_item->>'product_id')::uuid; v_qty:=(v_item->>'quantity')::integer; v_cost:=(v_item->>'unit_cost')::integer;
  if v_qty<1 or v_cost<0 then raise exception 'Cantidad o costo no válido.'; end if;
  if not exists(select 1 from public.products where id=v_product_id) then raise exception 'Producto no encontrado.'; end if;
  insert into public.purchase_order_items(purchase_order_id,product_id,quantity,unit_cost) values(v_order_id,v_product_id,v_qty,v_cost);
  v_total:=v_total+v_qty::bigint*v_cost::bigint;
 end loop;
 update public.purchase_orders set total_amount=v_total where id=v_order_id;
 return v_order_id;
end; $$;

create or replace function public.receive_purchase_order(p_order_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_order public.purchase_orders%rowtype; v_item record;
begin
 if not exists(select 1 from public.admin_users where user_id=auth.uid()) then raise exception 'No autorizado.'; end if;
 select * into v_order from public.purchase_orders where id=p_order_id for update;
 if not found then raise exception 'Orden no encontrada.'; end if;
 if v_order.status<>'pending' then raise exception 'Esta orden ya fue procesada.'; end if;
 for v_item in select product_id,quantity,unit_cost from public.purchase_order_items where purchase_order_id=p_order_id loop
  update public.products set stock=coalesce(stock,0)+v_item.quantity where id=v_item.product_id and track_inventory=true;
  if not found then raise exception 'El producto no tiene control de inventario o ya no existe.'; end if;
  insert into public.product_costs(product_id,cost_price,updated_at)
  values(v_item.product_id,v_item.unit_cost,now())
  on conflict(product_id) do update set cost_price=excluded.cost_price,updated_at=now();
 end loop;
 update public.purchase_orders set status='received',received_at=now() where id=p_order_id;
end; $$;
grant execute on function public.create_purchase_order(uuid,text,jsonb) to authenticated;
grant execute on function public.receive_purchase_order(uuid) to authenticated;

