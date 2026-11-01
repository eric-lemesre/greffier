# Contribuer

Les règles complètes sont dans [AGENTS.md](AGENTS.md) (contrat faisant
autorité) et la méthode dans [docs/methode/](docs/methode/README.md). Résumé
opérationnel :

## Mise en place

```bash
task setup   # accueil complet : dépendances, hooks, portes, orientation
```

(ou `sh tools/setup.sh` sans façade). Le script est idempotent ; il enchaîne
`bootstrap` (socle + modules du projet, installation consentie des manquants —
ADR-0014), l'installation des hooks, puis l'**état** des portes : il en
rapporte le bilan et ne fait jamais de leur verdict un échec de l'accueil —
un dépôt dont la spécification précède la réalisation a des portes
légitimement rouges, et ce n'est pas à un arrivant de les porter. La sanction
reste à `task ci`. Détail des cibles : AGENTS.md §3.

Prérequis : git, un shell `sh` POSIX (fourni par Git sous Windows), curl,
Java 17+ (pour OpenFastTrace, téléchargé automatiquement et vérifié par
empreinte). [Task](https://taskfile.dev/) est la façade par défaut ; elle est
optionnelle et remplaçable (ADR-0007, `templates/orchestrators/`).

## Flux

1. Branche `type/sujet-court` depuis `main`.
2. Suivre la boucle de travail d'AGENTS.md §2 : exigence d'abord, tags de
   couverture, tests du niveau déclaré, `task ci` vert.
3. Commits conventionnels en français, l'identifiant d'exigence dans le sujet.
4. Pull request : la checklist du modèle est la Definition of Done.
5. Revue par un second regard ; chaque constat est soldé avant fusion.

## Ce qui bloque une contribution

- Une exigence orpheline ou un tag fantôme (`task trace` échoue).
- Un ADR accepté sans section Vérification (`task check` échoue).
- Un message de commit non conventionnel, ou ne respectant pas la politique
  de mention de l'IA du projet — ici, aucune mention d'agent, de co-auteur
  généré ni d'outil d'IA n'est admise (R0, ADR-0011 du gabarit).
- Un contrôle introduit sans démonstration de son cas d'échec (R3).
- Un secret dans une contribution (`task secrets` — bloquant en CI ; les faux
  positifs passent par une entrée justifiée de `.gitleaks.toml`).
