# KNR — Time is yours

Tienda KNR en React + Vite. Incluye catálogo responsive, selector Urban/Luxury, combos, carrito, checkout y panel de administración con Supabase.

## Ejecutar localmente

```bash
npm install
cp .env.example .env.local
npm run dev
```

## Configurar Supabase

1. Crea un proyecto en Supabase.
2. En **Project Settings → API**, copia Project URL y la clave pública (anon/publishable).
3. Coloca los valores en `.env.local`:

```env
VITE_WHATSAPP_NUMBER=573XXXXXXXXX
VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
VITE_SUPABASE_ANON_KEY=TU_CLAVE_PUBLICA
```

4. Abre **SQL Editor** en Supabase y ejecuta el contenido completo de `supabase/schema.sql`. Si ya habías configurado Supabase antes de esta actualización, vuelve a ejecutar el archivo completo: añade columnas multimedia e inventario, las tablas privadas `product_costs` y `operating_expenses`, la biblioteca `music_tracks`, la tabla privada `orders`, sus políticas RLS y la función transaccional `place_order`. La función también valida y calcula en servidor los descuentos de combos; vuelve a ejecutar el archivo para aplicar esta corrección.
5. En **Authentication → Users**, crea el usuario administrador con correo y contraseña.
6. Copia su UUID y autorízalo ejecutando en SQL Editor:

```sql
insert into public.admin_users(user_id)
values ('UUID-DEL-USUARIO-ADMIN');
```

7. Inicia la aplicación y entra en `/admin`.

La clave usada en el frontend debe ser la clave pública de Supabase. Nunca coloques la `service_role` key en variables `VITE_*`, código de navegador ni repositorio. La autorización administrativa se valida mediante Auth y políticas RLS.

## Funciones incluidas

- Portada de marca y ambientes Urban / Luxury.
- Catálogo conectado a Supabase cuando se configura el backend; los productos de muestra sirven como vista previa mientras no haya catálogo.
- Filtros y búsqueda, ficha de producto y galería de imágenes.
- Carrito guardado en el navegador y límites de unidades disponibles cuando el producto tiene inventario controlado.
- Inventario por producto: activa el control de stock desde el administrador, define las unidades y la tienda bloquea la compra cuando no quedan existencias. Registra también el costo de compra por unidad en una tabla privada de administración (no se expone en el catálogo público) para calcular la utilidad bruta.
- Pedidos persistidos en Supabase mediante `place_order`: el servidor vuelve a comprobar disponibilidad, calcula el total con precios vigentes, valida el combo (mínimo dos artículos y al menos un reloj), aplica el descuento correspondiente solo a sus artículos y descuenta el inventario de forma transaccional. El pedido conserva el precio de lista y el precio aplicado por unidad.
- Panel privado de pedidos con datos de entrega, detalle de artículos, total y estados: pendiente, confirmado, preparando, enviado, entregado o cancelado.
- Resumen administrativo de pedidos, pendientes, ventas entregadas y alertas de inventario bajo (5 unidades o menos), con acceso directo para ajustar el stock.
- Historial de pedidos paginado (50 por página), con filtros por estado y fechas, contador total y exportación CSV de todo el conjunto filtrado (descarga por bloques para superar el límite de una sola consulta).
- Reportes históricos mediante `admin_order_report`: pedidos totales, pendientes, ventas entregadas, costo de productos, utilidad y margen bruto, gastos operativos, utilidad neta estimada y margen neto, top 5 productos por utilidad, 5 productos con menor utilidad para revisión, rentabilidad por categoría (unidades, ingresos, costo, utilidad y margen) y evolución mensual de los últimos 12 meses calculados en PostgreSQL sobre todos los pedidos coincidentes con los filtros, sin depender de la página visible. Los gastos se registran por fecha y categoría (envío, empaque, publicidad, comisiones, operación u otros) desde el panel administrativo. Los pedidos históricos anteriores al registro de costos se calculan con costo cero hasta que se actualicen sus snapshots; la rentabilidad histórica anterior no puede reconstruirse automáticamente. La gráfica compara ventas entregadas del mes actual frente al anterior. Ejecuta `supabase/schema.sql` completo en Supabase SQL Editor para instalar o actualizar esta función.
- Constructor de combos: reloj obligatorio y accesorios opcionales. Descuento adicional automático por cantidad (2 productos: 5%, 3: 10%, 4 o más: 15%), aplicado al precio vigente de cada artículo.
- Formulario de entrega: nombre, teléfono, barrio, dirección, detalles de apartamento/conjunto/piso y persona que recibe.
- Resumen del pedido preparado para WhatsApp. El cliente revisa y envía el mensaje desde su propia cuenta.
- Panel `/admin` con login, alta/edición/eliminación de productos, visibilidad, precio base, descuento porcentual y subida de imágenes.
- Gestor de campañas y banners de portada: texto, imagen o vídeo MP4 público, enlace, prioridad, visibilidad y ambiente Urban/Luxury/Todos. La portada consume la campaña activa de mayor prioridad para el ambiente elegido.
- Ficha de producto con vídeo MP4 opcional además de fotografías.
- Biblioteca musical administrable por ambiente: nombre, URL directa de audio, prioridad y publicación. El reproductor discreto reproduce la lista activa correspondiente a Urban o Luxury y pasa a la siguiente pista al terminar.
- Favicon KNR.

## Importante antes de publicar

- Los productos de muestra y fotografías de Unsplash son referencias de diseño; reemplázalos por inventario, imágenes y especificaciones verificadas.
- La biblioteca musical necesita pistas de audio autorizadas cargadas desde `/admin`.
- El panel administrativo gestiona catálogo, inventario, banners, vídeos, música y pedidos. La confirmación del pedido y la coordinación de entrega siguen dependiendo de la conversación con el cliente.
- El pedido queda registrado con estado `pending` antes de abrir WhatsApp. WhatsApp no confirma pagos ni entregas: el equipo debe actualizar manualmente el estado desde `/admin`. Si se cancela antes del despacho, el inventario reservado se devuelve automáticamente; los pedidos enviados o entregados requieren gestión de devolución.
- Añade aviso de privacidad y define el tratamiento de datos personales conforme a la normativa colombiana antes de operar.
- Prueba la aplicación en un entorno de despliegue y configura las variables de entorno en el proveedor de hosting.
\n\n- Reportes históricos mediante `admin_order_report`: conteo total, pedidos pendientes, ventas entregadas y top 5 productos calculados en PostgreSQL sobre todos los pedidos que coinciden con los filtros, sin depender de la página visible. Tras actualizar `supabase/schema.sql`, ejecutar el archivo completo en Supabase SQL Editor para habilitar la función.\n