#!/bin/sh
# [utest->req~onboarding-outille~2]
# Test mécanisé du bootstrap consenti et modulaire (ADR-0014) : rejoue les
# critères d'acceptation sur leurs cas d'échec — R3, aucun contrôle qui passe
# toujours. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM

fail=0

echo "bootstrap-test — poste complet, entrée non interactive : vérification seule, succès"
if ! (cd "${ROOT}" && sh tools/bootstrap.sh </dev/null >/dev/null); then
    echo "ÉCHEC : bootstrap.sh a échoué alors que le socle est complet" >&2
    fail=1
fi

echo "bootstrap-test — idempotence (seconde exécution identique)"
if ! (cd "${ROOT}" && sh tools/bootstrap.sh </dev/null >/dev/null); then
    echo "ÉCHEC : bootstrap.sh n'est pas relançable" >&2
    fail=1
fi

echo "bootstrap-test — argument inconnu : usage rappelé, code 2"
code=0
(cd "${ROOT}" && sh tools/bootstrap.sh --mauvais-argument) >/dev/null 2>&1 || code=$?
if [ "${code}" -ne 2 ]; then
    echo "ÉCHEC : argument inconnu accepté (code ${code}, attendu 2)" >&2
    fail=1
fi

echo "bootstrap-test — prérequis git absent : échec"
if (cd "${ROOT}" && PATH="" sh tools/bootstrap.sh) >/dev/null 2>&1; then
    echo "ÉCHEC : bootstrap.sh a réussi sans aucun outil dans le PATH" >&2
    fail=1
fi

echo "bootstrap-test — outil du socle absent, sans accord : échec en le nommant"
mkdir -p "${TMP}/bin"
# PATH minimal : le shell, git (prérequis) et les utilitaires de l'orchestrateur,
# mais ni curl ni java — le bootstrap doit les signaler et échouer.
for c in sh git uname dirname cut head sed pwd; do
    src="$(command -v "${c}" || true)"
    [ -n "${src}" ] && ln -s "${src}" "${TMP}/bin/${c}"
done
sortie="${TMP}/sortie.txt"
code=0
(cd "${ROOT}" && PATH="${TMP}/bin" "${TMP}/bin/sh" tools/bootstrap.sh </dev/null) \
    >"${sortie}" 2>&1 || code=$?
if [ "${code}" -eq 0 ]; then
    echo "ÉCHEC : bootstrap.sh a réussi alors que curl et java manquent" >&2
    fail=1
fi
if ! grep -q "curl" "${sortie}" || ! grep -q "ÉCHEC" "${sortie}"; then
    echo "ÉCHEC : l'outil absent n'est pas nommé dans le bilan d'échec" >&2
    sed 's/^/  | /' "${sortie}" >&2
    fail=1
fi

echo "bootstrap-test — install-git : présent → succès, argument inconnu → code 2"
if ! (cd "${ROOT}" && sh tools/install-git.sh --verifie >/dev/null); then
    echo "ÉCHEC : install-git.sh --verifie a échoué alors que git est présent" >&2
    fail=1
fi
code=0
(cd "${ROOT}" && sh tools/install-git.sh --mauvais-argument) >/dev/null 2>&1 || code=$?
if [ "${code}" -ne 2 ]; then
    echo "ÉCHEC : install-git.sh accepte un argument inconnu (code ${code}, attendu 2)" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "bootstrap-test : ÉCHEC." >&2
    exit 1
fi
echo "bootstrap-test : OK."
