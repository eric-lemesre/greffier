#!/bin/sh
# Test mécanisé de la porte anti-secrets : un secret de synthèse est détecté,
# un dépôt sain passe. Le motif est assemblé à l'exécution pour ne jamais
# figurer en clair dans ce dépôt (sinon la porte se détecterait elle-même).
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

echo "secrets-test — dépôt sain : la porte doit passer"
(cd "${TMP}" && git init -q && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init)
mkdir -p "${TMP}/tools" "${TMP}/.cache"
cp "${ROOT}/tools/secrets.sh" "${TMP}/tools/"
cp "${ROOT}"/.cache/gitleaks-* "${TMP}/.cache/" 2>/dev/null || true
printf 'contenu parfaitement anodin\n' > "${TMP}/notes.txt"
(cd "${TMP}" && git add notes.txt && git -c user.name=t -c user.email=t@t commit -q -m "chore: notes")
if ! (cd "${TMP}" && sh tools/secrets.sh scan >/dev/null 2>&1); then
    echo "ÉCHEC : la porte échoue sur un dépôt sain" >&2
    fail=1
fi

echo "secrets-test — secret de synthèse : la porte doit échouer"
# Jeton factice de type PAT GitHub assemblé à l'exécution (préfixe ghp_ +
# 36 caractères). Pièges vérifiés en construisant ce test : la clé d'exemple
# de la documentation AWS est en liste blanche par défaut, et la règle AWS
# exige une entropie que des suffixes simples n'atteignent pas — le motif
# PAT, lui, est détecté de façon fiable.
prefixe="ghp_"
suffixe="A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"
printf 'token = %s%s\n' "${prefixe}" "${suffixe}" > "${TMP}/config.ini"
(cd "${TMP}" && git add config.ini && git -c user.name=t -c user.email=t@t commit -q -m "chore: config")
if (cd "${TMP}" && sh tools/secrets.sh scan >/dev/null 2>&1); then
    echo "ÉCHEC : la porte n'a pas détecté le secret de synthèse" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "secrets-test : ÉCHEC." >&2
    exit 1
fi
echo "secrets-test : OK."
