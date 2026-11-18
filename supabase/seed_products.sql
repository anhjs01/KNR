-- KNR demo products: idempotent restore, does not duplicate existing names.
-- Run in Supabase SQL Editor. Existing real products are kept untouched.
insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Noir Chronograph', 'Relojes', 'urban', 189000, 229000, 17, 'MÁS VENDIDO',
        'Presencia contundente, líneas limpias y un acabado negro que combina con todo. Una pieza para llevar tu propio ritmo.',
        '["Movimiento de cuarzo","Correa ajustable","Resistente a salpicaduras*"]'::jsonb,
        '["https://images.unsplash.com/photo-1524592094714-0f0654e20314?auto=format&fit=crop&w=1000&q=85","https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Noir Chronograph');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Steel Horizon', 'Relojes', 'luxury', 245000, null, 0, 'NUEVO',
        'Acero, equilibrio y una estética atemporal. El detalle preciso para elevar cualquier look.',
        '["Caja metálica","Esfera minimalista","Cierre de seguridad"]'::jsonb,
        '["https://images.unsplash.com/photo-1524805444758-089113d48a6d?auto=format&fit=crop&w=1000&q=85","https://images.unsplash.com/photo-1539874754764-5a96559165b0?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Steel Horizon');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Midnight Sport', 'Relojes', 'urban', 159000, 199000, 20, '-20%',
        'Carácter deportivo y una silueta versátil. Diseñado para acompañar días que no se quedan quietos.',
        '["Diseño deportivo","Correa cómoda","Cierre ajustable"]'::jsonb,
        '["https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?auto=format&fit=crop&w=1000&q=85","https://images.unsplash.com/photo-1508057198894-247b23fe5ade?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Midnight Sport');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Classic Gold', 'Relojes', 'luxury', 279000, null, 0, 'EDICIÓN SELECTA',
        'Un acento dorado, proporciones elegantes y una presencia que habla sin levantar la voz.',
        '["Acabado dorado","Estética clásica","Correa ajustable"]'::jsonb,
        '["https://images.unsplash.com/photo-1547996160-81dfa63595aa?auto=format&fit=crop&w=1000&q=85","https://images.unsplash.com/photo-1614164185128-e4ec99c436d7?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Classic Gold');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Urban Frame', 'Gafas', 'urban', 89000, 109000, 18, '-18%',
        'Gafas de líneas marcadas para completar el conjunto con personalidad.',
        '["Montura liviana","Diseño urbano","Incluye estuche"]'::jsonb,
        '["https://images.unsplash.com/photo-1511499767150-a48a237f0083?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Urban Frame');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'KNR Essential Cap', 'Gorras', 'urban', 69000, null, 0, 'ESENCIAL',
        'Una gorra versátil con un perfil limpio para cerrar el look.',
        '["Visera curva","Ajuste posterior","Estilo unisex"]'::jsonb,
        '["https://images.unsplash.com/photo-1588850561407-ed78c282e89b?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'KNR Essential Cap');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'KNR Street Cap', 'Gorras', 'urban', 74000, null, 0, 'URBAN',
        'Gorra de perfil urbano para completar un look casual de todos los días.',
        '["Visera curva","Ajuste posterior","Diseño urbano"]'::jsonb,
        '["https://images.unsplash.com/photo-1521369909029-2afed882baee?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'KNR Street Cap');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'KNR Classic Cap', 'Gorras', 'luxury', 79000, null, 0, 'CLÁSICA',
        'Una silueta sencilla y versátil, pensada para combinar con prendas básicas.',
        '["Perfil clásico","Correa ajustable","Estilo unisex"]'::jsonb,
        '["https://images.unsplash.com/photo-1534215754734-18e55d13e346?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'KNR Classic Cap');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Scent No. 08', 'Perfumería', 'luxury', 139000, null, 0, 'AROMA',
        'Una propuesta olfativa cálida y envolvente. Consulta las notas y concentración antes de elegir.',
        '["Familia aromática: amaderada*","Presentación de referencia","Verifica contenido y autenticidad"]'::jsonb,
        '["https://images.unsplash.com/photo-1594035910387-fea47794261f?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Scent No. 08');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Scent No. 12', 'Perfumería', 'urban', 119000, 139000, 14, 'SELECCIÓN KNR',
        'Una fragancia de carácter fresco y moderno, pensada para acompañar el día con una presencia limpia y versátil.',
        '["Perfil fresco y moderno","Presentación de referencia","Consulta disponibilidad y contenido"]'::jsonb,
        '["https://images.unsplash.com/photo-1592945403244-b3fbafd7f539?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Scent No. 12');

insert into public.products (name, category, style, price, old_price, discount, tag, description, specs, image_urls, video_url, stock, track_inventory, reorder_level, reorder_quantity, active) select 
        'Scent No. 21', 'Perfumería', 'luxury', 159000, null, 0, 'EDICIÓN SELECTA',
        'Una propuesta intensa y elegante para quienes prefieren aromas con personalidad y una estela memorable.',
        '["Perfil cálido e intenso","Presentación de referencia","Consulta disponibilidad y contenido"]'::jsonb,
        '["https://images.unsplash.com/photo-1615634260167-c8cdede054de?auto=format&fit=crop&w=1000&q=85"]'::jsonb,
        null, 0, false, 5, 10, true
       where not exists (select 1 from public.products where name = 'Scent No. 21');
