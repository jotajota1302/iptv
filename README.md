# IPTV Player

Reproductor de listas IPTV (M3U/M3U8) multiplataforma hecho con Flutter y
media_kit. TV en directo por categorías, favoritos, buscador y reproducción de
streams MPEG-TS/HLS.

## Requisitos

- Flutter estable (canal `stable`), Dart >= 3.4.
- Windows: Visual Studio Build Tools 2022 con el workload **Desktop development
  with C++** (para `flutter build windows`).

## Arranque

```bash
flutter pub get
dart run build_runner build   # genera el código de Drift
flutter test                  # 17 tests
flutter run -d windows
```

## IMPORTANTE: parche de libmpv (desentrelazado)

`media_kit` empaqueta una build **mínima** de `libmpv-2.dll` que **no incluye
ningún filtro de desentrelazado** (`bwdif`, `yadif`, ...). Sin ellos, la TV en
directo entrelazada (1080i) se ve con "líneas peine" (combing) y no hay forma de
corregirlo por código.

La solución es sustituir esa DLL por una build **completa** de mpv. Tras cada
`flutter build windows`, ejecuta:

```bash
bash tool/patch_libmpv.sh
```

El script descarga (si hace falta) la build completa de
[`shinchiro/mpv-winbuild-cmake`](https://github.com/shinchiro/mpv-winbuild-cmake)
y reemplaza `libmpv-2.dll` en `build/windows/x64/runner/{Debug,Release}`.
La DLL (117 MB) no se versiona porque supera el límite de tamaño de GitHub; se
guarda localmente en `third_party/libmpv/` (ignorada por git).

## Ajustes de reproducción (en la app)

- **Desentrelazado (deinterlace)**: activado por defecto; aplica `bwdif`.
  Corrige el combing de la TV en directo.
- **Aceleración por hardware (GPU)**: por si aparecen artefactos en 4K.

Ambos se guardan entre sesiones (`shared_preferences`).

## Documentación de diseño

- Diseño: `docs/superpowers/specs/2026-07-01-iptv-player-design.md`
- Plan Fase 1: `docs/superpowers/plans/2026-07-01-iptv-player-fase1.md`
