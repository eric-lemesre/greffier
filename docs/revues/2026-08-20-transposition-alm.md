# Revue de code — transposition ALM — 2026-08-20

- **Périmètre** : git diff origin/main...HEAD (80 fichiers)
- **Relecteur** : Kimi (kimi-cli 0.28.0)
- **Verdict global** : approuvé avec réserves — **les sept constats sont soldés**

## Constats

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | haute | `tools/audit.sh` n'accepte qu'une seule langue pour les verdicts. En mode `fr-en`, les formes anglaises (`compliant`, `gap`, `not examined`) sont rejetées comme « hors lexique » (lignes 45-52 : on reste sur `lex_fr` tant que `LEXIQUE_LANGUE` n'est pas exactement `en`). Cela contredit `req~lexique-outille~1` et l'ADR-0015 qui affirment que `fr-en` accepte les deux formes. Le test `gouvernance-test.sh` ne le détecte pas car il force `LEXIQUE_LANGUE="en"`, pas `fr-en`. | Corrigé | `lex_est` ajouté au lexique (reconnaissance selon la langue figée) et employé par `audit.sh` ; `lex_fr` ne sert plus qu'à l'AFFICHAGE. Même classe de défaut trouvée en corrigeant : `todo.sh` et `statuts.sh` inséraient l'alternance `Statut\|Status` **nue** dans une regex — d'où `lex_motif`, qui parenthèse. Cas de test bilingue ajouté à `gouvernance-test.sh` : c'était l'angle mort du test lui-même. Commit de correction. |
| 2 | moyenne | Itération non quotée sur des listes de chemins : `tools/perimetre.sh:83` (`for chemin in ${EMPREINTE}`), `tools/todo.sh:60` (`for f in ${FICHES}`), `tools/revues.sh:69` (`${FICHES}` en argument awk), `tools/badges.sh:80` (`${exigences}` en argument awk), `tools/classification.sh:105` (`${FICHERS}`). Un nom de fichier contenant un espace ou une globule est découpé ou expansé ; la porte peut alors ignorer un fichier ou en traiter un inexistant. | Corrigé | `IFS` restreint aux fins de ligne et `set -f` en tête des dix portes concernées, avec le motif en commentaire. `releves.sh` : son seul glob non quoté (`ls docs/adr/${num}-*.md`) remplacé par une interrogation de l'index git. `badges.sh` : le `tr '\n' ' '` qui aplatissait la liste est retiré. Cas de test « chemin à espace » ajouté. |
| 3 | moyenne | `tools/liens.sh:157` extrait les cibles Markdown avec `/\]\([^)( \t]+(\)\|[ \t])/`, qui s'arrête à la première parenthèse ou espace dans l'URL. Un lien relatif dont le chemin contient des parenthèses (ex. `fichier-(v2).md`) est tronqué et signalé mort à tort. | Corrigé | Extraction réécrite avec un compteur de parenthèses : les parenthèses équilibrées appartiennent à la cible, l'arrêt se fait sur parenthèse fermante de niveau 0 ou sur espace (titre de lien). Cas de test `guide-(v2).md` ajouté. |
| 4 | moyenne | `templates/forge/tools/automatismes.sh:102` appelle `gh issue list --search "${doc}"` sans échapper le nom de fichier. Si `${doc}` contient des caractères spéciaux pour la recherche GitHub (espace, guillemet, `AND`, `OR`, `NOT`), la requête est corrompue ou filtre des issues non désirées. | Corrigé | Le terme est désormais entouré de guillemets dans la requête (`--search "\"${doc}\""`), ce qui force la recherche littérale. |
| 5 | basse | `tools/init.sh:446` supprime `templates/forge/` à l'instanciation (`rm -rf templates/forge`). Les automatismes sont donc livrés « prêts à câbler » dans le gabarit mais retirés du projet instancié, ce qui affaiblit la promesse de `req~automatismes-forge~1` (ils doivent être copiés à la main depuis le gabarit source). | Corrigé | `rm -rf templates/forge` supprimé de `init.sh`. Constat sous-évalué à « basse » : il annulait pour le projet instancié ce que `req~automatismes-forge~1` promet de lui fournir. `templates/forge/` est du matériel post-instanciation, comme `templates/orchestrators/`. |
| 6 | basse | `tools/journaux.sh:34` fixe `FENETRE=6`, c'est-à-dire que seules les 6 sections de version les plus récentes sont contrôlées. Une section plus ancienne modifiée après coup passe sous le radar. C'est un choix documenté, mais le paramètre est magique et non configurable. | Corrigé | `FENETRE="${JOURNAUX_FENETRE:-6}"` — surchargeable, avec le motif du réglage en commentaire. |
| 7 | basse | `tools/lexique.sh:44-45` utilise `eval "LEX_${_lex_cle}_FR=\$_lex_fr"` pour construire des variables dynamiques. C'est un pattern fragile : si une clé contenait un caractère shell-spécial (les clés actuelles sont saines), cela injecterait du code au `source`. Préférer un préfixe fixe et des clés contrôlées, ou documenter explicitement que les clés sont des identifiants stricts. | Corrigé | Garde ajoutée à `lex_def` : une clé hors `[A-Z0-9_]` est refusée. L'invariant que le constat supposait est maintenant explicite et mécanisé, au lieu d'être seulement vrai. |

## Suite donnée

Les sept constats sont **corrigés**, aucun rejeté. Deux méritent d'être
soulignés :

- Le constat n° 1 était plus large que son énoncé : la même classe de défaut —
  une alternance de lexique insérée nue dans une expression régulière —
  touchait aussi `todo.sh` et `statuts.sh`, où elle produisait
  `^\*\*Statut|Status[ \t]*:`, c'est-à-dire deux branches fausses. Le lexique
  gagne `lex_est` (reconnaissance) et `lex_motif` (alternance parenthésée) :
  la classe entière est refermée, pas le seul cas signalé.
- Le constat n° 5, classé « basse » par le relecteur, était en réalité une
  **annulation d'exigence** : supprimer `templates/forge/` à l'instanciation
  privait le projet de ce que `req~automatismes-forge~1` promet de lui
  fournir.

Le relecteur a par ailleurs relevé, à juste titre, que le test bilingue
existant ne prouvait rien sur le mode `fr-en` — qui est pourtant le **défaut**
de l'instanciation. Le cas manquant est ajouté.

## Points vérifiés hors constats

- Traçabilité OpenFastTrace : OK, couverture complète, tests d'orphelin et de maillon posé dans `tools/socle-test.sh`.
- Portes documentaires (`liens`, `statuts`, `releves`, `journaux`, `classification`, `todo`, `revues`, `badges`) : passent sur le dépôt courant.
- Anti-dérive (`tools/derive.sh`) : double contrôle suivi-par-git + comparaison après régénération, éprouvé sur les quatre cas dans `tools/derive-test.sh`.
- Périmètre constaté (`tools/perimetre.sh`) : allowlist restrictive, prise en compte des fichiers non suivis, tests négatifs dans `tools/perimetre-test.sh`.
- `tools/checks.sh` : parité templates, section Vérification des ADR, VERSION↔CHANGELOG, index ADR réciproque, alignement des façades CI, complétude du lexique — tous éprouvés sur leur cas d'échec.
- CI : GitHub et GitLab délèguent toutes deux à `tools/ci.sh`, sans liste d'étapes propre.
- Hooks commit-msg : trois politiques d'attribution IA gérées, tests de refus/passage dans `tools/socle-test.sh`.
- Lexique : 42 termes déclarés avec leurs deux formes ; contrôle de complétude mécanisé.
- Tous les tests d'outillage listés dans `tools/ci.sh` passent sur la branche courante.
