#!/bin/sh
# Point unique d'exécution d'OpenFastTrace : la CI, les hooks et les façades
# d'orchestration (Taskfile, justfile…) passent tous par ce script, avec le
# même périmètre de fichiers (R2, ADR-0002, ADR-0007).
# POSIX sh strict — aucun bashisme : exécutable par dash, bash, et le sh de
# Git pour Windows.
set -eu

OFT_VERSION="4.9.0"
OFT_SHA256="d4ed42503ae066f51d55c3aad7c6e4b16acb80365921951ef5a065a4dc3d94f3"
OFT_URL="https://github.com/itsallcode/openfasttrace/releases/download/${OFT_VERSION}/openfasttrace-${OFT_VERSION}.jar"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAR="${ROOT}/.cache/openfasttrace-${OFT_VERSION}.jar"

# Périmètre scanné (relatif à la racine). templates/ est exclu : les modèles
# contiennent des identifiants d'exemple qui ne doivent pas devenir des items.
# Les chemins absents sont filtrés à l'exécution : un projet instancié peut
# retirer une langue (ADR-0009) ou une forge (ADR-0010) sans casser la porte.
# « src » est le répertoire du code de RÉALISATION du produit. Le gabarit n'en
# a pas — il ne réalise rien — mais tout projet instancié en aura un, et sans
# lui au périmètre ses exigences resteraient orphelines sans qu'on sache
# pourquoi. Manque constaté sur un projet instancié.
INPUTS="spec docs examples src tools .github .gitlab .gitlab-ci.yml AGENTS.md README.md README.en.md CONTRIBUTING.md CHANGELOG.md Taskfile.yml"

scan_inputs() {
    SCAN=""
    for p in ${INPUTS}; do
        if [ -e "${p}" ]; then SCAN="${SCAN} ${p}"; fi
    done
}

require_java() {
    command -v java >/dev/null 2>&1 || {
        echo "ERREUR : java introuvable — OpenFastTrace requiert Java 17+." >&2
        exit 1
    }
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

fetch_jar() {
    if [ ! -f "${JAR}" ]; then
        mkdir -p "${ROOT}/.cache"
        echo "Téléchargement d'OpenFastTrace ${OFT_VERSION}…" >&2
        curl -fsSL -o "${JAR}.tmp" "${OFT_URL}"
        mv "${JAR}.tmp" "${JAR}"
    fi
    # L'empreinte est vérifiée à chaque exécution : un jar altéré ou corrompu
    # doit échouer bruyamment, jamais tracer en silence.
    set -- $(sha256_of "${JAR}")
    if [ "$1" != "${OFT_SHA256}" ]; then
        echo "ERREUR : empreinte SHA-256 du jar OpenFastTrace invalide (${JAR})." >&2
        echo "Supprimez le fichier et relancez pour retélécharger." >&2
        exit 1
    fi
}

cd "${ROOT}"
case "${1:-trace}" in
    trace)
        require_java
        fetch_jar
        scan_inputs
        # shellcheck disable=SC2086 — la découpe en mots de SCAN est voulue.
        java -jar "${JAR}" trace -v failures ${SCAN}
        echo "Traçabilité : OK (aucune exigence orpheline)."
        ;;
    report)
        require_java
        fetch_jar
        scan_inputs
        mkdir -p build
        # Le rapport HTML est informatif : généré même en cas de défauts ; le
        # code retour de la porte est porté par le résumé qui suit.
        java -jar "${JAR}" trace -o html -f build/tracabilite.html ${SCAN} || true
        java -jar "${JAR}" trace -v summary ${SCAN}
        echo "Rapport : build/tracabilite.html"
        ;;
    *)
        echo "Usage : tools/oft.sh [trace|report]" >&2
        exit 2
        ;;
esac
