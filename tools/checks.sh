#!/bin/sh
# Contrôles de cohérence du dépôt, exécutés par le hook pre-commit, la CI et
# les façades d'orchestration. POSIX sh strict, uniquement des commandes
# intégrées et utilitaires universels (cat, ls) : aucun grep/sed/diff requis.
# Chaque contrôle est tagué vers l'exigence qu'il réalise (R2) et a été testé
# sur son cas d'échec à sa mise en place (R3).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
FAILURES=0

# --- parite-templates:debut ---
# Parité des templates fr/en : mêmes noms de fichiers des deux côtés.
# Bloc retiré à l'instanciation quand une seule langue est conservée
# (ADR-0009) ; ne pas déplacer les marqueurs.
parity_fail=0
for f in templates/fr/*.md; do
    if [ ! -f "templates/en/${f##*/}" ]; then
        echo "ÉCHEC : templates/en/${f##*/} manquant" >&2
        parity_fail=1
    fi
done
for f in templates/en/*.md; do
    if [ ! -f "templates/fr/${f##*/}" ]; then
        echo "ÉCHEC : templates/fr/${f##*/} manquant" >&2
        parity_fail=1
    fi
done
if [ "${parity_fail}" -eq 0 ]; then
    echo "ok — parité des templates fr/en"
else
    FAILURES=$((FAILURES + 1))
fi
# --- parite-templates:fin ---

# Tout ADR au statut Accepté comporte une section « ## Vérification » (R6).
adr_fail=0
for f in docs/adr/[0-9]*.md; do
    # Glob sans correspondance (projet fraîchement instancié, aucun ADR) :
    # la chaîne littérale reste — l'ignorer au lieu d'échouer sur la lecture.
    [ -e "${f}" ] || continue
    accepte=0
    verif=0
    while IFS= read -r line; do
        case "${line}" in
            "**Statut** : Accepté"*) accepte=1 ;;
            "## Vérification"*) verif=1 ;;
        esac
    done < "${f}"
    if [ "${accepte}" -eq 1 ] && [ "${verif}" -eq 0 ]; then
        echo "ÉCHEC : ADR accepté sans section Vérification : ${f}" >&2
        adr_fail=1
    fi
done
if [ "${adr_fail}" -eq 0 ]; then
    echo "ok — section Vérification présente dans les ADR acceptés"
else
    FAILURES=$((FAILURES + 1))
fi

# La version du fichier VERSION a sa section dans le CHANGELOG (Keep a Changelog).
version="$(cat VERSION)"
found=0
while IFS= read -r line; do
    case "${line}" in
        "## [${version}]"*) found=1 ;;
    esac
done < CHANGELOG.md
if [ "${found}" -eq 1 ]; then
    echo "ok — VERSION ${version} présente dans le CHANGELOG"
else
    echo "ÉCHEC : la version ${version} (fichier VERSION) n'a pas de section dans CHANGELOG.md" >&2
    FAILURES=$((FAILURES + 1))
fi

# Tout ADR a sa ligne dans l'index, et réciproquement. Même dérive que tout
# index tenu à la main : il finit par ignorer les décisions récentes, et une
# décision qu'on ne trouve plus est une décision qu'on rouvre.
if [ -f docs/adr/README.md ]; then
    index_fail=0
    for f in docs/adr/[0-9]*.md; do
        [ -e "${f}" ] || continue
        base="${f##*/}"
        if ! grep -Fq "(${base})" docs/adr/README.md; then
            echo "ÉCHEC : ${base} absent de l'index docs/adr/README.md" >&2
            index_fail=1
        fi
    done
    # Réciproque : une ligne d'index qui renvoie vers un ADR inexistant.
    for cite in $(grep -oE '\]\([0-9]{4}-[a-z0-9-]+\.md\)' docs/adr/README.md | \
                  sed -e 's/^](//' -e 's/)$//'); do
        if [ ! -f "docs/adr/${cite}" ]; then
            echo "ÉCHEC : index des ADR — renvoie vers un fichier absent : ${cite}" >&2
            index_fail=1
        fi
    done
    if [ "${index_fail}" -eq 0 ]; then
        echo "ok — index des ADR complet"
    else
        FAILURES=$((FAILURES + 1))
    fi
fi

