# ADR-0018 — Porter le statut de cycle de vie au niveau de l'exigence

**Statut** : Accepté
**Date** : 2026-08-20
**Décideur** : Éric Lemesre — arbitrage de l'écart d'audit (voir D-2026-08-17, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~statut-par-exigence~1`

Le statut de cycle de vie est porté par **l'exigence**, une ligne
`**Statut : …**` sous son identifiant, au vocabulaire du lexique (ADR-0015).
Il se lit sur deux parts :

- **déclarée** — brouillon, proposée, approuvée, rejetée, dépréciée : du
  jugement, que seul un humain rend ;
- **calculée** — implémentée, vérifiée : dérivées de la couverture réellement
  posée dans le dépôt, jamais écrites à la main. La porte refuse qu'on les
  déclare.

Le statut de **domaine** (ADR-0016, méthode ch. 13) subsiste sur un axe
**orthogonal** : il dit si le document est arbitré, non où en est la
réalisation d'une exigence. Une règle de compatibilité les empêche de
diverger : une exigence ne peut être approuvée que dans un domaine actif.

Le dénominateur des taux d'audit et de classification se calcule désormais à
la granularité de l'exigence : approuvée et au-delà comptent, le reste non.

Covers:
- req~cycle-de-vie-exigence~2

## Contexte

L'audit de réalisation, mis en place le jour même, a révélé un écart de
fondation : `req~cycle-de-vie-exigence~1` réclamait depuis toujours un statut
par exigence, et le dépôt n'a jamais connu que le statut de domaine. L'écart
n'était pas une régression — il n'avait simplement jamais eu de témoin, ce qui
est précisément ce que l'audit sert à produire.

Deux issues étaient ouvertes : entériner la pratique en abaissant l'exigence
au niveau du domaine, ou tenir l'exigence et l'outiller. L'arbitrage a retenu
la seconde.

## Décision

Le statut vit au niveau de l'exigence, et il est **partiellement calculé**.

Ce partage est le cœur de la décision. Un statut entièrement déclaré aurait
reproduit le défaut que la méthode combat : une exigence marquée « vérifiée »
que plus aucun test ne couvre ne se signale par rien, et le tableau qui la
compte inspire d'autant plus confiance qu'il affiche un chiffre. En calculant
l'avancement depuis les tags réellement posés, on obtient un statut qui ne peut
pas mentir sur sa moitié la plus contestable.

La conservation du statut de domaine mérite d'être justifiée, puisque le
chapitre 11 met en garde contre deux systèmes d'état sur un même objet. Il n'y
en a pas deux ici : le domaine et l'exigence sont deux **objets** distincts,
avec deux questions distinctes. Le risque de divergence est réel, et c'est
pourquoi il est refermé mécaniquement plutôt que par une consigne.

## Alternatives écartées

### Abaisser l'exigence au niveau du domaine

Le moins coûteux : la pratique l'appliquait déjà, il suffisait de récrire
l'énoncé. Écarté parce que le domaine est une granularité trop grossière pour
la question posée. Un domaine actif contient des exigences approuvées mais non
réalisées, d'autres livrées et prouvées : les compter ensemble revient à ne
plus rien pouvoir dire de l'avancement — et c'est justement le chiffre que le
tableau de bord d'audit prétend donner.

### Statut entièrement déclaré, jusqu'à « vérifiée »

Simple à mettre en œuvre, et faux dès le premier oubli. Un statut d'avancement
saisi se périme au premier refactoring ; rien ne le rattrape. C'est
l'anti-pattern « agrégat saisi » du chapitre 4, ajouté deux heures plus tôt.

### Statut entièrement calculé

Séduisant, mais impossible : « approuvée » traduit une décision humaine
qu'aucun tag ne porte. Le calculer supposerait de dériver l'approbation de la
présence de code, c'est-à-dire de déclarer approuvé ce qui est fait — l'exact
renversement du sens de la chaîne.

### Supprimer le statut de domaine

Cohérent avec « un seul système d'état », mais perdrait l'acte d'arbitrage :
le domaine actif est adossé à une décision du registre, et c'est ce qui
empêche un document de gagner le dénominateur d'un trait de plume.

## Conséquences

- Ce que cela apporte : un avancement lisible exigence par exigence, dont la
  moitié calculée ne peut pas mentir ; un dénominateur à la bonne granularité.
- Ce que cela coûte : une ligne de statut sur chaque exigence, et une règle de
  compatibilité de plus à tenir. Le calcul de l'avancement lit les tags du
  dépôt, ce qui suppose que le périmètre scanné par la porte suive celui de la
  traçabilité.
- Ce que cela ferme : l'idée d'un statut d'exigence entièrement déclaratif.
  Toute évolution devra préserver le partage déclaré/calculé.

## Vérification

`tools/statuts.sh` échoue si une exigence n'a pas de statut, si elle déclare un
statut calculé, ou si elle est approuvée dans un domaine en proposition.
`tools/gouvernance-test.sh` éprouve ces trois cas, plus le calcul de
l'avancement sur une exigence taguée et sur une exigence orpheline.

## Références

- Registre des décisions : D-2026-08-17.
- Exigence : `req~cycle-de-vie-exigence~2` (révision 2 — l'énoncé initial
  réclamait le statut sans en définir ni le vocabulaire, ni le partage
  déclaré/calculé, ni l'articulation avec le domaine).
- ADR-0015 (lexique), ADR-0016 (audit de réalisation) : inchangés.
