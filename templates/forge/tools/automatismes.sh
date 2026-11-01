#!/bin/sh
# Automatismes de coordination des issues — logique unique, façades par forge.
# Exigence servie : req~automatismes-forge~1.
#
# MATÉRIEL PRÊT À CÂBLER, non actif dans le gabarit (R7 ; voir
# templates/forge/README.md). Copier dans le tools/ du projet, créer les
# étiquettes, puis ÉPROUVER CHAQUE AUTOMATISME SUR SON CAS D'ÉCHEC avant de
# le déclarer câblé.
#
# Principe non négociable : un automatisme dérive l'état depuis l'acte, jamais
# l'inverse, et signale sans décider. Aucun ne ferme une issue à la place d'un
# humain.
#
#   sh tools/automatismes.sh lecture    <numéro> <auteur>
#   sh tools/automatismes.sh retombee   <base> <tête>
#   sh tools/automatismes.sh a-cloturer <numéro>
#   sh tools/automatismes.sh dormantes  [jours]
#   sh tools/automatismes.sh fermeture  <numéro> <étiquette>
#
# Vocabulaire pris au lexique (ADR-0015) : fonctionne quelle que soit la
# langue du dépôt. Forge : GitHub via `gh`. Le portage GitLab passe par
# `glab api`, dont les points d'appel sont signalés en commentaire.
#
# POSIX sh + awk.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
. "${ROOT}/tools/lexique.sh"

command -v gh >/dev/null 2>&1 || {
    echo "ERREUR : « gh » requis (portage GitLab : remplacer les appels gh par glab api)." >&2
    exit 1
}

CMD="${1:-}"
[ -n "${CMD}" ] || { echo "Usage : sh tools/automatismes.sh <lecture|retombee|a-cloturer|dormantes|fermeture> …" >&2; exit 2; }
shift

# Documents dont la modification ne doit JAMAIS faire retomber les lectures.
# Piège vécu : cités par le gabarit d'issue, les documents de procédure
# déclenchaient la retombée sur toutes les consultations ouvertes à la fois,
# alors qu'aucun dossier de fond n'avait bougé.
EXCLUS_RETOMBEE="docs/methode/ docs/adr/ templates/"

# SECOND piège, plus grave, et vécu lui aussi (ergonomia, FIX-#846) : ce filtre
# est écrit en CHEMINS. Un répertoire renommé le laisse syntaxiquement valide
# et fonctionnellement mort — il ne filtre plus rien, en silence, et la
# première retouche d'un document de procédure vide les positions de toutes
# les consultations ouvertes. Un filtre qui ne filtre plus ne lève aucune
# erreur : il faut donc lui demander de se prouver.
verifier_filtre() {
    _absents=""
    for _p in ${EXCLUS_RETOMBEE}; do
        [ -e "${_p}" ] || _absents="${_absents} ${_p}"
    done
    if [ -n "${_absents}" ]; then
        echo "ERREUR : le filtre d'exclusion vise des chemins qui n'existent pas :${_absents}" >&2
        echo "  Renommage non répercuté ? Tant que ce filtre est faux, la retombée" >&2
        echo "  viderait les positions de TOUTES les consultations ouvertes." >&2
        exit 1
    fi
}

case "${CMD}" in

# --- Un lecteur déclare avoir lu ---------------------------------------------
# La case du lecteur est cochée avec la date, et il est DÉSASSIGNÉ :
# l'assignation dit qui est encore attendu, pas qui a déjà répondu.
lecture)
    num="${1:?numéro d'issue}"; auteur="${2:?auteur du commentaire}"
    corps="$(gh issue view "${num}" --json body --jq .body)"
    jour="$(date +%Y-%m-%d)"
    nouveau="$(printf '%s' "${corps}" | awk -v qui="${auteur}" -v jour="${jour}" '
        # Coche la seule ligne de case qui nomme ce lecteur, et l’horodate.
        index($0, qui) > 0 && /^[ \t]*- \[ \]/ {
            sub(/\[ \]/, "[x]"); print $0 "  — " jour; coche = 1; next
        }
        { print }
        END { if (!coche) exit 3 }
    ')" || {
        gh issue comment "${num}" --body \
            "Aucune case de lecture au nom de @${auteur} : la consultation ne l'attend pas."
        exit 0
    }
    printf '%s' "${nouveau}" | gh issue edit "${num}" --body-file -
    gh issue edit "${num}" --remove-assignee "${auteur}"
    ;;

