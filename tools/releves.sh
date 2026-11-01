#!/bin/sh
# [impl->req~releves-de-decision~1]
# Contrôle des relevés de séance et du registre des décisions.
#
# Pourquoi cette porte existe — le précédent qui l'a motivée (ergonomia,
# juillet 2026). Le document d'une séance de paramétrage portait une section
# « Relevé de décisions (à compléter en séance) ». Elle n'a JAMAIS été
# remplie : zéro décision consignée, registre resté à zéro entrée. Les
# décisions avaient pourtant bien été prises — on les retrouve citées dans
# les spécifications sous la forme « décision 94.4 » — et les issues
# correspondantes ont été fermées. La trace opposable, elle, n'existait pas.
#
# Trois invariants :
#   1. tout relevé porte une section de décisions NON VIDE (le modèle
#      livre un gabarit à remplir : le laisser tel quel est le défaut type) ;
#   2. toute décision D-AAAA-MM-NN citée dans un relevé figure au registre ;
#   3. toute décision du registre renvoie vers un relevé ou un ADR existant.
#
#   sh tools/releves.sh
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

[ "${1:-}" = "" ] || { echo "Usage : sh tools/releves.sh" >&2 ; exit 2 ; }

REGISTRE="docs/decisions/registre.md"
RELEVES="$(git ls-files 'docs/decisions/*.md' 2>/dev/null | grep -v "${REGISTRE}" || true)"
FAILURES=0

[ -f "${REGISTRE}" ] || { echo "ÉCHEC : ${REGISTRE} absent." >&2; exit 1; }

SECTION="$(lex SECTION_DECISIONS)"

# --- 1. Aucun relevé sans décision consignée --------------------------------
for f in ${RELEVES}; do
    corps="$(awk -v s="${SECTION}" '
        $0 ~ ("^#+[ \t]+.*(" s ")") { dans = 1; next }
        dans && /^#+[ \t]/ { dans = 0 }
        dans { print }
    ' "${f}")"

    if [ -z "$(printf '%s' "${corps}" | tr -d '[:space:]')" ]; then
        echo "ÉCHEC : ${f} — section « ${SECTION} » absente ou vide." >&2
        echo "        Un relevé sans décision consignée ne prouve rien : la séance" >&2
        echo "        a eu lieu, la trace opposable n'existe pas." >&2
        FAILURES=$((FAILURES + 1))
        continue
    fi

    # Gabarit laissé tel quel : les accolades du modèle trahissent une
    # section jamais remplie, qui passerait le test « non vide ».
    if printf '%s' "${corps}" | grep -q '{{'; then
        echo "ÉCHEC : ${f} — section « ${SECTION} » restée à l'état de gabarit ({{ … }})." >&2
        FAILURES=$((FAILURES + 1))
        continue
    fi

    # 2. Les décisions citées existent au registre.
    for d in $(printf '%s' "${corps}" | grep -oE 'D-[0-9]{4}-[0-9]{2}-[0-9]{2,3}' | sort -u); do
        grep -q "${d}" "${REGISTRE}" || {
            echo "ÉCHEC : ${f} — décision ${d} absente du registre." >&2
            FAILURES=$((FAILURES + 1))
        }
    done
done

# --- 3. Le registre ne renvoie pas dans le vide -----------------------------
# Chaque ligne de décision cite soit un ADR, soit un relevé : les deux doivent
# exister. Une entrée qui renvoie vers un document jamais versé est le
# symétrique du relevé jamais rempli.
while IFS= read -r ligne; do
    case "${ligne}" in
        "| D-"*) ;;
        *) continue ;;
    esac
    id="$(printf '%s' "${ligne}" | grep -oE 'D-[0-9]{4}-[0-9]{2}-[0-9]{2,3}' | head -1)"
    for adr in $(printf '%s' "${ligne}" | grep -oE 'ADR-[0-9]{4}' | sort -u); do
        num="${adr#ADR-}"
        # Un ADR cité comme provenance externe (« du gabarit alm-forge »)
        # n'est pas un fichier de ce dépôt : on ne l'exige pas.
        case "${ligne}" in
            *"alm-forge"*) continue ;;
        esac
        # « ls docs/adr/${num}-*.md » dépendrait du globbing, désactivé
        # ci-dessus : on interroge l'index, qui est de toute façon la seule
        # source qui vaille (un ADR non versionné n'existe pour personne).
        if ! git ls-files "docs/adr/${num}-*.md" | grep -q .; then
            echo "ÉCHEC : ${REGISTRE} — ${id} renvoie vers ${adr}, introuvable dans docs/adr/." >&2
            FAILURES=$((FAILURES + 1))
        fi
    done
done < "${REGISTRE}"

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} défaut(s) sur les relevés et le registre." >&2
    exit 1
fi
echo "Relevés de décision : OK."
