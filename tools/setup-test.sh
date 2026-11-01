#!/bin/sh
# Test mécanisé du parcours d'accueil : exécute setup.sh sur une copie
# temporaire et vérifie ses critères d'acceptation : hooks installés, état des
# portes RAPPORTÉ sans faire échouer l'accueil, idempotence, et échec du
# bootstrap sur un prérequis manquant.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

echo "setup-test — copie de travail dans ${TMP}"
cp -R "${ROOT}/." "${TMP}/"
rm -rf "${TMP}/.git" "${TMP}/build"
# Un fichier d'identifiants local ne suit pas la copie : l'accueil n'en a
# aucun besoin, et un tel fichier n'a rien à faire dans un répertoire
# temporaire, fût-ce le temps d'une exécution.
rm -f "${TMP}/.env"
(cd "${TMP}" && git init -q && git add -A &&
    git -c user.name="Setup Test" -c user.email="setup-test@example.invalid" \
        -c commit.gpgsign=false commit -q -m "gabarit: état initial")

fail=0

echo "setup-test — premier accueil"
if ! sortie_saine="$( (cd "${TMP}" && sh tools/setup.sh) 2>&1 )"; then
    echo "ÉCHEC : setup.sh a échoué sur un clone frais" >&2
    printf '%s\n' "${sortie_saine}" | tail -20 | sed 's/^/        /' >&2
    fail=1
fi
case "${sortie_saine}" in
    *"État du dépôt :"*) ;;
    *) echo "ÉCHEC : l'accueil ne rapporte pas l'état du dépôt" >&2 ; fail=1 ;;
esac
hooks_path="$(cd "${TMP}" && git config core.hooksPath || true)"
if [ "${hooks_path}" != ".githooks" ]; then
    echo "ÉCHEC : hooks non installés (core.hooksPath = '${hooks_path}')" >&2
    fail=1
fi

echo "setup-test — idempotence (second accueil)"
if ! (cd "${TMP}" && sh tools/setup.sh >/dev/null); then
    echo "ÉCHEC : setup.sh n'est pas relançable" >&2
    fail=1
fi

echo "setup-test — porte en échec : l'accueil renseigne et REUSSIT"
# Le cas d'échec de req~accueil-informatif~1, joué sur son défaut réel. Une
# porte légitimement rouge — une traçabilité qui attend la réalisation
# d'exigences déjà écrites — ne doit pas faire échouer le premier geste d'un
# arrivant. Mais elle ne doit pas non plus disparaître : un accueil muet
# laisserait croire le dépôt sain, ce qui est pire que l'accueil qui échoue.
printf '\n[lien mort](fichier-qui-nexiste-pas.md)\n' >> "${TMP}/docs/methode/README.md"
if ! sortie_cassee="$( (cd "${TMP}" && sh tools/setup.sh) 2>&1 )"; then
    echo "ÉCHEC : l'accueil échoue sur une porte rouge au lieu de la rapporter" >&2
    fail=1
fi
case "${sortie_cassee}" in
    *"État du dépôt : des portes sont en ÉCHEC"*) ;;
    *) echo "ÉCHEC : l'accueil ne dit pas qu'une porte est en échec" >&2 ; fail=1 ;;
esac
case "${sortie_cassee}" in
    *"ÉCHEC    liens"*) ;;
    *) echo "ÉCHEC : le bilan de l'accueil ne nomme pas la porte fautive" >&2 ; fail=1 ;;
esac
# Remise en état : les cas suivants ne portent pas sur ce défaut.
(cd "${TMP}" && git checkout -- docs/methode/README.md 2>/dev/null) || \
    sed -i '$ d' "${TMP}/docs/methode/README.md"

echo "setup-test — bootstrap doit échouer si un prérequis du socle manque"
if (cd "${TMP}" && PATH="" sh tools/bootstrap.sh) >/dev/null 2>&1; then
    echo "ÉCHEC : bootstrap.sh a réussi sans aucun outil dans le PATH" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "setup-test : ÉCHEC." >&2
    exit 1
fi
echo "setup-test : OK."
