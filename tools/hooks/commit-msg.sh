#!/bin/sh
# [impl->req~garde-fous-locaux~1]
# Corps du hook commit-msg : commits conventionnels en français (R4) et
# interdiction des mentions d'agent ou de co-auteur généré (R0). POSIX sh ;
# grep est fourni partout où git l'est (y compris Git pour Windows).
set -eu

MSG_FILE="$1"
SUBJECT="$(head -n1 "${MSG_FILE}")"

# Commits techniques de git tolérés tels quels.
case "${SUBJECT}" in
    Merge\ *|Revert\ *|fixup!\ *|squash!\ *) exit 0 ;;
esac

TYPES='feat|fix|docs|test|chore|refactor|perf|ci|build|style|revert'
if ! printf '%s' "${SUBJECT}" | grep -Eq "^(${TYPES})(\([a-z0-9-]+\))?!?: .+"; then
    echo "ERREUR : sujet de commit non conventionnel :" >&2
    echo "  ${SUBJECT}" >&2
    echo "Attendu : type(scope): sujet — types admis : ${TYPES}" >&2
    exit 1
fi

# --- politique-attribution:debut ---
# [impl->req~politique-attribution-agents~2]
# R0 — diligence (politique par défaut, ADR-0011) : chaque commit déclare
# l'usage de l'IA, tout usage déclaré exige un responsable humain, la
# relecture est recommandée. L'instanciation remplace ou retire ce bloc selon
# l'arbitrage d'instanciation ; ne pas déplacer les marqueurs.
if ! grep -q '^IA: ' "${MSG_FILE}"; then
    echo "ERREUR : déclaration d'usage de l'IA manquante (R0, diligence)." >&2
    echo "Ajouter un trailer : « IA: aucune » ou « IA: <outil> »." >&2
    echo "Si IA : ajouter « Responsable: Prénom Nom » (« Relu-par: … » recommandé)." >&2
    exit 1
fi
if ! grep -q '^IA: aucune$' "${MSG_FILE}"; then
    if ! grep -q '^Responsable: ' "${MSG_FILE}"; then
        echo "ERREUR : usage d'IA déclaré sans responsable humain (R0, diligence)." >&2
        echo "Ajouter « Responsable: Prénom Nom » — la relecture (« Relu-par: … ») est recommandée." >&2
        exit 1
    fi
fi
# --- politique-attribution:fin ---
