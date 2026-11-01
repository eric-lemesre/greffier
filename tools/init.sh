#!/bin/sh
# [impl->req~instanciation-outillee~2]
# Script d'instanciation du gabarit : personnalise l'identité du projet,
# applique les arbitrages de l'instanciateur (attribution des agents,
# ADR-0011 ; langue, ADR-0009 ; cycle de vie des issues, ADR-0013) et retire
# tout ce qui n'appartient qu'à alm-forge, en laissant la traçabilité verte.
# À lancer UNE FOIS, juste après la création du dépôt (« Use this template »
# sur GitHub, ou simple clone + nouveau remote sur GitLab et toute autre
# forge, ADR-0010).
#   sh tools/init.sh --nom mon-projet --porteur "Prénom Nom" \
#       [--attribution-agents autorisee|interdite] [--langue fr|en|fr-en] \
#       [--cycle-issues complet|reduit] [--force]
# POSIX sh strict. GitHub ne substituant aucune variable à la création depuis
# un template, ce script est le mécanisme de personnalisation.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

NOM=""
PORTEUR=""
ATTRIBUTION=""
LANGUE=""
CYCLE=""
FORCE=0

usage() {
    echo "Usage : sh tools/init.sh --nom mon-projet --porteur \"Prénom Nom\" [--attribution-agents autorisee|interdite] [--langue fr|en|fr-en] [--cycle-issues complet|reduit] [--force]" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --nom) NOM="${2:-}"; shift 2 ;;
        --porteur) PORTEUR="${2:-}"; shift 2 ;;
        --attribution-agents)
            case "${2:-}" in
                obligatoire|autorisee|interdite) ATTRIBUTION="$2" ;;
                *) echo "ERREUR : --attribution-agents attend « obligatoire », « autorisee » ou « interdite »." >&2 ; exit 2 ;;
            esac
            shift 2 ;;
        --langue)
            case "${2:-}" in
                fr|en|fr-en) LANGUE="$2" ;;
                *) echo "ERREUR : --langue attend « fr », « en » ou « fr-en »." >&2 ; exit 2 ;;
            esac
            shift 2 ;;
        --cycle-issues)
            case "${2:-}" in
                complet|reduit) CYCLE="$2" ;;
                *) echo "ERREUR : --cycle-issues attend « complet » ou « reduit »." >&2 ; exit 2 ;;
            esac
            shift 2 ;;
        --force) FORCE=1; shift ;;
        *) echo "Option inconnue : $1" >&2 ; usage ;;
    esac
done

# Invites interactives si les valeurs manquent et qu'un terminal est là.
if [ -z "${NOM}" ] && [ -t 0 ]; then
    printf 'Nom du projet (kebab-case) : '
    read -r NOM
fi
if [ -z "${PORTEUR}" ] && [ -t 0 ]; then
    printf 'Porteur du projet (Prénom Nom) : '
    read -r PORTEUR
fi
if [ -z "${ATTRIBUTION}" ] && [ -t 0 ]; then
    printf 'Mention de l'"'"'IA dans les commits — obligatoire, autorisee ou interdite ? [obligatoire] '
    read -r reponse_attr
    case "${reponse_attr}" in
        obligatoire|autorisee|interdite) ATTRIBUTION="${reponse_attr}" ;;
        *) ATTRIBUTION="obligatoire" ;;
    esac
fi
if [ -z "${LANGUE}" ] && [ -t 0 ]; then
    printf 'Langue du dépôt — fr, en ou fr-en ? [fr-en] '
    read -r reponse_langue
    case "${reponse_langue}" in
        fr|en|fr-en) LANGUE="${reponse_langue}" ;;
        *) LANGUE="fr-en" ;;
    esac
fi
if [ -z "${CYCLE}" ] && [ -t 0 ]; then
    printf 'Cycle de vie des issues — complet ([Spec]/[Orga] par consultation) ou reduit (questions ouvertes + ADR) ? [complet] '
    read -r reponse_cycle
    case "${reponse_cycle}" in
        complet|reduit) CYCLE="${reponse_cycle}" ;;
        *) CYCLE="complet" ;;
    esac
