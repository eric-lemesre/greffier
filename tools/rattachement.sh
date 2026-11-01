#!/bin/sh
# [impl->req~rattachement-code-exigence~1]
# Porte du rattachement : tout fichier de code suivi par git se rattache à
# une exigence existante.
#
# Pourquoi cette porte existe. OpenFastTrace part des exigences et cherche
# leurs couvertures : il ne voit jamais le code qui ne revendique RIEN. La
# matrice (tools/matrice.sh) le montre en section 2, mais à titre informatif,
# et sur l'outillage seulement. Constaté dans un projet aval : plus d'une
# centaine de fichiers de code s'y étaient accumulés sans trace, sans
# qu'aucune porte ne bronche. Et OpenFastTrace ne balaie pas templates/ : une
# étiquette périmée posée dans le matériel prêt à copier n'y casse rien.
#
# Un fichier de code suivi par git (extensions de EXTENSIONS ci-dessous) est
# RATTACHÉ quand il porte au moins une de ces deux traces :
#   - une étiquette de couverture `[<type>->req~…~n]` (impl, utest, itest,
#     stest…) dont l'item existe ;
#   - la mention d'une exigence qui existe, écrite par convention
#     `Exigence servie : req~…~n` — la forme honnête pour un outil d'appoint,
#     un fichier de structure, du matériel prêt à copier : elle dit
#     l'exigence servie sans prétendre la couvrir, et OpenFastTrace ne la lit
#     pas comme une couverture.
# Une étiquette dont l'item n'existe pas (révision périmée, faute de frappe)
# fait échouer, qu'une autre trace soit valide ou non. Une mention d'un
# identifiant inconnu ne fait pas échouer — la prose cite aussi des
# révisions remplacées — mais ne rattache pas.
#
# Les items existants sont les définitions (identifiant seul entre accents
# graves sur sa ligne) des fichiers Markdown suivis, hors blocs de code et
# hors templates/ — le périmètre d'OpenFastTrace (tools/oft.sh) : un
# identifiant d'exemple d'un modèle n'est pas un item.
#
# Code hérité du gabarit (projet instancié seulement). L'instanciation retire
# la spécification du gabarit et les traces de son outillage : ce code ne
# peut plus se rattacher à rien dans le projet. tools/init.sh en dresse la
# liste dans tools/rattachement-herites.txt (un chemin par ligne). Une
# déclaration doit viser un fichier de code suivi, sans trace propre ; le
# gabarit lui-même n'hérite de rien et refuse ce fichier. Un fichier ajouté
# par le projet n'y figure pas : il se rattache à ses exigences.
#
#   sh tools/rattachement.sh           # contrôle (bloquant)
#   sh tools/rattachement.sh --liste   # fichiers sans rattachement, un par
#                                      # ligne, sans échouer (tools/init.sh)
#
# POSIX sh strict ; git, grep -E, sed, awk.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

MODE="controle"
case "${1:-}" in
    '') ;;
    --liste) MODE="liste" ;;
    *) echo "Usage : sh tools/rattachement.sh [--liste]" >&2; exit 2 ;;
esac

# Extensions tenues pour du code. Le gabarit est agnostique du langage : la
# liste couvre les langages courants ; un projet l'étend au besoin.
EXTENSIONS='sh|bash|ps1|py|rs|go|java|kt|kts|scala|c|h|cc|cpp|hpp|cs|swift|rb|php|ts|tsx|js|jsx|mjs|cjs|sql'
HERITES="tools/rattachement-herites.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

# --- Items existants ------------------------------------------------------------
: > "${TMP}/items"
git ls-files '*.md' | grep -v '^templates/' > "${TMP}/docs" || true
while IFS= read -r doc; do
    [ -f "${doc}" ] || continue
    awk '
        /^[ \t]*```/ { dans_bloc = !dans_bloc; next }
        dans_bloc { next }
        /^[ \t]*`[a-z]+~[A-Za-z0-9_.-]+~[0-9]+`[ \t]*$/ {
            gsub(/[ \t`]/, ""); print
        }
    ' "${doc}" >> "${TMP}/items"
