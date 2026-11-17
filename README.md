# KNR — Time is yours

Tienda inicial de KNR construida con React + Vite.

## Ejecutar localmente

```bash
npm install
npm run dev
```

## Configuración pendiente

Crea un archivo `.env.local` (no lo subas a GitHub) con:

```env
VITE_WHATSAPP_NUMBER=573XXXXXXXXX
```

Usa el número de WhatsApp de la tienda con indicativo de país, solo dígitos.

## Estado de esta primera entrega

- Portada KNR con selector Urban / Luxury.
- Catálogo demostrativo y filtros por categoría.
- Ficha de producto, galería básica y carrito persistente en el navegador.
- Constructor inicial de combos (el reloj es el punto de partida).
- Cálculo de precios y descuentos por producto.
- Preparación de pedido y apertura de WhatsApp con el resumen.
- Diseño adaptable a móvil, tablet y escritorio.

## Antes de publicar como tienda real

Esta versión es una base visual funcional con datos de demostración. La edición de catálogo en el panel de administración, inventario compartido, descuentos por reglas de combo, almacenamiento de imágenes/vídeos y autenticación segura todavía requieren integrar un backend. La siguiente fase recomendada es Supabase (Auth + PostgreSQL + Storage) con políticas RLS y un panel protegido. No se deben guardar credenciales de administrador en el frontend.

Las imágenes actuales son referencias externas de Unsplash, no fotografías de inventario real. Confirma especificaciones, resistencia al agua, materiales y autenticidad con el proveedor antes de publicar fichas definitivas.

El control de sonido es por ahora una interfaz visual: se integrará audio con archivos autorizados cuando se definan las pistas. Los navegadores exigen interacción del usuario antes de iniciar reproducción.

## Privacidad y WhatsApp

El flujo genera un mensaje para que el cliente lo revise y lo envíe desde WhatsApp. El sitio no transmite automáticamente el pedido ni valida el pago. Añade aviso de privacidad y define el tratamiento de datos personales conforme a la normativa aplicable en Colombia antes de operar.
