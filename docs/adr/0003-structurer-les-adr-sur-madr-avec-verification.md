# ADR-0003 — Structurer les ADR sur MADR avec section Vérification

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre
**Portée** : durable

## Item de conception

`dsn~format-adr~1`

Le modèle d'ADR du gabarit dérive de MADR 4.0 (en-tête statut/date/décideur,
contexte, décision, alternatives écartées avec une sous-section chacune,
conséquences) et lui ajoute deux éléments : une section **Vérification**
obligatoire pour tout ADR accepté, et un champ **Portée** (phase ou durable,
avec condition de réouverture).

Covers:
- req~registre-adr~1

## Contexte

Les deux dépôts de référence divergent : wallos-rs a laissé son format d'ADR se
stabiliser par convention (deux variantes coexistent, sections inégalement
présentes), quand ergonomia impose un template strict dont la section
Vérification (« comment sait-on que la décision est effectivement tenue ? »)
s'est révélée être le garde-fou le plus utile. MADR 4.0 est le standard
communautaire le plus proche de ces pratiques.

## Décision

Un modèle unique (`templates/fr/adr.md`, `templates/en/adr.md`), dérivé de
MADR, enrichi de Vérification et Portée, avec la règle d'immuabilité
d'ergonomia : un ADR accepté ne se modifie pas, il se remplace. La présence de
la section Vérification dans les ADR acceptés est contrôlée par `tools/checks.sh`.

## Alternatives écartées

### MADR 4.0 nu

Il n'impose ni vérification ni portée : c'est précisément ce qui laisse les
décisions dériver une fois le fichier écrit.

### Format Nygard historique

Plus concis (Contexte/Décision/Conséquences) mais ne force ni les alternatives
écartées ni la vérification ; les deux dépôts de référence l'ont dépassé.

## Conséquences

- Ce que cela apporte : des ADR comparables entre eux et entre projets
  instanciés ; un contrôle mécanique plutôt qu'une discipline de relecture.
- Ce que cela coûte : écrire un ADR complet demande plus d'effort qu'une note ;
  c'est assumé — un ADR sans coût est un ADR qui ment.
- Ce que cela ferme : pas de format libre par projet ; les écarts au modèle se
  décident par un nouvel ADR.

## Vérification

`just check` échoue si un ADR au statut Accepté ne contient pas de section
« Vérification » ; le contrôle est lui-même tracé vers l'exigence dédiée.

## Références

- MADR : <https://adr.github.io/madr/>
- Charte du registre : `docs/adr/README.md`.
