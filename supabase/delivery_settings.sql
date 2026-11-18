-- KNR: tarifas de envío por pedido y entregas prioritarias.
-- Ejecutar una sola vez en Supabase > SQL Editor como propietario del proyecto.

-- Permisos explícitos: el storefront consulta la biblioteca pública de música.
grant usage on schema public to anon, authenticated;
grant select on public.music_tracks to anon, authenticated;
grant insert, update, delete on public.music_tracks to authenticated;
grant select on public.store_banners to anon, authenticated;
grant insert, update, delete on public.store_banners to authenticated;

create table if not exists public.store_settings (
  id boolean primary key default true check (id = true),
  shipping_fee integer not null default 15000 check (shipping_fee >= 0),
  delivery_start time not null default '08:00',
  delivery_end time not null default '18:00',
  same_day_fee_before_14_pct numeric(5,2) not null default 5 check (same_day_fee_before_14_pct between 0 and 100),
  same_day_fee_14_16_pct numeric(5,2) not null default 8 check (same_day_fee_14_16_pct between 0 and 100),
  same_day_fee_16_18_pct numeric(5,2) not null default 15 check (same_day_fee_16_18_pct between 0 and 100),
  updated_at timestamptz not null default now()
);
insert into public.store_settings(id) values(true) on conflict(id) do nothing;
alter table public.store_settings enable row level security;
grant select on public.store_settings to anon, authenticated;
grant insert, update on public.store_settings to authenticated;
drop policy if exists "Public can read KNR delivery settings" on public.store_settings;
create policy "Public can read KNR delivery settings" on public.store_settings
for select to anon, authenticated using (true);
drop policy if exists "KNR admins manage delivery settings" on public.store_settings;
create policy "KNR admins manage delivery settings" on public.store_settings
for all to authenticated
using (exists(select 1 from public.admin_users where user_id=auth.uid()))
with check (exists(select 1 from public.admin_users where user_id=auth.uid()));

alter table public.orders add column if not exists shipping_cost integer not null default 0 check (shipping_cost >= 0);
alter table public.orders add column if not exists priority_fee integer not null default 0 check (priority_fee >= 0);
alter table public.orders add column if not exists delivery_priority boolean not null default false;
alter table public.orders add column if not exists delivery_date date;
alter table public.orders add column if not exists delivery_window text not null default '';

-- Reemplaza la RPC anterior por una que calcula las tarifas en el servidor.
drop function if exists public.place_order(jsonb,jsonb);
create or replace function public.place_order(p_customer jsonb, p_items jsonb, p_delivery jsonb default '{}'::jsonb)
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
  v_settings public.store_settings%rowtype;
  v_shipping integer := 0;
  v_priority_fee integer := 0;
  v_priority_pct numeric := 0;
  v_requested_for text := coalesce(p_delivery->>'requested_for','tomorrow');
  v_is_priority boolean := coalesce((p_delivery->>'priority')::boolean,false);
  v_local_time time := (now() at time zone 'America/Bogota')::time;
  v_delivery_date date;
  v_delivery_window text;
