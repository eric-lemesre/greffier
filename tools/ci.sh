#!/bin/sh
# Point d'entrée UNIQUE des portes : ce que la CI exécute est exactement ce
# que le poste exécute. Les façades (Taskfile, justfile) et les deux CI
# délèguent ici — aucune ne redéfinit sa propre liste d'étapes, faute de quoi
# « vert en local, rouge en CI » redevient possible.
#
# La voie est CONSTATÉE par tools/perimetre.sh, jamais déclarée :
#   docs    — le changement ne touche que de la documentation : portes
#             documentaires seules (quelques secondes) ;
#   complet — tout le reste, tests d'outillage compris.
#
# TOUTES LES PORTES SONT JOUÉES, puis un bilan est rendu (ADR-0019). Un
# lanceur qui s'arrête à la première porte rouge ne dit rien des suivantes :
# la première porte de la liste masque alors l'état de tout ce qui la suit, et
# elle le masque d'autant plus longtemps qu'elle est légitimement rouge — une
# traçabilité qui attend sa réalisation, par exemple. Le code de retour reste
# non nul dès qu'une porte échoue : le bilan informe, il n'absout pas.
#
#   sh tools/ci.sh              # voie constatée
#   sh tools/ci.sh --complet    # force la voie complète
#   sh tools/ci.sh --rapide     # force la voie documentaire (hook pre-commit)
#   CI_COMPLET=1 sh tools/ci.sh # complète, par l'environnement (CI planifiée)
#
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

FORCE=""
case "${1:-}" in
    --complet) FORCE="complet" ;;
    # Le hook pre-commit force la voie documentaire : ces portes coûtent
    # quelques secondes, là où les tests d'outillage créent une dizaine de
    # dépôts git jetables. Un hook trop lent finit contourné, et une porte
    # contournée ne protège personne — la porte complète reste due avant de
    # proposer le travail.
    --rapide)  FORCE="docs" ;;
    "") ;;
    *) echo "Usage : sh tools/ci.sh [--complet | --rapide]" >&2 ; exit 2 ;;
esac
# L'ARGUMENT EXPLICITE PRIME sur l'environnement. Sans cette garde, un
# CI_COMPLET=1 hérité re-force en voie complète le « ci.sh --rapide » que
# lance la vérification finale de l'instanciation — dont la voie complète
# relance le test d'instanciation, qui relance ci.sh : récursion infinie
# constatée à la remontée (un niveau toutes les ~9 s, plus de 700 processus
# avant l'arrêt manuel). L'outillage d'instanciation se retire du projet
# produit ; la garde reste, un argument explicite devant primer sur un
# environnement hérité quel que soit l'appelant.
[ -n "${FORCE}" ] || [ "${CI_COMPLET:-0}" != "1" ] || FORCE="complet"

if [ -n "${FORCE}" ]; then
    voie="${FORCE}"
    echo "• voie ${voie} (forcée)"
else
    voie="$(sh tools/perimetre.sh)"
    echo "• voie ${voie} (périmètre constaté)"
fi

# Chaque porte est jouée, son verdict retenu, et la suivante est jouée quoi
# qu'il arrive. Le bilan final les rend toutes d'un coup — c'est là qu'on voit
# si une porte rouge en cache deux autres, ce qu'un arrêt à la première ne
# permet jamais de savoir.
BILAN=""
ECHECS=0
# --- lanceur:debut --- (fonctions éprouvées à part par tools/ci-test.sh)
# Secondes depuis l'époque, ou rien : un « date » sans %s prive la durée de
# sa valeur, jamais le lanceur de son bilan.
secondes() {
    _s="$(date +%s 2>/dev/null || true)"
    case "${_s}" in ''|*[!0-9]*) ;; *) printf '%s' "${_s}" ;; esac
}
# La durée de chaque porte figure au bilan : c'est elle qui dit où optimiser.
etape() {
    _titre="$1"
    shift
    printf '— %s\n' "${_titre}"
    _debut="$(secondes)"
    if "$@"; then _verdict="ok"; else _verdict="ÉCHEC"; ECHECS=$((ECHECS + 1)); fi
    _fin="$(secondes)"
    if [ -n "${_debut}" ] && [ -n "${_fin}" ]; then _duree=$((_fin - _debut)); else _duree="?"; fi
    retenir "${_verdict}" "${_duree}" "${_titre}"
}
retenir() {   # retenir <ok|ÉCHEC> <secondes> <titre>
    # Colonnes alignées à la main : printf compterait les octets de « É ».
    case "$1" in ok) _col="ok      " ;; *) _col="ÉCHEC   " ;; esac
    BILAN="${BILAN}
