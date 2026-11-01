# Revue de code — instanciation, droits d'exécution et matrice — 2026-10-31

- **Périmètre** : `git diff origin/main...fix/init-droits-et-matrice` (PR #18) —
  `req~instanciation-outillee~2`, `tools/init.sh`, `tools/init-test.sh`,
  CHANGELOG.
- **Relecteur** : Claude Opus 5.5, sous-agent indépendant de l'auteur, en
  lecture seule et par lecture statique : sa session n'avait pas de shell.
  Les preuves d'exécution ont été rejouées par l'auteur, voir « Suite donnée ».
- **Verdict global** : approuvé avec réserves. Les quatre constats sont
  soldés : trois corrigés, un rejeté avec motif.

## Constats

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | basse | `tools/init.sh`, `remplacer` : `cat f.tmp > f` tronque la cible avant de la réécrire. On perd l'atomicité du `mv`, et un lien symbolique serait suivi. | Rejeté | Le script ne tourne qu'une fois, sur un dépôt neuf. Le gabarit ne suit aucun lien symbolique : `git ls-files -s` ne liste aucun mode 120000. Garder les droits avec `chmod --reference` ne serait pas POSIX, et `cp -p` est équivalent à la copie actuelle. Ces limites sont écrites en tête de la fonction. |
| 2 | moyenne (R3) | `tools/init-test.sh` : la liste des exécutables, tirée de `git ls-files` du gabarit, pouvait être vide (pas de git, index illisible). Le contrôle des droits passait alors sans rien vérifier. | Corrigé | La liste doit contenir `tools/hooks/pre-commit.sh`, sinon le test échoue en disant que le contrôle est sans objet. |
| 3 | basse | `tools/init-test.sh` : le contrôle de dérive commence par `git add -A`, qui masque l'état de l'index laissé par `init.sh`. Le retrait de l'index (`git rm --cached … \|\| true`) n'était donc jamais vérifié. | Corrigé | Avant tout `git add`, le test exige que `tools/init.sh` et `tools/init-test.sh` soient absents de l'index (`git ls-files --error-unmatch`). |
| 4 | basse | `tools/init.sh` : les étiquettes `[impl->req~instanciation-outillee~2]` ajoutées dans les commentaires répètent celle de la ligne 2 du fichier. | Corrigé | Les deux étiquettes ajoutées sont retirées. |

## Suite donnée

Le relecteur n'avait pas pu prouver que les contrôles échouent sur l'ancien
script. Je l'ai rejoué :

- avec l'`init.sh` d'`origin/main`, trois échecs : droits perdus, outillage
  resté dans l'index, artefacts périmés ;
- avec un mutant privé du `git rm --cached`, deux échecs : outillage resté
  dans l'index, artefacts périmés ;
- avec le correctif, le test passe.

Leçon : un script qui se réécrit pendant qu'il s'exécute est lu à travers le
fichier modifié. Le correctif l'a montré : la règle R0 du cas [B] sortait
tronquée tant que l'étape 1 réécrivait `init.sh` sur place.

## Points vérifiés hors constats

- Conformité EARS des exigences : sans objet, `req~instanciation-outillee~2`
  est inchangée.
- Absence de tag de complaisance : ok.
- Niveau de test conforme au Needs déclaré : ok, `tools/init-test.sh`.
- `sh tools/ci.sh --complet` : vert après corrections.
