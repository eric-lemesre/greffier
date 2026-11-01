# ADR-0009 — Rendre la langue du dépôt arbitrable à l'instanciation

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-07, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~politique-langue~1`

La langue du dépôt instancié (fr, en ou fr-en) est un paramètre du script
d'instanciation (`--langue`, défaut fr-en). Le choix gouverne : la langue des
artefacts générés (README, squelettes de spec, registres, CHANGELOG), le jeu
de modèles conservé (`templates/fr/`, `templates/en/` ou les deux), et la
porte de parité des templates — retirée (bloc à marqueurs dans
`tools/checks.sh`) quand une seule langue est conservée.

Covers:
- req~politique-langue~1

## Contexte

L'ADR-0005 a fixé la politique linguistique **du gabarit** : normatif en
français, modèles bilingues. Un projet instancié a ses propres contraintes
(équipe monolingue, projet international) : imposer le bilinguisme des modèles
— et sa porte de parité — à un projet francophone pur est du bruit ; imposer
des artefacts français à un projet anglophone est un obstacle.

## Décision

Le choix appartient à l'instanciateur. Limitation assumée et affichée par le
script : la documentation normative du gabarit (méthode, AGENTS.md, charte
ADR) n'existe aujourd'hui qu'en français — le choix « en » produit des
artefacts et modèles anglais mais hérite d'une méthode en français, à traduire
par le projet s'il le souhaite. L'ADR-0005 reste en vigueur pour le gabarit
lui-même.

## Alternatives écartées

### Traduire tout le normatif en anglais dans le gabarit

Double la surface à maintenir synchronisée (rejeté par l'ADR-0005 pour cette
raison) ; pourra devenir un chantier propre si un besoin réel émerge.

### Laisser le nettoyage linguistique à la main

C'est la garantie d'un dépôt incohérent : porte de parité cassée après
suppression manuelle d'un jeu de modèles, README bilingue orphelin.

## Conséquences

- Ce que cela apporte : un dépôt instancié cohérent avec sa langue de travail,
  sans porte morte ni fichier orphelin.
- Ce que cela coûte : trois variantes d'artefacts générés à maintenir dans
  init.sh ; le périmètre de traçabilité filtre désormais les chemins absents
  (un projet « fr » n'a plus de README.en.md).
- Ce que cela ferme : rien — un projet peut évoluer (ajouter une langue) par
  sa propre décision.

## Vérification

`tools/init-test.sh` vérifie mécaniquement les trois branches : « fr » (plus
de templates/en ni de README.en.md, portes vertes sans parité), « en »
(README anglais, plus de templates/fr, portes vertes), défaut « fr-en »
(bilinguisme et parité conservés).

## Références

- Registre des décisions : D-2026-08-07.
- Exigence : req~politique-langue~1 (`spec/02-exigences/gouvernance.md`).
- ADR-0005 (politique linguistique du gabarit, inchangée).
