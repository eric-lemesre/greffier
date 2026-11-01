# 3. Décisions et ADR

La charte complète du registre (quand écrire un ADR, conventions, cycle de vie,
niveaux d'enjeu S/F/É) est dans [`docs/adr/README.md`](../adr/README.md) — elle
fait foi. Ce chapitre précise l'articulation avec le reste de la méthode.

## La décision dans la chaîne de traçabilité

Quand une exigence appelle une conception (`Needs: dsn`), c'est un ADR qui la
fournit : l'ADR porte un item de type **dsn** qui couvre l'exigence. La
décision entre ainsi dans la matrice — une exigence structurante sans décision
tracée est un défaut détecté par l'outil, pas par la mémoire du relecteur.

```markdown
## Item de conception

`dsn~nom-de-la-decision~1`

Résumé opérationnel de la décision, en une ou deux phrases.

Covers:
- req~exigence-motivante~1
```

Toutes les décisions ne couvrent pas une exigence (choix d'intendance,
outillage) : un ADR sans item dsn est légitime. L'inverse — un item dsn hors
ADR — ne l'est pas.

Quand un ADR est remplacé, son item de conception suit la décision en
vigueur : l'ADR remplaçant porte l'item (révision incrémentée si l'exigence a
elle-même changé de révision), et la définition d'item est retirée de l'ADR
remplacé au profit d'une note de renvoi — la prose historique, elle, reste
intacte. La matrice trace le présent ; les ADR tracent l'histoire.

## Trois circuits selon l'enjeu

- **S (structurant)** : séance avec les parties prenantes, relevé de décision
  figé (modèle `templates/fr/decision-record.md`), entrée au
  [registre](../decisions/registre.md), puis ADR.
- **F (fonctionnel)** : consultation asynchrone (issue ou question ouverte),
  décision du responsable de domaine, ADR si structurant pour le code.
- **É (éditorial)** : la pull request suffit.

En consultation asynchrone, le silence à l'échéance vaut absence d'objection,
jamais approbation : la décision reste portée par celui qui la prend.

## Hygiène des décisions

- Un ADR accepté est immuable ; le remplacer, jamais le retoucher (seul l'index
  et le statut changent).
- Les alternatives écartées sont rédigées avec le même sérieux que la décision :
  c'est elles qui éviteront de rejouer le débat dans six mois.
- La section Vérification répond à une seule question : *comment saura-t-on que
  la décision est tenue ?* Si la réponse honnête est « on fera attention »,
  la décision n'est pas finie — il manque sa porte.
