# 15. Cadrage des nouvelles fonctionnalités

Ce chapitre est l'**amont** du circuit : il décrit comment une idée éparse
devient une proposition de spécification recevable. Il ne remplace ni le cycle
de vie des exigences (ch. 2), ni celui des issues (ch. 11) — il produit la
matière première qui y entre.

## Les deux dérives qu'il évite

Elles sont symétriques, et toutes deux coûteuses :

- **proposer une fonctionnalité qui contredit une spécification déjà actée**,
  parce que personne n'a vérifié le vide avant d'écrire ;
- **laisser partir en développement une proposition que personne n'a relue**,
  parce que l'étape de relecture a été sautée au motif que « c'est évident ».

Traiter le sujet dans l'ordre — demandes → thèmes → confrontation aux specs →
proposition — coûte moins cher que de défaire l'une ou l'autre.

## Le déclencheur : pas de rituel de plus

Le cadrage s'accroche à la **revue de triage** déjà existante (ch. 11). C'est
ce rendez-vous qui porte la charge de s'en souvenir, pas la mémoire de qui
pilote. Multiplier les rituels est le moyen le plus sûr de n'en tenir aucun.

## Les quatre étapes

1. **Rassembler.** Parcourir les demandes ouvertes sans les traiter une à
   une : on cherche les récurrences, pas les cas. Trois demandes distinctes
   qui contournent le même manque valent un thème.
2. **Nommer le thème.** Un thème est un besoin (ch. 1), pas une solution. S'il
   se formule déjà comme un écran ou une table, c'est qu'on a sauté l'étape.
3. **Confronter à l'existant.** Le thème contredit-il une spécification
   `ACTIVE` (ch. 13) ? Est-il déjà couvert par une exigence dont
   l'implémentation a dérivé — auquel cas c'est un **écart d'audit** (ch. 14),
   pas une fonctionnalité nouvelle ? Cette étape évite de spécifier deux fois
   la même chose, sous deux noms.
4. **Proposer.** Rédiger la modification de spécification, statut
   `PROPOSITION`, et la faire entrer dans le circuit normal : consultation,
   arbitrage, passage `ACTIVE`.

## Ce que le cadrage ne fait pas

Il **cadre, il ne décide pas**. La proposition qu'il produit n'a aucune
autorité tant qu'elle n'est pas actée par le circuit d'arbitrage. Confondre
les deux — traiter une proposition cadrée comme une décision — est la manière
la plus courante de court-circuiter la consultation sans le vouloir.
