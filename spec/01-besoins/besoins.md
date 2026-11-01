# Expression des besoins — alm-forge

Besoins exprimés par le porteur du projet (Éric Lemesre, 2026-08-08) : disposer
d'un dépôt-gabarit qui outille l'ALM de bout en bout, réutilisable pour tout
nouveau projet quel que soit le langage et quel que soit l'agent (humain ou IA)
qui y travaille. Synthèse des pratiques éprouvées sur les dépôts ergonomia et
wallos-rs et des référentiels du domaine (MADR, EARS, OpenFastTrace,
Keep a Changelog, Conventional Commits).

## Tracer et protéger les décisions

`feat~cadre-de-decision~1`

Toute décision structurante (architecture, méthode, outillage) DOIT laisser une
trace écrite, datée, motivée, avec ses alternatives écartées et un moyen de
vérifier qu'elle est tenue. Une décision actée ne se réécrit pas : elle se
remplace.

Rationale:
Sur un projet où interviennent plusieurs personnes et plusieurs agents, la
décision non écrite est réinventée, contredite ou silencieusement contournée.

Needs: req

## Ingénierie des exigences de bout en bout

`feat~ingenierie-des-exigences~1`

Le cheminement complet DOIT être matérialisé dans le dépôt : expression de
besoin → exigences rédigées sans ambiguïté → conception → implémentation →
tests mécanisés. Chaque maillon est identifiable et reliable au précédent.

Rationale:
C'est le cœur de la demande : savoir à tout instant pourquoi une ligne de code
existe et comment on prouve qu'elle répond au besoin exprimé — ou à l'intention
du besoin quand celui-ci est incomplet.

Needs: req

## Traçabilité mécanisée, jamais déclarative

`feat~tracabilite-mecanisee~1`

La couverture besoin→exigence→code→test DOIT être vérifiée par un outil qui
échoue quand elle est incomplète, en local comme en intégration continue. Une
matrice tenue à la main ou une porte documentée mais non câblée sont réputées
inexistantes.

Rationale:
Leçon des dépôts de référence : un contrôle qui passe toujours est pire que pas
de contrôle, et une porte déclarée mais non exécutée crée une fausse confiance.

Needs: req

## Coordination du travail par les issues

`feat~coordination-issues~1`

Le parcours d'une issue — de son ouverture à sa fin de vie — DOIT être défini
pour les trois flux observés sur un dépôt vivant : arbitrage d'une
spécification, arbitrage d'un document d'organisation, réalisation d'une
demande ou correction d'une anomalie. L'état du travail se lit d'un coup
d'œil ; chaque acte (lecture, validation, décision, refus) laisse une trace
signée, datée et opposable dans le dépôt ou sur l'issue.

Rationale:
Besoin exprimé le 2026-08-09, à partir du processus éprouvé sur ergonomia
(docs/00-organisation) : sans cycle de vie explicite, les issues restent dans
des états faux (demande ventilée en exigences toujours « à discuter »), les
étiquettes prolifèrent sans servir, et la trace des arbitrages se perd hors du
dépôt.

Needs: req

## Gouvernance agnostique du langage et de l'agent

`feat~gouvernance-agnostique~1`

Les règles du dépôt DOIVENT s'appliquer indépendamment du langage de
programmation du projet instancié et indépendamment de l'agent qui produit le
travail (développeur humain, Claude, Copilot, Cursor ou autre). Un contrat
unique fait autorité ; les agents s'y raccordent par adaptateurs.

Rationale:
Le gabarit sera instancié sur des projets Rust, Python, TypeScript ou mixtes,
travaillés par des agents différents : aucune règle ne doit dépendre d'un
outil de génération particulier.

Needs: req

## Documentation soumise au même régime que le code

`feat~documentation-verifiee~1`

Sur un projet dont les décisions, les exigences et la méthode vivent dans le
dépôt, la documentation DOIT être vérifiée par des contrôles qui échouent :
liens qui atteignent leur cible, index dérivés de leur source, tableaux de
bord régénérés, badges sans dépendance externe.

Rationale:
Besoin exprimé le 2026-08-20 après l'inventaire comparé avec ergonomia. Un
lien mort, un index périmé ou un statut qui ment ne cassent aucun test : ils
égarent un lecteur, et lui font croire qu'une fonctionnalité ou une décision
existe. Sur un dépôt où la documentation EST une partie du produit, c'est un
défaut de premier ordre.

Needs: req