fi
# Défauts en l'absence de choix : déclaration obligatoire — diligence
# (ADR-0011) —, bilingue (ADR-0009) et cycle de vie complet (ADR-0013).
[ -n "${ATTRIBUTION}" ] || ATTRIBUTION="obligatoire"
[ -n "${LANGUE}" ] || LANGUE="fr-en"
[ -n "${CYCLE}" ] || CYCLE="complet"
if [ -z "${NOM}" ] || [ -z "${PORTEUR}" ]; then
    echo "ERREUR : --nom et --porteur sont requis." >&2
    exit 2
fi

# Garde 1 — ne pas ravager le dépôt de développement du gabarit lui-même.
origin="$(git remote get-url origin 2>/dev/null || true)"
case "${origin}" in
    *alm-forge*)
        if [ "${FORCE}" -ne 1 ]; then
            echo "ERREUR : l'origine git pointe vers alm-forge (le gabarit)." >&2
            echo "Ce script s'exécute dans un projet instancié. --force pour outrepasser." >&2
            exit 1
        fi ;;
esac

# Garde 2 — refuser de tourner deux fois : la présence de l'ADR fondateur du
# gabarit sert de marqueur « non encore initialisé ».
if [ ! -f docs/adr/0001-structurer-alm-forge-en-depot-gabarit.md ] && [ "${FORCE}" -ne 1 ]; then
    echo "ERREUR : dépôt déjà initialisé (ADR du gabarit absents). --force pour outrepasser." >&2
    exit 1
fi

if [ "${FORCE}" -ne 1 ]; then
    echo "Ce script va retirer la spécification et les ADR du gabarit, et"
    echo "réinitialiser README, CHANGELOG, VERSION, LICENSE et registres."
    printf 'Continuer ? [o/N] '
    read -r reponse
    case "${reponse}" in
        o|O|oui) ;;
        *) echo "Abandon." ; exit 1 ;;
    esac
fi

# remplacer <fichier> : le contenu de <fichier>.tmp remplace celui de
# <fichier>, qui garde ses droits. Un « mv » lui donnerait ceux du
# temporaire, sans droit d'exécution : le hook pre-commit d'un projet
# instancié refusait alors de s'exécuter (constaté le 2026-10-31, 43 scripts).
# La cible est tronquée puis réécrite, sans l'atomicité d'un « mv » : le
# script ne tourne qu'une fois, sur un dépôt neuf, et le gabarit ne contient
# aucun lien symbolique que la copie suivrait.
remplacer() {
    cat "$1.tmp" > "$1"
    rm -f "$1.tmp"
}

retirer_bloc() {
    # Supprime tout bloc — au sens des paragraphes séparés par une ligne vide
    # — qui cite le motif donné. Les façades d'orchestration déclarent une
    # cible par paragraphe : c'est la découpe qui leur convient, et elle ne
    # dépend d'aucun libellé, donc elle survit à une reformulation.
    _motif="$1"
    _fichier="$2"
    [ -f "${_fichier}" ] || return 0
    awk -v motif="${_motif}" '
        { bloc = bloc $0 "\n" }
        NF == 0 { if (index(bloc, motif) == 0) printf "%s", bloc; bloc = ""; next }
        END { if (index(bloc, motif) == 0) printf "%s", bloc }
    ' "${_fichier}" > "${_fichier}.tmp"
    remplacer "${_fichier}"
}

sed_inplace() {
    # sed -i n'est pas portable (BSD/macOS) : réécriture via fichier temporaire.
    _expr="$1"
    _file="$2"
    sed "${_expr}" "${_file}" > "${_file}.tmp"
    remplacer "${_file}"
}

annee="$(date +%Y)"

