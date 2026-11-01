# ADR-0001 — Structurer alm-forge en dépôt-gabarit instanciable

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-01, registre des décisions)
**Portée** : durable

## Contexte

Le besoin (voir `spec/01-besoins/besoins.md`) est de mettre en œuvre l'ALM de
manière agnostique du langage et de l'agent. Trois natures de dépôt étaient
possibles : un référentiel de méthode purement documentaire, un framework
outillé publié comme dépendance, ou un dépôt-gabarit prêt à cloner.

## Décision

alm-forge est un **dépôt-gabarit instanciable** : arborescence complète (ADR,
exigences, traçabilité, CI, hooks, templates), outillage fonctionnel dès le
premier commit, et guide de méthode embarqué. Le gabarit s'applique sa propre
méthode : il est son premier projet instrumenté.

## Alternatives écartées

### Référentiel de méthode pur

Documente sans outiller : chaque projet réimplémente les portes, avec la dérive
et les no-op silencieux que les dépôts de référence ont précisément montrés.

### Framework outillé publié comme dépendance

Impose un cycle de publication et une gestion de compatibilité prématurés ; le
gabarit peut évoluer vers ce modèle plus tard si plusieurs projets instanciés
convergent (les scripts de `tools/` sont autonomes et extractibles).

## Conséquences

- Ce que cela apporte : démarrage d'un projet conforme en quelques minutes ;
  la méthode est prouvée par le gabarit lui-même (traçabilité verte exigée ici
  même).
- Ce que cela coûte : les projets instanciés divergent du gabarit au fil du
  temps ; la rétro-propagation des améliorations est manuelle.
- Ce que cela ferme : pas de versionnage centralisé de l'outillage chez les
  consommateurs tant que le modèle « dépendance » n'est pas adopté.

## Vérification

La racine du dépôt contient `spec/`, `docs/methode/`, `docs/adr/`,
`templates/`, `tools/`, `.githooks/`, `.github/workflows/` opérationnels, et la
commande `just ci` passe sur le gabarit nu. Contrôlé en continu par la CI.

## Références

- Registre des décisions : D-2026-08-01.
- Besoins : `spec/01-besoins/besoins.md`.
