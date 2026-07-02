# Publicar una versión nueva

La app comprueba actualizaciones contra los **GitHub Releases** de este repo
(`lib/src/data/update_service.dart`). Para que los usuarios reciban el aviso:

1. Sube `version:` en `pubspec.yaml` (p. ej. `1.1.0+2`). Es la única fuente:
   la app lee su propia versión compilada con `package_info_plus`.
2. Compila y empaqueta:
   - Build comercial (LGPL): `flutter build windows --release` y después
     `bash tool/use_libmpv_lgpl.sh`.
   - Zip con `tar.exe -a -c -f` (no `Compress-Archive`: rompe los separadores).
3. Crea el release con **tag de versión** `vX.Y.Z` (los tags que no son de
   versión, como `libmpv-lgpl-*`, se ignoran):

   ```bash
   gh release create v1.1.0 IPTV-Player-Windows.zip \
     --title "v1.1.0" --notes "Cambios de esta versión..."
   ```

   El campo *notes* es lo que la app muestra como changelog en el diálogo de
   actualización.

Los borradores y prereleases no cuentan; se publica al marcarlo como latest.

## White-label

El feed se fija en compilación: `--dart-define=UPDATE_FEED=<url>` apunta a un
endpoint propio con el mismo formato JSON que la API de GitHub Releases, y
`--dart-define=UPDATE_FEED=off` desactiva el chequeo por completo.
