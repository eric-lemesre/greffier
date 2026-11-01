#!/bin/sh
# [impl->req~chaine-de-verification-du-moteur~1]
# En-têtes de licence du code du moteur (ADR-0002, section Vérification) :
# chaque fichier Rust de src/ et de tests/, et le manifeste Cargo.toml,
# porte dans ses trois premières lignes l'en-tête
#   SPDX-License-Identifier: EUPL-1.2
# Seul le code du moteur est concerné : l'outillage tools/ et templates/
# vient du gabarit alm-forge et garde sa propre licence.
#
#   sh tools/spdx.sh [racine]
#
# POSIX sh strict ; find, head, grep.
set -eu

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "${ROOT}"

ENTETE='SPDX-License-Identifier: EUPL-1.2'
fail=0
vus=0

for fichier in $( { [ -f Cargo.toml ] && echo Cargo.toml ; for d in src tests ; do [ -d "$d" ] && find "$d" -type f -name '*.rs' ; done ; } | LC_ALL=C sort ); do
    vus=$((vus + 1))
    if ! head -n 3 "${fichier}" | grep -q "${ENTETE}"; then
        echo "ÉCHEC : en-tête « ${ENTETE} » absent des trois premières lignes : ${fichier}" >&2
        fail=1
    fi
done

if [ "${fail}" -ne 0 ]; then
    exit 1
fi
echo "en-têtes de licence : ${vus} fichier(s) du moteur conforme(s)."
