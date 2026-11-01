#!/bin/sh
# Conformité des issues ouvertes au cycle de vie déclaré (méthode, ch. 11).
#
# DÉLIBÉRÉMENT HORS PORTE. Ce contrôle appelle l'API de la forge : il dépend
# du réseau et d'une session authentifiée, exactement ce que les autres
# scripts de tools/ évitent pour que la porte reste reproductible sur un poste
# déconnecté. Il sert la revue de triage périodique, pas l'intégration
# continue — la porte vérifie le dépôt, pas la conformité organisationnelle
# des issues. Sans session, il s'interrompt sans faire échouer quoi que ce
# soit.
#
#   sh tools/issues.sh
#
# Forges : GitHub via `gh`, GitLab via `glab`. Vocabulaire des étiquettes pris
# au lexique (ADR-0015), donc valable quelle que soit la langue du dépôt.
#
# POSIX sh + awk.
set -eu

# Chemins portant espaces ou métacaractères (constat de revue n° 2) : le
# découpage par défaut d'un « $(git ls-files) » non quoté coupe « mon
# document.md » en deux et laisse un glob s'expanser. Une porte qui rate un
# fichier ne signale rien — elle se contente de ne pas le voir. On découpe
# donc sur les seules fins de ligne, globbing désactivé.
IFS='
'
set -f

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
. "${ROOT}/tools/lexique.sh"

[ "${1:-}" = "" ] || { echo "Usage : sh tools/issues.sh" >&2 ; exit 2 ; }

# --- Détection de la forge et de la session ---------------------------------
CLI=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    CLI="gh"
elif command -v glab >/dev/null 2>&1 && glab auth status >/dev/null 2>&1; then
    CLI="glab"
fi

if [ -z "${CLI}" ]; then
    echo "Conformité des issues : ignorée — aucune session de forge authentifiée."
    echo "  Installer puis connecter « gh » (GitHub) ou « glab » (GitLab)."
    echo "  Ce contrôle n'est pas une porte : son absence ne fait échouer aucune"
    echo "  vérification (méthode, ch. 11)."
    exit 0
fi

# --- États du cycle de vie ---------------------------------------------------
# Un état, et un seul, à la fois. Les entraves (bloquant, en-attente-de…) sont
# cumulables et ne sont pas des états : elles ne comptent pas ici.
ETATS="$(lex LABEL_A_CONSULTER)|$(lex LABEL_A_DISCUTER)|$(lex LABEL_A_TESTER)|$(lex LABEL_A_CLOTURER)|$(lex LABEL_LIVRE)"
# Les états qui expriment une ATTENTE envers quelqu'un exigent une assignation :
# l'étiquette dit l'état, l'assignation dit qui est attendu.
ATTENTE="$(lex LABEL_A_CONSULTER)|$(lex LABEL_A_TESTER)"
SORTIES="$(lex LABEL_DOUBLON)|$(lex LABEL_INVALIDE)|$(lex LABEL_NE_SERA_PAS_FAIT)"

echo "• conformité des issues (${CLI}) — vocabulaire : ${ETATS}"

# Une ligne par issue : numéro, étiquettes séparées par des virgules, nombre
# d'assignés. `gh` embarque son propre filtre jq ; `glab` non, d'où le recours
# à jq quand il est présent — et un refus explicite plutôt qu'un parseur JSON
# maison, qui mentirait au premier titre contenant une accolade.
FILTRE='.[] | [ (.number // .iid), ([.labels[] | (.name // .)] | join(",")), (.assignees | length) ] | @tsv'

case "${CLI}" in
    gh)
        BRUT="$(gh issue list --state open --limit 200 \
                  --json number,labels,assignees --jq "${FILTRE}")"
        ;;
    glab)
        if ! command -v jq >/dev/null 2>&1; then
            echo "Conformité des issues : ignorée — « glab » détecté mais « jq » absent."
            echo "  Installer jq, ou lancer ce contrôle depuis un dépôt GitHub."
            exit 0
        fi
        BRUT="$(glab issue list --all-pages --output json 2>/dev/null | jq -r "${FILTRE}")"
        ;;
esac

if [ -z "${BRUT}" ]; then
    echo "Conformité des issues : aucune issue ouverte."
    exit 0
fi

printf '%s\n' "${BRUT}" | awk -F "\t" \
    -v etats="${ETATS}" -v attente="${ATTENTE}" -v sorties="${SORTIES}" '
{
    num = $1; labels = $2; assignes = $3 + 0
    n = split(labels, l, ",")
    nb_etats = 0; etat = ""
    for (i = 1; i <= n; i++) {
        if (l[i] ~ ("^(" etats ")$")) { nb_etats++; etat = l[i] }
    }
    if (nb_etats == 0) {
        printf "  #%s — aucune étiquette d’état : impossible de savoir où elle en est.\n", num
        ecarts++
    } else if (nb_etats > 1) {
        printf "  #%s — %d étiquettes d’état simultanées (%s).\n", num, nb_etats, labels
        ecarts++
    }
    if (etat ~ ("^(" attente ")$") && assignes == 0) {
        printf "  #%s — état « %s » sans assignation : personne n’est attendu.\n", num, etat
        ecarts++
    }
    for (i = 1; i <= n; i++) {
        if (l[i] ~ ("^(" sorties ")$")) {
            printf "  #%s — sortie négative « %s » sur une issue OUVERTE : fermer en « non planifiée ».\n", num, l[i]
            ecarts++
        }
    }
    total++
}
END {
    printf "Conformité des issues : %d issue(s) examinée(s), %d écart(s).\n", total + 0, ecarts + 0
    # Rapport, pas porte : les écarts se traitent en revue de triage, ils ne
    # font échouer aucune vérification.
}'
