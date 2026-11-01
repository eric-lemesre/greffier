#!/bin/sh
# Construit l'image disque macOS de Greffier (ADR-0005) : un binaire
# universel (Apple Silicon et Intel, assemblés par lipo), installé dans
# /usr/local/bin par un paquet .pkg, livré dans un .dmg avec la licence et
# la documentation. Ni le paquet ni l'image ne sont signés pour l'instant :
# le README dit comment les ouvrir malgré Gatekeeper.
#
#   sh packaging/macos/construire-dmg.sh VERSION BINAIRE_ARM64 BINAIRE_X86_64 SORTIE.dmg
#
# POSIX sh strict ; lipo, pkgbuild, hdiutil (outils de macOS).
# [impl->req~paquets-natifs~1]
set -eu

if [ "$#" -ne 4 ]; then
    echo "Usage : sh packaging/macos/construire-dmg.sh VERSION BINAIRE_ARM64 BINAIRE_X86_64 SORTIE.dmg" >&2
    exit 2
fi
version="$1"
arm64="$2"
x86_64="$3"
sortie="$4"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
travail="$(mktemp -d)"
trap 'rm -rf "${travail}"' EXIT

mkdir -p "${travail}/racine/usr/local/bin" "${travail}/image"
lipo -create -output "${travail}/racine/usr/local/bin/greffier" "${arm64}" "${x86_64}"
chmod 755 "${travail}/racine/usr/local/bin/greffier"

pkgbuild --root "${travail}/racine" \
    --identifier io.github.eric-lemesre.greffier \
    --version "${version}" \
    --install-location / \
    "${travail}/image/greffier-${version}.pkg"

cp "${ROOT}/LICENSE" "${travail}/image/LICENSE.txt"
cp "${ROOT}/README.md" "${ROOT}/NEWS.md" "${travail}/image/"

hdiutil create -volname "Greffier ${version}" -srcfolder "${travail}/image" \
    -format UDZO -ov "${sortie}"
