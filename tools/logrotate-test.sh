#!/bin/sh
# Exigence servie : req~journal-en-fichier~1
# Test de la porte de rotation du journal : la configuration livrée passe ;
# une configuration sans SIGHUP, avec copytruncate, sans « su », sans
# « create 0640 » ou sans rétention échoue en le disant ; un dossier vide
# échoue. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

porte() { sh "${ROOT}/tools/logrotate.sh" "$1" >/dev/null 2>&1; }
sortie() { sh "${ROOT}/tools/logrotate.sh" "$1" 2>&1 || true; }

echo "logrotate-test — configuration livrée : passe"
if ! porte "${ROOT}/packaging/linux/logrotate"; then
    echo "ÉCHEC : la configuration livrée est refusée — $(sortie "${ROOT}/packaging/linux/logrotate" | head -1)" >&2
    fail=1
fi

# $1 libellé, $2 sed à appliquer à la configuration livrée, $3 motif attendu
cas() {
    d="${TMP}/$1"
    mkdir -p "${d}"
    sed "$2" "${ROOT}/packaging/linux/logrotate/greffier" > "${d}/greffier"
    if porte "${d}"; then
        echo "ÉCHEC [$1] : la porte passe" >&2 ; fail=1
    elif ! sortie "${d}" | grep -q "$3"; then
        echo "ÉCHEC [$1] : le message ne dit pas « $3 »" >&2 ; fail=1
    fi
}

echo "logrotate-test — cas d'échec"
cas sans-hup 's/--signal=HUP/--signal=TERM/' "n'envoie pas SIGHUP"
cas copytruncate 's/^\(    \)delaycompress/\1copytruncate/' "copytruncate"
cas sans-su '/^    su /d' "su <compte>"
cas sans-create 's/create 0640/create 0644/' "create 0640"
cas sans-retention '/^    rotate /d' "rétention"
cas sans-postrotate '/postrotate/,/endscript/d' "pas de « postrotate »"

# La lecture à blanc ne se juge que là où logrotate est installé (CI).
if command -v logrotate >/dev/null 2>&1; then
    echo "logrotate-test — lecture à blanc : erreurs de syntaxe refusées"
    cas directive-inconnue 's/^    daily/    quotidien/' "logrotate -d"
    cas retention-illisible 's/^    rotate 14/    rotate quatorze/' "logrotate -d"
else
    echo "logrotate-test — lecture à blanc : logrotate absent, cas non joués"
fi

echo "logrotate-test — dossier vide : échoue"
mkdir -p "${TMP}/vide"
if porte "${TMP}/vide"; then echo "ÉCHEC [vide] : la porte passe" >&2 ; fail=1 ; fi

if [ "${fail}" -ne 0 ]; then
    echo "logrotate-test : ÉCHEC." >&2
    exit 1
fi
echo "logrotate-test : OK."
