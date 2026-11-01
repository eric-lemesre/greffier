# ADR-0005 — Documentation normative en français, templates bilingues

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-03, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~politique-linguistique~1`

La documentation normative (méthode, ADR, exigences, contrat d'agents) est
rédigée en français. Les modèles d'artefacts sont fournis en double dans
`templates/fr/` et `templates/en/`, avec des noms de fichiers identiques (en
anglais, comme tous les identifiants techniques) ; la parité des deux
arborescences est vérifiée mécaniquement.

Covers:
- req~bilinguisme-templates~1

## Contexte

Les dépôts de référence sont intégralement francophones. Un gabarit a vocation
à être instancié sur des projets qui peuvent accueillir des contributeurs non
francophones ; les référentiels externes (MADR, EARS, Keep a Changelog) sont
anglophones.

## Décision

Bilinguisme ciblé : le normatif reste en français (cohérence avec les dépôts
existants et le contexte de travail), les modèles — le point de contact d'un
nouveau projet — existent dans les deux langues. Identifiants techniques
(types et noms d'items, tags, commandes, noms de fichiers de templates) en
anglais.

## Alternatives écartées

### Tout français

Ferme le gabarit aux équipes mixtes et éloigne les référentiels externes.

### Tout anglais

Rompt avec ergonomia et wallos-rs dont ce gabarit capitalise les pratiques, et
dégrade la lecture pour l'équipe actuelle.

### Miroir intégral fr/en de toute la documentation

Double la surface à maintenir synchronisée pour un lectorat hypothétique ; la
parité ne serait pas tenable sans traduction outillée.

## Conséquences

- Ce que cela apporte : un point d'entrée utilisable dans les deux langues, un
  normatif sans dette de synchronisation.
- Ce que cela coûte : chaque évolution de modèle se fait deux fois ; le
  contrôle de parité ne vérifie que la présence des fichiers, pas l'équivalence
  des contenus — celle-ci relève de la revue.

## Vérification

`just check` échoue si `templates/fr/` et `templates/en/` ne contiennent pas
exactement les mêmes noms de fichiers.

## Références

- Registre des décisions : D-2026-08-03.
