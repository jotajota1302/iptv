#!/usr/bin/env bash
# Sustituye la libmpv-2.dll mínima que empaqueta media_kit por una build
# COMPLETA (con los filtros de desentrelazado bwdif/yadif), imprescindible para
# ver bien la TV en directo entrelazada (1080i).
#
# La build mínima de media_kit no incluye ningún filtro de desentrelazado, así
# que hay que parchear la DLL en la salida de compilación tras cada
# `flutter build windows`.
#
# Uso:
#   bash tool/patch_libmpv.sh            # parchea Debug y Release si existen
#
# Fuente de la DLL completa: shinchiro/mpv-winbuild-cmake (estándar de la
# comunidad para builds de mpv en Windows). Se verifica por SHA256 tanto el
# archivo descargado como la DLL antes de usarla (defensa cadena de suministro).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_DLL="$ROOT/third_party/libmpv/libmpv-2.dll"
MPV_TAG="20260610"
MPV_FILE="mpv-dev-x86_64-20260610-git-304426c.7z"
MPV_URL="https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/$MPV_TAG/$MPV_FILE"
SEVENZIP="/c/Program Files/7-Zip/7z.exe"

# Hashes fijados de la versión verificada (20260610). Si actualizas MPV_TAG/
# MPV_FILE, recalcula ambos con `sha256sum`.
SHA256_7Z="8cbb25ea784f01afbb3f904217cab1317430a8bcfd5680fd827a866367f71cc9"
SHA256_DLL="5c876d79e070529128331591b48f87846fb30557f19c11280df9c6ee9b6dbafa"

verify_dll() {
  echo "$SHA256_DLL  $LOCAL_DLL" | sha256sum -c - >/dev/null 2>&1
}

# Obtener/verificar la DLL completa en third_party/.
if [ ! -f "$LOCAL_DLL" ] || ! verify_dll; then
  echo "libmpv completa ausente o con hash incorrecto; descargando build verificada..."
  mkdir -p "$ROOT/third_party/libmpv"
  tmp7z="$(mktemp -u).7z"
  curl -sL --max-time 300 "$MPV_URL" -o "$tmp7z"
  # Verificar el archivo ANTES de extraer nada de él.
  if ! echo "$SHA256_7Z  $tmp7z" | sha256sum -c - >/dev/null 2>&1; then
    echo "ERROR: el SHA256 del archivo descargado NO coincide. Abortando." >&2
    rm -f "$tmp7z"
    exit 1
  fi
  "$SEVENZIP" e "$tmp7z" -o"$ROOT/third_party/libmpv" "libmpv-2.dll" -y >/dev/null
  rm -f "$tmp7z"
  if ! verify_dll; then
    echo "ERROR: el SHA256 de la DLL extraída NO coincide. Abortando." >&2
    exit 1
  fi
fi

patched=0
for cfg in Debug Release; do
  dst="$ROOT/build/windows/x64/runner/$cfg/libmpv-2.dll"
  if [ -f "$dst" ]; then
    cp "$LOCAL_DLL" "$dst"
    echo "Parcheada libmpv-2.dll en $cfg ($(du -h "$dst" | cut -f1))"
    patched=1
  fi
done

if [ "$patched" -eq 0 ]; then
  echo "No hay build/windows/.../runner/{Debug,Release}. Compila primero con 'flutter build windows'."
  exit 1
fi
echo "Listo."
