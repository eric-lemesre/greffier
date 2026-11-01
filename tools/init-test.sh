#!/bin/sh
# [utest->req~instanciation-outillee~2]
# [utest->req~politique-attribution-agents~2]
# [utest->req~politique-langue~1]
# [utest->req~rattachement-code-exigence~1]
# Test mécanisé du script d'instanciation : exécute tools/init.sh sur des
# copies temporaires et vérifie les critères d'acceptation des quatre
# arbitrages (identité, attribution des agents, langue, cycle de vie des
# issues), le refus de tourner deux fois, et des portes vertes dans chaque
# variante. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TA="$(mktemp -d)"
TB="$(mktemp -d)"
TC="$(mktemp -d)"
TD="$(mktemp -d)"
TE="$(mktemp -d)"
TF="$(mktemp -d)"
trap 'rm -rf "${TA}" "${TB}" "${TC}" "${TD}" "${TE}" "${TF}"' EXIT INT TERM
fail=0

instancier() {
    _dest="$1"
    shift
    cp -R "${ROOT}/." "${_dest}/"
    rm -rf "${_dest}/.git" "${_dest}/build"
    # Commit initial obligatoire : un vrai clone (ou un dépôt « Use this
    # template ») a un index peuplé, et les générateurs le consultent via
    # « git ls-files ». Sans ce commit l'index est vide et le test resterait
    # aveugle aux fichiers hérités du gabarit supprimés mais non désindexés
    # par init.sh (cas constaté : awk fatal sur todo-0001).
    (cd "${_dest}" && git init -q &&
        git add -A &&
        git -c user.name="Init Test" -c user.email="init-test@example.invalid" \
            -c commit.gpgsign=false commit -q -m "gabarit: état initial" &&
        sh tools/init.sh --nom projet-test --porteur "Porteuse Test" --force "$@")
}

echo "init-test [A] — instanciation par défaut"
instancier "${TA}"
if [ -f "${TA}/docs/adr/0001-structurer-alm-forge-en-depot-gabarit.md" ]; then
    echo "ÉCHEC [A] : les ADR du gabarit n'ont pas été retirés" >&2 ; fail=1
fi
if [ -f "${TA}/spec/01-besoins/besoins.md" ]; then
    echo "ÉCHEC [A] : la spécification du gabarit n'a pas été retirée" >&2 ; fail=1
fi
case "$(cat "${TA}/LICENSE")" in
    *"Porteuse Test"*) ;;
    *) echo "ÉCHEC [A] : la LICENSE ne porte pas le porteur" >&2 ; fail=1 ;;
esac
case "$(cat "${TA}/README.md")" in
    *projet-test*) ;;
    *) echo "ÉCHEC [A] : le README ne porte pas le nom du projet" >&2 ; fail=1 ;;
esac
if [ ! -d "${TA}/templates/en" ] || [ ! -f "${TA}/README.en.md" ]; then
    echo "ÉCHEC [A] : le défaut fr-en doit conserver le bilinguisme" >&2 ; fail=1
