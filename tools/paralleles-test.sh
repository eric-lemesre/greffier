#!/bin/sh
# Test du lanceur parallèle (tools/paralleles.sh) sur ses cas d'échec (R3) :
# une étape en échec n'empêche pas les autres, même quand elles attendent
# leur tour (CI_PARALLELE=1), et rend le lanceur rouge ; les sorties sortent
# dans l'ordre de la liste ; les étapes tournent vraiment en même temps
# (rendez-vous qu'un lanceur séquentiel ne peut pas tenir) ; une étape non
# jouée jusqu'au bout — travailleur tué, xargs absent — est un échec, jamais
# un vert ; une dernière ligne sans fin de ligne compte ; une liste vide, une
# ligne mal formée ou un CI_PARALLELE invalide sont refusés.
#
#   sh tools/paralleles-test.sh
#
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0
T="$(printf '\t')"

# lancer <liste> : rend CODE, la sortie dans ${TMP}/sortie, le bilan dans
# ${TMP}/bilan. La liste est passée telle quelle, sans fin de ligne ajoutée.
CODE=0
lancer() {
    CODE=0
    rm -f "${TMP}/bilan"
    printf '%s' "$1" | sh "${ROOT}/tools/paralleles.sh" "${TMP}/bilan" > "${TMP}/sortie" 2>&1 || CODE=$?
}
attendre() {   # attendre <libellé> <code attendu>
    if [ "${CODE}" -ne "$2" ]; then
        echo "ÉCHEC : $1 — code ${CODE}, attendu $2" >&2
        sed 's/^/  | /' "${TMP}/sortie" >&2 ; fail=1
    fi
}
verdicts() {   # verdicts <attendus séparés par des espaces>
    _vus="$(cut -f1 "${TMP}/bilan" 2>/dev/null | tr '\n' ' ')"
    if [ "${_vus}" != "$1 " ]; then
        echo "ÉCHEC : verdicts « ${_vus}», attendus « $1 »" >&2
        sed 's/^/  | /' "${TMP}/bilan" >&2 2>/dev/null || true ; fail=1
    fi
}

echo "paralleles-test — trois étapes saines : vert, sorties dans l'ordre de la liste"
lancer "premiere${T}sleep 1; echo sortie-un
deuxieme${T}echo sortie-deux
troisieme${T}echo sortie-trois
"
attendre "étapes saines" 0
ordre="$(grep -E '^(— |sortie-)' "${TMP}/sortie" | tr '\n' ' ')"
if [ "${ordre}" != "— premiere sortie-un — deuxieme sortie-deux — troisieme sortie-trois " ]; then
    echo "ÉCHEC : sorties hors de l'ordre de la liste : ${ordre}" >&2 ; fail=1
fi
if [ "$(cut -f1,3 "${TMP}/bilan" | tr '\t\n' ': ')" != "ok:premiere ok:deuxieme ok:troisieme " ]; then
    echo "ÉCHEC : bilan inattendu :" >&2 ; sed 's/^/  | /' "${TMP}/bilan" >&2 ; fail=1
fi

LISTE_CASSEE="avant${T}echo joue-avant
casse${T}echo casse-dit-pourquoi; exit 255
apres${T}echo joue-apres
encore${T}echo joue-encore
fin${T}echo joue-fin
"
for p in 1 2 ""; do
    echo "paralleles-test — étape en échec, CI_PARALLELE=${p:-défaut} : rouge, toutes les suivantes jouées"
    # Avec CI_PARALLELE=1, les étapes d'après l'échec attendent leur tour : un
    # lanceur qui s'arrêterait au premier échec ne les jouerait jamais. Le
    # code 255 est celui qui, rendu à xargs, l'arrêterait.
    if [ -n "${p}" ]; then export CI_PARALLELE="${p}"; else unset CI_PARALLELE; fi
    lancer "${LISTE_CASSEE}"
    attendre "une étape en échec" 1
    for attendu in joue-avant casse-dit-pourquoi joue-apres joue-encore joue-fin; do
        grep -q "${attendu}" "${TMP}/sortie" || { echo "ÉCHEC : « ${attendu} » absent de la sortie" >&2 ; fail=1; }
    done
    verdicts "ok ÉCHEC ok ok ok"
done
unset CI_PARALLELE