echo "1/13 — Retrait des tags de couverture du gabarit dans les documents conservés"
# L'outillage est balayé par MOTIF et non par énumération. La liste explicite
# qu'il y avait ici oubliait tout script ajouté au gabarit après elle : le tag
# survivait alors dans le dépôt produit, y devenait un item orphelin, et la
# traçabilité du projet naissait rouge sans que son porteur puisse deviner
# pourquoi. Constaté à l'ajout de tools/ci-test.sh.
# Les mentions « Exigence servie : req~… » (req~rattachement-code-exigence~1)
# suivent le même sort, matériel prêt à copier compris : elles citeraient des
# exigences que l'étape 4 retire.
for f in AGENTS.md docs/methode/*.md docs/adr/README.md \
         examples/demo-multi-langages/README.md \
         docs/verification-manuelle/*.md \
         tools/*.sh tools/*.ps1 tools/hooks/*.sh tools/bootstrap.d/*.sh \
         templates/bootstrap.d/*.sh templates/bootstrap.d/*/*.sh \
         templates/bootstrap.d/*/*.mjs templates/forge/tools/*.sh \
         .github/workflows/*.yml .gitlab-ci.yml \
         .github/ISSUE_TEMPLATE/*.yml .gitlab/issue_templates/*.md; do
    [ -f "${f}" ] || continue
    # Ce script et son test sont retirés à l'étape 12/13. Celui-ci surtout ne
    # se réécrit pas : le shell le lit au fil de l'exécution, et le remplacer
    # sur place décalerait la lecture au milieu d'une ligne.
    case "${f}" in tools/init.sh|tools/init-test.sh) continue ;; esac
    sed -e '/^<!-- \[impl->/d' -e '/^<!-- \[utest->/d' \
        -e '/^# \[impl->/d' -e '/^# \[utest->/d' \
        -e '/^# Exigence servie : req~/d' -e '/^\/\/ Exigence servie : req~/d' \
        "${f}" > "${f}.tmp"
    remplacer "${f}"
done

echo "2/13 — Politique de mention de l'IA dans les commits : ${ATTRIBUTION}"
# [impl->req~politique-attribution-agents~2]
if [ "${ATTRIBUTION}" != "obligatoire" ]; then
    # Le bloc livré par défaut (déclaration obligatoire) est retiré…
    sed '/politique-attribution:debut/,/politique-attribution:fin/d' \
        tools/hooks/commit-msg.sh > tools/hooks/commit-msg.sh.tmp
    remplacer tools/hooks/commit-msg.sh
    chmod +x tools/hooks/commit-msg.sh
fi
case "${ATTRIBUTION}" in
    autorisee)
        sed_inplace "s/^| R0 |.*/| R0 | Mentions d'agents dans les commits : autorisées, sans obligation (choix d'instanciation, cf. ADR-0011 du gabarit) — les autres règles restent entières | — |/" AGENTS.md
        ;;
    interdite)
        # … et remplacé par le contrôle d'interdiction.
        cat >> tools/hooks/commit-msg.sh <<'FINHOOK'

# R0 — attribution d'agents interdite (choix d'instanciation, cf. ADR-0011
# du gabarit).
if grep -Eiq 'co-authored-by|generated with|generated by|🤖|^IA: ' "${MSG_FILE}"; then
    echo "ERREUR : mention d'agent ou de co-auteur généré interdite dans les commits (R0)." >&2
    exit 1
fi
FINHOOK
        sed_inplace "s/^| R0 |.*/| R0 | Aucune mention d'agent, de co-auteur généré ou d'outil d'IA dans les commits (choix d'instanciation, cf. ADR-0011 du gabarit) | hook commit-msg, revue |/" AGENTS.md
# [impl->req~coherence-choix-instanciation~1]
        # La ligne R0 ne suffit pas : tout texte qui PRESCRIT un trailer doit
        # suivre le choix, sans quoi le dépôt produit naît avec un contrat
        # inapplicable — la boucle de travail réclamant « IA: » que le hook
        # refuse. Constaté sur un dépôt instancié avant d'être exigé.
        # Le backtick est échappé pour le SHELL (« \` ») dans le texte de
        # remplacement, jamais dans le motif : dans un motif, sed lit « \` »
        # comme l ancre de début de tampon et la substitution ne matche
        # jamais. Le motif se contente donc de « .* ».
        sed_inplace "s|^   la politique R0 (.*|   la politique R0 (\`Responsable:\`, \`Relu-par:\` le cas échéant). La politique\n   retenue ici interdit toute mention d'agent : le trailer \`IA:\` est refusé\n   par le hook.|" AGENTS.md
        if [ -f CONTRIBUTING.md ]; then
            sed_inplace "s|^  de mention de l'IA du projet (par défaut.*|  de mention de l'IA du projet — ici, aucune mention d'agent, de co-auteur|" CONTRIBUTING.md
            sed_inplace "s|^  responsable humain si IA — R0, ADR-0011).|  généré ni d'outil d'IA n'est admise (R0, ADR-0011 du gabarit).|" CONTRIBUTING.md
        fi
        ;;
