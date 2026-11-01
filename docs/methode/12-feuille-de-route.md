# 12. Feuille de route

<!-- [impl->req~feuille-de-route-outillee~1] -->

La feuille de route dit **ce qui est en cours, ce qui vient, ce qui est
soldé** — à l'échelle du chantier, pas de l'issue. Les issues coordonnent le
travail au jour le jour (ch. 11) ; une fiche de feuille de route porte un
chantier qui traverse plusieurs issues et plusieurs versions.

## Une fiche par chantier

`docs/todo/todo-NNNN-titre.md`, depuis le modèle
[`templates/fr/roadmap-card.md`](../../templates/fr/roadmap-card.md). Chaque
fiche porte, en tête, une ligne de statut :

```markdown
**Statut : 🚧 en cours**
```

Trois pastilles, et rien d'autre : ✅ soldé, 🚧 en cours, ⏳ à venir. Le
libellé (« Statut » / « Status ») vient du lexique, la pastille n'a pas besoin
de traduction.

## L'index est dérivé, jamais tenu

`docs/todo/README.md` est **généré** par `tools/todo.sh --ecrire` et protégé
par la porte anti-dérive (ch. 4). Le retoucher à la main fait échouer la
vérification.

Cette contrainte vient d'un défaut réel : sur ergonomia, sept lignes de
l'index annonçaient « à venir » ou « en cours » des jalons livrés depuis des
semaines. Le même jour, les statuts de spécification présentaient la même
dérive. Un index tenu à la main finit toujours par mentir — non par
négligence, mais parce que rien ne rappelle de le mettre à jour au moment où
la fiche change. Le générer supprime la classe entière de défauts.

## Ce qu'une fiche doit contenir

- **Le pourquoi**, en deux phrases : le chantier qu'on rouvre dans six mois
  sans savoir pourquoi il existait est un chantier perdu.
- **Ce qui reste à faire**, explicitement — y compris « rien », quand le lot
  est refermé. Une section vide ne se distingue pas d'une section oubliée.
- **Les renvois** vers les exigences, ADR et issues concernés.

Ce qu'elle ne contient pas : le détail d'exécution (il vit dans les issues),
ni les décisions (elles vivent dans les ADR et les relevés).

## Solder une fiche

Passer la pastille à ✅ et vider la section « reste à faire ». La fiche
**reste** : elle documente ce qui a été fait et pourquoi. Une feuille de route
dont on supprime les lignes soldées perd sa seule valeur rétrospective.
