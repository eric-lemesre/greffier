# ADR-0007 — Séparer les portes de l'orchestrateur, façade interchangeable

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-05, registre des décisions, et OQ-001)
**Portée** : durable

## Contexte

Le gabarit initial orchestrait ses portes avec just, dont les recettes en bash
appelaient des scripts bash. Deux constats ont rouvert le sujet : just exécute
ses recettes via un shell `sh` dont la présence n'est pas garantie hors
environnement POSIX (limite documentée de son manuel), et un fichier
`justfile`, sans extension, n'est pas scanné par OpenFastTrace — l'orchestrateur
ne pouvait pas porter de tags de couverture. Enfin, le porteur souhaite que le
choix de l'outil d'orchestration reste ouvert **à l'instanciation** du gabarit.

## Décision

Découpler définitivement les deux rôles :

- **Les portes** vivent dans `tools/*.sh`, en **POSIX sh strict** (aucun
  bashisme, uniquement des commandes intégrées et utilitaires universels),
  taguées vers leurs exigences. La CI et les hooks git les appellent
  **directement** : aucune porte ne dépend d'un orchestrateur.
- **L'orchestrateur** est une **façade de délégation pure**, interchangeable :
  `Taskfile.yml` ([Task](https://taskfile.dev/)) fourni par défaut à la racine,
  variante `justfile` dans `templates/orchestrators/`, possibilité documentée
  de n'en garder aucune. Une logique qui apparaît dans une façade est un défaut.

## Alternatives écartées

### Inliner les portes dans le Taskfile

L'interpréteur intégré de Task (utilitaires de base compilés en Go, activés
par défaut sous Windows) offrait « Windows sans bash », mais verrouillait
l'outil — exactement ce que le porteur refuse. L'argument de portabilité est
par ailleurs largement théorique : le gabarit exige git, et Git pour Windows
fournit toujours `sh` et ses utilitaires.

### Deux orchestrateurs complets avec contrôle de parité

Choix maximal mais double maintenance permanente de la logique ; la parité
mécanique ajouterait une porte pour protéger de la complexité qu'on aurait
soi-même introduite.

### Statu quo (just seul, logique en bash)

Laissait l'outil imposé, des bashismes dans les portes et un orchestrateur
invisible de la traçabilité.

## Conséquences

- Ce que cela apporte : le projet instancié choisit son confort (Task, just,
  make, rien) sans toucher aux portes ; CI et hooks fonctionnent partout où
  git fonctionne ; les scripts POSIX s'exécutent avec dash, bash ou le sh de
  Git pour Windows.
- Ce que cela coûte : les portes restent en shell — un poste Windows sans Git
  Bash ne peut pas les exécuter localement (cas jugé vide : git est requis) ;
  chaque façade ajoutée doit être maintenue alignée sur les noms de cibles.
- Ce que cela ferme : pas de logique de porte dans un orchestrateur, quel
  qu'il soit.

## Vérification

La CI n'installe aucun orchestrateur : `.github/workflows/ci.yml` appelle
`tools/oft.sh` et `tools/checks.sh` directement — si une logique migrait dans
une façade, la CI cesserait de l'exécuter et la revue le verrait. Les façades
sont revues comme délégation pure (règle inscrite en tête de chaque façade).
La conformité POSIX des scripts est vérifiable en les exécutant avec dash.

Les sections Vérification des ADR-0001 à 0005, immuables, citent les commandes
de l'époque : lire `just ci` comme `task ci`, `tools/oft.sh` et
`tools/checks.sh` restant les chemins de référence.

## Références

- Registre des décisions : D-2026-08-05 ; question ouverte : OQ-001.
- Manuel just (shell requis) : <https://just.systems/man/en/>
- FAQ Task (utilitaires intégrés sous Windows) : <https://taskfile.dev/docs/faq>
- Façades : `Taskfile.yml`, `templates/orchestrators/`.
