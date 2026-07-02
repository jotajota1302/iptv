# Builds white-label (marca de proveedor)

La app soporta rebranding en tiempo de compilación con `--dart-define`,
sin tocar código. Sin defines, la build es la marca propia ("IPTV Player").

## Parámetros

| Define | Ejemplo | Efecto |
|---|---|---|
| `BRAND_NAME` | `"Acme TV"` | Nombre de la app: título de ventana, Ajustes, lista guardada del login. |
| `BRAND_ACCENT` | `FF00A5FF` | Color de acento inicial (hex RGB o ARGB). El usuario puede cambiarlo después. |
| `BRAND_SERVER` | `http://portal.acme.tv:8080` | **Activa el modo proveedor**: Ajustes muestra login usuario/contraseña contra este servidor, y las URLs (con credenciales) dejan de mostrarse. |

## Ejemplos

Windows:

```bash
flutter build windows --release \
  --dart-define=BRAND_NAME="Acme TV" \
  --dart-define=BRAND_ACCENT=FF00A5FF \
  --dart-define=BRAND_SERVER=http://portal.acme.tv:8080
bash tool/patch_libmpv.sh
```

Android / Fire TV:

```bash
flutter build apk --release \
  --dart-define=BRAND_NAME="Acme TV" \
  --dart-define=BRAND_SERVER=http://portal.acme.tv:8080
```

## Pendiente por marca (manual, por ahora)

- Icono y banner de TV (`windows/runner/resources`, `android/app/src/main/res`).
- `applicationId` de Android distinto por marca (para instalar varias).
- Nombre del ejecutable/instalador de Windows.

## Licencias

Para distribución comercial cerrada, la app debe empaquetarse con el
**libmpv LGPL** generado por el workflow `build-libmpv-lgpl` (artifact
`libmpv-lgpl-windows-x64`), no con el build GPL completo de desarrollo:

```bash
flutter build windows --release [--dart-define=...]
bash tool/use_libmpv_lgpl.sh   # sustituye libmpv por el paquete LGPL
```

El script verifica el SHA256 de la DLL y copia también `licenses/` (textos
LGPL de mpv y FFmpeg), que deben distribuirse junto a la app. Verificado:
reproduce HLS con decodificación activa (mpv 0.39 + FFmpeg n7.1; bwdif/yadif
son LGPL, así que el desentrelazado se conserva).
