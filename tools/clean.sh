#!/bin/sh
# Nettoyage du dépôt local. Motivation (règle justifiée par son incident,
# pratique reprise d'ergonomia) : sans mécanisme dédié, les artefacts de
# build s'accumulent sans limite — 500 Go de target/ constatés sur un dépôt
# Cargo faute de nettoyage.
# Principe : ne supprimer QUE des chemins/commandes explicitement déclarés —
# jamais de git clean -x aveugle, qui détruirait aussi les états locaux non
# versionnés utiles (notes, caches d'agents, environnements).
#   sh tools/clean.sh          # artefacts générés (+ point d'extension projet)
#   sh tools/clean.sh --all    # purge aussi .cache (outillage re-téléchargé)
# Idempotent. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

ALL=0
case "${1:-}" in
    --all) ALL=1 ;;
    "") ;;
    *) echo "Usage : sh tools/clean.sh [--all]" >&2 ; exit 2 ;;
esac

total_kio=0

nettoyer() {
    _p="$1"
    if [ -e "${_p}" ]; then
        _kio="$(du -sk "${_p}" | cut -f1)"
        rm -rf "${_p}"
        total_kio=$((total_kio + _kio))
        echo "supprimé : ${_p} ($((_kio / 1024)) Mio)"
    fi
}

# Socle du gabarit : rapports et sorties générés.
nettoyer build

# --- Point d'extension du projet instancié -------------------------------
# Déclarer ici les artefacts de VOTRE outillage, avec un commentaire
# renvoyant vers l'ADR technologique qui les justifie. Exemples :
#   sh tools/rust.sh clean         # Rust — kit templates/bootstrap.d/rust/, par l'âge (ADR-00NN)
#   nettoyer node_modules          # Node (ADR-00NN)
#   nettoyer .venv                 # Python (ADR-00NN)
#
# PIÈGE VÉRIFIÉ (méthode, ch. 4, anti-patterns) : si le poste déplace les
# artefacts (CARGO_TARGET_DIR partagé, store pnpm, ccache…), les chemins
# ci-dessus deviennent silencieusement sans effet et les commandes de
# nettoyage de l'outil (cargo clean) peuvent devenir GLOBALES au poste.
# Résoudre les chemins via l'outil (cargo metadata → target_directory) et
# re-tester ce script après tout changement d'environnement : un nettoyage
# no-op est un contrôle qui passe toujours.
# -------------------------------------------------------------------------

# Rust — artefacts de compilation, par l'âge, chemin résolu par cargo
# metadata (ADR-0003, kit templates/bootstrap.d/rust/). Le kit REFUSE un
# cache partagé entre projets (CARGO_TARGET_DIR du poste) : ce refus est
# voulu, il est rapporté sans faire échouer le reste du nettoyage.
if [ -f Cargo.toml ] && [ -f tools/rust.sh ] && command -v cargo >/dev/null 2>&1; then
    sh tools/rust.sh clean \
        || echo "note : artefacts Rust non balayés (voir ci-dessus) — sh tools/rust.sh clean --partage pour un cache partagé, en connaissance de cause."
fi

if [ "${ALL}" -eq 1 ]; then
    # Cache d'outillage (jar OpenFastTrace…) : re-téléchargé et re-vérifié
    # par empreinte au prochain lancement des portes.
    nettoyer .cache
fi

echo "Nettoyage : $((total_kio / 1024)) Mio libérés."
