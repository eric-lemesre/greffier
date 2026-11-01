# 14. Audit de réalisation


**La traçabilité mesure la présence. L'audit mesure la vérité.**

OpenFastTrace (ch. 4) répond à : *cette exigence a-t-elle un item de
conception, du code, un test ?* La question se calcule, la réponse est
binaire, et un outil suffit.

L'audit répond à : *ce qui est livré fait-il ce que l'exigence dit ?* La
question se lit. Aucun outil ne la tranche — et un **tag de complaisance**,
posé sur un fichier qui ne réalise pas l'exigence, passe la traçabilité sans
la moindre réserve (décision : [ADR-0016](https://github.com/eric-lemesre/alm-forge/blob/main/docs/adr/0016-audit-de-realisation-distinct-de-la-tracabilite.md)).

## Le partage du travail

> Le générateur compte, l'humain juge.

- **Une fiche par domaine** — `docs/audit/<domaine>.md`, miroir de
  `spec/02-exigences/<domaine>.md`, depuis le modèle
  [`templates/fr/audit-sheet.md`](../../templates/fr/audit-sheet.md). Les
  verdicts et les preuves y sont écrits **à la main**.
- **Un tableau de bord** — `docs/audit/README.md`, **généré** par
  `tools/audit.sh --ecrire`, qui ne fait que compter.

Le tableau de bord est protégé par la porte anti-dérive. Les fiches, non :
c'est du jugement, il ne se régénère pas.

## Les trois verdicts

| Verdict | Ce qu'il dit |
| --- | --- |
| `conforme` | le livré fait ce que l'exigence dit — la preuve le montre |
| `écart` | il ne le fait pas, ou pas entièrement — la colonne dit en quoi |
| `non examiné` | personne n'a encore regardé |

Le vocabulaire vient du lexique. La colonne « Preuve / écart » n'est pas
facultative : un `conforme` sans preuve est une affirmation, pas un audit.

## Le plafond de non-examinées

`tools/audit.sh` porte un plafond déclaré — **0 pour le gabarit**. Il empêche
la dette de s'installer sans être vue.

Un projet qui transpose un existant volumineux peut le desserrer, à une
condition : **le faire décroître**. Un plafond qui suit le réel ne contrôle
plus rien, il l'enregistre. Le fixer une fois et le voir baisser est un
programme de travail ; le relever à chaque échec est une capitulation
documentée.

## Ce que l'audit n'est pas

- **Ce n'est pas la revue de code** (ch. 7). La revue voit un diff au moment
  où il est proposé ; elle ne dit rien de l'exigence rédigée il y a six mois
  dont l'implémentation a dérivé depuis. L'audit est un balayage d'état, la
  revue un contrôle de flux.
- **Ce n'est pas un taux de conformité calculé.** Tout chiffre d'audit est la
  somme de jugements humains. Le présenter autrement serait exactement le
  genre de faux chiffre que la méthode cherche à éliminer.

## Quand auditer

À chaque version **mineure**, et à toute révision d'exigence : une exigence
dont le sens change rend caduc le verdict qui la concernait. La porte le
rappelle mécaniquement — la ligne d'audit vise un identifiant, et un
identifiant dont la révision a bougé ne correspond plus.
