# ADR-0004 — Rédiger les exigences selon la syntaxe EARS

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre
**Portée** : durable

## Item de conception

`dsn~format-exigence~1`

Chaque exigence est un item OpenFastTrace de type req dans `spec/02-exigences/`,
rédigé selon l'un des cinq motifs EARS, portant un niveau normatif
DOIT/DEVRAIT/PEUT, une justification (Rationale) quand le motif n'est pas
évident, des critères d'acceptation Étant donné / Quand / Alors, et ses
relations amont (Covers vers le besoin) et aval (Needs vers les types de
couverture attendus).

Covers:
- req~format-exigence-ears~1

## Contexte

Les dépôts de référence utilisent deux formats : blocs YAML riches en attributs
(wallos-rs) et lignes normées DOIT/DEVRAIT/PEUT (ergonomia). Le YAML porte
beaucoup d'attributs mais exige un outillage dédié pour être exploité ; les
lignes normées sont légères mais laissent la formulation libre, donc ambiguë.
EARS (Easy Approach to Requirements Syntax, Mavin et al.) contraint la
formulation elle-même par cinq motifs : ubiquitaire, événementiel (Quand),
à état (Tant que), comportement indésirable (Si… alors), fonctionnalité
optionnelle (Là où).

## Décision

Combiner les trois apports : formulation EARS (précision), niveaux normatifs
DOIT/DEVRAIT/PEUT (priorité, lisible en français), critères d'acceptation
Étant donné / Quand / Alors (pont direct vers les tests mécanisés), le tout
dans le format d'item OpenFastTrace (traçabilité native, révisions).

## Alternatives écartées

### Blocs YAML à la wallos-rs

Les attributs (criticité, couches, oracle) sont utiles mais exigent un
générateur de matrice maison ; ceux qui restent pertinents ici s'expriment dans
le texte (niveau normatif) ou dans la structure OpenFastTrace (Needs, Status).

### User stories seules

« En tant que… je veux… afin de… » capture l'intention mais pas le contrat
vérifiable ; la forme reste admise dans l'expression de besoin, jamais comme
exigence.

## Conséquences

- Ce que cela apporte : des exigences vérifiables, testables, dont
  l'ambiguïté est traquée à la rédaction et non découverte au test.
- Ce que cela coûte : un effort de reformulation ; les motifs EARS doivent être
  appris (méthode, ch. 2, avec exemples en français).
- Ce que cela ferme : pas d'exigence « prose libre » dans `spec/02-exigences/`.

## Vérification

La revue de pull request contrôle la conformité EARS (checklist du modèle de
PR) ; la présence des relations et des identifiants est, elle, vérifiée
mécaniquement par la traçabilité.

## Références

- EARS : <https://alistairmavin.com/ears/>
- Méthode : `docs/methode/02-exigences.md`.