fi
# Politique par défaut : déclaration obligatoire (diligence, ADR-0011).
printf 'feat: sujet valide\n' > "${TA}/msg-attr"
if (cd "${TA}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [A] : le hook accepte un commit sans trailer IA (défaut = obligatoire)" >&2
    fail=1
fi
printf 'feat: sujet valide\n\nIA: aucune\n' > "${TA}/msg-attr"
if ! (cd "${TA}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [A] : le hook refuse « IA: aucune »" >&2
    fail=1
fi
printf 'feat: sujet valide\n\nIA: Outil X\n' > "${TA}/msg-attr"
if (cd "${TA}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [A] : le hook accepte un usage d'IA sans responsable humain" >&2
    fail=1
fi
printf 'feat: sujet valide\n\nIA: Outil X\nResponsable: Porteuse Test\n' > "${TA}/msg-attr"
if ! (cd "${TA}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [A] : le hook refuse une déclaration IA complète (outil + responsable)" >&2
    fail=1
fi
# Cycle de vie des issues par défaut : circuit complet conservé et consigné.
if [ ! -f "${TA}/.github/ISSUE_TEMPLATE/proposition-exigence.yml" ] || \
   [ ! -f "${TA}/.github/ISSUE_TEMPLATE/proposition-organisation.yml" ]; then
    echo "ÉCHEC [A] : le défaut complet doit conserver les formulaires [Spec]/[Orga]" >&2
    fail=1
fi
case "$(cat "${TA}/docs/decisions/registre.md")" in
    *"défaut du gabarit adopté"*) ;;
    *) echo "ÉCHEC [A] : l'arbitrage du cycle de vie n'est pas consigné au registre" >&2 ; fail=1 ;;
esac
if grep -q 'impl->req~issues-' "${TA}/.github/ISSUE_TEMPLATE/anomalie.yml" 2>/dev/null; then
    echo "ÉCHEC [A] : les tags de couverture des formulaires n'ont pas été retirés" >&2
    fail=1
fi
(cd "${TA}" && sh tools/oft.sh trace >/dev/null && sh tools/checks.sh >/dev/null) || {
    echo "ÉCHEC [A] : portes non vertes après instanciation" >&2 ; fail=1
}
# Une réécriture par fichier temporaire ne doit pas retirer le droit
# d'exécution : sans lui, le hook pre-commit refuse de s'exécuter
# (« Permission non accordée ») et le premier commit du projet échoue.
# Constaté sur deux projets instanciés le 2026-10-31 (43 scripts touchés).
# La liste des exécutables vient de l'index du gabarit. Vide (pas de git, index
# illisible), le contrôle ne vérifierait rien : elle doit contenir le hook.
executables="$(cd "${ROOT}" && git ls-files -s | awk '$1 == "100755" { print $4 }')" || executables=""
case "${executables}" in
    *tools/hooks/pre-commit.sh*) ;;
    *) echo "ÉCHEC [A] : exécutables du gabarit introuvables, contrôle des droits sans objet" >&2 ; fail=1 ;;
esac
perdus=""
for f in ${executables}; do
    if [ -f "${TA}/${f}" ] && [ ! -x "${TA}/${f}" ]; then
        perdus="${perdus} ${f}"
    fi
done
if [ -n "${perdus}" ]; then
    echo "ÉCHEC [A] : droit d'exécution perdu à l'instanciation :${perdus}" >&2 ; fail=1
fi
# L'outillage d'instanciation quitte aussi l'index, avant tout « git add » du
# test : sinon la matrice le citerait encore.
if (cd "${TA}" && git ls-files --error-unmatch tools/init.sh tools/init-test.sh >/dev/null 2>&1); then
    echo "ÉCHEC [A] : tools/init.sh ou tools/init-test.sh reste dans l'index" >&2 ; fail=1
fi
# Les artefacts générés sortent à jour de l'instanciation : la porte
# anti-dérive, que le hook pre-commit joue, ne doit pas refuser le premier
# commit du projet (constaté le 2026-10-31 : matrice de traçabilité périmée).
(cd "${TA}" && git add -A && sh tools/derive.sh >/dev/null 2>&1) || {
    echo "ÉCHEC [A] : artefacts générés périmés après instanciation (tools/derive.sh)" >&2 ; fail=1
}
# Le code hérité du gabarit est déclaré par l'instanciation, et seulement
# lui : le premier fichier de code que le projet ajoute sans trace fait
# échouer la porte du rattachement.
if ! grep -qxF 'tools/ci.sh' "${TA}/tools/rattachement-herites.txt" 2>/dev/null; then
    echo "ÉCHEC [A] : le code hérité du gabarit n'est pas déclaré (tools/rattachement-herites.txt)" >&2
    fail=1
fi
if grep -q 'req~' "${TA}/tools/bump.sh" "${TA}/templates/bootstrap.d/markdown/markdown.sh"; then
    echo "ÉCHEC [A] : une mention d'exigence du gabarit subsiste dans l'outillage hérité" >&2
    fail=1
fi
(cd "${TA}" && sh tools/rattachement.sh >/dev/null 2>&1) || {
    echo "ÉCHEC [A] : porte du rattachement rouge après instanciation" >&2 ; fail=1
}
mkdir -p "${TA}/src"
printf 'def f():\n    return 1\n' > "${TA}/src/sans_trace.py"
(cd "${TA}" && git add src/sans_trace.py)
if (cd "${TA}" && sh tools/rattachement.sh >/dev/null 2>&1); then
    echo "ÉCHEC [A] : un fichier de code du projet sans trace passe la porte du rattachement" >&2
    fail=1
