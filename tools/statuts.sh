#!/bin/sh
# Statuts des domaines de spécification — le COMMUTATEUR de couverture.
#
# Un statut n'est pas une décoration : il commande le dénominateur. ACTIVE
# fait entrer les exigences d'un domaine dans les taux d'audit et de
# classification ; PROPOSITION les en tient dehors, le temps de l'arbitrage.
# Un statut qui ment fausse donc un chiffre sans qu'aucune porte ne proteste
# — en-tête et index qui divergent, domaine déclaré ACTIVE sans décision qui
# l'acte, exigences comptées d'un domaine jamais validé.
#
# DEUX AXES ORTHOGONAUX, à ne jamais confondre (ADR-0018) :
#   - le statut du DOMAINE dit si le document est arbitré ;
#   - le statut de l'EXIGENCE dit où en est sa réalisation.
# Un domaine actif contient des exigences approuvées mais non réalisées et
# d'autres livrées et prouvées : les compter ensemble revient à ne plus rien
# pouvoir dire de l'avancement.
#
# Invariants du domaine, transposés d'ergonomia (doc 03 §6) :
#   1. chaque domaine porte UN statut, pris au lexique ;
#   2. un domaine ACTIVE est adossé à une décision du registre ;
#   3. l'index des domaines et les en-têtes disent la même chose.
#
# Invariants de l'exigence (ADR-0018) :
#   4. chaque exigence porte un statut DÉCLARÉ, pris au lexique ;
#   5. les statuts d'AVANCEMENT ne se déclarent jamais : ils se calculent
#      depuis les tags réellement posés — un « vérifiée » écrit à la main est
#      un chiffre faux qui inspire d'autant plus confiance qu'il est affiché ;
#   6. une exigence n'est approuvée que dans un domaine actif — c'est ce qui
#      empêche les deux axes de diverger en silence ;
#   7. le statut OpenFastTrace (« Status: … ») concorde avec le statut
#      déclaré : la traçabilité ne retient que les items approuvés (ADR-0021).
#
#   sh tools/statuts.sh
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

[ "${1:-}" = "" ] || { echo "Usage : sh tools/statuts.sh" >&2 ; exit 2 ; }

INDEX="spec/02-exigences/README.md"
FICHIERS="$(git ls-files 'spec/02-exigences/*.md' 2>/dev/null | grep -v "${INDEX}" || true)"
[ -n "${FICHIERS}" ] || { echo "Statuts : aucun domaine de spécification."; exit 0; }

MOTIF_STATUT="$(lex SPEC_PROPOSITION)|$(lex SPEC_ACTIVE)|$(lex SPEC_OBSOLETE)"
# Mots-clés de statut d'OpenFastTrace : vocabulaire de l'outil, invariant
# quelle que soit la langue du dépôt — rien à déclarer au lexique.
OFT_APPROUVE="approved"; OFT_PROPOSE="proposed"; OFT_BROUILLON="draft"; OFT_REJETE="rejected"
# Motif PARENTHÉSÉ — même piège que dans todo.sh (constat de revue n° 1).
LIB_STATUT="$(lex_motif SECTION_STATUT)"
FAILURES=0

# Statut déclaré en tête d'un domaine : « **Statut : ACTIVE** ».
statut_de() {
    awk -v lib="${LIB_STATUT}" -v motif="${MOTIF_STATUT}" '
        $0 ~ ("^\\*\\*" lib "[ \t]*:") {
            ligne = $0
            if (match(ligne, "(" motif ")")) { print substr(ligne, RSTART, RLENGTH); exit }
        }' "$1"
}

