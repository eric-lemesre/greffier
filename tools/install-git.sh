#!/bin/sh
# Installation multiplateforme de git — le PRÉREQUIS de tools/bootstrap.sh.
# Linux (apt/dnf) et macOS (Homebrew, sinon xcode-select). Sous Windows, aucun
# shell sh n'existe avant Git for Windows : utiliser tools/install-git.ps1
# (PowerShell + winget). Sans git pour cloner, récupérer le dépôt via
# l'archive d'export de la forge (ZIP/tarball).
#
#   sh tools/install-git.sh            # annonce → accord → installe si absent
#   sh tools/install-git.sh --oui      # sans question (accord donné d'avance)
#   sh tools/install-git.sh --verifie  # vérification seule, jamais d'installation
#
# Même flux consenti que le bootstrap (ADR-0014) : vérifier d'abord (déjà
# présent → on ne touche à rien), annoncer, n'installer qu'avec l'accord.
set -eu

DEMANDE="accord"                 # accord | oui | verifie
case "${1:-}" in
    "")         DEMANDE="accord" ;;
    --oui|-y)   DEMANDE="oui" ;;
    --verifie)  DEMANDE="verifie" ;;
    *) echo "Usage : tools/install-git.sh [--oui|--verifie]" >&2 ; exit 2 ;;
esac

# --- Déjà présent : rien à faire -----------------------------------------------
if command -v git >/dev/null 2>&1; then
    echo "ok — git déjà présent : $(git --version | cut -d' ' -f3)"
    exit 0
fi

# --- Détection de la plateforme --------------------------------------------------
case "$(uname -s)" in
    Linux)  PLATEFORME="linux" ;;
    Darwin) PLATEFORME="macos" ;;
    MINGW*|MSYS*|CYGWIN*)
        # Un shell sh sous Windows provient de Git for Windows : git devrait
        # être là. Cas résiduel : renvoyer vers le script PowerShell.
        echo "ÉCHEC : prérequis manquant — git ; sous Windows, utiliser :" >&2
        echo "  powershell -ExecutionPolicy Bypass -File tools/install-git.ps1" >&2
        exit 1 ;;
    *)      PLATEFORME="inconnue" ;;
esac

MOYEN=""
case "${PLATEFORME}" in
    linux)
        if command -v apt-get >/dev/null 2>&1; then MOYEN="apt"
        elif command -v dnf >/dev/null 2>&1; then MOYEN="dnf"
        fi ;;
    macos)
        if command -v brew >/dev/null 2>&1; then MOYEN="brew"
        else MOYEN="xcode-select"
        fi ;;
esac

echo "MANQUANT — git (prérequis du bootstrap)"
if [ -z "${MOYEN}" ]; then
    echo "  → installation automatique indisponible sur cette plateforme ;" >&2
    echo "    voir https://git-scm.com/downloads" >&2
    exit 3
fi
echo "Ce script propose d'installer git via ${MOYEN}."

# --- Accord de l'utilisateur ------------------------------------------------------
INSTALLE=0
case "${DEMANDE}" in
    oui)     INSTALLE=1 ;;
    verifie) echo "Mode --verifie : aucune installation." ; exit 1 ;;
    accord)
        if [ -t 0 ]; then
            printf "Installer git via %s ? [o/N] " "${MOYEN}"
            read -r REPONSE
            case "${REPONSE}" in
                o|O|oui|OUI|y|Y) INSTALLE=1 ;;
            esac
        else
            echo "Entrée non interactive : aucune installation (utilisez --oui)."
        fi ;;
esac
if [ "${INSTALLE}" -ne 1 ]; then
    echo "Pas d'installation : git reste à installer (https://git-scm.com/downloads)." >&2
    exit 1
fi

# --- Installation --------------------------------------------------------------------
case "${MOYEN}" in
    apt)          sudo apt-get install -y git ;;
    dnf)          sudo dnf install -y git ;;
    brew)         brew install git ;;
    # Ouvre le dialogue Apple des outils en ligne de commande (installation GUI).
    xcode-select) xcode-select --install ;;
esac

if command -v git >/dev/null 2>&1; then
    echo "ok — git installé : $(git --version | cut -d' ' -f3)"
else
    echo "git n'est pas encore visible dans le PATH — rouvrir un terminal, puis"
    echo "contrôler avec : sh tools/install-git.sh --verifie"
    exit 3
fi