fi
(cd "${TA}" && git rm -q --cached src/sans_trace.py) && rm -f "${TA}/src/sans_trace.py"
# L'outillage d'instanciation se retire lui-même, avec toutes ses amarres.
# Le laisser en place rendait la porte du dépôt produit rouge dès sa première
# réalisation taguée, et gardait un script destructeur documenté au contrat.
for f in tools/init.sh tools/init-test.sh; do
    if [ -e "${TA}/${f}" ]; then
        echo "ÉCHEC [A] : ${f} subsiste dans le dépôt produit" >&2 ; fail=1
    fi
done
for f in tools/ci.sh Taskfile.yml AGENTS.md templates/orchestrators/justfile; do
    if [ -f "${TA}/${f}" ] && grep -q 'tools/init\.sh' "${TA}/${f}"; then
        echo "ÉCHEC [A] : ${f} cite encore l'outillage d'instanciation retiré" >&2 ; fail=1
    fi
done

# Les gardes d'entrée du script se testent sur un exemplaire REMIS EN PLACE :
# sans ce geste, les deux assertions qui suivent passeraient parce que le
# fichier est absent — un contrôle qui ne contrôle rien, exactement ce que R3
# interdit. La garde, elle, lit l'état du dépôt et non sa propre présence.
cp "${ROOT}/tools/init.sh" "${TA}/tools/init.sh"
if (cd "${TA}" && sh tools/init.sh --nom x --porteur y </dev/null) 2>/dev/null; then
    echo "ÉCHEC [A] : init.sh a accepté de tourner deux fois sans --force" >&2 ; fail=1
fi
if (cd "${TA}" && sh tools/init.sh --nom x --porteur y --cycle-issues nimporte --force </dev/null) 2>/dev/null; then
    echo "ÉCHEC [A] : init.sh a accepté une valeur invalide pour --cycle-issues" >&2 ; fail=1
fi
rm -f "${TA}/tools/init.sh"

echo "init-test [B] — mentions autorisées, sans obligation"
instancier "${TB}" --attribution-agents autorisee
printf 'feat: sujet valide\n\nCo-Authored-By: Robot <r@x>\n' > "${TB}/msg-attr"
if ! (cd "${TB}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [B] : le hook refuse un co-auteur alors que les mentions sont autorisées" >&2
    fail=1
fi
printf 'feat: sujet valide\n' > "${TB}/msg-attr"
if ! (cd "${TB}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [B] : le hook impose un trailer alors que rien n'est obligatoire" >&2
    fail=1
fi
case "$(cat "${TB}/AGENTS.md")" in
    *"autorisées, sans obligation"*) ;;
    *) echo "ÉCHEC [B] : la règle R0 d'AGENTS.md ne reflète pas le choix" >&2 ; fail=1 ;;
esac

