#!/bin/sh
# Exigence servie : req~journal-en-fichier~1 — porte reprise d'un projet instancié (ADR-0023 du gabarit, ADR-0008).
# Porte de la rotation du journal : chaque configuration de
# packaging/linux/logrotate/ tient les règles qui font
# tourner un journal que le service ROUVRE sur SIGHUP :
#
#   - un « postrotate » qui envoie SIGHUP au service (--signal=HUP) ;
#   - pas de « copytruncate » (il perdrait les lignes écrites pendant la
#     copie, et le service rouvre de toute façon) ;
#   - « su » (le dossier appartient au compte du service) ;
#   - « create 0640 » (lisible du seul compte et de son groupe) ;
#   - une rétention bornée (« rotate N ») et la compression.
#
# Quand logrotate est installé, la configuration passe en plus sa lecture
# à blanc (`logrotate -d`) ; absent, la porte le dit et juge la structure.
#
#   sh tools/logrotate.sh [dossier]   # défaut : packaging/linux/logrotate
#
# POSIX sh strict ; grep.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
DOSSIER="${1:-packaging/linux/logrotate}"

if [ ! -d "${DOSSIER}" ]; then
    echo "ÉCHEC : ${DOSSIER} absent — la configuration logrotate est livrée avec le service." >&2
    exit 1
fi

fail=0
vus=0
for f in "${DOSSIER}"/*; do
    [ -f "${f}" ] || continue
    vus=$((vus + 1))
    # Les lignes de commentaire ne comptent pas.
    corps="$(grep -v '^[[:space:]]*#' "${f}" || true)"
    exiger() {  # $1 motif, $2 explication
        if ! printf '%s\n' "${corps}" | grep -Eq "$1"; then
            echo "ÉCHEC : ${f} — $2" >&2
            fail=1
        fi
    }
    exiger '^[[:space:]]*postrotate' "pas de « postrotate » : le service ne serait pas prévenu de la rotation"
    exiger '(--signal=HUP|-s[[:space:]]*HUP|kill[[:space:]]+-HUP)' "le postrotate n'envoie pas SIGHUP : le service écrirait dans le fichier renommé"
    exiger '^[[:space:]]*su[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+' "pas de « su <compte> <groupe> »"
    exiger '^[[:space:]]*create[[:space:]]+0640' "pas de « create 0640 »"
    exiger '^[[:space:]]*rotate[[:space:]]+[0-9]+' "pas de rétention bornée (« rotate N »)"
    exiger '^[[:space:]]*compress' "pas de « compress »"
    if printf '%s\n' "${corps}" | grep -Eq '^[[:space:]]*copytruncate'; then
        echo "ÉCHEC : ${f} — « copytruncate » perd des lignes : le service rouvre son fichier sur SIGHUP" >&2
        fail=1
    fi
    if command -v logrotate >/dev/null 2>&1; then
        # Les comptes nommés par « su » et « create » n'existent que là où
        # le paquet est installé (constaté en CI : « unknown user ») : la
        # lecture à blanc juge la syntaxe sous le compte courant, sur une
        # copie en 0644 (logrotate ignore un fichier inscriptible par le
        # groupe). L'épreuve du paquet installé juge les vrais comptes.
        etat="$(mktemp)"
        copie="$(mktemp)"
        compte="$(id -un)"
        groupe="$(id -gn)"
        sed -e "s/^\([[:space:]]*su\)[[:space:]].*/\1 ${compte} ${groupe}/" \
            -e "s/^\([[:space:]]*create[[:space:]][[:space:]]*[0-7][0-7]*\)[[:space:]].*/\1 ${compte} ${groupe}/" \
            "${f}" > "${copie}"
        chmod 644 "${copie}"
        # Une directive inconnue n'est qu'ignorée (sortie 0, ligne
        # « error: … ignoring line ») : le message compte autant que le code.
        lecture="$(mktemp)"
        if ! LC_ALL=C logrotate -d -s "${etat}" "${copie}" > "${lecture}" 2>&1 \
            || grep -q '^error:' "${lecture}"; then
            echo "ÉCHEC : ${f} — refusée par « logrotate -d » : $(grep '^error:' "${lecture}" | head -n 1)" >&2
            fail=1
        fi
        rm -f "${etat}" "${copie}" "${lecture}"
    fi
done

if [ "${vus}" -eq 0 ]; then
    echo "ÉCHEC : aucune configuration dans ${DOSSIER}." >&2
    exit 1
fi
if [ "${fail}" -ne 0 ]; then
    echo "logrotate : ÉCHEC." >&2
    exit 1
fi
if command -v logrotate >/dev/null 2>&1; then
    echo "logrotate : OK (${vus} configuration(s), lecture à blanc comprise)."
else
    echo "logrotate : OK (${vus} configuration(s) ; logrotate absent, structure seule jugée)."
fi
