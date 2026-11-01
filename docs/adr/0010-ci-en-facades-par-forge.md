# ADR-0010 — Porter la CI en façades de délégation par forge

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-08, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~ci-multi-forges~1`

Le gabarit ne dépend d'aucune forge : les portes s'exécutent localement
(`tools/*.sh`, hooks git), et chaque forge reçoit une configuration CI de
**délégation pure** appelant les mêmes scripts — `.github/workflows/ci.yml`
pour GitHub, `.gitlab-ci.yml` pour GitLab. Ajouter une forge consiste à écrire
une nouvelle façade CI, jamais à dupliquer une porte.

Covers:
- req~portabilite-forges~1

## Contexte

Le gabarit doit fonctionner sur GitHub mais aussi GitLab ou toute autre forge
git (demande du porteur). L'ADR-0007 avait déjà sorti la logique des portes
vers des scripts autonomes appelés directement par la CI : la dépendance à la
forge se réduisait donc à la syntaxe du fichier de CI, aux modèles
d'issues/MR, et au bouton « Use this template » (spécifique GitHub — le
chemin neutre est un clone ordinaire suivi de `tools/init.sh`).

## Décision

Assumer le multi-forges par le même motif que les orchestrateurs : façades de
délégation. Les deux façades CI fournies exécutent strictement les mêmes
étapes (traçabilité, cohérence, tests d'instanciation et d'accueil, rapport
HTML en artefact). Les modèles d'issues/MR existent pour GitHub
(`.github/ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`) et GitLab
(`.gitlab/issue_templates/`, `.gitlab/merge_request_templates/`). Un projet
instancié supprime les répertoires des forges qu'il n'utilise pas — le
périmètre de traçabilité filtre les chemins absents.

## Alternatives écartées

### Une seule forge documentée, adaptation à la main

Reporte sur chaque projet un travail identique et non tracé.

### Abstraction de CI multi-forges (générateur)

Machinerie disproportionnée pour deux fichiers de délégation d'une trentaine
de lignes chacun ; les syntaxes de CI divergent trop pour être abstraites sans
perte.

## Conséquences

- Ce que cela apporte : un dépôt utilisable tel quel sur GitHub et GitLab ;
  Forgejo/Gitea Actions, conçus pour réutiliser la syntaxe GitHub Actions,
  partent de la façade GitHub.
- Ce que cela coûte : deux façades CI à maintenir alignées sur la même liste
  d'étapes — la règle « délégation pure » borne ce coût, la revue le vérifie.
- Ce que cela ferme : rien.

## Vérification

Les deux façades CI n'appellent que `tools/*.sh` (aucune logique propre —
revue) ; la façade GitHub est exécutée sur ce dépôt ; la façade GitLab est
validée par exécution sur une instance GitLab lors de la première
instanciation qui l'utilise (limite assumée : pas de runner GitLab local).

## Références

- Registre des décisions : D-2026-08-08.
- Exigence : req~portabilite-forges~1 (`spec/02-exigences/gouvernance.md`).
- ADR-0007 (façades d'orchestration — même motif).
