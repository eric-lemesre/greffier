# ADR-0015 — Rassembler le vocabulaire outillé dans un lexique bilingue

**Statut** : Accepté
**Date** : 2026-08-20
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-13, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~lexique-bilingue~1`

Les termes que les portes reconnaissent — statuts de spécification, niveaux
normatifs, verdicts d'audit, gravités, sévérités, étiquettes de forge,
commandes de consultation, intitulés de sections lues — vivent dans un fichier
unique, `tools/lexique.sh`, qui déclare pour chaque terme sa forme française
et sa forme anglaise. Les portes le sourcent et interrogent le terme par sa
clé ; aucune n'écrit un de ces mots en dur.

Le réglage `LEXIQUE_LANGUE`, figé par `tools/init.sh` selon `--langue`, décide
des formes reconnues : `fr` ou `en` n'en reconnaissent qu'une, `fr-en` (défaut)
accepte les deux par alternance. Un terme identique dans les deux langues se
déclare quand même.

Covers:
- req~lexique-outille~1

## Contexte

L'ADR-0009 a rendu la langue du dépôt arbitrable, mais son périmètre s'arrête
aux artefacts **générés** : README, squelettes, registres, jeu de modèles. Le
vocabulaire que les contrôles **lisent** est resté français. Tant que le
gabarit n'avait que trois contrôles — parité des modèles, section de
vérification, cohérence de version — la question ne se posait pas : aucun ne
lit de terme métier.

La transposition des mécaniques d'ergonomia change l'échelle. Une porte qui
cherche `ACTIVE` dans un en-tête, `conforme` dans un tableau d'audit,
`à-tester` sur une issue ou `haute` dans une fiche de revue impose la langue du
gabarit à tout projet instancié — y compris celui qui a choisi `--langue en`,
et dont les portes deviendraient alors silencieusement inopérantes.

## Décision

Un lexique unique, sourcé par les portes, figé à l'instanciation.

Le point capital est le **silence** : une porte qui cherche un terme français
dans un dépôt anglophone ne produit pas d'erreur — elle ne trouve rien, donc
ne signale rien. Un audit sans verdict reconnu compte zéro écart ; un suivi de
revue sans sévérité reconnue ne voit aucun constat. C'est l'anti-pattern
« contrôle no-op » du chapitre 4 dans sa forme la plus insidieuse, puisqu'il
naît d'un choix légitime de l'instanciateur.

## Alternatives écartées

### Laisser chaque porte porter ses mots en dur

Ce qui existait. Chaque porte devient un point de traduction oublié, et rien
ne signale l'oubli — la porte se contente de ne plus rien voir.

### Traduire les portes par jeux de scripts séparés

Un `tools/fr/` et un `tools/en/`. Double la surface de maintenance, fait
diverger la logique des deux côtés, et rend intenable le mode bilingue où les
deux vocabulaires doivent coexister.

### Externaliser dans un fichier de données (JSON, INI)

Ajoute un analyseur à écrire en shell POSIX pour un gain nul : le lexique est
déjà un fichier de déclarations, et le sourcer est gratuit.

## Conséquences

- Ce que cela apporte : une porte se traduit en ajoutant une ligne au lexique ;
  le mode bilingue est gratuit ; un terme manquant est détecté par un contrôle
  de complétude au lieu de produire un silence.
- Ce que cela coûte : toute porte nouvelle doit passer par le lexique — une
  discipline que la revue doit tenir, aucun outil ne détectant un mot écrit en
  dur. Les identifiants techniques (types d'items, tags, noms de fichiers)
  restent en anglais et hors lexique, conformément à l'ADR-0005.
- Ce que cela ferme : rien. Une troisième langue s'ajoute en étendant
  `lex_def` et le réglage, sans toucher aux portes.

## Vérification

`tools/checks.sh` échoue si un terme déclaré n'a pas ses deux formes.
`tools/gouvernance-test.sh` vérifie qu'en langue `en`, un verdict d'audit resté
français fait échouer la porte concernée — c'est le cas d'échec qui prouve que
le lexique commande réellement les contrôles.

## Références

- Registre des décisions : D-2026-08-13.
- ADR-0005 (politique linguistique du gabarit), ADR-0009 (langue arbitrable) :
  cet ADR en étend le périmètre au vocabulaire lu par les portes.
