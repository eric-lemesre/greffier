# 1. Expression du besoin


Tout commence par un besoin exprimé — ou par une intention de besoin, quand
l'expression est incomplète. Ce chapitre définit comment le capturer avant
d'écrire la moindre exigence.

## L'artefact

Un besoin est un item OpenFastTrace de type **feat** dans `spec/01-besoins/`,
rédigé depuis le modèle `templates/fr/need.md`. Il capture :

- **le besoin** : ce que le porteur veut obtenir, en langage métier, sans
  solution technique ;
- **le porteur** : qui l'exprime et qui arbitrera les questions ouvertes qui en
  découleront ;
- **la justification** (Rationale) : pourquoi ce besoin existe, quelle valeur
  il produit — c'est elle qui permettra de servir *l'intention* quand le texte
  sera muet ;
- **la déclinaison attendue** : `Needs: req` — un besoin non décliné en
  exigences est visible comme orphelin dans la traçabilité.

La forme « user story » (En tant que… je veux… afin de…) est admise ici comme
matériau d'entrée ; elle ne vaut jamais exigence.

## Règles

1. Un besoin décrit un problème ou un résultat, jamais une solution. « Le
   système utilise PostgreSQL » n'est pas un besoin ; « les données survivent à
   un redémarrage » en est un.
2. Un besoin sans justification est renvoyé à son porteur : sans le pourquoi,
   impossible d'arbitrer les cas non prévus.
3. Quand l'expression est floue ou contradictoire, on n'« interprète » pas en
   silence : on ouvre une [question ouverte](06-questions-ouvertes.md) et le
   porteur tranche. L'interprétation retenue devient un ADR si elle engage la
   conception.
4. Les sources brutes (comptes-rendus, courriels, documents client) sont
   archivées dans `spec/01-besoins/sources/` : l'exigence doit pouvoir être
   confrontée à sa source d'origine.

## Critères de sortie

Un besoin entre en déclinaison quand : il a un identifiant feat, un porteur
nommé, une justification, et qu'aucune question ouverte bloquante ne le
concerne.
