#!/bin/sh
# [utest->req~nettoyage-outille~1]
# Test mécanisé du nettoyage : artefacts supprimés, cache préservé sans
# --all, fichiers versionnés intacts, idempotence. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

cp -R "${ROOT}/." "${TMP}/"
rm -rf "${TMP}/.git" "${TMP}/build"
fail=0

echo "clean-test — artefacts générés supprimés, cache préservé"
mkdir -p "${TMP}/build" "${TMP}/.cache"
printf 'rapport factice\n' > "${TMP}/build/tracabilite.html"
printf 'cache factice\n' > "${TMP}/.cache/temoin.txt"
(cd "${TMP}" && sh tools/clean.sh >/dev/null)
if [ -d "${TMP}/build" ]; then
    echo "ÉCHEC : build/ aurait dû être supprimé" >&2 ; fail=1
fi
if [ ! -f "${TMP}/.cache/temoin.txt" ]; then
    echo "ÉCHEC : .cache/ supprimé sans --all" >&2 ; fail=1
fi
if [ ! -f "${TMP}/README.md" ] || [ ! -f "${TMP}/AGENTS.md" ]; then
    echo "ÉCHEC : des fichiers versionnés ont été touchés" >&2 ; fail=1
fi

echo "clean-test — idempotence (dépôt déjà propre)"
if ! (cd "${TMP}" && sh tools/clean.sh >/dev/null); then
    echo "ÉCHEC : le nettoyage échoue sur un dépôt propre" >&2 ; fail=1
fi

echo "clean-test — purge du cache avec --all"
(cd "${TMP}" && sh tools/clean.sh --all >/dev/null)
if [ -d "${TMP}/.cache" ]; then
    echo "ÉCHEC : .cache/ aurait dû être supprimé avec --all" >&2 ; fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "clean-test : ÉCHEC." >&2
    exit 1
fi
echo "clean-test : OK."