${_col} $3 ($2 s)"
}

# Étapes indépendantes, jouées en parallèle par tools/paralleles.sh : la
# liste « titre<TAB>commande » arrive sur l'entrée ; chaque étape garde sa
# ligne au bilan, dans l'ordre de la liste, comme si elle avait été jouée
# seule. Un bilan qui n'a pas une ligne par étape est un échec : une étape
# omise ne doit jamais passer pour absente.
etapes_paralleles() {
    _liste="$(mktemp)"
    _bilan="$(mktemp)"
    awk 'NF { print }' > "${_liste}"
    sh tools/paralleles.sh "${_bilan}" < "${_liste}" || true
    while IFS="$(printf '\t')" read -r _verdict _duree _titre; do
        [ "${_verdict}" = "ok" ] || ECHECS=$((ECHECS + 1))
        retenir "${_verdict}" "${_duree}" "${_titre}"
    done < "${_bilan}"
    _attendues="$(awk 'END { print NR }' "${_liste}")"
    _rendues="$(awk 'END { print NR }' "${_bilan}")"
    if [ "${_rendues}" -ne "${_attendues}" ] || [ "${_attendues}" -eq 0 ]; then
        retenir "ÉCHEC" "?" "lanceur parallèle : ${_rendues} étape(s) au bilan pour ${_attendues}"
        ECHECS=$((ECHECS + 1))
    fi
    rm -f "${_liste}" "${_bilan}"
}
# --- lanceur:fin ---

bilan() {
    echo
    echo "— bilan (voie ${voie})"
    printf '%s\n' "${BILAN}" | sed -e '/^$/d' -e 's/^/  /'
    if [ "${ECHECS}" -gt 0 ]; then
        echo "CI locale (voie ${voie}) : ${ECHECS} porte(s) en échec." >&2
        exit 1
    fi
    echo "CI locale (voie ${voie}) : OK."
    exit 0
}

# --- Portes documentaires (les deux voies) ----------------------------------
etape "traçabilité"        sh tools/oft.sh trace
etape "rattachement"       sh tools/rattachement.sh
etape "cohérence"          sh tools/checks.sh
etape "liens"              sh tools/liens.sh
etape "statuts"            sh tools/statuts.sh
etape "classification"     sh tools/classification.sh
etape "relevés"            sh tools/releves.sh
etape "journaux"           sh tools/journaux.sh
etape "feuille de route"   sh tools/todo.sh
etape "avancement"         sh tools/avancement.sh
etape "constats de revue"  sh tools/revues.sh
etape "audit"              sh tools/audit.sh
etape "badges"             sh tools/badges.sh
etape "anti-dérive"        sh tools/derive.sh
etape "secrets"            sh tools/secrets.sh scan
etape "données"            sh tools/donnees.sh
etape "hygiène de compilation" sh tools/hygiene-compilation.sh

# Forme explicite plutôt que « [ … ] && bilan » : sous « set -e », un test
# faux en tête d'une liste ET est exempté, mais la règle est assez subtile
# pour qu'on ne la fasse pas porter par une porte.
if [ "${voie}" = "docs" ]; then
    bilan
fi

# --- Tests d'outillage (voie complète) --------------------------------------
# Chaque porte se teste sur son cas d'échec (R3). Ces tests créent des dépôts
# git jetables : c'est la partie coûteuse, et la raison d'être de
# l'aiguillage. Chacun travaille dans son propre dossier (mktemp) : ils sont
# joués en parallèle, au plus CI_PARALLELE à la fois (tools/paralleles.sh).
etape "test — lanceur parallèle" sh tools/paralleles-test.sh
# Liste protégée ('FIN') : rien n'y est développé avant le lanceur.
etapes_paralleles <<'FIN'
test — lanceur	sh tools/ci-test.sh
test — anti-secrets	sh tools/secrets-test.sh
test — données	sh tools/donnees-test.sh
test — liens	sh tools/liens-test.sh
test — périmètre	sh tools/perimetre-test.sh
test — anti-dérive	sh tools/derive-test.sh
test — cohérence	sh tools/checks-test.sh
test — socle	sh tools/socle-test.sh
test — gouvernance	sh tools/gouvernance-test.sh
test — accueil	sh tools/setup-test.sh
test — bootstrap	sh tools/bootstrap-test.sh
test — nettoyage	sh tools/clean-test.sh
test — hygiène de compilation	sh tools/hygiene-compilation-test.sh
test — kit Rust	sh tools/rust-kit-test.sh
test — rattachement	sh tools/rattachement-test.sh
test — indépendance à la locale	sh tools/locale-test.sh
FIN

bilan
