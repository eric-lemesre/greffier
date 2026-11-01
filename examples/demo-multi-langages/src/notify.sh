#!/usr/bin/env bash
# Notification de fin de tâche — implémentation shell.
set -euo pipefail

# [impl->req~notification-terminale~1]
# [impl->req~echec-signale-distinctement~1]
notifier() {
    local nom="$1" duree_s="$2" succes="${3:-1}"
    local etat="OK"
    [ "${succes}" -eq 1 ] || etat="ÉCHEC"
    printf '[%s] %s (%s s)\n' "${etat}" "${nom}" "${duree_s}"
}
