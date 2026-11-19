# Tema CIDATA / REVEDACYT

Tema hijo de `default` para OJS 3.5. Implementa la identidad nocturna de
REVEDACYT: azul noche, dorado y cian institucional.

## Activación

El tema se monta desde `theme/revedacyt` en el contenedor. En una instalación
nueva:

1. **Administración del sitio → Módulos**: instalar/activar
   **CIDATA · REVEDACYT**.
2. **Ajustes de la revista → Web → Apariencia → Tema**: seleccionarlo.

En desarrollo, `dev/compose.yaml` monta la misma carpeta:

```yaml
- ../theme/revedacyt:/var/www/html/plugins/themes/revedacyt:Z
```

La instancia local de prueba está en
`http://localhost:8080/index.php/revista-prueba/es/index`.

Vistas previas: `preview-home.png` y `preview-mobile.png`.

## Opciones del tema

En **Ajustes de la revista → Web → Apariencia → Tema**:

- **Barra institucional**: mostrar u ocultar la barra superior.
- **Dirección institucional** y **correo de contacto**.
- **URLs de Instagram, YouTube, Facebook y TikTok** (si están vacías, no se
  muestran).
- **Texto superior del hero** (kicker).
- **Logos institucionales en el pie**.

También conviene ajustar:

- **Tipografía:** Lato.
- **Color base:** `#00ABCC` (el tema aplica sus propios colores por CSS).
- **Logotipo de la revista:** se sube desde el admin de OJS.
- **Miniatura:** se sube desde el admin de OJS.
- **Favicon:** se sube desde el admin de OJS.
- **Imagen de la página de inicio:** una foto 2000 × 900 para el hero.

## Assets incluidos

| Archivo | Uso |
|---|---|
| `assets/logo.png` | Logo de respaldo si no se sube uno en OJS. Versión dorada/blanca. |
| `assets/institutional-logos.png` | Logos CIDATA + MINCYT para el pie. |
| `assets/hero-fallback.jpg` | Campo de estrellas generado para el hero si no hay `homepageImage`. |
| `assets/favicon.ico` / `favicon-32.png` | Favicon de respaldo si la revista no tiene uno. |

## Estructura

- `RevedacytThemePlugin.php`: opciones, estilos y herencia de `default`.
- `styles/index.css`: colores, encabezado, hero, tarjetas, pie y responsive.
- `templates/frontend/components/header.tpl`: barra superior y logo de respaldo.
- `templates/frontend/components/headerHead.tpl`: favicon de respaldo.
- `templates/frontend/components/footer.tpl`: pie institucional.
- `templates/frontend/pages/indexJournal.tpl`: portada con hero y secciones.
- `locale/es`, `locale/en`: textos de la interfaz del tema.

## Notas

- No modifica el núcleo de OJS.
- Es hijo de `default`; el padre se referencia como `defaultthemeplugin`
  (nombre del plugin, no la carpeta).
- La opción **"Usar la imagen de inicio como encabezado"** debe quedar
  desactivada: el hero se encarga de la imagen.
- Al actualizar OJS, comparar las tres plantillas copiadas con las del tema
  base y adaptar los cambios.
- El logo de respaldo es la versión oscura. Sobre un encabezado blanco no se
  vería; este tema usa encabezado azul noche.
- El hero usa `homepageImage` si está configurada; si no, el campo de estrellas.
- El pie muestra los logos institucionales si la opción está activa.

## Producción

El tema se monta desde el repositorio con `compose.yaml`; no se construye una
imagen propia. Para actualizarlo:

```bash
git pull
sudo docker compose up -d app
```

Ver [`../README.md`](../README.md).