esac

echo "3/13 — Langue du dépôt : ${LANGUE}"
# [impl->req~politique-langue~1]
if [ "${LANGUE}" != "fr-en" ]; then
    # Une seule langue : un seul jeu de modèles, plus de porte de parité.
    sed '/parite-templates:debut/,/parite-templates:fin/d' \
        tools/checks.sh > tools/checks.sh.tmp
    remplacer tools/checks.sh
    chmod +x tools/checks.sh
fi
case "${LANGUE}" in
    fr) rm -rf templates/en ; rm -f README.en.md ;;
    en) rm -rf templates/fr ; rm -f README.en.md ;;
esac
if [ "${LANGUE}" = "en" ]; then
    # La documentation lie les modèles par leur chemin (docs/adr/README.md,
    # méthode ch. 12 et 14…) : sans réécriture, ces liens meurent avec
    # templates/fr/ et la porte d'intégrité des liens refuse la vérification
    # finale. La parité des templates garantit les mêmes noms de fichiers.
    find docs -name '*.md' -exec sh -c '
        for f; do
            # Sous-shell, hors de portée de la fonction remplacer.
            sed "s|templates/fr/|templates/en/|g" "$f" > "$f.tmp" &&
                cat "$f.tmp" > "$f" && rm -f "$f.tmp"
        done' _ {} +
fi

# Le vocabulaire OUTILLÉ suit le même arbitrage que les artefacts générés
# (ADR-0015) : figer la langue ici, c'est décider ce que les portes
# reconnaîtront — « ACTIVE » et « conforme », ou « ACTIVE » et « compliant ».
# En « fr-en », les deux formes restent acceptées.
sed_inplace "s/^LEXIQUE_LANGUE=.*/LEXIQUE_LANGUE=\"\${LEXIQUE_LANGUE:-${LANGUE}}\"/" tools/lexique.sh

case "${LANGUE}" in
    fr)    modeles="templates/fr/" ;;
    en)    modeles="templates/en/" ;;
    fr-en) modeles="templates/fr/ (et templates/en/)" ;;
esac

