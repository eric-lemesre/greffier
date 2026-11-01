# 13. Statuts : deux axes, deux questions

<!-- [impl->req~statut-specification~1] -->

Un statut n'est pas une décoration : il commande le dénominateur des taux
d'audit (ch. 14) et de classification (ch. 2). Le dépôt en porte **deux**, et
les confondre est la première erreur à éviter.

| Axe | Objet | Question |
| --- | --- | --- |
| Statut de **domaine** | le fichier de spécification | ce document est-il **arbitré** ? |
| Statut d'**exigence** | une exigence donnée | où en est **sa réalisation** ? |

Ce ne sont pas deux systèmes d'état concurrents sur un même objet — ce que le
chapitre 11 proscrit — mais deux objets distincts. Un domaine actif contient
des exigences approuvées mais non réalisées et d'autres livrées et prouvées :
les compter ensemble revient à ne plus rien pouvoir dire de l'avancement
(décision : [ADR-0018](../adr/0018-statut-de-cycle-de-vie-porte-par-l-exigence.md)).

## Axe 1 — le domaine

| Statut | Ce qu'il dit |
| --- | --- |
| `PROPOSITION` | rédigé, pas encore arbitré |
| `ACTIVE` | acté, opposable |
| `OBSOLÈTE` | remplacé ou abandonné, fichier conservé |

Déclaré en tête du fichier **et** dans
[`spec/02-exigences/README.md`](../../spec/02-exigences/README.md). Les deux
doivent dire la même chose : `tools/statuts.sh` refuse la divergence, et c'est
le contrôle qui compte le plus — l'index est ce qu'on lit, l'en-tête est ce qui
fait foi, et personne ne remarque qu'ils se contredisent.

**Passer un domaine en ACTIVE exige une décision** inscrite au registre
(ch. 3). Sans cette règle, un domaine passe actif d'un trait de plume : la
couverture affichée grimpe sans que personne n'ait rien validé.

## Axe 2 — l'exigence

Une ligne `**Statut : …**` sous l'identifiant. Le vocabulaire vient du lexique
(ADR-0015), et il se lit sur **deux parts** :

| Part | Statuts | Qui les pose |
| --- | --- | --- |
| **déclarée** | brouillon · proposée · approuvée · rejetée · dépréciée | un humain — c'est du jugement |
| **calculée** | implémentée · vérifiée | la porte, depuis la couverture réelle |

**Les statuts d'avancement ne se déclarent jamais.** La porte refuse qu'on les
écrive, et les recalcule à chaque exécution depuis les tags et les items de
couverture réellement présents. La raison est celle du chapitre 4 : un
avancement saisi se périme au premier remaniement sans rien signaler, et un
tableau qui affiche « vérifiée » pour une exigence que plus aucun test ne
couvre inspire d'autant plus confiance qu'il donne un chiffre.

Une exigence est dite :

- **implémentée** si un tag `impl` la cite ;
- **vérifiée** si, en plus, un test la couvre — tag `utest`/`itest`/`stest`, ou
  item `mtest` la déclarant en `Covers`. Une procédure de vérification manuelle
  couvre autant qu'un test automatisé : c'est le principe du chapitre 5.

## La règle qui empêche les deux axes de diverger

> Une exigence ne peut être **approuvée** que dans un domaine **actif**.

Mécanisée, pas recommandée. C'est elle qui interdit qu'un document en
proposition contienne des exigences opposables — et donc qu'un même objet
raconte deux histoires selon l'endroit où on le regarde.

## Le dénominateur

Seules les exigences **approuvées ou au-delà** entrent au dénominateur des
taux. Une exigence en brouillon n'a pas à être jugée sur sa réalisation :
l'auditer reviendrait à reprocher à un texte en cours d'écriture de n'être pas
encore livré.

## Cycle de vie

1. Rédaction → domaine `PROPOSITION`, exigences `brouillon` puis `proposée`.
   Elles existent, elles sont tracées, elles ne comptent pas encore.
2. Consultation puis arbitrage (ch. 11, flux `[Spec]`) → décision au registre →
   domaine `ACTIVE`, exigences `approuvée`. L'avancement, lui, se met à jour
   tout seul à mesure que les tags apparaissent.
3. Remplacement → exigence `dépréciée` avec un renvoi vers celle qui prend la
   suite ; domaine `OBSOLÈTE` s'il disparaît en entier. On ne supprime pas :
   les décisions passées restent lisibles.

Un domaine `PROPOSITION` qui dort depuis longtemps est un signal — soit
l'arbitrage est bloqué et relève d'une question ouverte (ch. 6), soit le
domaine n'intéresse personne et devrait être `OBSOLÈTE`.