done < "${TMP}/docs"
sort -u -o "${TMP}/items" "${TMP}/items"

# --- Fichiers de code suivis ------------------------------------------------------
git ls-files | grep -E "\.(${EXTENSIONS})$" > "${TMP}/code" || true

fautes=0
signale() {
    [ "${MODE}" = "controle" ] && echo "ÉCHEC : $*" >&2
    fautes=$((fautes + 1))
}

# --- Déclarations du code hérité ----------------------------------------------------
: > "${TMP}/herites"
if [ -f "${HERITES}" ]; then
    if [ -f tools/init.sh ]; then
        signale "${HERITES} — le gabarit n'hérite de rien : ce fichier n'existe que dans un projet instancié"
    else
        grep -vE '^[[:space:]]*(#|$)' "${HERITES}" > "${TMP}/declarations" || true
        while IFS= read -r chemin; do
            if grep -qxF "${chemin}" "${TMP}/code"; then
                printf '%s\n' "${chemin}" >> "${TMP}/herites"
            else
                signale "${HERITES} — ${chemin} n'est pas un fichier de code suivi par git"
            fi
        done < "${TMP}/declarations"
    fi
fi

# --- Rattachement de chaque fichier ---------------------------------------------------
sans=0
while IFS= read -r f; do
    [ -f "${f}" ] || continue
    rattache=0

    # Étiquettes de couverture, forme courte ou complète : chacune doit
    # viser un item existant.
    grep -oE '\[[a-z]+(~[A-Za-z0-9_.-]+~[0-9]+)?->[a-z]+~[A-Za-z0-9_.-]+~[0-9]+(>>[a-z, ]*)?\]' "${f}" 2>/dev/null \
        | sort -u > "${TMP}/etiquettes" || true
    while IFS= read -r etiquette; do
        item="$(printf '%s' "${etiquette}" | sed -e 's/^.*->//' -e 's/>>.*$//' -e 's/\]$//')"
        if grep -qxF "${item}" "${TMP}/items"; then
            rattache=1
        else
            signale "${f} — ${etiquette} vise un item qui n'existe pas (révision périmée ?)"
        fi
    done < "${TMP}/etiquettes"

    # Mentions : au moins une exigence existante.
    if [ "${rattache}" -eq 0 ] && \
        grep -oE 'req~[A-Za-z0-9_.-]+~[0-9]+' "${f}" 2>/dev/null | sort -u \
            | grep -qxF -f "${TMP}/items"; then
        rattache=1
    fi

    # Code hérité du gabarit : déclaré, et seulement s'il n'a pas de trace.
    if grep -qxF "${f}" "${TMP}/herites"; then
        if [ "${rattache}" -eq 1 ]; then
            signale "${HERITES} — ${f} porte déjà sa trace : retirer la déclaration"
        fi
        rattache=1
    fi

    if [ "${rattache}" -eq 0 ]; then
        sans=$((sans + 1))
        if [ "${MODE}" = "liste" ]; then
            printf '%s\n' "${f}"
        else
            echo "ÉCHEC : ${f} ne se rattache à aucune exigence existante" >&2
        fi
    fi
done < "${TMP}/code"

[ "${MODE}" = "liste" ] && exit 0

total="$(wc -l < "${TMP}/code" | tr -d ' ')"
if [ "${sans}" -gt 0 ] || [ "${fautes}" -gt 0 ]; then
    echo "Rattachement : ${sans} fichier(s) de code sur ${total} sans exigence, ${fautes} autre(s) faute(s)." >&2
    echo "Poser une étiquette [impl->req~…~n] (ou utest, itest, stest) quand le fichier couvre l'exigence," >&2
    echo "sinon la mention « Exigence servie : req~…~n » d'une exigence existante." >&2
    exit 1
fi
echo "Rattachement : OK — ${total} fichier(s) de code, chacun rattaché à une exigence."
