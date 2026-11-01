#!/bin/sh
# Test des contrôles de cohérence, chacun sur son cas d'échec.
#
# Ces trois contrôles existaient sans test depuis la fondation du gabarit :
# rien ne prouvait qu'ils échouaient un jour. C'est précisément le défaut que
# R3 vise (« aucun contrôle qui passe toujours ») et que la porte de
# classification a mis au jour en réclamant une vérification pour toute
# exigence de niveau DOIT.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"
prepare() {
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/templates/fr" "${D}/templates/en" "${D}/docs/adr"
    cp "${ROOT}/tools/checks.sh" "${D}/tools/"
    printf '# Modèle\n' > "${D}/templates/fr/adr.md"
    printf '# Template\n' > "${D}/templates/en/adr.md"
    cat > "${D}/docs/adr/0001-decision.md" <<'EOF'
# ADR-0001 — Une décision

**Statut** : Accepté

## Vérification

Une porte le vérifie.
EOF
    cat > "${D}/docs/adr/README.md" <<'EOF'
# Registre des ADR

## Index

| ADR | Titre | Statut |
| --- | --- | --- |
| [0001](0001-decision.md) | Une décision | Accepté |
EOF
    mkdir -p "${D}/.github/workflows"
    printf 'name: ci\njobs:\n  portes:\n    steps:\n      - name: Portes\n        run: tools/ci.sh\n' \
        > "${D}/.github/workflows/ci.yml"
    printf 'portes:\n  script:\n    - tools/ci.sh\n' > "${D}/.gitlab-ci.yml"
    cp "${ROOT}/tools/lexique.sh" "${D}/tools/"
    # Les deux façades CI ci-dessus appellent tools/ci.sh : le contrôle des
    # références pendantes exige que la cible existe. Un talon suffit — il
    # n'est jamais exécuté.
    printf '#!/bin/sh\nexit 0\n' > "${D}/tools/ci.sh"
    printf '1.2.3\n' > "${D}/VERSION"
    printf '# Journal\n\n## [1.2.3] - 2026-01-01\n\n### Ajouté\n\n- Rien.\n' > "${D}/CHANGELOG.md"
}
porte() { (cd "${D}" && sh tools/checks.sh >/dev/null 2>&1); }

echo "checks-test — dépôt sain : la porte doit passer"
prepare
if ! porte; then
    echo "ÉCHEC : la porte refuse un dépôt sain" >&2
    fail=1
fi

# Contrôle CONDITIONNEL : un dépôt instancié dans une seule langue n'a qu'un
# jeu de modèles, et l'instanciation retire alors le bloc correspondant.
# Le test constate donc sa présence avant de l'éprouver — sans quoi il exige
# une porte absente et échoue sur un dépôt sain.
if grep -q 'parite-templates:debut' tools/checks.sh; then
    echo "checks-test — parité des templates rompue : la porte doit échouer"
    prepare
    rm -f "${D}/templates/en/adr.md"
    if porte; then
        echo "ÉCHEC : modèle anglais manquant non signalé" >&2
        fail=1
    fi
else
    echo "checks-test — parité des modèles : porte absente (dépôt monolingue), cas ignoré"
fi

echo "checks-test — ADR accepté sans section Vérification : la porte doit échouer"
prepare
printf '# ADR-0002 — Sans preuve\n\n**Statut** : Accepté\n\n## Contexte\n\nRien.\n' \
    > "${D}/docs/adr/0002-sans-preuve.md"
if porte; then
    echo "ÉCHEC : ADR accepté sans Vérification non signalé" >&2
    fail=1
fi

echo "checks-test — VERSION absente du journal : la porte doit échouer"
prepare
printf '9.9.9\n' > "${D}/VERSION"
if porte; then
    echo "ÉCHEC : version sans section de journal non signalée" >&2
    fail=1
fi

echo "checks-test — ADR absent de l'index : la porte doit échouer"
prepare
printf '# ADR-0002 — Hors index\n\n**Statut** : Proposé\n' > "${D}/docs/adr/0002-hors-index.md"
if porte; then
    echo "ÉCHEC : ADR absent de l'index non signalé" >&2
    fail=1
fi

echo "checks-test — index renvoyant vers un ADR absent : la porte doit échouer"
prepare
printf '| [0009](0009-fantome.md) | Fantôme | Accepté |\n' >> "${D}/docs/adr/README.md"
if porte; then
    echo "ÉCHEC : renvoi d'index vers un ADR inexistant non signalé" >&2
    fail=1
fi

echo "checks-test — façades CI désalignées : la porte doit échouer"
prepare
printf '    - tools/porte-supplementaire.sh\n' >> "${D}/.gitlab-ci.yml"
if porte; then
    echo "ÉCHEC : étape présente sur une seule forge non signalée" >&2
    fail=1
fi

echo "checks-test — façade citant un script absent : la porte doit échouer"
# Cas d'échec du contrôle posé par ADR-0003. Le défaut visé est la RÉFÉRENCE
# pendante, pas un nom de fichier particulier : une façade qui appelle un
# script retiré ou renommé ne se voit qu'à l'exécution, donc en CI et jamais
# en revue.
prepare
printf 'portes:\n  script:\n    - tools/ci.sh\n    - sh tools/porte-disparue.sh\n' \
    > "${D}/.gitlab-ci.yml"
printf 'name: ci\njobs:\n  portes:\n    steps:\n      - name: Portes\n        run: tools/ci.sh\n      - name: Portes\n        run: sh tools/porte-disparue.sh\n' \
    > "${D}/.github/workflows/ci.yml"
if porte; then
    echo "ÉCHEC : façade citant un script absent non signalée" >&2
    fail=1
fi

echo "checks-test — terme de lexique incomplet : la porte doit échouer"
prepare
printf '\nlex_def TERME_BANCAL "seulement en français" ""\n' >> "${D}/tools/lexique.sh"
if porte; then
    echo "ÉCHEC : terme de lexique sans forme anglaise non signalé" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "checks-test : ÉCHEC." >&2
    exit 1
fi
echo "checks-test : OK."
