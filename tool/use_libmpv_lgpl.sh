#!/usr/bin/env bash
# Sustituye el libmpv de la build Release por el paquete LGPL (apto para
# distribución comercial cerrada con enlazado dinámico).
#
# Uso:  bash tool/use_libmpv_lgpl.sh [ruta/al/libmpv-lgpl-windows-x64.zip]
#
# El zip lo genera el workflow de CI `build-libmpv-lgpl` (artifact
# libmpv-lgpl-windows-x64). Por defecto se busca en la raíz del proyecto
# (está gitignorado) y, si no, en el Escritorio.
# El desarrollo diario puede seguir usando patch_libmpv.sh (build GPL
# completo); este script es para las builds que se van a distribuir.
set -euo pipefail

ZIP="${1:-libmpv-lgpl-windows-x64.zip}"
[ -f "$ZIP" ] || ZIP="$HOME/Desktop/libmpv-lgpl-windows-x64.zip"
# SHA256 de la libmpv-2.dll LGPL conocida (mpv 0.39 + FFmpeg n7.1, run
# 28599441631). Si regeneras el paquete en CI, actualiza este valor con el
# SHA256SUMS.txt del artifact.
DLL_SHA256="f22512f5d05a9a016f3dcec4fe453eb688b7f30c263c21f65570e98a4ebe1e6a"
DEST="build/windows/x64/runner/Release"

[ -f "$ZIP" ] || { echo "No existe el zip: $ZIP"; exit 1; }
[ -d "$DEST" ] || { echo "No existe $DEST (compila antes con flutter build windows --release)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$ZIP" -d "$TMP"

echo "$DLL_SHA256 *$TMP/libmpv-2.dll" | sha256sum -c - >/dev/null \
  || { echo "SHA256 de libmpv-2.dll NO coincide: zip inesperado."; exit 1; }

rm -f "$DEST/libmpv-2.dll"
cp -f "$TMP"/*.dll "$DEST/"
mkdir -p "$DEST/licenses"
cp -f "$TMP"/licenses/* "$DEST/licenses/" 2>/dev/null || true

echo "Release ahora usa libmpv LGPL ($(du -sh "$TMP" | cut -f1) de DLLs)."
echo "Recuerda distribuir la carpeta licenses/ junto a la app."
