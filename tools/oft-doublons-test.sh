#!/bin/sh
# Test du contrôle des définitions en double de tools/oft.sh (sous-commande
# « doublons », jouée aussi en tête de « trace ») sur son cas d'échec (R3) :
# un identifiant repris en colonne 0 dans un second fichier échoue en
# nommant l'identifiant et les deux fichiers, même suivi de texte ; une
# citation indentée ou en milieu de phrase passe. Aucun Java requis : le
# contrôle précède l'appel à OpenFastTrace. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

mkdir -p "${TMP}/tools" "${TMP}/spec" "${TMP}/docs"
cp "${ROOT}/tools/oft.sh" "${TMP}/tools/"
printf '# Exigences\n\n`req~a~1`\n\nLe système DOIT a.\n\nNeeds: impl\n' > "${TMP}/spec/a.md"
controle() { (cd "${TMP}" && sh tools/oft.sh doublons 2>&1); }

echo "oft-doublons-test — [A] une seule définition, citations indentées ou dans la phrase : passe"
printf '# Journal\n\n- Ajout de `req~a~1`.\n  `req~a~1`, et la suite\n    `req~a~1`\n' > "${TMP}/CHANGELOG.md"
if ! controle >/dev/null; then
    echo "ÉCHEC [A] : des citations sont prises pour des définitions" >&2 ; fail=1
fi

echo "oft-doublons-test — [B] identifiant repris en colonne 0, suivi de texte : échoue en nommant fichiers et identifiant"
printf '# Audit\n\n`req~a~1`, et la suite de la phrase.\n' > "${TMP}/docs/audit.md"
if sortie="$(controle)"; then
    echo "ÉCHEC [B] : un doublon de définition passe" >&2 ; fail=1
else
    for attendu in "req~a~1" "spec/a.md:3" "docs/audit.md:3"; do
        printf '%s\n' "${sortie}" | grep -qF "${attendu}" \
            || { echo "ÉCHEC [B] : le rapport ne nomme pas « ${attendu} »" >&2 ; fail=1 ; }
    done
fi

echo "oft-doublons-test — [C] la trace joue le contrôle avant Java"
if (cd "${TMP}" && PATH="/usr/bin:/bin" JAVA_HOME= sh tools/oft.sh trace 2>&1) | grep -q "défini(s) plusieurs fois"; then
    :
else
    echo "ÉCHEC [C] : la trace ne signale pas le doublon" >&2 ; fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "oft-doublons-test : ÉCHEC." >&2
    exit 1
fi
echo "oft-doublons-test : OK."
