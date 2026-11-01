# Vérifications manuelles — coordination par les issues

Procédures de vérification **manuelle assumée** (items `mtest`, méthode
[ch. 5](../methode/05-tests-et-verification.md)) portant sur le cycle de vie
des issues. Elles ne sont pas mécanisées pour une raison de fond : l'état
d'une issue vit sur la forge, hors du dépôt, et une porte qui doit rester
exécutable hors ligne ne peut pas l'interroger.

Cadence par défaut : à la revue de triage périodique (méthode, ch. 11).

## L'état, l'attente et l'acte sont lisibles d'un coup d'œil

`mtest~etat-attente-acte~1`

**Geste** — prendre dix issues ouvertes au hasard. Pour chacune, répondre sans
lire les commentaires : dans quel état est-elle ? qui est attendu ?

**Critère** — l'étiquette donne l'état, l'assignation donne l'attendu. Une
issue portant deux étiquettes d'état, ou aucune, est un défaut. Une issue en
attente de quelqu'un sans assignation aussi. Vérifier ensuite que le dernier
acte (lecture, validation, refus) est tracé en commentaire daté : l'étiquette
dit où l'on en est, le commentaire dit ce qui s'est passé.

Covers:
- req~issues-etat-attente-acte~2

## Les trois flux se comportent comme décrits

`mtest~flux-avancement~1`

**Geste** — suivre une issue de chaque flux ([Spec], [Orga], réalisation) de
son ouverture à sa fin de vie, et confronter son parcours réel aux étapes du
chapitre 11.

**Critère** — les étapes franchies correspondent ; les entraves sont des
étiquettes cumulables et non des états ; toute fin de vie négative est motivée
et fermée en « non planifiée », jamais en « terminée ».

Covers:
- req~issues-flux-avancement~2

## La gravité se constate, la priorité se décide

`mtest~triage-priorites~1`

**Geste** — à la revue de triage, comparer la gravité déclarée par les
déclarants et la priorité décidée en séance. Compter les P1 ouvertes.

**Critère** — la gravité n'a pas été renégociée pour justifier une priorité ;
la priorité est motivée par un « quand », pas par une intensité ; la limite de
P1 est tenue — au-delà, plus rien n'est prioritaire.

Covers:
- req~issues-triage-priorites~2

## Le contrôle de conformité des issues fonctionne hors porte

`mtest~conformite-issues~1`

**Geste** — exécuter `sh tools/issues.sh` avec une session authentifiée sur la
forge, puis sans session.

**Critère** — avec session, le rapport liste les écarts au cycle de vie. Sans
session, le contrôle s'interrompt avec un message explicite et **ne fait pas
échouer** la porte : rien de ce qui exige un réseau n'entre dans une
vérification qui doit tourner sur un poste déconnecté.

Covers:
- req~conformite-issues~1

## Les automatismes de forge signalent sans décider

`mtest~automatismes-forge~1`

**Geste** — sur un projet ayant câblé le matériel de `templates/forge/`,
provoquer chaque automatisme sur son cas nominal **et** sur son cas d'échec :
commentaire de lecture sur une consultation, modification du document consulté,
liste de vérification complétée, issue dormante, sortie négative.

**Critère** — chaque automatisme dérive l'état depuis l'acte, jamais l'inverse.
Aucun ne ferme une issue à la place d'un humain ; la pose d'une étiquette de
clôture ne vaut pas clôture. Sur le gabarit lui-même, vérifier que ces
automatismes restent déclarés **non câblés** avec leur raison (R7).

Covers:
- req~automatismes-forge~1
