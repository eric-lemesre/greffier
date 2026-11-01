# Registre des décisions

Registre chronologique des décisions durables actées hors pull request (séance
ou consultation directe du décideur). Identifiant : D-AAAA-MM-NN. Chaque entrée
renvoie vers l'artefact qui la développe (ADR, relevé de séance). Les relevés
de séance sont archivés dans ce répertoire (modèle :
`templates/fr/decision-record.md`) et figés une fois actés.

| ID | Date | Décision | Développée dans |
| --- | --- | --- | --- |
| D-2026-08-01 | 2026-08-08 | alm-forge est un dépôt-gabarit instanciable (ni référentiel documentaire pur, ni framework publié) | [ADR-0001](../adr/0001-structurer-alm-forge-en-depot-gabarit.md) |
| D-2026-08-02 | 2026-08-08 | OpenFastTrace est le moteur de traçabilité | [ADR-0002](../adr/0002-tracer-les-exigences-avec-openfasttrace.md) |
| D-2026-08-03 | 2026-08-08 | Documentation normative en français, templates bilingues fr/en | [ADR-0005](../adr/0005-documentation-normative-francaise-templates-bilingues.md) |
| D-2026-08-04 | 2026-08-08 | Le dépôt est créé sous le nom alm-forge | — (décision d'intendance, pas d'ADR) |
| D-2026-08-05 | 2026-08-08 | Portes en scripts POSIX autonomes, orchestrateur en façade interchangeable (Task par défaut) | [ADR-0007](../adr/0007-orchestrateur-en-facade-interchangeable.md) |
| D-2026-08-06 | 2026-08-08 | L'attribution des agents dans les commits est à la discrétion de l'instanciateur (interdite par défaut) | [ADR-0008](../adr/0008-attribution-agents-arbitree-a-l-instanciation.md) |
| D-2026-08-07 | 2026-08-08 | La langue du dépôt (fr, en, fr-en) est à la discrétion de l'instanciateur (fr-en par défaut) | [ADR-0009](../adr/0009-langue-du-depot-arbitree-a-l-instanciation.md) |
| D-2026-08-08 | 2026-08-08 | Le gabarit fonctionne sur toute forge git : portes locales, CI en façades par forge (GitHub, GitLab fournies) | [ADR-0010](../adr/0010-ci-en-facades-par-forge.md) |
| D-2026-08-09 | 2026-08-08 | Défaut de la politique IA : déclaration obligatoire par commit, responsable humain, relecture recommandée (diligence) — remplace le défaut d'interdiction | [ADR-0011](../adr/0011-declaration-ia-obligatoire-par-defaut.md) |
| D-2026-08-10 | 2026-08-08 | Apports DevSecOps retenus : durcissement CI, porte anti-secrets gitleaks, chapitre sécurité continue (postmortem écarté) | [ADR-0012](../adr/0012-detecter-les-secrets-avec-gitleaks.md) |
| D-2026-08-11 | 2026-08-09 | Le cycle de vie des issues est un défaut du gabarit arbitrable à l'instanciation (option `--cycle-issues` d'init.sh, arbitrage consigné au registre du projet) ; seul le socle état/attente/acte est invariant | [ADR-0013](../adr/0013-cycle-de-vie-issues-arbitre-a-l-instanciation.md) |
| D-2026-08-12 | 2026-08-11 | Le bootstrap devient consenti (annonce → accord → vérifie → installe), modulaire (un module par outil dans `tools/bootstrap.d/`) et auto-installant pour son prérequis git — mécanique éprouvée sur un projet instancié | [ADR-0014](../adr/0014-bootstrap-consenti-et-modulaire.md) |
| D-2026-08-13 | 2026-08-20 | Le vocabulaire OUTILLÉ (statuts, verdicts, étiquettes, commandes) est bilingue et figé à l'instanciation, dans un lexique unique dont les portes sont clientes | [ADR-0015](../adr/0015-lexique-du-vocabulaire-outille.md) |
| D-2026-08-14 | 2026-08-20 | L'audit de réalisation est une porte distincte de la traçabilité : le générateur compte, l'humain juge | [ADR-0016](../adr/0016-audit-de-realisation-distinct-de-la-tracabilite.md) |
| D-2026-08-15 | 2026-08-20 | Le périmètre de la porte est constaté sur le changement réel, jamais déclaré ; le doute impose la voie complète | [ADR-0017](../adr/0017-perimetre-de-la-porte-constate.md) |
| D-2026-08-16 | 2026-08-20 | Les domaines de spécification du gabarit passent ACTIVE : gouvernance, tracabilite, decisions, ingenierie-exigences, securite, coordination-issues, documentation | [relevé 2026-08-20](2026-08-20-transposition-alm.md) |
| D-2026-08-17 | 2026-08-20 | Écart d'audit tranché : le statut de cycle de vie est porté par l'EXIGENCE, déclaré jusqu'à « approuvée » et calculé au-delà ; le statut de domaine subsiste sur un axe orthogonal | [ADR-0018](../adr/0018-statut-de-cycle-de-vie-porte-par-l-exigence.md) |
| D-2026-10-01 | 2026-10-28 | Tout fichier de code suivi par git se rattache à une exigence existante — étiquette de couverture quand il la couvre, mention « Exigence servie » quand il la sert sans la couvrir ; porte bloquante, code hérité du gabarit déclaré par l'instanciation (demande du porteur, règle éprouvée dans un projet aval) | [`req~rattachement-code-exigence~1`](../../spec/02-exigences/tracabilite.md) |
