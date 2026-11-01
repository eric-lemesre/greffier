# ADR-0008 — Rendre la politique d'attribution des agents arbitrable à l'instanciation

**Statut** : Remplacé par [ADR-0011](0011-declaration-ia-obligatoire-par-defaut.md)
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-06, registre des décisions)
**Portée** : durable

## Item de conception

*Item de conception repris en révision 2 par l'ADR-0011 (la traçabilité suit
la décision en vigueur ; la prose ci-dessous reste le texte d'origine).*

L'interdiction des mentions d'agents IA dans les commits (règle R0) est la
politique **par défaut** du gabarit, pas une constante : le script
d'instanciation demande l'arbitrage (option `--attribution-agents
autorisee|interdite`, interdiction en l'absence de choix), et applique la
décision mécaniquement — le bloc de contrôle du hook commit-msg, délimité par
des marqueurs, est conservé ou retiré, et la règle R0 d'AGENTS.md est
reformulée en conséquence.

## Contexte

Le gabarit héritait telle quelle la règle des dépôts de référence : aucune
mention d'agent ni de co-auteur généré dans l'historique. C'est un choix
d'éditorialisation de l'historique, pas une exigence de qualité : certaines
organisations imposent au contraire la transparence sur l'outillage IA. Le
porteur a tranché : la politique doit être à la discrétion de l'instanciateur.

## Décision

La politique devient un paramètre d'instanciation, arbitré une fois,
appliqué par l'outillage dans les deux cas (une politique non outillée n'est
pas une politique, R3), et modifiable ensuite comme toute décision : par ADR
du projet. Le défaut reste l'interdiction : c'est le comportement le plus
conservateur et celui des dépôts d'origine.

## Alternatives écartées

### Conserver l'interdiction en dur

Impose aux projets qui veulent la transparence de patcher hook et contrat à la
main, sans trace de décision.

### Ne rien vérifier du tout

Laisser la politique purement déclarative supprime le garde-fou pour les
projets qui interdisent — la règle deviendrait un vœu (contraire à R3).

### Fichier de configuration lu par le hook

Une indirection de plus à maintenir pour un choix binaire fait une seule
fois ; l'édition du hook par init.sh est plus simple et laisse un dépôt
sans machinerie morte.

## Conséquences

- Ce que cela apporte : le gabarit ne fige plus un choix éditorial ; chaque
  projet a une politique explicite, outillée, décidée à la création.
- Ce que cela coûte : le bloc du hook doit rester délimité par ses marqueurs
  pour que le retrait reste fiable ; deux chemins à tester (fait dans
  init-test).
- Ce que cela ferme : rien — un projet peut inverser sa politique plus tard
  par ADR, en restaurant ou retirant le bloc.

## Vérification

`tools/init-test.sh` vérifie mécaniquement les deux branches : instanciation
par défaut → le hook refuse toujours un Co-Authored-By ; instanciation avec
`--attribution-agents autorisee` → le hook l'accepte et la règle R0
d'AGENTS.md est reformulée. Le gabarit lui-même conserve l'interdiction (R0
inchangée ici).

## Références

- Registre des décisions : D-2026-08-06.
- Exigence : req~politique-attribution-agents~1 (`spec/02-exigences/gouvernance.md`).
- Hook : `tools/hooks/commit-msg.sh` (marqueurs `politique-attribution`).
