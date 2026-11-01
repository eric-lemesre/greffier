# Façades d'orchestration

L'orchestrateur est un confort, pas une dépendance (ADR-0007) : toute la
logique des portes vit dans `tools/*.sh`, que la CI et les hooks git appellent
directement. Une façade ne fait que donner des noms courts aux commandes.

| Façade | Fichier | Prérequis |
| --- | --- | --- |
| [Task](https://taskfile.dev/) (par défaut) | `Taskfile.yml` à la racine | binaire `task` |
| [just](https://just.systems/) | copier `justfile` d'ici vers la racine | binaire `just` + un shell `sh` |
| aucune | supprimer la façade | appeler `sh tools/oft.sh trace`, etc. |

Règles à l'instanciation :

1. Choisir **une** façade (ou aucune) et supprimer l'autre de la racine.
2. Une façade est une délégation pure : si une recette contient de la logique,
   c'est un défaut — la logique va dans `tools/`.
3. Ajouter une autre façade (Makefile, scripts npm…) suit le même contrat :
   mêmes noms de cibles (`init`, `setup`, `bootstrap`, `trace`, `report`,
   `check`, `secrets`, `ci`, `hooks`, `adr-new`, `bump`, `clean`), délégation
   pure.

Ce répertoire n'est pas scanné par la traçabilité (`templates/` est exclu du
périmètre, ADR-0002).
