#!/bin/sh
# [impl->req~journaux-depot-et-logiciel~1]
# Les deux journaux, et l'intangibilité de ce qui est publié.
#
# CHANGELOG ⟂ NEWS — deux lectorats, deux fichiers :
#   CHANGELOG.md = journal du DÉPÔT. Ce qui change pour qui contribue :
#                  portes, méthode, outillage, refactorisations.
#   NEWS.md      = journal du LOGICIEL (convention GNU). Ce qui change pour
#                  qui utilise ou exploite le produit livré.
# Les confondre produit soit un journal illisible pour l'utilisateur (noyé
# dans l'outillage), soit un journal muet pour le contributeur. Un projet
# sans logiciel livrable — un gabarit, une bibliothèque de méthode — n'a pas
# de NEWS : le fichier est alors absent, et c'est un choix, pas un oubli.
#
# SECTIONS CLOSES : une version publiée ne se réécrit pas. Piège constaté
# trois fois sur ergonomia les 16 et 17/08/2026 — des entrées ajoutées après
# coup dans la section d'une version déjà taguée, donc absentes du paquet
# réellement livré sous ce numéro. Le contrôle est mécanique : chaque ligne
# d'une section close doit provenir d'un commit ANCÊTRE du tag de sa version.
#
#   sh tools/journaux.sh
#
# POSIX sh + awk + git.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
. "${ROOT}/tools/lexique.sh"

[ "${1:-}" = "" ] || { echo "Usage : sh tools/journaux.sh" >&2 ; exit 2 ; }

# Fenêtre de contrôle : au-delà, l'attribution de lignes ne mesure plus rien
# d'utile (un fichier créé tardivement porte des lignes anciennes réécrites en
# bloc). Surchargeable — un projet qui publie souvent voudra une fenêtre plus
# large, un projet qui vient de reprendre son journal une plus étroite.
FENETRE="${JOURNAUX_FENETRE:-6}"

# Commits de RÉVISION ÉDITORIALE tolérés : reformatage, correction de faute,
# migration d'outil — des changements qui ne touchent pas au FOND d'une
# section close. Fichier distinct de .git-blame-ignore-revs pour ne pas
# fausser le blame global du dépôt avec des commits qui portent par ailleurs
# du vrai contenu.
EXCEPTIONS="tools/journaux-revisions-editoriales.txt"

FAILURES=0
LIB_NON_PUBLIE="$(lex JOURNAL_NON_PUBLIE)"

# --- 1. Cohérence VERSION ↔ journaux ----------------------------------------
version="$(cat VERSION)"
for journal in CHANGELOG.md NEWS.md; do
    [ -f "${journal}" ] || continue
    if ! grep -q "^## \[${version}\]" "${journal}"; then
        # Une version encore en préparation vit sous « Non publié » : ce n'est
        # un défaut que si le journal ne porte NI la version, NI cette section.
        if ! grep -qE "^## \[(${LIB_NON_PUBLIE})\]" "${journal}"; then
            echo "ÉCHEC : ${journal} — ni section [${version}], ni section [${LIB_NON_PUBLIE}]." >&2
            FAILURES=$((FAILURES + 1))
        fi
    fi
done

# --- 2. Sections closes ------------------------------------------------------
est_tolere() {
    [ -f "${EXCEPTIONS}" ] || return 1
    grep -qE "^$1" "${EXCEPTIONS}" 2>/dev/null
}

controler_sections_closes() {
    _journal="$1"
    [ -f "${_journal}" ] || return 0
    git ls-files --error-unmatch "${_journal}" >/dev/null 2>&1 || return 0

    # Plages de lignes par version publiée, les FENETRE plus récentes.
    _plages="$(awk -v non_publie="${LIB_NON_PUBLIE}" '
        /^## \[/ {
            if (v != "") print v "\t" debut "\t" (FNR - 1)
            v = $0
            sub(/^## \[/, "", v); sub(/\].*$/, "", v)
            debut = FNR
            if (v ~ ("^(" non_publie ")$")) v = ""
        }
        END { if (v != "") print v "\t" debut "\t" FNR }
    ' "${_journal}" | head -n "${FENETRE}")"

    [ -n "${_plages}" ] || return 0

    _blame="$(mktemp)"
    # -M suit les déplacements de lignes : une section déplacée dans le
    # fichier n'est pas une réécriture de son contenu.
    git blame --line-porcelain -M -- "${_journal}" 2>/dev/null | \
        awk '/^[0-9a-f]{40} /{ sha = $1 } /^\t/ { n++; print n "\t" sha }' > "${_blame}"

    printf '%s\n' "${_plages}" | while IFS="$(printf '\t')" read -r v debut fin; do
        [ -n "${v}" ] || continue
        tag=""
        for candidat in "v${v}" "${v}"; do
            if git rev-parse -q --verify "refs/tags/${candidat}" >/dev/null 2>&1; then
                tag="${candidat}"; break
            fi
        done
        if [ -z "${tag}" ]; then
            # Sans tag, « publiée » n'est qu'une affirmation du journal : rien
            # à vérifier, et surtout rien à conclure.
            echo "  ${_journal} — [${v}] : pas de tag, section non contrôlée."
            continue
        fi
        _fautifs="$(awk -v d="${debut}" -v f="${fin}" '$1 >= d && $1 <= f { print $2 }' "${_blame}" | sort -u)"
        for sha in ${_fautifs}; do
            case "${sha}" in 0000000000000000000000000000000000000000) continue ;; esac
            est_tolere "${sha}" && continue
            if ! git merge-base --is-ancestor "${sha}" "${tag}" 2>/dev/null; then
                echo "ÉCHEC : ${_journal} — section close [${v}] modifiée après le tag ${tag}" >&2
                echo "        commit ${sha} — $(git log -1 --format=%s "${sha}" 2>/dev/null)" >&2
                echo "        Une version publiée ne se réécrit pas : porter l'entrée sous" >&2
                echo "        « ${LIB_NON_PUBLIE} », ou déclarer une révision éditoriale dans" >&2
                echo "        ${EXCEPTIONS}." >&2
                echo "FAUTIF" >> "${_blame}.verdict"
            fi
        done
    done

    if [ -f "${_blame}.verdict" ]; then
        rm -f "${_blame}" "${_blame}.verdict"
        return 1
    fi
    rm -f "${_blame}"
    return 0
}

for journal in CHANGELOG.md NEWS.md; do
    controler_sections_closes "${journal}" || FAILURES=$((FAILURES + 1))
done

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} défaut(s) sur les journaux." >&2
    exit 1
fi
echo "Journaux : OK."