begin
  if coalesce(trim(p_customer->>'name'),'') = ''
    or coalesce(trim(p_customer->>'phone'),'') = ''
    or coalesce(trim(p_customer->>'neighborhood'),'') = ''
    or coalesce(trim(p_customer->>'address'),'') = '' then
    raise exception 'Completa los datos obligatorios de entrega.';
  end if;
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'El carrito está vacío o el formato no es válido.';
  end if;
  select * into v_settings from public.store_settings where id=true;
  if not found then
    v_settings.shipping_fee := 15000;
    v_settings.delivery_start := '08:00';
    v_settings.delivery_end := '18:00';
    v_settings.same_day_fee_before_14_pct := 5;
    v_settings.same_day_fee_14_16_pct := 8;
    v_settings.same_day_fee_16_18_pct := 15;
  end if;
  if v_requested_for not in ('today','tomorrow') then
    raise exception 'Selecciona entrega para hoy o mañana.';
  end if;
  if v_requested_for = 'today' then
    if v_local_time < time '06:00' or v_local_time >= time '18:00' then
      raise exception 'La entrega para hoy ya no está disponible. Selecciona mañana.';
    end if;
    v_delivery_date := (now() at time zone 'America/Bogota')::date;
    if v_local_time < time '14:00' then
      v_priority_pct := v_settings.same_day_fee_before_14_pct;
    elsif v_local_time < time '16:00' then
      v_priority_pct := v_settings.same_day_fee_14_16_pct;
    else
      v_priority_pct := v_settings.same_day_fee_16_18_pct;
    end if;
    if v_is_priority then
      v_priority_fee := 0; -- Se calcula sobre el subtotal al terminar el recorrido del carrito.
    else
      raise exception 'Confirma la entrega prioritaria para hoy.';
    end if;
  else
    v_delivery_date := (now() at time zone 'America/Bogota')::date + 1;
    v_is_priority := false;
  end if;
  v_shipping := v_settings.shipping_fee;
  v_delivery_window := to_char(v_settings.delivery_start,'HH24:MI') || ' - ' || to_char(v_settings.delivery_end,'HH24:MI');

  select count(distinct value->>'id') into v_combo_count
  from jsonb_array_elements(p_items) where value->>'is_combo' = 'true';
  if v_combo_count >= 2 and exists (
    select 1 from jsonb_array_elements(p_items) item
    join public.products p on p.id = (item->>'id')::uuid
    where item->>'is_combo' = 'true' and p.active = true and p.category = 'Relojes'
  ) then
    v_combo_pct := case when v_combo_count >= 4 then 15 when v_combo_count = 3 then 10 when v_combo_count = 2 then 5 else 0 end;
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_qty := (v_item->>'qty')::integer;
    if v_qty is null or v_qty < 1 or v_qty > 20 then raise exception 'Cantidad de producto no válida.'; end if;
    select * into v_product from public.products where id = (v_item->>'id')::uuid and active = true for update;
    if not found then raise exception 'Uno de los productos ya no está disponible.'; end if;
    if v_product.track_inventory and v_product.stock < v_qty then raise exception 'Stock insuficiente para: %', v_product.name; end if;
    v_unit_price := v_product.price;
    select coalesce(pc.cost_price,0) into v_unit_cost from (select 1) seed left join public.product_costs pc on pc.product_id=v_product.id;
    if v_combo_pct > 0 and v_item->>'is_combo' = 'true' then v_unit_price := round(v_product.price * (100 - v_combo_pct) / 100.0)::integer; end if;
    v_total := v_total + (v_unit_price * v_qty);
    v_snapshot := v_snapshot || jsonb_build_array(jsonb_build_object(
      'id',v_product.id,'name',v_product.name,'qty',v_qty,'unit_price',v_unit_price,
      'unit_cost',v_unit_cost,'list_price',v_product.price,
      'combo_discount_pct',case when v_item->>'is_combo' = 'true' then v_combo_pct else 0 end,
      'category',v_product.category,'style',v_product.style
    ));
    if v_product.track_inventory then update public.products set stock = stock - v_qty where id = v_product.id; end if;
  end loop;

  if v_is_priority then v_priority_fee := round(v_total * v_priority_pct / 100.0)::integer; end if;
  insert into public.orders(customer_name,customer_phone,neighborhood,delivery_address,delivery_details,receiver,items,total,shipping_cost,priority_fee,delivery_priority,delivery_date,delivery_window)
  values(trim(p_customer->>'name'),trim(p_customer->>'phone'),trim(p_customer->>'neighborhood'),
    trim(p_customer->>'address'),coalesce(p_customer->>'details',''),
    coalesce(nullif(trim(p_customer->>'receiver'),''),trim(p_customer->>'name')),
    v_snapshot,v_total+v_shipping+v_priority_fee,v_shipping,v_priority_fee,v_is_priority,v_delivery_date,v_delivery_window)
  returning id into v_order_id;
  return v_order_id;
end;
$$;
grant execute on function public.place_order(jsonb,jsonb,jsonb) to anon, authenticated;