echo "init-test [E] — mentions interdites"
instancier "${TE}" --attribution-agents interdite
printf 'feat: sujet valide\n\nCo-Authored-By: Robot <r@x>\n' > "${TE}/msg-attr"
if (cd "${TE}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [E] : le hook accepte un co-auteur alors que les mentions sont interdites" >&2
    fail=1
fi
printf 'feat: sujet valide\n' > "${TE}/msg-attr"
if ! (cd "${TE}" && sh tools/hooks/commit-msg.sh msg-attr) 2>/dev/null; then
    echo "ÉCHEC [E] : le hook refuse un commit sain sous interdiction" >&2
    fail=1
fi

# [utest->req~coherence-choix-instanciation~1]
# Le hook seul ne suffit pas : ce qui manquait était la propagation du choix
# aux TEXTES et aux TESTS du dépôt produit. Trois constats, chacun sur son
# cas d'échec réel — tous trois observés sur un dépôt instancié avant que
# l'exigence de cohérence n'existe.
if grep -q 'la politique R0 (`IA:`' "${TE}/AGENTS.md"; then
    echo "ÉCHEC [E] : AGENTS.md prescrit encore le trailer IA que le hook refuse" >&2
    fail=1
fi
if grep -q 'trailer `IA:` obligatoire' "${TE}/CONTRIBUTING.md"; then
    echo "ÉCHEC [E] : CONTRIBUTING.md annonce le défaut du gabarit et non le choix" >&2
    fail=1
fi
if ! (cd "${TE}" && sh tools/socle-test.sh) >/dev/null 2>&1; then
    echo "ÉCHEC [E] : les tests d'outillage du dépôt produit échouent sous interdiction" >&2
    fail=1
fi
if find "${TE}/docs/decisions" -name '*.md' ! -name 'README.md' ! -name 'registre.md' \
        | grep -q .; then
    echo "ÉCHEC [E] : un relevé du gabarit subsiste alors que le registre est réécrit" >&2
    fail=1
fi
if ! (cd "${TE}" && sh tools/releves.sh) >/dev/null 2>&1; then
    echo "ÉCHEC [E] : la porte des relevés échoue sur un dépôt fraîchement instancié" >&2
    fail=1
fi

echo "init-test [C] — langue fr uniquement"
instancier "${TC}" --langue fr
if [ -d "${TC}/templates/en" ] || [ -f "${TC}/README.en.md" ]; then
    echo "ÉCHEC [C] : le jeu anglais aurait dû être retiré" >&2 ; fail=1
fi
if grep -q "parite-templates:debut" "${TC}/tools/checks.sh"; then
    echo "ÉCHEC [C] : la porte de parité aurait dû être retirée" >&2 ; fail=1
fi
# [utest->req~coherence-choix-instanciation~1]
# Retirer la porte sans neutraliser son test laissait la voie complète rouge
# à la naissance du projet : le test exigeait une porte que l'instanciation
# venait de supprimer.
if ! (cd "${TC}" && sh tools/checks-test.sh) >/dev/null 2>&1; then
    echo "ÉCHEC [C] : les tests d'outillage échouent sur un dépôt monolingue" >&2
    fail=1
fi
(cd "${TC}" && sh tools/oft.sh trace >/dev/null && sh tools/checks.sh >/dev/null) || {
    echo "ÉCHEC [C] : portes non vertes en langue fr" >&2 ; fail=1
}

echo "init-test [D] — langue en uniquement"
instancier "${TD}" --langue en
if [ -d "${TD}/templates/fr" ]; then
    echo "ÉCHEC [D] : le jeu français aurait dû être retiré" >&2 ; fail=1
fi
case "$(cat "${TD}/README.md")" in
    *"instantiated from"*) ;;
    *) echo "ÉCHEC [D] : le README principal devrait être en anglais" >&2 ; fail=1 ;;
esac
(cd "${TD}" && sh tools/oft.sh trace >/dev/null && sh tools/checks.sh >/dev/null) || {
    echo "ÉCHEC [D] : portes non vertes en langue en" >&2 ; fail=1
}
(cd "${TD}" && sh tools/adr-new.sh premiere-decision >/dev/null && \
    [ -f docs/adr/0001-premiere-decision.md ]) || {
    echo "ÉCHEC [D] : adr-new doit fonctionner sans templates/fr" >&2 ; fail=1
}

echo "init-test [F] — cycle de vie des issues réduit"
instancier "${TF}" --cycle-issues reduit
if [ -f "${TF}/.github/ISSUE_TEMPLATE/proposition-exigence.yml" ] || \
   [ -f "${TF}/.github/ISSUE_TEMPLATE/proposition-organisation.yml" ]; then
    echo "ÉCHEC [F] : les formulaires de consultation [Spec]/[Orga] auraient dû être retirés" >&2
    fail=1
fi
case "$(cat "${TF}/docs/decisions/registre.md")" in
    *"circuit réduit"*) ;;
    *) echo "ÉCHEC [F] : la réduction du cycle de vie n'est pas consignée au registre" >&2 ; fail=1 ;;
esac
(cd "${TF}" && sh tools/oft.sh trace >/dev/null && sh tools/checks.sh >/dev/null) || {
    echo "ÉCHEC [F] : portes non vertes en cycle réduit" >&2 ; fail=1
}

if [ "${fail}" -ne 0 ]; then
    echo "init-test : ÉCHEC." >&2
    exit 1
fi
echo "init-test : OK."
