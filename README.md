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

4. Abre **SQL Editor** en Supabase y ejecuta el contenido completo de `supabase/schema.sql`. Si ya habías configurado Supabase antes de esta actualización, vuelve a ejecutar el archivo para crear también la tabla de campañas `store_banners` y sus políticas.
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
- Carrito guardado en el navegador.
- Constructor de combos: reloj obligatorio y accesorios opcionales. Descuento adicional automático por cantidad (2 productos: 5%, 3: 10%, 4 o más: 15%), aplicado al precio vigente de cada artículo.
- Formulario de entrega: nombre, teléfono, barrio, dirección, detalles de apartamento/conjunto/piso y persona que recibe.
- Resumen del pedido preparado para WhatsApp. El cliente revisa y envía el mensaje desde su propia cuenta.
- Panel `/admin` con login, alta/edición/eliminación de productos, visibilidad, precio base, descuento porcentual y subida de imágenes.
- Gestor de campañas y banners de portada: texto, imagen pública, enlace, prioridad, visibilidad y ambiente Urban/Luxury/Todos. La portada consume el banner activo de mayor prioridad para el ambiente elegido.
- Favicon KNR.

## Importante antes de publicar

- Los productos de muestra y fotografías de Unsplash son referencias de diseño; reemplázalos por inventario, imágenes y especificaciones verificadas.
- El reproductor musical aún necesita pistas de audio autorizadas y su integración real. El control visual actual es una maqueta, no reproduce audio.
- El panel administrativo gestiona productos e imágenes. Banners, música, vídeos promocionales, reglas avanzadas de combos y pedidos almacenados todavía son etapas posteriores.
- WhatsApp no confirma pagos ni registra automáticamente órdenes en una base de datos; solo prepara el mensaje con los artículos y datos que el cliente introduce.
- Añade aviso de privacidad y define el tratamiento de datos personales conforme a la normativa colombiana antes de operar.
- Prueba la aplicación en un entorno de despliegue y configura las variables de entorno en el proveedor de hosting.
