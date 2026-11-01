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
# Statuts OpenFastTrace retenus par la porte (ADR-0020) ; exigences
# approuvées à réaliser tolérées (ADR-0020).
STATUTS_TRACES="approved"

# Périmètre scanné (relatif à la racine). templates/ est exclu : les modèles
# contiennent des identifiants d'exemple qui ne doivent pas devenir des items.
# Les chemins absents sont filtrés à l'exécution : un projet instancié peut
# retirer une langue (ADR-0009) ou une forge (ADR-0010) sans casser la porte.
# « src » est le répertoire du code de RÉALISATION du produit. Le gabarit n'en
# a pas — il ne réalise rien — mais tout projet instancié en aura un, et sans
# lui au périmètre ses exigences resteraient orphelines sans qu'on sache
# pourquoi. Manque constaté sur un projet instancié.
# « tests » porte les tests d'intégration d'un projet Rust (tags itest), que
# cargo range hors de src (constaté sur un projet instancié).
INPUTS="spec docs examples src tests tools .github .gitlab .gitlab-ci.yml AGENTS.md README.md README.en.md CONTRIBUTING.md CHANGELOG.md Taskfile.yml"

scan_inputs() {
    SCAN=""
    for p in ${INPUTS}; do
        if [ -e "${p}" ]; then SCAN="${SCAN} ${p}"; fi
    done
}

# Définitions en double. OpenFastTrace tient pour DÉFINITION d'item toute
# ligne Markdown qui COMMENCE (colonne 0) par un identifiant entre accents
# graves — « `req~x~1`, et la suite » compris ; indenté ou en milieu de
# phrase, l'identifiant n'est qu'une citation (vérifié sur OFT 4.9.0). Une
# citation mal placée dans un CHANGELOG ou une fiche redéfinit donc l'item,
# et la trace échoue en ne listant que des identifiants, sans dire où est
# le doublon (constaté sur un projet instancié). Ce contrôle, joué avant la
# trace, nomme chaque identifiant défini plusieurs fois et ses fichiers.
doublons() {
    _md="$(for p in ${SCAN}; do
        if [ -d "${p}" ]; then find "${p}" -type f -name '*.md'
        else case "${p}" in *.md) echo "${p}" ;; esac
        fi
    done | LC_ALL=C sort)"
    [ -n "${_md}" ] || return 0
    # shellcheck disable=SC2086 — la découpe en mots de la liste est voulue.
    _rapport="$(grep -nE '^`[a-z]+~[^`[:space:]]+~[0-9]+`' ${_md} 2>/dev/null \
        | sed -E 's/^([^:]+):([0-9]+):`([^`]+)`.*/\3 \1:\2/' \
        | LC_ALL=C sort \
        | awk '{ n[$1]++; lieux[$1] = lieux[$1] "\n    " $2 }
               END { for (i in n) if (n[i] > 1) printf "%s%s\n", i, lieux[i] }' \
        | LC_ALL=C sort)" || true
    if [ -n "${_rapport}" ]; then
        echo "ÉCHEC : identifiant(s) défini(s) plusieurs fois :" >&2
        printf '%s\n' "${_rapport}" | sed 's/^\([^ ]\)/  \1/' >&2
        echo "Une ligne qui COMMENCE par un identifiant entre accents graves est une définition OpenFastTrace : pour le citer, l'indenter ou le placer dans la phrase." >&2
        return 1
    fi
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
        scan_inputs
        doublons
        require_java
        fetch_jar
        # shellcheck disable=SC2086 — la découpe en mots de SCAN est voulue.
        # Seuls les items approuvés entrent dans la porte (ADR-0020) : un
        # besoin ou une exigence non arbitrés portent « Status: draft » (ou
        # proposed) sous leur identifiant, et tools/statuts.sh vérifie que ce
        # statut concorde avec le statut déclaré de l'exigence.
        rc=0
        SORTIE="$(java -jar "${JAR}" trace -c BLACK_AND_WHITE -v direct_failure_summaries \
                  -w "${STATUTS_TRACES}" ${SCAN} 2>&1)" || rc=$?
        if [ "${rc}" -eq 0 ]; then
            echo "Traçabilité : OK (aucune exigence orpheline)."
            exit 0
        fi
        # Défauts DIRECTS seulement : un défaut transitif (un besoin en
        # échec à cause de son exigence) a toujours sa cause parmi eux.
        DEFAUTS="$(printf '%s\n' "${SORTIE}" | grep '^not ok \[' || true)"
        if [ -z "${DEFAUTS}" ]; then
            # Aucun défaut lisible : erreur de l'outil, jamais un succès.
            printf '%s\n' "${SORTIE}" >&2
            exit "${rc}"
        fi
        # Exigence approuvée À RÉALISER (ADR-0020) : aucun maillon aval
        # (« in: 0 / 0 »), lien amont sain (« out: … ✔ »), et pour seul défaut
        # des types requis non couverts (« (-impl, -utest) »). Dès le premier
        # tag ou item aval, la couverture complète est exigée.
        MOTIF_A_REALISER='^not ok \[ in: +0 / +0 +\| out: +[0-9]+ / +[0-9]+ ✔ \] req~[a-z0-9-]+~[0-9]+ \(-[a-z]+(, -[a-z]+)*\)$'
        BLOQUANTS="$(printf '%s\n' "${DEFAUTS}" | grep -Ev "${MOTIF_A_REALISER}" || true)"
        if [ -n "${BLOQUANTS}" ]; then
            printf '%s\n' "${SORTIE}" >&2
            echo "ÉCHEC : traçabilité — défauts bloquants :" >&2
            printf '%s\n' "${BLOQUANTS}" >&2
            exit 1
        fi
        A_REALISER="$(printf '%s\n' "${DEFAUTS}" | grep -oE 'req~[a-z0-9-]+~[0-9]+')"
        echo "Traçabilité : OK — $(printf '%s\n' "${A_REALISER}" | wc -l | tr -d ' ') exigence(s) approuvée(s) à réaliser :"
        printf '%s\n' "${A_REALISER}" | sed 's/^/  /'
        ;;
    doublons)
        scan_inputs
        doublons
        echo "Définitions : aucun identifiant défini deux fois."
        ;;
    report)
        require_java
        fetch_jar
        scan_inputs
        mkdir -p build
        # Le rapport HTML est informatif : généré même en cas de défauts ; le
        # code retour est celui de la porte, exigences à réaliser tolérées
        # comprises (ADR-0020).
        java -jar "${JAR}" trace -o html -f build/tracabilite.html -w "${STATUTS_TRACES}" ${SCAN} || true
        echo "Rapport : build/tracabilite.html"
        sh "${ROOT}/tools/oft.sh" trace
        ;;
    *)
        echo "Usage : tools/oft.sh [trace|report|doublons]" >&2
        exit 2
        ;;
esac
