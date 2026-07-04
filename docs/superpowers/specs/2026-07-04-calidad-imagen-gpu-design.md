# Ajuste "Calidad de imagen" por GPU (render-chain de mpv)

Fecha: 2026-07-04

## Contexto

Investigación previa (deep-research) confirmó que media_kit renderiza con
`vo=libmpv`, que implementa el render-chain GPU de mpv. Por tanto las
propiedades `scale`/`cscale`/`dscale`/`deband`/`sigmoid-upscaling`/
`correct-downscaling` **sí surten efecto** vía `NativePlayer.setProperty`
(la misma vía que ya se usa para `vf` y `demuxer-*`). `vo=gpu-next` y los user
shaders quedan fuera (no disponibles/hit-or-miss en el path D3D11).

## Decisiones

- Niveles: **auto** (defecto) / **alta** / **media** / **off**.
- `auto` se resuelve por plataforma: **Windows → media**, **Android/FireTV → off**.
- Se aplica **solo a VOD** (películas y series). TV en directo sin cambios.
- **Sin user shaders** en esta versión.
- Best-effort: cada `setProperty` en try/catch; un valor no soportado nunca
  rompe la reproducción (fallback = defaults de mpv).

## Diseño

### Dominio (`lib/src/domain/image_quality.dart`) — lógica pura, testeable

```dart
enum ImageQuality { auto, alta, media, off }  // con label

/// auto -> media (no Android) u off (Android); el resto sin cambios.
ImageQuality resolveImageQuality(ImageQuality q, {required bool isAndroid});

/// Mapa de propiedades mpv para un nivel. TODOS los niveles fijan el MISMO
/// juego de claves para que cambiar de nivel sobreescriba por completo el
/// anterior (sin restos). off = defaults (bilinear, deband no).
Map<String, String> imageQualityProps(ImageQuality q);
```

Juego de claves común: `scale, cscale, dscale, deband, sigmoid-upscaling,
correct-downscaling, linear-downscaling`.
- **off**: bilinear/bilinear/bilinear, deband=no, sigmoid=no, correct=no, linear=no.
- **media**: spline36/spline36/mitchell, deband=yes, sigmoid=yes, correct=yes, linear=no.
- **alta**: ewa_lanczossharp/ewa_lanczossharp/mitchell, deband=yes, sigmoid=yes,
  correct=yes, linear=yes.

### Controlador (`media_kit_player_controller.dart`)

```dart
/// Aplica el chain de calidad (best-effort) sobre el NativePlayer.
Future<void> setVideoQuality(Map<String, String> props);
```

### Provider (`providers.dart`)

`imageQualityProvider` (StateProvider<ImageQuality>, persistido en
`image_quality`, defecto `auto`) + `setImageQuality`.

### Aplicación (`player_screen.dart`)

En `initState`, solo si el item es VOD: resolver con
`resolveImageQuality(ref.read(imageQualityProvider), isAndroid: Platform.isAndroid)`
y llamar `_ctrl.setVideoQuality(imageQualityProps(nivel))` tras `configure`.

### UI (`settings_tab.dart`)

Selector de 4 niveles (ListTile + DropdownButton) junto a Aceleración/
Desentrelazado, con subtítulo explicativo (aplica a películas/series al abrir).

### Backup

Añadir `image_quality` a `kBackupPrefsKeys`.

## Pruebas (TDD)

- `resolveImageQuality`: auto+Android→off; auto+!Android→media; alta/media/off
  sin cambios en cualquier plataforma.
- `imageQualityProps`: off→scale=bilinear & deband=no; media→scale=spline36 &
  deband=yes; alta→scale=ewa_lanczossharp; los tres niveles devuelven el mismo
  conjunto de claves.

## Fuera de alcance

- User shaders (FSR/RAVU/FSRCNNX/NNEDI3/Anime4K).
- Tone-mapping HDR avanzado (requiere gpu-next, no disponible).
- Detección de GPU concreta (auto se basa solo en plataforma).
- Aplicar a TV en directo.