for f in ${FICHIERS}; do
    dom="${f##*/}"; dom="${dom%.md}"
    statut="$(statut_de "${f}")"

    # 1. Statut présent et au vocabulaire.
    if [ -z "${statut}" ]; then
        echo "ÉCHEC : ${f} — pas de ligne « **$(lex SECTION_STATUT) : …** » au vocabulaire (${MOTIF_STATUT})." >&2
        FAILURES=$((FAILURES + 1))
        continue
    fi

    # 2. Un domaine ACTIVE s'appuie sur une décision actée. Sans cela, un
    #    domaine peut passer ACTIVE d'un simple trait de plume et gonfler la
    #    couverture sans que personne n'ait rien validé.
    if lex_est SPEC_ACTIVE "${statut}"; then
        if ! grep -q "${dom}" docs/decisions/registre.md 2>/dev/null; then
            echo "ÉCHEC : ${f} — domaine ACTIVE sans entrée au registre des décisions." >&2
            echo "        Acter le domaine (relevé + ligne D-AAAA-MM-NN citant « ${dom} »)," >&2
            echo "        ou le repasser en $(lex SECTION_STATUT) : $(lex SPEC_PROPOSITION)." >&2
            FAILURES=$((FAILURES + 1))
        fi
    fi

    # 3. L'index dit la même chose que l'en-tête.
    if [ -f "${INDEX}" ]; then
        ligne_index="$(grep -F "${dom}.md" "${INDEX}" 2>/dev/null || true)"
        if [ -z "${ligne_index}" ]; then
            echo "ÉCHEC : ${INDEX} — domaine absent de l'index : ${dom}" >&2
            FAILURES=$((FAILURES + 1))
        elif ! printf '%s' "${ligne_index}" | grep -Eq "${MOTIF_STATUT}"; then
            echo "ÉCHEC : ${INDEX} — la ligne de ${dom} ne porte aucun statut." >&2
            FAILURES=$((FAILURES + 1))
        elif ! printf '%s' "${ligne_index}" | grep -Fq "${statut}"; then
            echo "ÉCHEC : ${dom} — l'index et l'en-tête divergent (en-tête : ${statut})." >&2
            FAILURES=$((FAILURES + 1))
        fi
    fi
done

# Dérive inverse : une ligne d'index sans domaine réel. Seules les cibles du
# MÊME répertoire sont des domaines — un renvoi vers la méthode
# (`../../docs/methode/…`) n'en est pas un, et le confondre produisait un
# faux positif à la première rédaction de cette porte.
if [ -f "${INDEX}" ]; then
    for cite in $(grep -oE '\]\([a-z0-9-]+\.md\)' "${INDEX}" | \
                  sed -e 's/^](//' -e 's/)$//' | sort -u); do
        [ -f "spec/02-exigences/${cite}" ] || {
            echo "ÉCHEC : ${INDEX} — cite un domaine inexistant : ${cite}" >&2
            FAILURES=$((FAILURES + 1))
        }
    done
fi

# --- Statuts des exigences (ADR-0018) ---------------------------------------
# Tags de couverture réellement posés dans le dépôt, tous types aval confondus.
# C'est la seule source de l'avancement : ce que le dépôt PROUVE, pas ce qu'une
# ligne affirme.
TAGS="$(git grep -hoE '\[(impl|utest|itest|stest|mtest)->req~[a-z0-9-]+~[0-9]+\]' \
        2>/dev/null || true)"

