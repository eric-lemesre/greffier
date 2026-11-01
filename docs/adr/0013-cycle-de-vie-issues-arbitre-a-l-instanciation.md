# ADR-0013 — Rendre le cycle de vie des issues arbitrable à l'instanciation

**Statut** : Accepté
**Date** : 2026-08-09
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-11, registre
des décisions)
**Portée** : durable

## Item de conception

`dsn~cycle-issues-instanciation~1`

Le cycle de vie des issues (méthode, ch. 11) se décompose en deux couches :

- un **socle invariant**, qui ne dépend ni de l'équipe, ni du rythme, ni de la
  forge : l'étiquette dit l'état, l'assignation dit qui est attendu, le
  commentaire trace l'acte et fait seul foi ; rien de nominatif dans une
  étiquette ; aucune transition ni fin de vie sans motif écrit ;
- des **défauts arbitrables à l'instanciation** : flux d'arbitrage
  `[Spec]`/`[Orga]` (adoption, adaptation ou réduction), jeu d'étiquettes,
  décideurs par domaine, valeurs (délai de consultation, limite de P1,
  cadences), outillage des automatismes de forge.

L'arbitrage est **outillé** : l'option `--cycle-issues complet|reduit` de
`tools/init.sh` applique le choix — le circuit réduit retire les formulaires
de consultation `[Spec]`/`[Orga]`, remplacés par les questions ouvertes
(méthode, ch. 6) et les ADR — et le **consigne au registre des décisions du
projet**. Sans choix explicite, le défaut `complet` s'applique, et se
consigne aussi : un arbitrage non consigné n'existe pas.

Covers:
- req~issues-etat-attente-acte~2
- req~issues-flux-avancement~2
- req~issues-triage-priorites~2

## Contexte

La première rédaction du chapitre 11 gravait dans la méthode des choix qui
supposent une équipe, un rythme et une forge donnés : circuit de consultation
à plusieurs intervenants, jeu d'étiquettes complet, délais et cadences. Le
porteur relève que ces choix reviennent à l'instanciateur : un porteur solo
n'a personne à consulter, une équipe de trois en a besoin ; un dépôt sans
forge n'a ni étiquettes ni assignations. Le gabarit a déjà tranché deux cas
analogues par le même patron « défaut + arbitrage d'instanciation » :
la politique d'attribution IA (ADR-0011) et la langue du dépôt (ADR-0009).

## Décision

Distinguer explicitement les deux couches, dans les exigences comme dans le
chapitre. Le socle reste invariant parce qu'il fonde l'opposabilité des actes
— une trace signée, datée, motivée — quel que soit le contexte du projet ;
tout le reste est un défaut que l'instanciateur arbitre, l'arbitrage étant
lui-même une décision consignée. Comme pour l'attribution (ADR-0011) et la
langue (ADR-0009), l'arbitrage est outillé dans `tools/init.sh` (option
`--cycle-issues`) : le choix est appliqué mécaniquement et consigné au
registre du projet, y compris quand c'est le défaut qui s'applique. Ce que le
script ne peut pas atteindre (étiquettes de forge, automatismes) reste
documentaire.

## Alternatives écartées

### Tout graver dans la méthode (première rédaction)

Imposerait à un porteur solo un circuit de consultation sans consultés, et à
tout projet un jeu d'étiquettes dimensionné pour une équipe de trois — la
cause exacte des étiquettes mortes que le processus source (ergonomia, ~400
issues) documente.

### Tout rendre arbitrable, socle compris

La règle état/attente/acte est le pendant « issues » des règles R du contrat :
un projet qui l'abandonne perd l'opposabilité de ses actes de coordination.
Ce ne serait plus une adaptation du cycle de vie mais une autre méthode —
hors de ce que le gabarit promet.

### Arbitrage purement documentaire, sans option d'instanciation

Première rédaction de cet ADR : consigner l'arbitrage au registre sans
l'outiller, au motif que les artefacts vivent sur la forge. Écartée sur
décision du porteur (amendement du 2026-08-09, voir Références) : un
arbitrage que rien n'applique est une checklist manuelle — le travers exact
des portes documentées non câblées — et une partie des artefacts est bien
dans le dépôt (formulaires d'issues, registre). Seul ce qui est réellement
hors de portée du script (étiquettes, automatismes de forge) reste
documentaire.

## Conséquences

- Ce que cela apporte : un gabarit honnête sur ce qui relève de la méthode et
  ce qui relève du contexte ; un projet instancié qui sait ce qu'il peut
  adapter sans « casser » la méthode, et où consigner ce choix.
- Ce que cela coûte : les exigences passent en révision 2 et tous les sites
  tagués sont revisités — c'est le mécanisme voulu par le cycle de vie des
  exigences (méthode, ch. 2) ; une option d'instanciation de plus à
  maintenir, testée sur ses deux modes et son cas d'échec.
- Ce que cela ferme : rien — un projet peut durcir ses propres invariants par
  ADR local.

## Vérification

- `tools/init-test.sh` vérifie mécaniquement l'arbitrage : défaut →
  formulaires de consultation conservés et adoption du défaut consignée au
  registre du projet ; `reduit` → formulaires `[Spec]`/`[Orga]` retirés et
  réduction consignée ; valeur invalide refusée ; portes vertes dans chaque
  variante.
- La propagation des révisions est mécanique : `tools/oft.sh trace` échoue si
  un site tagué pointe une révision périmée des exigences couvertes.
- Le chapitre 11 sépare explicitement socle et défauts ; la revue vérifie que
  tout écart ultérieur au défaut est consigné au registre des décisions du
  projet instancié. Aucune porte mécanique côté forge — non câblée (R7) : la
  coordination vit hors du dépôt ; échéance : rouvrir si l'expérience
  d'instanciation montre des dérives répétées.

## Références

- Amendement du 2026-08-09, pendant la conception du gabarit : l'arbitrage,
  initialement documentaire, est outillé dans `init.sh` sur décision du
  porteur. L'immuabilité des ADR (R6) protège la vie d'un dépôt ; elle ne
  fige pas la conception du gabarit tant qu'aucun projet n'est instancié.
- Registre des décisions : D-2026-08-11.
- Exigences : `spec/02-exigences/coordination-issues.md` (révision 2).
- Méthode : chapitre 11 (cycle de vie des issues).
- Patron suivi : [ADR-0009](0009-langue-du-depot-arbitree-a-l-instanciation.md),
  [ADR-0011](0011-declaration-ia-obligatoire-par-defaut.md).
