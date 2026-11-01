#!/bin/sh
# Test des portes de gouvernance documentaire, chacune sur son cas d'échec.
# Un dépôt de synthèse est reconstruit avant chaque cas : les portes se
# vérifient sur des données maîtrisées, jamais sur l'état du dépôt réel.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"

prepare() {
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/spec/02-exigences" "${D}/docs/decisions" \
             "${D}/docs/todo" "${D}/docs/revues" "${D}/docs/audit"
    for s in lexique statuts releves classification todo revues audit journaux badges avancement; do
        cp "${ROOT}/tools/${s}.sh" "${D}/tools/"
    done

    cat > "${D}/spec/02-exigences/domaine.md" <<'EOF'
# Exigences — domaine de démonstration

**Statut : ACTIVE** — actée le 2026-01-01 (D-2026-01-01).

## Une exigence

`req~exigence-de-demonstration~1`

**Statut : approuvée**

Le dépôt DOIT porter une exigence de démonstration.

Covers:
- feat~besoin~1

Needs: impl, utest
EOF
    cat > "${D}/spec/02-exigences/README.md" <<'EOF'
# Exigences

| Domaine | Statut | Objet |
| --- | --- | --- |
| [domaine](domaine.md) | ACTIVE | objet de démonstration |
EOF
    cat > "${D}/docs/decisions/registre.md" <<'EOF'
# Registre des décisions

| ID | Date | Décision | Développée dans |
| --- | --- | --- | --- |
| D-2026-01-01 | 2026-01-01 | Domaine « domaine » acté | relevé 2026-01-seance.md |
EOF
    cat > "${D}/docs/decisions/2026-01-seance.md" <<'EOF'
# Séance du 2026-01-01

## Relevé de décisions

- D-2026-01-01 — le domaine « domaine » passe ACTIVE.
EOF
    cat > "${D}/docs/todo/todo-0001-chantier.md" <<'EOF'
# ToDo-0001 — Un chantier

**Statut : 🚧 en cours**

Description.
EOF
    cat > "${D}/docs/audit/domaine.md" <<'EOF'
# Audit — domaine

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~exigence-de-demonstration~1` | conforme | porte de démonstration |
EOF
    printf 'MIT License\n\nCopyright (c) 2026 Test\n' > "${D}/LICENSE"
    printf '1.0.0\n' > "${D}/VERSION"
    printf '# Journal\n\n## [1.0.0] - 2026-01-01\n\n### Ajouté\n\n- Rien.\n' > "${D}/CHANGELOG.md"

    (cd "${D}" && git init -q && git add -A && \
        git -c user.name=t -c user.email=t@t commit -q -m "chore: socle de test")
    # Artefacts dérivés, générés puis versionnés comme dans le dépôt réel.
    (cd "${D}" && sh tools/todo.sh --ecrire >/dev/null && \
                  sh tools/badges.sh --ecrire >/dev/null && \
                  sh tools/revues.sh --ecrire >/dev/null && \
                  sh tools/audit.sh --ecrire >/dev/null && \
                  sh tools/avancement.sh --ecrire >/dev/null && \
                  git add -A && \
                  git -c user.name=t -c user.email=t@t commit -q -m "chore: artefacts dérivés")
}

porte() { (cd "${D}" && sh "tools/$1.sh" >/dev/null 2>&1); }

cas_sain() {
    prepare
    for p in statuts releves classification todo revues audit journaux badges avancement; do
        if ! porte "${p}"; then
            echo "ÉCHEC : ${p} refuse un dépôt sain" >&2
            (cd "${D}" && sh "tools/${p}.sh" 2>&1 | sed 's/^/        /') >&2
            fail=1
        fi
    done
}

cas_echec() {
    _porte="$1"; _libelle="$2"
    if porte "${_porte}"; then
        echo "ÉCHEC : ${_porte} — ${_libelle} non signalé" >&2
        fail=1
    fi
}

echo "gouvernance-test — dépôt sain : les huit portes doivent passer"
cas_sain

echo "gouvernance-test — statuts : domaine sans statut"
prepare
sed '/^\*\*Statut/d' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
cas_echec statuts "statut absent"

echo "gouvernance-test — statuts : index et en-tête divergents"
prepare
sed 's/| ACTIVE |/| PROPOSITION |/' "${D}/spec/02-exigences/README.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/README.md"
cas_echec statuts "divergence index/en-tête"

echo "gouvernance-test — statuts : ACTIVE sans décision au registre"
prepare
sed '/D-2026-01-01/d' "${D}/docs/decisions/registre.md" > "${D}/x" && \
    mv "${D}/x" "${D}/docs/decisions/registre.md"
cas_echec statuts "domaine ACTIVE non acté"

echo "gouvernance-test — statuts : exigence sans ligne de statut"
prepare
sed '/^\*\*Statut : approuvée\*\*$/d' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
cas_echec statuts "exigence sans statut déclaré"

echo "gouvernance-test — statuts : statut d AVANCEMENT déclaré à la main"
# Le refus qui donne son sens au partage déclaré/calculé (ADR-0018) : un
# « vérifiée » saisi se périme au premier remaniement, sans rien signaler.
prepare
sed 's/^\*\*Statut : approuvée\*\*$/**Statut : vérifiée**/' \
    "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
cas_echec statuts "statut calculé écrit à la main"

echo "gouvernance-test — statuts : exigence approuvée dans un domaine NON actif"
# La règle qui empêche les deux axes de diverger.
prepare
sed 's/^\*\*Statut : ACTIVE\*\*.*$/**Statut : PROPOSITION** — pas encore actée./' \
    "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
sed 's/| ACTIVE |/| PROPOSITION |/' "${D}/spec/02-exigences/README.md" > "${D}/y" && \
    mv "${D}/y" "${D}/spec/02-exigences/README.md"
cas_echec statuts "approbation dans un domaine en proposition"

echo "gouvernance-test — statuts : un brouillon sort du dénominateur"
prepare
sed 's/^\*\*Statut : approuvée\*\*$/**Statut : brouillon**/' \
    "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
# L exigence sort du périmètre de l audit : la fiche qui la juge encore vise
# donc une exigence hors dénominateur, et la porte doit le dire.
cas_echec audit "audit d une exigence sortie du dénominateur"

echo "gouvernance-test — relevés : section de décisions vide"
prepare
printf '# Séance du 2026-01-01\n\n## Relevé de décisions\n\n' \
    > "${D}/docs/decisions/2026-01-seance.md"
cas_echec releves "relevé sans décision consignée"

echo "gouvernance-test — relevés : gabarit laissé tel quel"
prepare
printf '# Séance\n\n## Relevé de décisions\n\n- {{ décision }}\n' \
    > "${D}/docs/decisions/2026-01-seance.md"
cas_echec releves "gabarit non rempli"

echo "gouvernance-test — relevés : décision citée absente du registre"
prepare
printf '# Séance\n\n## Relevé de décisions\n\n- D-2026-09-99 — décision fantôme.\n' \
    > "${D}/docs/decisions/2026-01-seance.md"
cas_echec releves "décision hors registre"

echo "gouvernance-test — classification : DOIT sans vérification déclarée"
prepare
sed 's/^Needs: impl, utest$/Needs: impl/' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
cas_echec classification "exigence DOIT sans niveau de test"

echo "gouvernance-test — classification : mtest seul sans report (complétude durcie)"
prepare
sed 's/^Needs: impl, utest$/Needs: impl, mtest/' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
cas_echec classification "DOIT couvert par mtest seul, sans report"

echo "gouvernance-test — classification : mtest seul reporté par fiche (dette nommée)"
prepare
sed 's/^Needs: impl, utest$/Needs: impl, mtest/' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
printf '\n- `req~exigence-de-demonstration~1` (à élever : à mécaniser)\n' \
    >> "${D}/docs/todo/todo-0001-chantier.md"
if ! porte classification; then
    echo "ÉCHEC : classification refuse un mtest seul pourtant reporté par fiche" >&2
    (cd "${D}" && sh tools/classification.sh 2>&1 | sed 's/^/        /') >&2
    fail=1
fi

echo "gouvernance-test — classification : énoncé sans niveau normatif"
prepare
sed 's/^Le dépôt DOIT porter.*$/Le dépôt porte une exigence de démonstration./' \
    "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
cas_echec classification "énoncé sans DOIT/DEVRAIT/PEUT"

echo "gouvernance-test — classification : niveau EMPRUNTÉ au rationale"
# Le piège : « DOIT » n'apparaît que dans le Rationale. L'énoncé, lui, n'a
# aucun niveau — la porte doit le dire, et surtout ne pas classer en DOIT.
prepare
cat > "${D}/spec/02-exigences/domaine.md" <<'EOF'
# Exigences — domaine de démonstration

**Statut : ACTIVE** — actée le 2026-01-01 (D-2026-01-01).

## Une exigence

`req~exigence-de-demonstration~1`

**Statut : approuvée**

Le dépôt porte une exigence de démonstration.

Rationale:
Toute porte DOIT rester exécutable hors ligne.

Covers:
- feat~besoin~1

Needs: impl, utest
EOF
cas_echec classification "niveau normatif emprunté au rationale"

echo "gouvernance-test — feuille de route : fiche sans ligne de statut"
prepare
printf '# ToDo-0002 — Sans statut\n\nTexte.\n' > "${D}/docs/todo/todo-0002-sans-statut.md"
(cd "${D}" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: fiche")
cas_echec todo "fiche sans ligne de statut"

echo "gouvernance-test — feuille de route : index périmé"
prepare
printf '# Feuille de route\n\nvide\n' > "${D}/docs/todo/README.md"
cas_echec todo "index édité à la main"

echo "gouvernance-test — revues : constat de sévérité haute sans verdict"
prepare
cat > "${D}/docs/revues/2026-01-revue.md" <<'EOF'
# Revue de code — 2026-01-01

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | haute | Fuite de contexte entre locataires | | |
EOF
(cd "${D}" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: revue" && \
    sh tools/revues.sh --ecrire >/dev/null && git add -A && \
    git -c user.name=t -c user.email=t@t commit -q -m "chore: suivi")
cas_echec revues "sévérité haute laissée ouverte"

echo "gouvernance-test — revues : sévérité haute REJETÉE (réponse valable)"
prepare
cat > "${D}/docs/revues/2026-01-revue.md" <<'EOF'
# Revue de code — 2026-01-01

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | haute | Fuite supposée entre locataires | Rejeté | hors modèle de menace, cf. ADR-0002 |
EOF
(cd "${D}" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: revue" && \
    sh tools/revues.sh --ecrire >/dev/null && git add -A && \
    git -c user.name=t -c user.email=t@t commit -q -m "chore: suivi")
if ! porte revues; then
    echo "ÉCHEC : revues — un rejet motivé doit solder le constat" >&2
    fail=1
fi

echo "gouvernance-test — revues : « | » non échappé dans une cellule"
# Le décalage de colonnes qui en résulte faisait lire le verdict au mauvais
# endroit : un constat soldé s affichait « ouvert », sans la moindre erreur.
# Défaut trouvé en consolidant la revue de cette branche.
prepare
cat > "${D}/docs/revues/2026-01-revue.md" <<'EOF'
# Revue de code — 2026-01-01

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | basse | Motif a|b cité sans échappement | Corrigé | commit |
EOF
(cd "${D}" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: revue")
cas_echec revues "barre non échappée dans une cellule"

echo "gouvernance-test — revues : la même cellule, barre ÉCHAPPÉE cette fois"
prepare
cat > "${D}/docs/revues/2026-01-revue.md" <<'EOF'
# Revue de code — 2026-01-01

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | basse | Motif a\|b cité correctement | Corrigé | commit |
EOF
(cd "${D}" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "chore: revue" && \
    sh tools/revues.sh --ecrire >/dev/null && git add -A && \
    git -c user.name=t -c user.email=t@t commit -q -m "chore: suivi")
if ! porte revues; then
    echo "ÉCHEC : revues — une barre échappée est du texte, pas un séparateur" >&2
    fail=1
fi

echo "gouvernance-test — avancement : due tenue (Needs déclaré) -> implémentée"
prepare
if ! grep -q '| implémentée | objet de démonstration |' "${D}/spec/02-exigences/README.md"; then
    echo "ÉCHEC : avancement — domaine entièrement tenu non reconnu implémentée" >&2
    fail=1
fi

echo "gouvernance-test — avancement : Needs vide, aucune fiche ouverte -> à planifier"
prepare
sed 's/^Needs: impl, utest$/Needs:/' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
(cd "${D}" && sh tools/avancement.sh --ecrire >/dev/null)
if ! grep -q '| à planifier | objet de démonstration |' "${D}/spec/02-exigences/README.md"; then
    echo "ÉCHEC : avancement — domaine non tenu et non cité non reconnu à planifier" >&2
    fail=1
fi

echo "gouvernance-test — avancement : Needs vide, fiche OUVERTE qui cite -> planifiée"
prepare
sed 's/^Needs: impl, utest$/Needs:/' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
printf '# ToDo-0001 — Un chantier\n\n**Statut : 🚧 en cours**\n\nCite req~exigence-de-demonstration~1.\n' \
    > "${D}/docs/todo/todo-0001-chantier.md"
(cd "${D}" && sh tools/todo.sh --ecrire >/dev/null && sh tools/avancement.sh --ecrire >/dev/null)
if ! grep -q '| planifiée | objet de démonstration |' "${D}/spec/02-exigences/README.md"; then
    echo "ÉCHEC : avancement — domaine cité par une fiche ouverte non reconnu planifiée" >&2
    fail=1
fi

echo "gouvernance-test — avancement : la même citation, fiche SOLDÉE -> ne compte plus"
prepare
sed 's/^Needs: impl, utest$/Needs:/' "${D}/spec/02-exigences/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
printf '# ToDo-0001 — Un chantier\n\n**Statut : ✅ fait**\n\nCite req~exigence-de-demonstration~1.\n' \
    > "${D}/docs/todo/todo-0001-chantier.md"
(cd "${D}" && sh tools/todo.sh --ecrire >/dev/null && sh tools/avancement.sh --ecrire >/dev/null)
if ! grep -q '| à planifier | objet de démonstration |' "${D}/spec/02-exigences/README.md"; then
    echo "ÉCHEC : avancement — une fiche soldée comptée comme citation ouverte" >&2
    fail=1
fi

echo "gouvernance-test — avancement : aucune due (PEUT seul) -> hors mesure"
prepare
sed 's/^Le dépôt DOIT porter.*$/Le dépôt PEUT porter une exigence de démonstration./' \
    "${D}/spec/02-exigences/domaine.md" > "${D}/x" && mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
(cd "${D}" && sh tools/avancement.sh --ecrire >/dev/null)
if ! grep -q '| hors mesure | objet de démonstration |' "${D}/spec/02-exigences/README.md"; then
    echo "ÉCHEC : avancement — domaine sans exigence due non reconnu hors mesure" >&2
    fail=1
fi

echo "gouvernance-test — avancement : domaine non ACTIVE -> —"
prepare
sed 's/^\*\*Statut : ACTIVE\*\*.*$/**Statut : PROPOSITION** — pas encore actée./' \
    "${D}/spec/02-exigences/domaine.md" > "${D}/x" && mv "${D}/x" "${D}/spec/02-exigences/domaine.md"
sed 's/| ACTIVE |/| PROPOSITION |/' "${D}/spec/02-exigences/README.md" > "${D}/y" && \
    mv "${D}/y" "${D}/spec/02-exigences/README.md"
(cd "${D}" && sh tools/avancement.sh --ecrire >/dev/null)
if ! grep -q '| — | objet de démonstration |' "${D}/spec/02-exigences/README.md"; then
    echo "ÉCHEC : avancement — domaine non actif non marqué « — »" >&2
    fail=1
fi

echo "gouvernance-test — avancement : colonne modifiée à la main"
prepare
sed 's/| implémentée |/| en cours |/' "${D}/spec/02-exigences/README.md" > "${D}/x" && \
    mv "${D}/x" "${D}/spec/02-exigences/README.md"
cas_echec avancement "colonne Avancement modifiée à la main"

echo "gouvernance-test — audit : exigence non examinée"
prepare
printf '# Audit — domaine\n\n| Exigence | Verdict | Preuve / écart |\n| --- | --- | --- |\n' \
    > "${D}/docs/audit/domaine.md"
(cd "${D}" && sh tools/audit.sh --ecrire >/dev/null 2>&1 || true)
cas_echec audit "exigence sans ligne d'audit"

echo "gouvernance-test — audit : verdict hors lexique"
prepare
sed 's/| conforme |/| plutôt bien |/' "${D}/docs/audit/domaine.md" > "${D}/x" && \
    mv "${D}/x" "${D}/docs/audit/domaine.md"
cas_echec audit "verdict hors vocabulaire"

echo "gouvernance-test — audit : ligne visant une exigence disparue"
prepare
printf '| `req~exigence-disparue~1` | conforme | — |\n' >> "${D}/docs/audit/domaine.md"
cas_echec audit "audit d'une exigence inexistante"

echo "gouvernance-test — journaux : version sans aucune section"
prepare
printf '9.9.9\n' > "${D}/VERSION"
printf '# Journal\n\n## [1.0.0] - 2026-01-01\n\n- Rien.\n' > "${D}/CHANGELOG.md"
cas_echec journaux "version absente du journal"

echo "gouvernance-test — journaux : section close réécrite après le tag"
prepare
(cd "${D}" && git tag v1.0.0)
printf '# Journal\n\n## [1.0.0] - 2026-01-01\n\n### Ajouté\n\n- Rien.\n- Entrée glissée après coup.\n' \
    > "${D}/CHANGELOG.md"
(cd "${D}" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "docs: retouche tardive")
cas_echec journaux "section publiée modifiée après son tag"

echo "gouvernance-test — badges : badge périmé après changement de version"
prepare
printf '2.0.0\n' > "${D}/VERSION"
cas_echec badges "badge de version non régénéré"

# La langue est un CHOIX D'INSTANCIATION (ADR-0009) : l'assertion doit suivre
# le lexique installé, jamais supposer le défaut du gabarit. Écrit en dur sur
# « fr-en », ce cas exigeait qu'un verdict anglais soit accepté — vrai ici,
# faux dans tout dépôt instancié en « fr », où la porte le refuse à bon droit.
# C'est le défaut corrigé sur socle-test par ADR-0002, resté sur celui-ci : un
# test qui affirme le contraire de la règle installée n'échoue pas une fois,
# il échoue toujours, et finit désactivé.
LANGUE="$(. "${ROOT}/tools/lexique.sh"; echo "${LEXIQUE_LANGUE}")"
echo "gouvernance-test — lexique : langue constatée = ${LANGUE}"

case "${LANGUE}" in
    fr-en)
        echo "gouvernance-test — lexique : en « fr-en », les DEUX formes sont acceptées"
        # Angle mort du test lui-même, trouvé en revue (constat n° 1) : le cas
        # « en » ci-dessous ne prouvait rien sur le mode bilingue, qui est le
        # DÉFAUT de l'instanciation. La porte n'acceptait alors que le français.
        prepare
        sed 's/| conforme |/| compliant |/' "${D}/docs/audit/domaine.md" > "${D}/x" && \
            mv "${D}/x" "${D}/docs/audit/domaine.md"
        (cd "${D}" && sh tools/audit.sh --ecrire >/dev/null 2>&1 || true)
        if ! porte audit; then
            echo "ÉCHEC : audit — un verdict anglais doit être accepté en langue « fr-en »" >&2
            (cd "${D}" && sh tools/audit.sh 2>&1 | sed 's/^/        /') >&2
            fail=1
        fi
        ;;
    fr)
        echo "gouvernance-test — lexique : en « fr », un verdict anglais doit être REFUSÉ"
        prepare
        sed 's/| conforme |/| compliant |/' "${D}/docs/audit/domaine.md" > "${D}/x" && \
            mv "${D}/x" "${D}/docs/audit/domaine.md"
        cas_echec audit "verdict anglais dans un dépôt francophone"
        ;;
    en)
        echo "gouvernance-test — lexique : en « en », le verdict anglais est le seul admis"
        prepare
        sed 's/| conforme |/| compliant |/' "${D}/docs/audit/domaine.md" > "${D}/x" && \
            mv "${D}/x" "${D}/docs/audit/domaine.md"
        (cd "${D}" && sh tools/audit.sh --ecrire >/dev/null 2>&1 || true)
        if ! porte audit; then
            echo "ÉCHEC : audit — un verdict anglais doit être accepté en langue « en »" >&2
            fail=1
        fi
        ;;
esac

echo "gouvernance-test — lexique : vocabulaire anglais avec --langue en"
prepare
sed 's/^LEXIQUE_LANGUE=.*/LEXIQUE_LANGUE="en"/' "${D}/tools/lexique.sh" > "${D}/x" && \
    mv "${D}/x" "${D}/tools/lexique.sh"
# En langue « en », « ACTIVE » reste ACTIVE mais « conforme » ne l'est plus :
# l'audit doit refuser un verdict resté français.
cas_echec audit "verdict français dans un dépôt anglophone"

if [ "${fail}" -ne 0 ]; then
    echo "gouvernance-test : ÉCHEC." >&2
    exit 1
fi
echo "gouvernance-test : OK."
