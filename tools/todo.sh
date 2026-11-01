#!/bin/sh
# [impl->req~feuille-de-route-outillee~1]
# Feuille de route : cohérence des fiches et GÉNÉRATION de leur index.
#
# Pourquoi cette porte existe. Un index tenu à la main finit toujours par
# mentir. Cas fondateur (ergonomia, 2026-08-11) : sept lignes de l'index
# annonçaient « à venir » ou « en cours » des jalons livrés depuis des
# semaines — même dérive que les statuts de spécification corrigés le même
# jour. Ici l'index n'est plus tenu : il est DÉRIVÉ des fiches (R8), et la
# porte anti-dérive refuse un index édité à la main.
#
#   sh tools/todo.sh             # contrôle les fiches et la fraîcheur de l'index
#   sh tools/todo.sh --ecrire    # régénère docs/todo/README.md
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

ECRIRE=0
case "${1:-}" in
    --ecrire) ECRIRE=1 ;;
    "") ;;
    *) echo "Usage : sh tools/todo.sh [--ecrire]" >&2 ; exit 2 ;;
esac

REP="docs/todo"
INDEX="${REP}/README.md"
mkdir -p "${REP}"

# Motif PARENTHÉSÉ : « Statut|Status » inséré nu dans une regex donnerait
# « ^\*\*Statut|Status[ \t]*: » — deux branches fausses (constat de revue).
LIBELLE="$(lex_motif TODO_LIBELLE)"
PASTILLES="$(lex TODO_FAIT)$(lex TODO_EN_COURS)$(lex TODO_A_VENIR)"

FICHES="$(git ls-files "${REP}/todo-*.md" 2>/dev/null || true)"

# Rendu de l'index : une ligne par fiche, dans l'ordre des identifiants.
rendre() {
    if [ "${LEXIQUE_LANGUE}" = "en" ]; then
        cat <<'EOF'
# Roadmap

<!-- GÉNÉRÉ par tools/todo.sh — ne pas éditer à la main (R8). -->

| Card | Status | Title |
| --- | --- | --- |
EOF
    else
        cat <<'EOF'
# Feuille de route

<!-- GÉNÉRÉ par tools/todo.sh — ne pas éditer à la main (R8). -->

| Fiche | Statut | Titre |
| --- | --- | --- |
EOF
    fi
    [ -n "${FICHES}" ] || return 0
    for f in ${FICHES}; do
        titre="$(awk '/^#[ \t]+/ { sub(/^#[ \t]+/, ""); print; exit }' "${f}")"
        statut="$(awk -v l="${LIBELLE}" '
            $0 ~ ("^\\*\\*" l "[ \t]*:") {
                sub(/^[^:]*:[ \t]*/, "")
                sub(/\*\*[ \t]*$/, "")
                gsub(/[ \t]+$/, "")
                print; exit
            }' "${f}")"
        printf '| [%s](%s) | %s | %s |\n' "${f##*/}" "${f##*/}" "${statut}" "${titre}"
    done
}

# --- Contrôle des fiches ----------------------------------------------------
FAILURES=0
for f in ${FICHES}; do
    ligne="$(awk -v l="${LIBELLE}" '$0 ~ ("^\\*\\*" l "[ \t]*:") { print; exit }' "${f}")"
    if [ -z "${ligne}" ]; then
        echo "ÉCHEC : ${f} — ligne « **${LIBELLE} : …** » absente." >&2
        FAILURES=$((FAILURES + 1))
        continue
    fi
    case "${ligne}" in
        *"$(lex TODO_FAIT)"*|*"$(lex TODO_EN_COURS)"*|*"$(lex TODO_A_VENIR)"*) ;;
        *)
            echo "ÉCHEC : ${f} — statut sans pastille reconnue (${PASTILLES})." >&2
            FAILURES=$((FAILURES + 1))
            ;;
    esac
done

if [ "${ECRIRE}" -eq 1 ]; then
    rendre > "${INDEX}.tmp"
    mv "${INDEX}.tmp" "${INDEX}"
    echo "Index de la feuille de route régénéré : ${INDEX}"
else
    rendre > "${INDEX}.verif"
    if ! cmp -s "${INDEX}.verif" "${INDEX}" 2>/dev/null; then
        echo "ÉCHEC : ${INDEX} périmé — exécuter « sh tools/todo.sh --ecrire »." >&2
        FAILURES=$((FAILURES + 1))
    fi
    rm -f "${INDEX}.verif"
fi

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} défaut(s) sur la feuille de route." >&2
    exit 1
fi
echo "Feuille de route : OK."
