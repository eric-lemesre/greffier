# Revue de code — tests d'outillage en parallèle, artefacts indépendants de la locale — 2026-10-30

- **Périmètre** : `git diff origin/main...06cc458` de la branche
  `perf/ci-parallele` (PR #17) — `req~porte-ci~2` (lanceur parallèle
  `tools/paralleles.sh`, `tools/ci.sh`, `tools/ci-test.sh`, `tools/init.sh`)
  et `req~anti-derive-generes~1` (`tools/revues.sh`, `tools/matrice.sh`,
  `tools/badges.sh`).
- **Relecteur** : Claude Opus 5.5 (sous-agent indépendant du modèle auteur,
  lecture seule, constats reproduits dans un clone jetable, sous dash et
  busybox).
- **Verdict global** : approuvé avec réserves — **les onze constats sont
  soldés** (dix corrigés, un en partie rejeté motivé), plus un défaut trouvé
  en corrigeant.

## Constats

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | moyenne | `tools/paralleles.sh` : `wc -l` et `while read` ignoraient une dernière ligne sans fin de ligne, qu'`awk` comptait et que xargs jouait ; absente de la sortie et du bilan, elle pouvait échouer avec un code de retour 0. Une liste d'une seule ligne sans fin de ligne était refusée comme vide. | Corrigé | L'entrée est normalisée par `awk 'NF { print }'` (lignes vides ôtées, fin de ligne ajoutée) et comptée par awk. `tools/ci.sh` compare le nombre de lignes du bilan au nombre d'étapes de la liste et compte un écart comme un échec. Cas « dernière ligne sans fin de ligne, en échec » de `tools/paralleles-test.sh`, cas « bilan incomplet » de `tools/ci-test.sh`. |
| 2 | moyenne | `tools/paralleles-test.sh` : avec trois étapes et la parallélisation par défaut, toutes étaient lancées avant l'échec ; un lanceur qui s'arrête au premier échec (travailleur rendant 255 à xargs) restait vert. | Corrigé | Le cas joue cinq étapes, l'échec en deuxième position avec le code 255, sous `CI_PARALLELE=1`, `2` et la valeur par défaut, et exige les cinq sorties et les verdicts `ok ÉCHEC ok ok ok`. Les mutants « exit 255 sur échec » et « travailleur qui rend le code de l'étape » sont refusés. |
| 3 | moyenne | Les gardes « fermé en cas de panne » n'avaient aucun test : travailleur sans code, `\|\| true` sur xargs, bilan vide dans `tools/ci.sh` ; `etapes_paralleles` n'était couverte par aucun test (`ci-test.sh` ne joue que `--rapide`). | Corrigé | `tools/paralleles-test.sh` : travailleur tué (`kill -9`), xargs absent du PATH — tout rouge, bilan complet. `tools/ci-test.sh` extrait les fonctions du lanceur de `tools/ci.sh` entre les marqueurs `lanceur:debut` et `lanceur:fin` et les joue dans un harnais : étape rouge comptée et nommée, bilan incomplet compté. Quatre mutants de ces fonctions refusés. |
| 4 | moyenne | Aucun test ne refusait la dépendance à la locale ; remettre les anciennes versions de `revues.sh`, `matrice.sh` et `badges.sh` ne cassait rien. | Corrigé | `tools/locale-test.sh` : copie du dépôt, fiches de revue `z-a-c` et `z-ab`, répertoires d'outillage `a-c` et `ab` (ordres opposés en locale de langue et en ordre des octets), génération sous `fr_FR`/`en_US` puis `C`, sorties exigées identiques ; largeur de « réalisé » exigée à 59 sous les deux locales. Mutants (tri par octets retiré de chaque générateur, ancien `badges.sh`) refusés. Sauté, en le disant, sans locale de langue installée. Câblé dans la liste parallèle. |
| 5 | basse | xargs absent, sans `-P`, `CI_PARALLELE` invalide ou travailleur tué : les étapes non lancées sortaient `ÉCHEC` avec une sortie vide, indiscernables d'un échec réel. | Corrigé | `CI_PARALLELE` validé (entier positif ou nul, sinon code 2) ; une étape sans code imprime « étape non jouée jusqu'au bout (lanceur interrompu ou travailleur tué) » ; le travailleur rend toujours 0 à xargs, si bien qu'un code 255 d'une étape n'arrête plus le lanceur. Seule la mort du travailleur par signal peut encore interrompre xargs, et elle reste un échec nommé. |
| 6 | basse | `tools/ci.sh` : `$(( $(date +%s) - _debut ))` sans `date +%s` arrêtait le lanceur après la première porte, sans bilan. | Corrigé | Fonction `secondes()` qui ne rend que des chiffres ; durée « ? » au bilan si elle manque. Même garde dans le travailleur de `tools/paralleles.sh`. Cas « date sans %s » de `tools/ci-test.sh` : la porte suivante est jouée, les deux figurent au bilan. |
| 7 | basse | `tools/paralleles.sh` : un `<bilan>` relatif était écrit dans la racine du dépôt, le `cd` précédant la lecture de l'argument. | Corrigé | Chemin rendu absolu avant le changement de répertoire ; cas « bilan relatif » du test. |
| 8 | basse | `echo "— ${titre}"` : l'`echo` de dash interprète les antislashs ; un titre `a\\b` sortait `a\b`. Même défaut dans `etape` de `tools/ci.sh`. | Corrigé | `printf '— %s\n'` aux deux endroits ; cas « titre à antislash » du test. |
| 9 | basse | `tools/ci.sh` : heredoc non protégé (`<<FIN`) ; une commande future contenant `$(…)` serait évaluée par ci.sh avant le lanceur. | Corrigé | `<<'FIN'`. |
| 10 | basse | `sleep 0.1` n'est pas POSIX ; là où il est refusé, le rendez-vous échouait à tort. | Corrigé | `sleep 1`, dix tours au plus. |
| 11 | basse | L'exigence `req~porte-ci~2` ne dit rien du parallélisme, de l'ordre des sorties ni des durées ; `CI_PARALLELE` n'est documenté qu'au CHANGELOG ; le commit mêle deux exigences (R4). | Rejeté | En partie corrigé : `CI_PARALLELE`, l'ordre des sorties et l'échec d'une étape non jouée sont décrits au chapitre 4 de la méthode. Rejeté pour l'exigence : le parallélisme est un moyen, pas une obligation nouvelle ; « jouer toutes les portes et les nommer toutes au bilan » est déjà l'énoncé, que les tests de ce lot éprouvent désormais contre le lanceur parallèle ; une révision `~3` déplacerait toutes les étiquettes sans rien exiger de plus. Rejeté pour le commit : 06cc458 est publié dans la PR #17 ; les corrections suivent en deux commits, un par exigence. |
| 12 | basse | Trouvé en corrigeant, par mutation : le contrôle « une ligne au bilan par étape » de `tools/paralleles.sh` ne pouvait jamais échouer, la boucle lisant la liste elle-même. | Corrigé | Contrôle retiré du lanceur ; la vérification réelle du compte est dans `etapes_paralleles` de `tools/ci.sh`, éprouvée par `tools/ci-test.sh`. |

