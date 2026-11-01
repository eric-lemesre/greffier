#!/bin/sh
# Porte lint Markdown — MODÈLE à copier dans tools/ d'un projet instancié.
# Matériel post-instanciation : le gabarit ne l'exécute pas. À la copie,
# taguer ce fichier vers l'exigence de qualité documentaire du projet (R2),
# le câbler en CI (R7) et tester son cas d'échec à la mise en place (R3).
#
#   sh tools/markdown.sh lint   # la porte (défaut) : échoue à la première erreur
#   sh tools/markdown.sh fix    # normalise les tableaux + corrections auto, puis lint
#
# Auto-suffisant : installe les dépendances npm épinglées (npm ci) si
# node_modules manque — même esprit que tools/oft.sh avec son jar.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# markdownlint-cli2 ≥ 0.23 exige Node 22+ : échouer avec un message clair
# plutôt qu'une erreur cryptique (« outillage aveugle à son environnement »).
NV=""
if command -v node >/dev/null 2>&1; then
    NV="$(node --version | sed 's/^v//; s/\..*//')"
fi
if ! [ "${NV:-0}" -ge 22 ] 2>/dev/null; then
    echo "ÉCHEC : Node.js 22+ requis (détecté : ${NV:-aucun}) — sh tools/bootstrap.sh" >&2
    exit 1
fi

if [ ! -d node_modules/markdownlint-cli2 ]; then
    echo "Dépendances npm absentes : installation épinglée (npm ci)…"
    npm ci --no-audit --no-fund
fi

case "${1:-lint}" in
    lint)
        npx --no-install markdownlint-cli2
        ;;
    fix)
        node tools/format-tables.mjs
        npx --no-install markdownlint-cli2 --fix || true
        npx --no-install markdownlint-cli2
        ;;
    *)
        echo "Usage : tools/markdown.sh [lint|fix]" >&2
        exit 2
        ;;
esac
