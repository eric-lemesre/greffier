#!/bin/sh
# [impl->req~anti-derive-generes~1]
# Anti-dérive des artefacts GÉNÉRÉS : un fichier produit par un outil ne
# s'édite jamais à la main, il se régénère (règle R8 du contrat). Cette porte
# régénère puis compare — si le résultat diffère de ce qui est versionné, le
# fichier a dérivé.
#
# Les deux contrôles, et pourquoi il en faut DEUX :
#   1. le fichier attendu est SUIVI par git (`git ls-files --error-unmatch`) ;
#   2. sa régénération ne produit aucune différence (`git diff --exit-code`).
# Sans le premier, la porte est aveugle : un généré non versionné ne produit
# aucune différence — le contrôle passe toujours, ce qui est pire que pas de
# contrôle (méthode, ch. 4, anti-pattern « contrôle no-op »). Angle mort
# constaté sur ergonomia avant d'être refermé par ce double contrôle.
#
#   sh tools/derive.sh
#
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

FAILURES=0
CIBLES_VUES=0

# verifier "<commande de régénération>" <fichier attendu> [autres fichiers…]
verifier() {
    _cmd="$1"
    shift
    CIBLES_VUES=$((CIBLES_VUES + 1))

    for _f in "$@"; do
        if ! git ls-files --error-unmatch "${_f}" >/dev/null 2>&1; then
            echo "ÉCHEC : ${_f} n'est pas suivi par git — l'anti-dérive ne le verrait pas." >&2
            FAILURES=$((FAILURES + 1))
            return 0
        fi
    done

    if ! sh -c "${_cmd}" >/dev/null 2>&1; then
        echo "ÉCHEC : la régénération a échoué : ${_cmd}" >&2
        FAILURES=$((FAILURES + 1))
        return 0
    fi

    if ! git diff --quiet -- "$@"; then
        echo "ÉCHEC : artefact périmé — exécuter « ${_cmd} » et committer le résultat :" >&2
        for _f in "$@"; do echo "        ${_f}" >&2; done
        FAILURES=$((FAILURES + 1))
        return 0
    fi
    echo "ok — à jour : $*"
}

# --- socle:debut ------------------------------------------------------------
# Cibles du gabarit. Bloc remplacé par tools/derive-test.sh pour éprouver la
# mécanique sur des cibles de synthèse ; ne pas déplacer les marqueurs.
verifier "sh tools/todo.sh --ecrire"   docs/todo/README.md
verifier "sh tools/revues.sh --ecrire" docs/revues/SUIVI.md
verifier "sh tools/audit.sh --ecrire"  docs/audit/README.md
verifier "sh tools/badges.sh --ecrire" docs/badges/version.svg \
                                       docs/badges/exigences.svg \
                                       docs/badges/licence.svg
verifier "sh tools/matrice.sh"         docs/tracabilite/matrice.md
verifier "sh tools/avancement.sh --ecrire" spec/02-exigences/README.md
# --- socle:fin --------------------------------------------------------------

# --- Point d'extension du projet instancié ----------------------------------
# Déclarer ici les artefacts générés de VOTRE outillage — un couple
# « commande de régénération » + fichiers attendus. Exemples :
#   verifier "cargo run -p xtask -- openapi" api/openapi.json
#   verifier "npm run gen:types"             packages/client/src/schema.d.ts
#
# Règle de mise en place (R3) : après avoir déclaré une cible, MODIFIER le
# fichier généré à la main et vérifier que cette porte échoue. Une cible dont
# la commande ne produit rien — ou écrit ailleurs — laisse une porte verte qui
# ne vérifie rien.
# ----------------------------------------------------------------------------

if [ "${CIBLES_VUES}" -eq 0 ]; then
    echo "Anti-dérive : aucune cible déclarée (rien à vérifier)."
    exit 0
fi
if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} artefact(s) en dérive." >&2
    exit 1
fi
echo "Anti-dérive : OK."