echo "paralleles-test — rendez-vous : les étapes tournent en même temps"
# La première attend un fichier que seule la seconde crée : jouées l'une
# après l'autre, la première échouerait au bout de dix secondes.
R="${TMP}/rendez-vous"
export CI_PARALLELE=2
lancer "attend${T}i=0; while [ ! -f ${R} ] && [ \$i -lt 10 ]; do sleep 1; i=\$((i+1)); done; [ -f ${R} ]
cree${T}touch ${R}
"
attendre "rendez-vous de deux étapes parallèles" 0
unset CI_PARALLELE

echo "paralleles-test — dernière ligne sans fin de ligne, en échec : comptée et rouge"
lancer "a${T}echo A
b${T}echo B; exit 1"
attendre "dernière ligne sans fin de ligne" 1
verdicts "ok ÉCHEC"

echo "paralleles-test — travailleur tué : étape non jouée, rouge, bilan complet"
export CI_PARALLELE=1
lancer "tue${T}kill -9 \$PPID
apres${T}echo joue-apres
"
attendre "travailleur tué" 1
grep -q "non jouée" "${TMP}/sortie" || { echo "ÉCHEC : la sortie ne dit pas qu'une étape n'a pas été jouée" >&2 ; fail=1; }
[ "$(cut -f1 "${TMP}/bilan" | head -n 1)" = "ÉCHEC" ] || { echo "ÉCHEC : l'étape tuée n'est pas rouge au bilan" >&2 ; fail=1; }
[ "$(awk 'END { print NR }' "${TMP}/bilan")" -eq 2 ] || { echo "ÉCHEC : le bilan n'a pas une ligne par étape" >&2 ; fail=1; }
unset CI_PARALLELE

echo "paralleles-test — xargs absent : tout est rouge, rien n'est vert par défaut"
mkdir -p "${TMP}/sans-xargs"
for c in sh dirname pwd getconf mktemp awk grep sed cat rm date tr cut; do
    src="$(command -v "${c}" || true)"
    [ -n "${src}" ] && ln -s "${src}" "${TMP}/sans-xargs/${c}"
done
CODE=0
printf 'a\techo A\n' | PATH="${TMP}/sans-xargs" sh "${ROOT}/tools/paralleles.sh" "${TMP}/bilan-sx" > "${TMP}/sortie" 2>&1 || CODE=$?
attendre "xargs absent" 1
[ "$(cut -f1 "${TMP}/bilan-sx" 2>/dev/null)" = "ÉCHEC" ] || { echo "ÉCHEC : sans xargs, l'étape n'est pas rouge au bilan" >&2 ; fail=1; }

echo "paralleles-test — CI_PARALLELE invalide : usage fautif"
export CI_PARALLELE=abc
lancer "a${T}echo A
"
attendre "CI_PARALLELE invalide" 2
unset CI_PARALLELE

echo "paralleles-test — bilan relatif : écrit dans le répertoire de l'appelant"
mkdir -p "${TMP}/appelant"
(cd "${TMP}/appelant" && printf 'a\techo A\n' | sh "${ROOT}/tools/paralleles.sh" bilan-relatif > /dev/null 2>&1) || true
[ -s "${TMP}/appelant/bilan-relatif" ] || { echo "ÉCHEC : bilan relatif absent du répertoire de l'appelant" >&2 ; fail=1; }

echo "paralleles-test — titre à antislash : imprimé tel quel"
lancer 'a\\b'"${T}echo A
"
attendre "titre à antislash" 0
grep -qF -- '— a\\b' "${TMP}/sortie" || { echo "ÉCHEC : titre à antislash altéré dans le journal" >&2 ; fail=1; }

echo "paralleles-test — liste vide : échec, rien n'est vert par vide"
lancer ""
attendre "liste vide" 1

echo "paralleles-test — ligne sans tabulation : usage fautif"
lancer "titre-sans-commande
"
attendre "ligne mal formée" 2

echo "paralleles-test — bilan non désigné : usage fautif"
code=0
sh "${ROOT}/tools/paralleles.sh" < /dev/null > /dev/null 2>&1 || code=$?
if [ "${code}" -ne 2 ]; then
    echo "ÉCHEC : sans argument, code ${code}, attendu 2" >&2 ; fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "paralleles-test : ÉCHEC." >&2
    exit 1
fi
echo "paralleles-test : OK."