## Suite donnée

Dix constats corrigés, le onzième en partie, plus un contrôle mort retiré.
Deux leçons :

- **Un test de lanceur parallèle doit attendre son tour.** Avec autant de
  processeurs que d'étapes, tout est lancé avant le premier échec, et un
  lanceur qui s'arrête au premier échec passe pour sain. Le cas capital se
  joue sous `CI_PARALLELE=1`.
- **Un test de locale fixe toutes les variables que le générateur lit.** La
  première version de `tools/locale-test.sh` ne fixait que `LC_ALL`, que les
  générateurs annulent ; ils retombaient sur le `LANG` du poste dans les deux
  passes, et le test passait même sans la correction. Le mutant l'a montré ;
  le test fixe désormais `LANG` aussi.

## Points vérifiés hors constats

- Instanciation : le retrait de la ligne d'`init-test.sh` est exact sous
  `C` et `fr_FR` ; une mutation (tabulation remplacée par une espace) est
  refusée par `init-test.sh`.
- Caractères spéciaux dans les titres et commandes, CRLF, liste vide, ligne
  sans tabulation, absence d'argument : comportements attendus.
- busybox 1.38 : `xargs -P` disponible, test vert avec les outils de busybox.
- Largeur des badges identique sous gawk, mawk et busybox awk en `LC_ALL=C`.
- Artefacts régénérés identiques sous `fr_FR.UTF-8`, `C.UTF-8` et `C`.
- Ressources partagées : chaque test dans son `mktemp`, `bootstrap-test`
  n'écrit rien dans le dépôt, téléchargements de `.cache` atomiques et faits
  avant le bloc parallèle, aucune imbrication de la voie complète.
- Colonnes du bilan compatibles avec les motifs de `tools/ci-test.sh` ; R9
  respectée (« ok » et « ÉCHEC » hors lexique) ; CHANGELOG cohérent.
