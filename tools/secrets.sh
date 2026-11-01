#!/bin/sh
# [impl->req~detection-secrets~1]
# Porte anti-secrets (gitleaks, ADR-0012) : bloquante en CI, signalante en
# local quand l'outil est indisponible. Binaire épinglé par version et par
# empreinte SHA-256 (même mécanique que le jar OpenFastTrace).
#   sh tools/secrets.sh scan     # balayage complet (CI — bloquant)
#   sh tools/secrets.sh staged   # fichiers indexés (hook pre-commit)
# Faux positifs : entrée justifiée dans .gitleaks.toml, jamais de
# désactivation de la porte. POSIX sh strict.
set -eu

GL_VERSION="8.30.1"
# Empreintes officielles des archives par plateforme (checksums de release).
GL_SHA_linux_x64="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
GL_SHA_linux_arm64="e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080"
GL_SHA_darwin_x64="dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709"
GL_SHA_darwin_arm64="b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
BIN="${ROOT}/.cache/gitleaks-${GL_VERSION}"

plateforme() {
    _os="$(uname -s)"
    _arch="$(uname -m)"
    case "${_os}" in
        Linux) _os="linux" ;;
        Darwin) _os="darwin" ;;
        *) return 1 ;;
    esac
    case "${_arch}" in
        x86_64|amd64) _arch="x64" ;;
        aarch64|arm64) _arch="arm64" ;;
        *) return 1 ;;
    esac
    echo "${_os}_${_arch}"
}

# Empreinte SHA-256 portable : shasum (macOS, Git pour Windows) ou sha256sum
# (Linux minimal, runners CI). Un appel `shasum` en dur casse sur la plupart
# des images Linux minimales — remontée d'un projet instancié.
sha256_of() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1"
    else
        sha256sum "$1"
    fi
}

obtenir_gitleaks() {
    # 1. binaire épinglé déjà en cache ;
    if [ -x "${BIN}" ]; then return 0; fi
    # 2. téléchargement épinglé si la plateforme est couverte ;
    _pf="$(plateforme)" || return 1
    eval "_sha=\${GL_SHA_${_pf}:-}"
    [ -n "${_sha}" ] || return 1
    _archive="gitleaks_${GL_VERSION}_${_pf}.tar.gz"
    mkdir -p "${ROOT}/.cache"
    echo "Téléchargement de gitleaks ${GL_VERSION} (${_pf})…" >&2
    curl -fsSL -o "${ROOT}/.cache/${_archive}" \
        "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VERSION}/${_archive}" || return 1
    set -- $(sha256_of "${ROOT}/.cache/${_archive}")
    if [ "$1" != "${_sha}" ]; then
        echo "ERREUR : empreinte SHA-256 de l'archive gitleaks invalide." >&2
        rm -f "${ROOT}/.cache/${_archive}"
        exit 1
    fi
    tar -xzf "${ROOT}/.cache/${_archive}" -C "${ROOT}/.cache" gitleaks
    mv "${ROOT}/.cache/gitleaks" "${BIN}"
    rm -f "${ROOT}/.cache/${_archive}"
}

MODE="${1:-scan}"
case "${MODE}" in
    scan) ARGS="detect --redact --no-banner" ;;
    staged) ARGS="protect --staged --redact --no-banner" ;;
    *) echo "Usage : tools/secrets.sh [scan|staged]" >&2 ; exit 2 ;;
esac

if obtenir_gitleaks; then
    GL="${BIN}"
elif command -v gitleaks >/dev/null 2>&1; then
    # Outil du poste (version non épinglée) : mieux que rien, signalé.
    echo "note : gitleaks du poste utilisé (version non épinglée)." >&2
    GL="gitleaks"
else
    if [ "${MODE}" = "staged" ]; then
        echo "AVERTISSEMENT : gitleaks indisponible sur ce poste — détection de" >&2
        echo "secrets NON exécutée localement ; la CI la rejouera en bloquant (ADR-0012)." >&2
        exit 0
    fi
    echo "ERREUR : gitleaks indisponible — la porte anti-secrets ne peut pas s'exécuter." >&2
    exit 1
fi

# shellcheck disable=SC2086 — découpe voulue des arguments.
"${GL}" ${ARGS}
echo "Porte anti-secrets : OK (aucun secret détecté)."
