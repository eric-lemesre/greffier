# ADR-0017 — Constater le périmètre de la porte plutôt que le déclarer

**Statut** : Accepté
**Date** : 2026-08-20
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-15, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~perimetre-constate~1`

`tools/perimetre.sh` déduit du changement réel la voie à emprunter et
l'imprime : `docs` ou `complet`. L'empreinte est prise large — commits depuis
la base de fusion, index, arbre de travail **et fichiers non suivis**. Le
classement est une liste blanche : un chemin qui n'y figure pas impose la voie
complète, comme l'absence de base de fusion et l'empreinte vide.

`tools/ci.sh` est le point d'entrée unique qui consomme ce verdict. Les
façades — Taskfile, justfile, CI GitHub, CI GitLab — y délèguent sans
redéclarer d'étapes.

Covers:
- req~perimetre-constate~1

## Contexte

La transposition des portes d'ergonomia porte la vérification complète à une
dizaine de scripts, dont sept tests qui créent chacun des dépôts git jetables.
Sur un changement purement documentaire — corriger une phrase de la méthode —
payer ce prix décourage l'exécution locale de la porte, et une porte qu'on
n'exécute pas ne protège personne.

La tentation naturelle est de laisser le contributeur déclarer son périmètre
(« c'est de la doc, voie rapide »). C'est un contrôle qui passe toujours dès
que le jugement se trompe, et le jugement se trompe précisément dans les cas
qui comptent.

## Décision

Le périmètre est **constaté**, jamais déclaré, et le doute tranche toujours en
faveur de la voie complète.

Le point le plus important est la prise en compte des **fichiers non suivis**.
`git diff` ne voit pas un fichier jamais ajouté à l'index : sur ergonomia, un
nouveau script d'outillage échappait ainsi au classement, et un changement
d'outillage passait pour de la documentation. C'est l'angle mort le plus
coûteux de ce mécanisme, parce qu'il ne se manifeste par aucune erreur.

## Alternatives écartées

### Déclaration par le contributeur, ou par étiquette de pull request

Rapide à mettre en place, faux dès le premier oubli, et invérifiable : rien ne
dit qu'une étiquette « docs » décrit le diff qu'elle accompagne.

### Voie complète toujours

Sûr, et c'est le comportement de repli. Comme régime permanent, il rend la
porte locale si lente qu'elle finit contournée — un coût réel, simplement
déplacé.

### Cache de résultats par empreinte de contenu

Plus fin, mais introduit un état à invalider, donc une classe entière de
défauts silencieux (« la porte a passé, mais sur l'empreinte d'hier »). Hors
de proportion avec le gain.

## Conséquences

- Ce que cela apporte : la porte reste exécutable en quelques secondes sur un
  changement documentaire, sans jamais relâcher la vérification sur le reste.
- Ce que cela coûte : une liste blanche à tenir. Un chemin oublié coûte une
  porte complète — quelques minutes ; un chemin ajouté à tort laisse passer un
  défaut. L'asymétrie est délibérée et rappelée dans le point d'extension.
- Ce que cela ferme : rien. Un projet peut ajouter ses propres voies en
  étendant le classement et `tools/ci.sh`.

## Vérification

`tools/perimetre-test.sh` éprouve six cas, dont quatre négatifs : outillage
modifié, fichier non suivi, façade CI modifiée, empreinte vide, absence de base
de fusion — tous doivent produire `complet`.

## Références

- Registre des décisions : D-2026-08-15.
- ADR-0007 (portes en scripts, orchestrateur en façade) : `tools/ci.sh` en est
  l'application directe — la logique d'aiguillage vit dans un script, pas dans
  une façade.
