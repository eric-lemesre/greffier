#!/bin/sh
# [impl->req~porte-ci~2]
# Lanceur parallèle des étapes indépendantes de tools/ci.sh : les tests
# d'outillage, qui travaillent chacun dans leur propre dossier jetable
# (mktemp). Joués l'un après l'autre, ils faisaient la plus longue part de
# la voie complète.
#
#   sh tools/paralleles.sh <bilan> < liste
#
# <liste> : une ligne « titre<TAB>commande » par étape ; la commande est
# passée à « sh -c », depuis la racine du dépôt. Les lignes vides sont
# ignorées ; une dernière ligne sans fin de ligne compte comme les autres.
#
# Toutes les étapes sont jouées, quel que soit le verdict des autres, au plus
# CI_PARALLELE à la fois (défaut : le nombre de processeurs ; 0 : sans
# limite). Puis, DANS L'ORDRE DE LA LISTE, chaque étape imprime « — titre »
# suivi de sa sortie complète : le journal se lit comme celui d'un lanceur
# séquentiel, sans lignes entremêlées. <bilan> reçoit une ligne par étape,
# dans le même ordre : « ok|ÉCHEC<TAB>secondes<TAB>titre ».
#
# Fermé en cas de panne : une étape qui n'a pas rendu de code — lanceur
# interrompu, travailleur tué, xargs absent — est un ÉCHEC, et sa sortie dit
# qu'elle n'a pas été jouée jusqu'au bout. Le bilan a une ligne par étape
# de la liste, écrite d'après la liste elle-même ; tools/ci.sh en vérifie le
# compte.
#
# Code de retour : 0 si toutes les étapes passent, 1 sinon, 2 sur un usage
# fautif. xargs -P n'est pas POSIX, mais GNU, BSD, busybox et Git pour
# Windows le fournissent.
#
# POSIX sh strict.
set -eu

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "Usage : sh tools/paralleles.sh <bilan> < liste" >&2
    exit 2
fi
# Chemin du bilan rendu absolu AVANT le changement de répertoire.
case "$1" in
    /*) BILAN_FICHIER="$1" ;;
    *)  BILAN_FICHIER="$(pwd)/$1" ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

PARALLELE="${CI_PARALLELE:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
case "${PARALLELE}" in
    ''|*[!0-9]*)
        echo "Usage : CI_PARALLELE doit être un entier positif ou nul (reçu « ${PARALLELE} »)." >&2
        exit 2
        ;;
esac

REP="$(mktemp -d)"
trap 'rm -rf "${REP}"' EXIT INT TERM
# awk normalise : lignes vides ôtées, fin de ligne ajoutée à la dernière.
awk 'NF { print }' > "${REP}/liste"
NB="$(awk 'END { print NR }' "${REP}/liste")"
if [ "${NB}" -eq 0 ]; then
    echo "ÉCHEC : liste d'étapes vide — un lanceur sans étape passerait toujours." >&2
    exit 1
fi
if grep -qv '^[^	][^	]*	.' "${REP}/liste"; then
    echo "ÉCHEC : ligne sans « titre<TAB>commande » dans la liste." >&2
    exit 2
fi

# Chaque travailleur reçoit le numéro de sa ligne ; il range sortie, code et
# durée sous ce numéro. Il rend toujours 0 à xargs : un code 255 ou une
# mort par signal arrêteraient xargs, et les étapes suivantes ne seraient
# jamais lancées.
# shellcheck disable=SC2016 — développé par le sh du travailleur.
awk '{ print NR }' "${REP}/liste" | xargs -P "${PARALLELE}" -n 1 sh -c '
    ligne="$(sed -n "$1p" "$0/liste")"
    debut="$(date +%s 2>/dev/null || true)"
    code=0
    sh -c "${ligne#*	}" > "$0/$1.sortie" 2>&1 < /dev/null || code=$?
    fin="$(date +%s 2>/dev/null || true)"
    # Un « date » sans %s prive la durée de sa valeur, jamais l étape de
    # son verdict.
    case "${debut}:${fin}" in
        :*|*:|*[!0-9:]*) echo "?" > "$0/$1.duree" ;;
        *) echo "$((fin - debut))" > "$0/$1.duree" ;;
    esac
    echo "${code}" > "$0/$1.code"
    exit 0
' "${REP}" || true

echecs=0
n=0
: > "${BILAN_FICHIER}.tmp"
while IFS= read -r ligne; do
    n=$((n + 1))
    titre="${ligne%%	*}"
    printf '— %s\n' "${titre}"
    cat "${REP}/${n}.sortie" 2>/dev/null || true
    if [ -f "${REP}/${n}.code" ]; then
        code="$(cat "${REP}/${n}.code")"
    else
        echo "ÉCHEC : étape non jouée jusqu'au bout (lanceur interrompu ou travailleur tué) — voir les messages de xargs plus haut."
        code=1
    fi
    duree="$(cat "${REP}/${n}.duree" 2>/dev/null || echo "?")"
    if [ "${code}" = "0" ]; then verdict="ok"; else verdict="ÉCHEC"; echecs=$((echecs + 1)); fi
    printf '%s\t%s\t%s\n' "${verdict}" "${duree}" "${titre}" >> "${BILAN_FICHIER}.tmp"
done < "${REP}/liste"
cat "${BILAN_FICHIER}.tmp" >> "${BILAN_FICHIER}"
rm -f "${BILAN_FICHIER}.tmp"

[ "${echecs}" -eq 0 ]
