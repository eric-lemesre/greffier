# Exigences — domaine ingénierie des exigences

**Statut : ACTIVE** — domaine acté le 2026-08-20 (D-2026-08-16). Le statut commande
le dénominateur des taux d'audit et de classification (méthode, ch. 13).

## Expression du besoin formalisée

`req~expression-du-besoin~1`

**Statut : approuvée**

Le dépôt DOIT fournir un format d'expression de besoin (artefact de type feat)
qui capture le besoin, sa justification et son porteur, et que les exigences
référencent explicitement.

Critères d'acceptation :

- Étant donné un besoin exprimé, quand une exigence le décline, alors la
  relation besoin→exigence est déclarée dans l'exigence et vérifiée par l'outil
  de traçabilité.

Covers:
- feat~ingenierie-des-exigences~1

Needs: impl, mtest

## Rédaction selon EARS

`req~format-exigence-ears~1`

**Statut : approuvée**

Chaque exigence DOIT être rédigée selon l'un des cinq motifs EARS (ubiquitaire,
événementiel, à état, comportement indésirable, fonctionnalité optionnelle),
porter un niveau normatif DOIT/DEVRAIT/PEUT et des critères d'acceptation en
forme Étant donné / Quand / Alors.

Rationale:
EARS contraint doucement la langue naturelle et élimine l'essentiel des
ambiguïtés sans imposer un formalisme lourd ; les critères d'acceptation
préparent directement les tests mécanisés.

Covers:
- feat~ingenierie-des-exigences~1

Needs: dsn, impl, utest, mtest

## Cycle de vie des exigences

`req~cycle-de-vie-exigence~2`

**Statut : approuvée**

Chaque exigence DOIT porter, dans son texte, un statut de cycle de vie pris au
lexique. Les statuts qui relèvent du jugement — brouillon, proposée,
approuvée, rejetée, dépréciée — DOIVENT être déclarés ; ceux qui expriment un
avancement — implémentée, vérifiée — DOIVENT être calculés depuis la
couverture réelle et NE DOIVENT jamais être déclarés. Une exigence NE DOIT
être approuvée que dans un domaine actif, et seules les exigences approuvées
ou au-delà entrent au dénominateur des taux. Seule la révision de
l'identifiant change quand le fond de l'exigence change.

Rationale:
Un statut d'exigence répond à « où en est celle-ci ? », un statut de domaine à
« ce document est-il arbitré ? » : deux axes orthogonaux, que confondre revient
à ne plus pouvoir dire d'une exigence approuvée depuis six mois si quoi que ce
soit la réalise. Le partage déclaré/calculé applique la règle du chapitre 4 —
un avancement se calcule, il ne se saisit pas : un statut « vérifiée » écrit à
la main est exactement le genre de chiffre faux qui inspire plus confiance
qu'une absence de chiffre. La règle de compatibilité avec le statut du domaine
est ce qui empêche les deux axes de diverger en silence.

Critères d'acceptation :

- Étant donné une exigence sans ligne de statut, quand la porte s'exécute,
  alors elle échoue.
- Étant donné une exigence déclarant « implémentée » ou « vérifiée », quand la
  porte s'exécute, alors elle échoue : ces statuts se calculent.
- Étant donné une exigence approuvée dans un domaine en proposition, quand la
  porte s'exécute, alors elle échoue.
- Étant donné une exigence approuvée que rien ne tague, quand l'avancement est
  calculé, alors elle n'est ni implémentée ni vérifiée, et le tableau de bord
  le montre.
- Étant donné une exigence dont le texte normatif change, quand elle est
  republiée, alors sa révision est incrémentée et les couvertures pointant
  l'ancienne révision sont signalées obsolètes par l'outil de traçabilité.

Covers:
- feat~ingenierie-des-exigences~1

Needs: dsn, impl, utest, mtest

`req~questions-ouvertes~1`

**Statut : approuvée**

Lorsqu'un contributeur (humain ou agent) est bloqué par une ambiguïté du besoin
ou un conflit de règles, il DOIT ouvrir une question ouverte structurée
(contexte, options, recommandation, décision, statut) plutôt que de trancher
seul ou de contourner la règle.

Rationale:
Protocole repris de wallos-rs : c'est le mécanisme qui permet de servir
« l'intention du besoin » sans inventer — l'agent propose, l'humain arbitre, la
décision est tracée.

Covers:
- feat~ingenierie-des-exigences~1

Needs: impl, mtest