echo "4/13 — Spécification du gabarit retirée, squelette prêt pour vos besoins"
rm -f spec/01-besoins/besoins.md
rm -f spec/02-exigences/*.md
if [ "${LANGUE}" = "en" ]; then
    cat > spec/README.md <<EOF
# ${NOM} specification

This directory follows the alm-forge template method (docs/methode/, in
French): needs (feat items) in 01-besoins/, EARS requirements (req items) in
02-exigences/, blockers in open-questions.md. Templates: templates/en/.
EOF
    cat > spec/02-exigences/README.md <<EOF
# ${NOM} requirements

One Markdown file per functional domain, requirements following
templates/en/requirement.md (EARS, SHALL/SHOULD/MAY, acceptance criteria,
Covers towards the need, Needs towards the expected coverage).
EOF
    cat > spec/open-questions.md <<'EOF'
# Open questions

Register of blockers awaiting human arbitration. Protocol:
docs/methode/06-questions-ouvertes.md — template: templates/en/open-question.md.

---

No open question to date.
EOF
else
    cat > spec/README.md <<EOF
# Spécification de ${NOM}

Ce répertoire suit la méthode du gabarit alm-forge (voir docs/methode/) :
besoins (items feat) dans 01-besoins/, exigences EARS (items req) dans
02-exigences/, blocages dans open-questions.md. Modèles : ${modeles}.
EOF
    cat > spec/02-exigences/README.md <<EOF
# Exigences de ${NOM}

Un fichier Markdown par domaine fonctionnel, exigences au format du modèle
templates/fr/requirement.md (EARS, DOIT/DEVRAIT/PEUT, critères d'acceptation,
Covers vers le besoin, Needs vers la couverture attendue).
EOF
    cat > spec/open-questions.md <<'EOF'
# Questions ouvertes

Registre des blocages en attente d'arbitrage humain. Protocole :
docs/methode/06-questions-ouvertes.md — modèle : templates/fr/open-question.md.

---

Aucune question ouverte à ce jour.
EOF
fi

echo "5/13 — ADR du gabarit retirés, registre prêt pour votre ADR-0001"
rm -f docs/adr/0*.md
sed -n '1,/^## Index/p' docs/adr/README.md > docs/adr/README.md.tmp
cat >> docs/adr/README.md.tmp <<EOF

| ADR | Titre | Statut |
| --- | --- | --- |

Aucun ADR à ce jour. Les décisions fondatrices du gabarit alm-forge restent
consultables dans son dépôt d'origine.
EOF
remplacer docs/adr/README.md
# La documentation de méthode cite ces ADR fondateurs par lien relatif ; les
# cibles viennent d'être retirées, et la porte d'intégrité des liens ferait
# échouer la vérification finale. On honore la promesse ci-dessus (« restent
# consultables dans son dépôt d'origine ») : chaque lien relatif vers un ADR
# du gabarit devient une URL absolue vers alm-forge — classée externe par
# tools/liens.sh dans le projet instancié, donc hors de son périmètre.
for f in docs/methode/*.md; do
    [ -f "${f}" ] || continue
    sed 's|](\.\./adr/0|](https://github.com/eric-lemesre/alm-forge/blob/main/docs/adr/0|g' \
        "${f}" > "${f}.tmp" && remplacer "${f}"
done

echo "6/13 — Registre des décisions réinitialisé"
# Les relevés archivés du gabarit partent avec son registre : un relevé qui
# cite des décisions absentes du registre réinitialisé ferait échouer la
# porte des relevés (même logique que pour les fiches de revue et d'audit).
find docs/decisions -name '*.md' ! -name 'registre.md' -exec rm -f {} +
if [ "${LANGUE}" = "en" ]; then
    cat > docs/decisions/registre.md <<'EOF'
# Decision register

Chronological register of durable decisions enacted outside pull requests.
Identifier: D-YYYY-MM-NN; each entry links to the ADR or meeting record that
elaborates it (template: templates/en/decision-record.md, records archived
here).

| ID | Date | Decision | Elaborated in |
| --- | --- | --- | --- |

No decision recorded to date.
EOF
else
    cat > docs/decisions/registre.md <<'EOF'
# Registre des décisions

Registre chronologique des décisions durables actées hors pull request.
Identifiant : D-AAAA-MM-NN ; chaque entrée renvoie vers l'ADR ou le relevé qui
la développe (modèle : templates/fr/decision-record.md, relevés archivés ici).

| ID | Date | Décision | Développée dans |
| --- | --- | --- | --- |

Aucune décision enregistrée à ce jour.
EOF
fi

echo "7/13 — Arbitrage du cycle de vie des issues : ${CYCLE}"
# [impl->req~issues-flux-avancement~2]
# L'arbitrage s'applique (formulaires) puis se consigne au registre du projet
# (ADR-0013) — y compris quand c'est le défaut : un arbitrage non consigné
# n'existe pas. Étiquettes et automatismes de forge restent documentaires
# (méthode, ch. 11).
if [ "${CYCLE}" = "reduit" ]; then
    # Porteur solo : les flux de consultation [Spec]/[Orga] sont remplacés
    # par les questions ouvertes (méthode, ch. 6) et les ADR.
    rm -f .github/ISSUE_TEMPLATE/proposition-exigence.yml \
          .github/ISSUE_TEMPLATE/proposition-organisation.yml
fi
if [ "${LANGUE}" = "en" ]; then
    if [ "${CYCLE}" = "reduit" ]; then
        decision_cycle="Issue lifecycle: reduced circuit — [Spec]/[Orga] consultation flows replaced by open questions and ADRs"
    else
        decision_cycle="Issue lifecycle: template default adopted (full [Spec]/[Orga] consultation circuit)"
    fi
    ref_cycle="alm-forge template ADR-0013"
else
    if [ "${CYCLE}" = "reduit" ]; then
        decision_cycle="Cycle de vie des issues : circuit réduit — flux de consultation [Spec]/[Orga] remplacés par questions ouvertes et ADR"
    else
        decision_cycle="Cycle de vie des issues : défaut du gabarit adopté (circuit de consultation [Spec]/[Orga] complet)"
    fi
    ref_cycle="ADR-0013 du gabarit alm-forge"
fi
awk -v row="| D-$(date +%Y-%m)-01 | $(date +%Y-%m-%d) | ${decision_cycle} | ${ref_cycle} |" '
    /Aucune décision enregistrée à ce jour\./ { next }
    /No decision recorded to date\./ { next }
    { print }
    $0 == "| --- | --- | --- | --- |" { print row }
' docs/decisions/registre.md > docs/decisions/registre.md.tmp
remplacer docs/decisions/registre.md

echo "8/13 — CHANGELOG et VERSION réinitialisés"
if [ "${LANGUE}" = "en" ]; then
    cat > CHANGELOG.md <<EOF
# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) —
versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] - $(date +%Y-%m-%d)

### Added

- Instantiation of ${NOM} from the alm-forge template.
EOF
else
    cat > CHANGELOG.md <<EOF
# Journal des changements

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versionnement : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

## [0.1.0] - $(date +%Y-%m-%d)

### Ajouté

- Instanciation de ${NOM} depuis le gabarit alm-forge.
EOF
fi
printf '0.1.0\n' > VERSION

echo "9/13 — LICENSE au nom du porteur"
sed_inplace "s/^Copyright (c) .*/Copyright (c) ${annee} ${PORTEUR}/" LICENSE