# --- Un document consulté a changé -------------------------------------------
# « J'ai lu » porte sur une VERSION : si le document change, les lectures
# retombent. Cases décochées, intervenants réassignés, comparatif en
# commentaire pour qu'on relise le delta, pas tout.
retombee)
    verifier_filtre
    base="${1:?commit de base}"; tete="${2:?commit de tête}"
    modifies="$(git diff --name-only "${base}" "${tete}")"
    for doc in ${modifies}; do
        for exclu in ${EXCLUS_RETOMBEE}; do
            case "${doc}" in "${exclu}"*) continue 2 ;; esac
        done
        # Consultations ouvertes qui citent ce document. Le terme est
        # entouré de guillemets DANS la requête : un chemin contient des « / »
        # et des « - » que la syntaxe de recherche de la forge interpréterait
        # (constat de revue n° 4).
        for num in $(gh issue list --state open \
                        --label "$(lex_fr LABEL_A_CONSULTER)" \
                        --search "\"${doc}\"" --json number --jq '.[].number'); do
            corps="$(gh issue view "${num}" --json body --jq .body)"
            printf '%s' "${corps}" | sed 's/^\([ \t]*- \)\[x\]/\1[ ]/' | \
                gh issue edit "${num}" --body-file -
            for qui in $(printf '%s' "${corps}" | \
                         awk '/^[ \t]*- \[/ { if (match($0, /@[A-Za-z0-9_-]+/)) \
                              print substr($0, RSTART + 1, RLENGTH - 1) }'); do
                gh issue edit "${num}" --add-assignee "${qui}"
            done
            gh issue comment "${num}" --body \
"Le document consulté a changé : les lectures retombent.

- Document : \`${doc}\`
- Comparatif : \`git diff ${base}..${tete} -- ${doc}\`

Une lecture porte sur une version. Relire le delta, puis re-déclarer."
        done
    done
    ;;

# --- La liste de vérification est complète -----------------------------------
# L'automatisme SIGNALE : il pose l'étiquette et prévient l'auteur. Il ne
# ferme pas — les cases ne prouvent rien, c'est l'auteur qui vérifie que les
# validations existent et citent la version en cours.
a-cloturer)
    num="${1:?numéro d'issue}"
    corps="$(gh issue view "${num}" --json body --jq .body)"
    restantes="$(printf '%s' "${corps}" | grep -c '^[ \t]*- \[ \]' || true)"
    total="$(printf '%s' "${corps}" | grep -c '^[ \t]*- \[[ x]\]' || true)"
    [ "${total}" -gt 0 ] || exit 0
    [ "${restantes}" -eq 0 ] || exit 0
    etiquettes="$(gh issue view "${num}" --json labels --jq '[.labels[].name] | join(",")')"
    # Un seul rappel par tour de recette : retirer l'étiquette réarme
    # l'automatisme pour le tour suivant.
    case ",${etiquettes}," in *",$(lex_fr LABEL_A_CLOTURER),"*) exit 0 ;; esac
    gh issue edit "${num}" --add-label "$(lex_fr LABEL_A_CLOTURER)"
    auteur="$(gh issue view "${num}" --json author --jq .author.login)"
    gh issue comment "${num}" --body \
"@${auteur} — liste de vérification complète : l'issue passe « $(lex_fr LABEL_A_CLOTURER) ».

La clôture vous revient. Avant de fermer, vérifier que les validations
existent réellement et citent la version en cours : une case cochée ne prouve
rien par elle-même."
    ;;

# --- Les recettes qui dorment ------------------------------------------------
# Une issue en recette sans activité signale un oubli — ou une réticence que
# personne n'a formulée, le cas le plus intéressant. Un rappel, pas une
# injonction : aucune escalade, aucune fermeture automatique.
dormantes)
    jours="${1:-15}"
    limite="$(date -u -d "-${jours} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
              date -u -v-"${jours}"d +%Y-%m-%dT%H:%M:%SZ)"
    gh issue list --state open --label "$(lex_fr LABEL_A_TESTER)" \
        --json number,updatedAt --jq \
        ".[] | select(.updatedAt < \"${limite}\") | .number" | \
    while IFS= read -r num; do
        [ -n "${num}" ] || continue
        # Le commentaire de rappel rafraîchit lui-même l'activité de l'issue :
        # le prochain rappel n'arrivera donc que ${jours} jours plus tard.
        # Sans cette propriété, l'automatisme se redéclencherait sans fin.
        gh issue comment "${num}" --body \
"Recette sans activité depuis plus de ${jours} jours.

Un rappel, pas une injonction : si la recette bloque, ou si quelque chose
gêne sans avoir été dit, l'écrire ici vaut mieux que de laisser dormir."
    done
    ;;

# --- Sortie négative ---------------------------------------------------------
# Une issue rejetée se ferme en « non planifiée », jamais en « terminée ».
# Sans cela, rien ne distingue une demande traitée d'une demande refusée.
# « Différé » est délibérément absent : un report n'est pas un rejet, et
# l'issue doit rester ouverte avec sa condition de réouverture.
fermeture)
    num="${1:?numéro d'issue}"; etiquette="${2:?étiquette posée}"
    case "${etiquette}" in
        "$(lex_fr LABEL_DOUBLON)"|"$(lex_en LABEL_DOUBLON)"|\
        "$(lex_fr LABEL_INVALIDE)"|"$(lex_en LABEL_INVALIDE)"|\
        "$(lex_fr LABEL_NE_SERA_PAS_FAIT)"|"$(lex_en LABEL_NE_SERA_PAS_FAIT)") ;;
        *) exit 0 ;;
    esac
    gh issue close "${num}" --reason "not planned" \
        --comment "Fermée en « non planifiée » : sortie « ${etiquette} ». Le motif doit figurer ci-dessus."
    ;;

*)
    echo "ERREUR : automatisme inconnu : ${CMD}" >&2
    exit 2
    ;;
esac