# La couverture ne passe pas QUE par des tags : une procédure de vérification
# manuelle est un ITEM qui déclare « Covers: req~… ». L'ignorer ferait passer
# pour non vérifiées les exigences que la méthode couvre justement à la main
# — le contraire du but (méthode, ch. 5).
COUVERTURES="$(awk '
    /^`(mtest|dsn|utest|itest|stest)~[a-z0-9-]+~[0-9]+`[ \t]*$/ {
        type = $0; sub(/~.*/, "", type); gsub(/`/, "", type); item_type = type; next
    }
    /^Covers:/ { dans = 1; next }
    dans && /^- / { id = $0; sub(/^- /, "", id); print item_type "\t" id; next }
    dans && NF == 0 { dans = 0 }
' $(git ls-files 'docs/**/*.md' 'spec/**/*.md' 2>/dev/null) 2>/dev/null || true)"

a_tag() {   # a_tag <identifiant> <types séparés par |>
    printf '%s\n' "${TAGS}" | grep -qE "\[($2)->$1\]" && return 0
    printf '%s\n' "${COUVERTURES}" | grep -qE "^($2)	$1\$"
}

nb_approuvees=0; nb_implementees=0; nb_verifiees=0; nb_autres=0

for f in ${FICHIERS}; do
    dom="${f##*/}"; dom="${dom%.md}"
    dom_actif=0
    lex_est SPEC_ACTIVE "$(statut_de "${f}")" && dom_actif=1

    # Chaque exigence, la ligne de statut qui la suit, et le statut
    # OpenFastTrace (« Status: … » collé sous l'identifiant, seule place où
    # l'outil le lit) — « approved » quand il est absent (ADR-0021).
    exigences="$(awk '
        /^`req~[a-z0-9-]+~[0-9]+`[ \t]*$/ {
            id = $0; gsub(/`/, "", id); gsub(/[ \t]/, "", id)
            attente = 1; oft = "approved"; colle = 1; next
        }
        attente && colle && /^Status:/ {
            oft = $0; sub(/^Status:[ \t]*/, "", oft); gsub(/[ \t]+$/, "", oft)
            colle = 0; next
        }
        attente { colle = 0 }
        attente && /^\*\*/ {
            st = $0
            sub(/^[^:]*:[ \t]*/, "", st); sub(/\*\*[ \t]*$/, "", st)
            gsub(/[ \t]+$/, "", st)
            print id "\t" st "\t" oft "\t" FNR
            attente = 0; next
        }
        attente && NF > 0 { print id "\t\t" oft "\t" FNR; attente = 0 }
    ' "${f}")"

    for entree in ${exigences}; do
        id="${entree%%	*}"
        reste="${entree#*	}"
        statut="${reste%%	*}"
        reste="${reste#*	}"
        oft="${reste%%	*}"
        ligne="${reste##*	}"

        # 4. statut déclaré, au vocabulaire.
        if [ -z "${statut}" ]; then
            echo "ÉCHEC : ${f}:${ligne} — ${id} : pas de ligne « **$(lex SECTION_STATUT) : …** »." >&2
            echo "        Déclarés : $(lex EXIGENCE_BROUILLON) | $(lex EXIGENCE_PROPOSEE) | $(lex EXIGENCE_APPROUVEE) | $(lex EXIGENCE_REJETEE) | $(lex EXIGENCE_DEPRECIEE)" >&2
            FAILURES=$((FAILURES + 1))
            continue
        fi

        # 5. un statut d'avancement ne se déclare pas.
        if lex_est EXIGENCE_IMPLEMENTEE "${statut}" || lex_est EXIGENCE_VERIFIEE "${statut}"; then
            echo "ÉCHEC : ${f}:${ligne} — ${id} déclare « ${statut} », qui se CALCULE." >&2
            echo "        Un avancement saisi se périme au premier remaniement, sans rien signaler." >&2
            FAILURES=$((FAILURES + 1))
            continue
        fi

        # 7. le statut lu par OpenFastTrace suit le statut déclaré. La porte
        #    de traçabilité ne retient que les items « approved » (ADR-0021) :
        #    sans cette concordance, une exigence approuvée marquée
        #    « Status: draft » échapperait à la traçabilité en silence.
        if lex_est EXIGENCE_APPROUVEE "${statut}"; then attendu="${OFT_APPROUVE}"
        elif lex_est EXIGENCE_PROPOSEE "${statut}"; then attendu="${OFT_PROPOSE}"
        elif lex_est EXIGENCE_BROUILLON "${statut}"; then attendu="${OFT_BROUILLON}"
        else attendu="${OFT_REJETE}"
        fi
        if [ "${oft}" != "${attendu}" ]; then
            echo "ÉCHEC : ${f}:${ligne} — ${id} déclare « ${statut} » mais OpenFastTrace lit « ${oft} » (attendu : ${attendu})." >&2
            if [ "${attendu}" = "${OFT_APPROUVE}" ]; then
                echo "        Retirer la ligne « Status: ${oft} » sous l'identifiant." >&2
            else
                echo "        Placer « Status: ${attendu} » sur la ligne qui suit l'identifiant." >&2
            fi
            FAILURES=$((FAILURES + 1))
            continue
        fi

        if lex_est EXIGENCE_APPROUVEE "${statut}"; then
            # 6. compatibilité avec l'axe du domaine.
            if [ "${dom_actif}" -eq 0 ]; then
                echo "ÉCHEC : ${f}:${ligne} — ${id} est approuvée dans un domaine non actif." >&2
                FAILURES=$((FAILURES + 1))
                continue
            fi
            nb_approuvees=$((nb_approuvees + 1))
            # Avancement CALCULÉ.
            if a_tag "${id}" "impl"; then
                nb_implementees=$((nb_implementees + 1))
                a_tag "${id}" "utest|itest|stest|mtest" && nb_verifiees=$((nb_verifiees + 1))
            fi
        elif lex_est EXIGENCE_BROUILLON "${statut}" || lex_est EXIGENCE_PROPOSEE "${statut}" \
          || lex_est EXIGENCE_REJETEE "${statut}" || lex_est EXIGENCE_DEPRECIEE "${statut}"; then
            nb_autres=$((nb_autres + 1))
        else
            echo "ÉCHEC : ${f}:${ligne} — ${id} : statut hors lexique « ${statut} »." >&2
            FAILURES=$((FAILURES + 1))
        fi
    done
done

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} défaut(s) de statut." >&2
    exit 1
fi
echo "Statuts : OK — domaines conformes ; ${nb_approuvees} exigence(s) approuvée(s)"
printf '  avancement calculé : %s implémentée(s), %s vérifiée(s)' "${nb_implementees}" "${nb_verifiees}"
[ "${nb_autres}" -eq 0 ] && echo "." || echo " ; ${nb_autres} hors dénominateur."