echo "10/13 — README réécrits pour ${NOM}"
if [ "${LANGUE}" = "en" ]; then
    cat > README.md <<EOF
# ${NOM}

Project instantiated from the [alm-forge](https://github.com/eric-lemesre/alm-forge)
ALM template: traced requirements from need to mechanized tests, decisions as
ADRs, quality gates enforced locally and in CI. Note: the template's
normative method documentation (docs/methode/) is currently in French.

- Method: docs/methode/ — working contract: AGENTS.md
- Commands: \`task ci\` (or \`sh tools/oft.sh trace && sh tools/checks.sh\`)
- Getting started: \`task setup\`, then write the first need
  (spec/01-besoins/, template templates/en/need.md) and your ADR-0001

Owner: ${PORTEUR}. Licence: [MIT](LICENSE).
EOF
else
    cat > README.md <<EOF
# ${NOM}

Projet instancié depuis le gabarit [alm-forge](https://github.com/eric-lemesre/alm-forge) :
exigences tracées du besoin aux tests, décisions en ADR, portes vérifiées en
local et en CI.

- Méthode : docs/methode/ — contrat de travail : AGENTS.md
- Commandes : \`task ci\` (ou \`sh tools/oft.sh trace && sh tools/checks.sh\`)
- Démarrage : \`task setup\` puis écrire le premier besoin (spec/01-besoins/)
  et l'ADR-0001 (templates/fr/adr.md)

Porteur : ${PORTEUR}. Licence : [MIT](LICENSE).
EOF
    if [ "${LANGUE}" = "fr-en" ]; then
        cat > README.en.md <<EOF
# ${NOM}

Project instantiated from the [alm-forge](https://github.com/eric-lemesre/alm-forge)
ALM template: traced requirements from need to mechanized tests, ADRs,
quality gates enforced locally and in CI. See README.md (French) and
docs/methode/.
EOF
    fi
fi

echo "11/13 — Artefacts documentaires réinitialisés"
# Fiches du gabarit retirées, artefacts DÉRIVÉS régénérés puis indexés. Les
# indexer est nécessaire : la porte anti-dérive compare le résultat de la
# régénération à l'index, et un artefact hérité du gabarit y ferait échouer
# la première vérification du projet.
# Fiches du gabarit : feuille de route, audit ET revues de code. Une revue
# porte sur un diff qui n'existe pas dans le projet instancié ; la garder lui
# ferait hériter de constats qui ne le concernent pas.
rm -f docs/todo/todo-*.md docs/audit/*.md docs/revues/SUIVI.md
find docs/revues -name '*.md' ! -name 'README.md' ! -name 'SUIVI.md' -exec rm -f {} +
# [impl->req~coherence-choix-instanciation~1]
# Relevés de décision du gabarit : même raison, et une conséquence mesurable.
# Le registre est réécrit plus haut sans les décisions du gabarit ; un relevé
# qui les cite reste alors dans le dépôt en renvoyant vers des décisions
# absentes, et « tools/releves.sh » échoue dès la première vérification du
# projet produit.
find docs/decisions -name '*.md' ! -name 'README.md' ! -name 'registre.md' -exec rm -f {} +
# Les procédures de vérification manuelle du gabarit couvrent des exigences
# qui viennent d'être retirées : les garder laisserait des items orphelins.
# Le README du répertoire, lui, explique le dispositif et reste.
find docs/verification-manuelle -name '*.md' ! -name 'README.md' -exec rm -f {} +
# templates/forge/ est CONSERVÉ : c'est du matériel post-instanciation, au
# même titre que templates/orchestrators/ et templates/bootstrap.d/. Le
# supprimer priverait le projet instancié de ce que req~automatismes-forge~1
# promet de lui fournir — il devrait aller le rechercher dans le gabarit
# (constat de revue n° 5).
# Les générateurs découvrent leurs fiches par « git ls-files », qui interroge
# l'INDEX : les suppressions ci-dessus (et celles des étapes précédentes —
# spécification, ADR) doivent y être enregistrées d'abord, sinon awk tente de
# lire des fichiers disparus de l'arbre de travail et l'instanciation échoue
# (cas constaté : todo-0001 du gabarit, awk fatal dans un vrai clone).
git add -A >/dev/null 2>&1 || true
sh tools/todo.sh --ecrire       >/dev/null
sh tools/revues.sh --ecrire     >/dev/null
sh tools/audit.sh --ecrire      >/dev/null
sh tools/badges.sh --ecrire     >/dev/null
# Sans objet tant qu'aucun domaine n'existe (spec/02-exigences/*.md retirés à
# l'étape 4/13) : appelé quand même, par la même rigueur que les générateurs
# ci-dessus — le jour où un domaine survivrait à l'instanciation, sa colonne
# Avancement doit être à jour dès cette étape, pas découverte en dérive à la
# vérification finale.
sh tools/avancement.sh --ecrire >/dev/null
git add docs/todo docs/audit docs/revues docs/badges spec/02-exigences >/dev/null 2>&1 || true
# docs/tracabilite/matrice.md n'est PAS régénéré ici : il balaie tout
# l'outillage par fichier:ligne, y compris tools/init.sh et tools/init-test.sh
# que l'étape suivante retire. Le régénérer maintenant le figerait avec des
# références à des fichiers sur le point de disparaître — dérive détectée dès
# la vérification finale. Sa régénération est donc reportée après le retrait
# (étape 13/13).

echo "12/13 — Retrait de l'outillage d'instanciation, devenu sans objet"
# L'instanciation a lieu une fois. Ce qui la sert n'a plus d'objet ensuite, et
# le laisser coûte deux fois.
#
# D'abord le test : il rejoue ce script sur des copies du dépôt DEVENU projet,
# qui porte alors sa propre spécification et son propre code de réalisation.
# Ce script ne retire que les fichiers du gabarit — les exigences du projet
# survivent dans le dépôt produit, et les tags de couverture de son code y
# deviennent orphelins. La porte échoue donc pour une raison qui ne dit rien
# de la qualité du travail, et qui empire à mesure que le projet écrit du
# code.
#
# Ensuite ce script lui-même, qui est destructeur : « --force » efface la
# spécification, les ADR et le registre des décisions, et réécrit le journal
# des versions. Le laisser dans un dépôt vivant, documenté au contrat et
# exposé par une commande de la façade, sans aucun usage légitime, c'est
# garder une arme chargée dans un tiroir dont on a expliqué l'emplacement.
#
# Ce retrait était jusqu'ici PROPOSÉ en fin de message, comme une option,
# après cinq autres étapes. Une option qui doit être prise à chaque fois n'en
# est pas une.
# La ligne du test, dans la liste des tests joués en parallèle :
# « titre<TAB>commande ».
sed_inplace '/^test — instanciation	sh tools\/init-test\.sh$/d' tools/ci.sh
retirer_bloc 'tools/init.sh' Taskfile.yml
retirer_bloc 'tools/init.sh' templates/orchestrators/justfile
# Contrat de dépôt : la SEULE ligne du tableau des commandes qui cite le
# script. Un retrait par paragraphe emporterait le tableau entier.
sed_inplace '/`sh tools\/init\.sh …`/d' AGENTS.md
sed_inplace 's/(`init`, `setup`/(`setup`/' templates/orchestrators/README.md
rm -f tools/init-test.sh
# Ce script s'efface en dernier. Le shell garde le fichier ouvert par son
# descripteur : le délier n'interrompt pas l'exécution en cours.
rm -f tools/init.sh
# Retirés de l'index aussi : la matrice se dresse depuis « git ls-files », et
# les y laisser la figeait avec deux fichiers absents — la porte anti-dérive
# refusait alors le premier commit du projet (constaté le 2026-10-31).
git rm -q --cached --ignore-unmatch tools/init.sh tools/init-test.sh >/dev/null 2>&1 || true

# [impl->req~rattachement-code-exigence~1]
# Code hérité du gabarit : ses traces sont retirées (étape 1) et ses
# exigences avec la spécification (étape 4) ; il ne peut plus se rattacher à
# rien dans le projet. La liste en est dressée ICI, une fois l'outillage
# d'instanciation retiré, par la porte elle-même : un fichier que le projet
# ajoutera ensuite n'y figurera pas, et devra se rattacher à ses exigences.
if [ "${LANGUE}" = "en" ]; then
    entete_herites="# Code inherited from the alm-forge template, without a requirement of
# this project: listed by the instantiation, one path per line. Remove a
# line once the file is deleted or carries its own trace —
# tools/rattachement.sh enforces it."
else
    entete_herites="# Code hérité du gabarit alm-forge, sans exigence de ce projet : liste
# dressée par l'instanciation, un chemin par ligne. Retirer une ligne dès que
# le fichier disparaît ou porte sa propre trace — tools/rattachement.sh
# l'impose."
fi
{
    printf '%s\n' "${entete_herites}"
    sh tools/rattachement.sh --liste
} > tools/rattachement-herites.txt
git add tools/rattachement-herites.txt >/dev/null 2>&1 || true

# Régénérée ICI, une fois l'outillage d'instanciation retiré : la matrice
# balaie tout tools/ par fichier:ligne, et tools/init.sh en portait des tags
# (Cf. étape 11/13). La régénérer avant ce retrait l'aurait figée avec des
# références à des fichiers qui viennent de disparaître.
sh tools/matrice.sh >/dev/null
git add docs/tracabilite >/dev/null 2>&1 || true

echo "13/13 — Vérification finale (traçabilité + cohérence)"
# Environnement assaini (défense en profondeur, en plus de la primauté de
# l'argument dans ci.sh) : un CI_COMPLET hérité de la CI appelante ne doit
# jamais transformer cette vérification documentaire en voie complète.
CI_COMPLET=0 sh tools/ci.sh --rapide

cat <<EOF

Instanciation de ${NOM} terminée (langue : ${LANGUE}, attribution d'agents :
${ATTRIBUTION}, cycle de vie des issues : ${CYCLE}). Prochaines étapes :
  1. task setup               — accueil du poste (bootstrap, hooks, portes)
  2. Écrire le premier besoin — spec/01-besoins/ (modèle need.md)
  3. Écrire votre ADR-0001    — task adr-new -- votre-premiere-decision
  4. Choisir la façade        — garder Taskfile.yml, ou templates/orchestrators/
  5. Choisir la ou les forges — supprimer .github/ ou .gitlab*/ selon l'hébergeur
  6. Premier commit           — les hooks vérifient tout
L'outillage d'instanciation s'est retiré : tools/init.sh, tools/init-test.sh
et leurs références dans les façades et le contrat ont disparu. Cette
instanciation ne se rejoue pas.
EOF