# Les façades CI exécutent la MÊME liste d'étapes (ADR-0010). Une étape
# ajoutée d'un seul côté produit exactement ce que la portabilité promet
# d'éviter : un verdict qui dépend de l'hébergeur.
if [ -f .github/workflows/ci.yml ] && [ -f .gitlab-ci.yml ]; then
    # Les scripts invoqués, dans l'ordre, de part et d'autre.
    # Seules les lignes de COMMANDE comptent : une mention en prose dans un
    # commentaire n'est pas une étape (faux positif de la première rédaction).
    etapes_gh="$(sed -n 's/^[ \t-]*run:[ \t]*\(sh \)\{0,1\}\(tools\/.*\)$/\2/p' \
                     .github/workflows/ci.yml || true)"
    etapes_gl="$(sed -n 's/^[ \t]*-[ \t]*\(sh \)\{0,1\}\(tools\/.*\)$/\2/p' \
                     .gitlab-ci.yml || true)"
    if [ "${etapes_gh}" = "${etapes_gl}" ]; then
        echo "ok — façades CI GitHub et GitLab alignées"
    else
        echo "ÉCHEC : les façades CI n'exécutent pas les mêmes étapes." >&2
        echo "  GitHub : ${etapes_gh}" >&2
        echo "  GitLab : ${etapes_gl}" >&2
        FAILURES=$((FAILURES + 1))
    fi
fi

# Complétude du lexique : tout terme déclaré porte ses deux formes. Un terme
# dont la forme anglaise manque ferait taire une porte dans un dépôt
# anglophone, sans erreur — le pire des symptômes.
if [ -f tools/lexique.sh ]; then
    . ./tools/lexique.sh
    lex_fail=0
    for cle in $(lex_cles); do
        if [ -z "$(lex_fr "${cle}")" ] || [ -z "$(lex_en "${cle}")" ]; then
            echo "ÉCHEC : lexique — terme incomplet : ${cle}" >&2
            lex_fail=1
        fi
    done
    if [ "${lex_fail}" -eq 0 ]; then
        echo "ok — lexique complet dans les deux langues"
    else
        FAILURES=$((FAILURES + 1))
    fi
fi

# Tout script est analysable par le shell. Contrôle trivial, ajouté après
# TROIS occurrences du même défaut : une apostrophe dans un commentaire de
# programme awk referme la quote qui l entoure, et le shell se met à lire le
# programme awk comme du code. Le script reste sur le disque, apparemment
# sain, et casse à l exécution — donc en CI, jamais en revue.
syntaxe_fail=0
for f in tools/*.sh templates/forge/tools/*.sh; do
    [ -e "${f}" ] || continue
    if ! sh -n "${f}" 2>/dev/null; then
        echo "ÉCHEC : script non analysable par sh : ${f}" >&2
        sh -n "${f}" 2>&1 | sed 's/^/        /' >&2
        syntaxe_fail=1
    fi
done
if [ "${syntaxe_fail}" -eq 0 ]; then
    echo "ok — tous les scripts sont analysables par sh"
else
    FAILURES=$((FAILURES + 1))
fi

# Aucune référence pendante depuis une façade ou depuis le contrat de dépôt
# (ADR-0003). Une façade qui appelle un script absent ne se voit qu'à
# l'exécution — donc en CI, jamais en revue — et le contrat, lui, documente
# alors une commande qui échoue. Le contrôle porte sur la RÉFÉRENCE et non sur
# un nom de fichier : il attrape aussi bien le script retiré sans ses amarres
# que le script renommé dont une façade continue de parler.
pendantes=0
for f in tools/ci.sh Taskfile.yml AGENTS.md .gitlab-ci.yml .github/workflows/*.yml \
         templates/orchestrators/*; do
    [ -f "${f}" ] || continue
    # Le motif exige que « tools/ » ne soit pas précédé d'un caractère de
    # chemin : sans cette garde, « templates/forge/tools/x.sh » produirait la
    # référence « tools/x.sh », qui n'existe pas — un faux positif.
    for cite in $(grep -oE '(^|[^/[:alnum:]_.-])tools/[A-Za-z0-9_.-]+\.sh' "${f}" \
                  | sed 's#^.*\(tools/\)#\1#' | sort -u); do
        [ -f "${cite}" ] || {
            echo "ÉCHEC : ${f} cite un script absent : ${cite}" >&2
            pendantes=$((pendantes + 1))
        }
    done
done
if [ "${pendantes}" -eq 0 ]; then
    echo "ok — aucune référence pendante depuis les façades ni le contrat"
else
    FAILURES=$((FAILURES + 1))
fi

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} contrôle(s) en échec." >&2
    exit 1
fi
echo "Contrôles de cohérence : OK."
