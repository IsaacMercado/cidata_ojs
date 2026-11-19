# Tema REVEDACYT

Tema hijo del tema `default` de OJS 3.5. Implementa el encabezado azul noche,
el logo dorado, el hero astronómico y los acentos cian de la revista.

## Estructura

```text
theme/
└── revedacyt/              # plugin del tema
    ├── index.php
    ├── RevedacytThemePlugin.php
    ├── version.xml
    ├── settings.xml
    ├── styles/index.css
    ├── templates/frontend/
    ├── assets/
    ├── locale/en|es
    └── README.md
```

El tema no se compila ni se copia dentro de una imagen. `compose.yaml` lo monta
directamente en el contenedor:

```yaml
- ./theme/revedacyt:/var/www/html/plugins/themes/revedacyt
```

Por eso actualizarlo es tan simple como cambiar los archivos y reiniciar la
aplicación.

## Producción

El tema vive en el repositorio y se monta en OJS:

```bash
git pull
sudo docker compose up -d app
```

Si cambias el CSS, OJS puede mantener una copia concatenada en caché. Fuerza una
recarga del navegador (`Ctrl+F5`) y, si hace falta, limpia la caché del
contenedor:

```bash
sudo docker exec ojs-app sh -c 'rm -f /var/www/html/cache/*.css'
```

La primera vez hay que activarlo en el admin:

**Ajustes de la revista → Web → Apariencia → Tema → REVEDACYT**

Después, el logo, la miniatura, el favicon y la imagen de portada se suben una
sola vez desde el admin. El tema incluye respaldos para el logo, el favicon y el
hero, así que la portada funciona sin subir nada.

## Desarrollo local

`dev/compose.yaml` monta la misma carpeta. Los cambios se ven al recargar la
página; si OJS mantiene caché, reinicia el contenedor:

```bash
cd dev
podman compose restart app
```

La instancia local queda en:

```text
http://localhost:8080/index.php/revista-prueba/es/index
```

## Actualizar OJS

Cambia `OJS_VERSION` en `.env` y ejecuta:

```bash
sudo docker compose pull app
sudo docker compose up -d app
sudo docker exec ojs-app /usr/local/bin/pkp-upgrade
```

La versión anterior de la imagen queda disponible para volver atrás.

## Opciones del tema

En **Ajustes de la revista → Web → Apariencia → Tema**:

- Barra institucional.
- Dirección y correo.
- URLs de Instagram, YouTube, Facebook y TikTok.
- Texto superior del hero.
- Logos institucionales en el pie.

Tipografía recomendada: **Lato**. Color base: **#00ABCC**. No actives “Usar la
imagen de inicio como encabezado”; el hero ya usa `homepageImage`.

## Notas

- No modifica el núcleo de OJS.
- Es hijo de `default`; el padre se referencia como `defaultthemeplugin`.
- Al actualizar OJS, compara las plantillas copiadas con las del tema base.
- El tema es específico de REVEDACYT/CIDATA (logo y pie institucional).
