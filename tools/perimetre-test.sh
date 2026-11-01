#!/bin/sh
# [utest->req~perimetre-constate~1]
# Test du classement de périmètre. L'outil qui décide de CE QUI SERA VÉRIFIÉ
# doit lui-même être vérifié : une allowlist trop large ne se manifeste par
# aucune erreur — elle se manifeste par un défaut qui passe. Les cas NÉGATIFS
# (« doit répondre complet ») comptent donc davantage que les positifs.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"
prepare() {
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/docs" "${D}/spec"
    cp "${ROOT}/tools/perimetre.sh" "${D}/tools/"
    (cd "${D}" && git init -q -b main && \
        printf '# socle\n' > docs/socle.md && \
        git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: socle" && \
        git checkout -q -b travail)
}
commit() {
    (cd "${D}" && git add -A && \
        git -c user.name=t -c user.email=t@t commit -q -m "chore: cas de test")
}
voie() { (cd "${D}" && sh tools/perimetre.sh); }

verifie() {
    _attendu="$1"; _obtenu="$2"; _cas="$3"
    if [ "${_obtenu}" != "${_attendu}" ]; then
        echo "ÉCHEC : ${_cas} — attendu « ${_attendu} », obtenu « ${_obtenu} »" >&2
        fail=1
    fi
}

echo "perimetre-test — documentation seule : voie docs"
prepare
printf '# Ajout\n' > "${D}/docs/nouveau.md"
printf '# Exigences\n' > "${D}/spec/exigences.md"
commit
verifie "docs" "$(voie)" "documentation seule"

echo "perimetre-test — outillage modifié : voie complète"
prepare
printf '\n# retouche\n' >> "${D}/tools/perimetre.sh"
commit
verifie "complet" "$(voie)" "outillage modifié"

echo "perimetre-test — fichier NON SUIVI : voie complète"
# L'angle mort du classement : « git diff » ne voit pas un fichier jamais
# ajouté. Sans la prise en compte des non-suivis, un nouveau script
# d'outillage passerait pour un changement documentaire.
prepare
printf '# Ajout\n' > "${D}/docs/nouveau.md"
commit
printf 'echo bidon\n' > "${D}/tools/nouvelle-porte.sh"
verifie "complet" "$(voie)" "fichier non suivi dans tools/"

echo "perimetre-test — façade CI modifiée : voie complète"
prepare
mkdir -p "${D}/.github/workflows"
printf 'name: ci\n' > "${D}/.github/workflows/ci.yml"
commit
verifie "complet" "$(voie)" "façade CI"

echo "perimetre-test — aucun changement : voie complète (jamais de pari)"
prepare
verifie "complet" "$(voie)" "empreinte vide"

echo "perimetre-test — pas de branche de référence : voie complète"
rm -rf "${D}"
mkdir -p "${D}/tools"
cp "${ROOT}/tools/perimetre.sh" "${D}/tools/"
(cd "${D}" && git init -q -b sans-reference && \
    git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: seul commit")
verifie "complet" "$(voie)" "aucune base de fusion"

if [ "${fail}" -ne 0 ]; then
    echo "perimetre-test : ÉCHEC." >&2
    exit 1
fi
echo "perimetre-test : OK."
