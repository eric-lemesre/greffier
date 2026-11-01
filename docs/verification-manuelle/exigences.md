# Vérifications manuelles — ingénierie des exigences

Procédures de vérification **manuelle assumée** (items `mtest`, méthode
[ch. 5](../methode/05-tests-et-verification.md)) portant sur la qualité de
rédaction et le cycle de vie des exigences. Une porte sait vérifier qu'un
niveau normatif est présent ; elle ne sait pas dire s'il est juste.

Cadence par défaut : à chaque version **mineure**, et à toute rédaction ou
révision d'un besoin.

## Le besoin capture l'intention, pas la solution

`mtest~besoin-capture-intention~1`

**Geste** — relire chaque besoin (`spec/01-besoins/`) et chercher, dans son
énoncé, une décision de conception déguisée : un nom d'outil, une structure de
données, un choix d'interface.

**Critère** — le besoin dit ce qu'il faut obtenir et pourquoi ; le comment vit
dans une exigence ou un ADR. Vérifier aussi que le rationale explique le
problème vécu — un besoin sans motif ne survit pas à son auteur.

Covers:
- req~expression-du-besoin~1

## La rédaction EARS est sans ambiguïté

`mtest~redaction-ears~1`

**Geste** — pour un échantillon d'exigences, vérifier que l'énoncé suit un
patron EARS reconnaissable (ubiquitaire, événementiel, état, option,
indésirable), qu'il ne contient qu'une seule obligation, et que ses critères
d'acceptation sont observables — pas « le système doit être performant », mais
un fait constatable.

**Critère** — chaque exigence est réfutable : on peut décrire ce qui prouverait
qu'elle n'est pas tenue. La porte de classification vérifie la présence d'un
niveau normatif dans l'énoncé ; elle ne peut pas juger de la clarté.

Covers:
- req~format-exigence-ears~1

## Le cycle de vie d'une exigence est respecté

`mtest~cycle-de-vie-exigence~2`

**Geste** — prendre les exigences dont la révision a été incrémentée depuis la
version précédente et vérifier que chaque incrément était nécessaire (le sens
a changé, pas seulement la formulation) et que les sites tagués ont suivi.

**Critère** — pas de révision cosmétique, pas de tag laissé sur une révision
morte. Une exigence remplacée renvoie vers celle qui la remplace.

Covers:
- req~cycle-de-vie-exigence~2

## Les questions ouvertes sont vivantes

`mtest~questions-ouvertes-vivantes~1`

**Geste** — parcourir `spec/open-questions.md` : chaque question porte-t-elle
ses options, sa recommandation et son décideur ? Les questions résolues
renvoient-elles vers la décision qui les a tranchées ? Une question sans
mouvement depuis plusieurs semaines a-t-elle une raison de dormir ?

**Critère** — aucune question ouverte sans option par défaut : sans elle, la
séance produit « à revoir » au lieu d'une décision. Aucune question résolue
réécrite : l'addendum daté est la seule voie.

Covers:
- req~questions-ouvertes~1
