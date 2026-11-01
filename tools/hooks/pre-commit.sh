#!/bin/sh
# Corps du hook pre-commit : rejoue les portes de la CI avant que le commit
# n'atteigne le dépôt, sans dépendre d'aucun orchestrateur (ADR-0007). Le
# wrapper .githooks/pre-commit (sans extension, non scanné par OpenFastTrace)
# délègue ici — voir méthode, ch. 4. POSIX sh strict.
set -eu

ROOT="$(git rev-parse --show-toplevel)"

if [ "${ALM_SKIP_HOOKS:-0}" = "1" ]; then
    echo "AVERTISSEMENT : portes locales contournées (ALM_SKIP_HOOKS=1)." >&2
    echo "La CI les rejouera : un échec là-bas est un échec ici différé." >&2
    exit 0
fi

# Voie documentaire forcée : traçabilité, cohérence et portes documentaires,
# soit quelques secondes. Les tests d'outillage — une dizaine de dépôts git
# jetables — restent dus avant de proposer le travail : « sh tools/ci.sh ».
# Un hook trop lent finit contourné, et une porte contournée ne protège
# personne.
sh "${ROOT}/tools/ci.sh" --rapide

echo "Porte locale — détection de secrets (fichiers indexés)"
sh "${ROOT}/tools/secrets.sh" staged

echo
echo "Rappel : « sh tools/ci.sh » avant de proposer le travail (tests d'outillage compris)." 
