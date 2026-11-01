#!/bin/sh
# Met à jour VERSION : tools/bump.sh X.Y.Z (compléter le CHANGELOG à la main,
# tools/checks.sh vérifie la cohérence). POSIX sh strict.
# Exigence servie : req~versionnement-release~1.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

v="${1:-}"
if [ -z "${v}" ]; then
    echo "Usage : tools/bump.sh X.Y.Z" >&2
    exit 2
fi

printf '%s\n' "${v}" > "${ROOT}/VERSION"
echo "VERSION → ${v}."
echo "Compléter CHANGELOG.md (section [${v}]) : tools/checks.sh le vérifie."
