#!/bin/sh
# [impl->req~donnees-hors-depot~1]
# Porte des données : le dépôt porte le MODÈLE des données, jamais les données.
#
# Trois refus, tous constatés sur le CONTENU et non sur un nom de fichier. Un
# .gitignore ne protège que du geste distrait : il n'empêche ni un
# « git add -f », ni le suivi d'un fichier déjà versionné, et il ne dit rien
# de ce qu'un fichier porte.
#
#   1. aucun export versionné — archive, tableur, sauvegarde ;
#   2. aucun SQL versionné porteur de données : seuls les schémas sont admis,
#      donc ni INSERT ni COPY … FROM stdin. C'est le cas le plus insidieux —
#      nom, extension et emplacement sont alors légitimes, et seules les
#      lignes trahissent l'extrait de production ;
#   3. aucun chemin de partage réseau qualifié : nom de serveur et domaine
#      d'annuaire renseignent sur l'infrastructure d'une organisation, et ils
#      arrivent au dépôt par le même chemin que le reste — recopiés d'un code
#      existant que l'on documente.
#
#   sh tools/donnees.sh
#
# POSIX sh + grep.
set -eu

# Chemins portant espaces ou métacaractères : on découpe sur les seules fins
# de ligne, globbing désactivé.
IFS='
'
set -f

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

[ "${1:-}" = "" ] || { echo "Usage : sh tools/donnees.sh" >&2 ; exit 2 ; }

# --- fixtures:debut ---------------------------------------------------------
# Chemins où un SQL PEUT porter des données : jeux d'essai SYNTHÉTIQUES, et
# eux seuls. Le gabarit n'en déclare aucun ; ne pas déplacer les marqueurs,
# tools/donnees-test.sh les remplace pour éprouver la mécanique.
#
# Un projet instancié déclare ici ses chemins, en vérification de sa propre
# décision, un par ligne. Exemple :
#   FIXTURES="tests/fixtures
#   src/sql/jeux-d-essai"
#
# Règle de mise en place (R3) : après avoir déclaré un chemin, y placer un SQL
# porteur de données et vérifier que la porte le laisse passer, puis placer le
# MÊME fichier hors de ce chemin et vérifier qu'elle le refuse. Un chemin trop
# large — « src », « . » — rouvre la porte en grand sans que rien ne le dise.
FIXTURES=""
# --- fixtures:fin -----------------------------------------------------------

FAILURES=0
SUIVIS="$(git ls-files 2>/dev/null || true)"

sous_fixtures() {
    [ -n "${FIXTURES}" ] || return 1
    for _prefixe in ${FIXTURES}; do
        [ -n "${_prefixe}" ] || continue
        case "$1" in
            "${_prefixe}"/*|"${_prefixe}") return 0 ;;
        esac
    done
    return 1
}

# --- 1. Exports versionnés ---------------------------------------------------
exports="$(printf '%s\n' "${SUIVIS}" | \
    grep -iE '\.(zip|gz|tgz|dump|bak|csv|tsv|xls|xlsx|xlsm)$' || true)"
if [ -n "${exports}" ]; then
    for f in ${exports}; do
        echo "ÉCHEC : export de données versionné : ${f}" >&2
    done
    echo "        Le dépôt porte le modèle des données, jamais les données." >&2
    FAILURES=$((FAILURES + 1))
else
    echo "ok — aucun export de données versionné"
fi

# --- 2. SQL porteur de données ----------------------------------------------
# Le motif est assemblé à l'exécution : écrit en clair, il ferait échouer
# cette porte sur son propre fichier le jour où on le rangerait en .sql.
motif_donnees="$(printf 'INSERT[ \t]+INTO|^COPY[ \t].*FROM[ \t]+stdin')"
avec_donnees=""
for f in $(printf '%s\n' "${SUIVIS}" | grep -E '\.sql$' || true); do
    [ -f "${f}" ] || continue
    sous_fixtures "${f}" && continue
    if grep -qiE "${motif_donnees}" "${f}"; then
        avec_donnees="${avec_donnees}${f}
"
    fi
done
if [ -n "${avec_donnees}" ]; then
    for f in ${avec_donnees}; do
        echo "ÉCHEC : SQL versionné porteur de données : ${f}" >&2
    done
    echo "        Seuls les schémas peuvent figurer : un DDL, jamais son contenu." >&2
    echo "        Un jeu d'essai synthétique se déclare au bloc « fixtures » de cette porte." >&2
    FAILURES=$((FAILURES + 1))
else
    echo "ok — aucun SQL versionné ne porte de données"
fi

# --- 3. Chemins de partage réseau qualifiés ---------------------------------
# Un chemin UNC dont l'hôte porte un domaine : « \\serveur.domaine\… ». Le
# motif est assemblé, faute de quoi ce fichier se dénoncerait lui-même.
bs='\\'
motif_unc="${bs}${bs}${bs}${bs}[A-Za-z0-9_-]+[.][A-Za-z0-9._-]+${bs}${bs}"
partages="$(git grep -lIE "${motif_unc}" -- . 2>/dev/null | grep -v '^tools/donnees' || true)"
if [ -n "${partages}" ]; then
    for f in ${partages}; do
        echo "ÉCHEC : chemin de partage réseau qualifié : ${f}" >&2
    done
    echo "        Nom de serveur et domaine d'annuaire n'ont pas leur place ici." >&2
    FAILURES=$((FAILURES + 1))
else
    echo "ok — aucun chemin de partage réseau qualifié"
fi

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} contrôle(s) de données en échec." >&2
    exit 1
fi
echo "Porte des données : OK."
