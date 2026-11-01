# 6. Questions ouvertes

Le protocole qui remplace l'interprétation silencieuse : quand un contributeur
— humain ou agent — rencontre une ambiguïté du besoin, un conflit de règles ou
une décision qui ne lui appartient pas, il **s'arrête et demande**, dans une
forme qui rend l'arbitrage rapide.

## Le registre

`spec/open-questions.md`, entrées OQ-NNN numérotées en continu. Une question
résolue reste au registre avec sa décision : le registre est aussi la mémoire
des arbitrages.

## Format d'une entrée

- **Bloque** : le ou les identifiants d'exigence (ou d'ADR) bloqués.
- **Contexte** : ce qui rend la décision nécessaire — deux phrases, pas une
  page.
- **Options** : au moins deux options réelles, avec leurs conséquences ; une
  question sans options est une délégation de travail, pas une question.
- **Recommandation** : celle du demandeur, motivée. Un agent IA recommande
  toujours — c'est l'humain qui décide, mais l'agent instruit le dossier.
- **Décision** : remplie par l'arbitre (le porteur du besoin ou le décideur du
  domaine), avec renvoi vers l'ADR si la décision engage la conception.
- **Statut** : open → resolved. Les compléments postérieurs se font par
  addendum daté, jamais par réécriture.

## Règles

1. **Bloqué = arrêté.** On ne contourne pas une règle du contrat d'agents et on
   ne choisit pas à la place du porteur ; on livre ce qui n'est pas bloqué et
   on documente le blocage.
2. Une question ouverte n'est pas un ticket : elle appelle une décision, pas
   une réalisation. Si du travail en découle, il redevient exigence ou tâche.
3. L'arbitrage rendu vaut pour le cas générique, pas pour l'instance : si la
   même question revient, c'est que la décision n'a pas été généralisée en ADR
   ou en exigence — le faire à la deuxième occurrence.
4. Les statuts des exigences bloquées restent en brouillon (Status: draft) le
   temps de l'arbitrage : elles sortent du dénominateur de couverture sans
   disparaître.
