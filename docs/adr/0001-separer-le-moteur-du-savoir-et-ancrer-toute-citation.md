# ADR-0001 — Séparer le moteur du savoir et ancrer toute citation dans un texte authentique

**Statut** : Accepté
**Date** : 2026-11-01
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-02 au registre
**Portée** : durable

## Item de conception

`dsn~trois-couches-et-ancrage~1`

Le système se compose de trois couches — textes authentiques immuables et
versionnés, wiki de situations compilé par un agent sous schéma, recherche
hybride — et ne rend jamais un élément qui ne porte pas l'identifiant
officiel d'un texte de la première couche. Le moteur (ce dépôt) et le
savoir (un dépôt de texte séparé) sont deux objets distincts.

Covers:

- req~citation-ancree~1
- req~textes-authentiques-versionnes~1
- req~moteur-separe-du-savoir~1

## Contexte

Citer un texte est ce qu'un modèle de langue fait le plus mal : il produit
un article de code plausible et inexistant, et son lecteur ne peut pas s'en
apercevoir. Un premier client de ce moteur, un outil de conciliation de
justice, avait tiré la conséquence dès 2026 : sa recherche juridique ne
passe jamais par un modèle, et reste adossée à un catalogue tant qu'aucune
source documentaire n'est branchée. Greffier est cette source.

Le public visé cherche la règle applicable à une situation de la vie
courante, dans ses mots à lui ; les textes, eux, sont écrits dans ceux du
droit. Il faut donc, entre les textes et la question, une couche qui fasse
le pont, et cette couche est une œuvre de doctrine qui engage une
responsabilité éditoriale.

Le motif « LLM wiki » (sources brutes immuables, wiki Markdown compilé par
un agent selon un schéma écrit, index, journal, vérification de cohérence)
fournit la discipline de cette couche. Il est conçu pour un usage
personnel ; sa transposition à un savoir collectif et juridique exige une
gouvernance, un format de page et un critère de péremption qui lui sont
propres.

## Décision

1. **Trois couches.** La couche 1 contient les textes authentiques
   (articles, décisions), identifiés par leur identifiant officiel et
   versionnés dans le temps ; rien n'y est écrit par un modèle. La couche 2
   est un wiki de situations et de pratique, compilé par un agent-curateur
   sous un schéma, relu et validé par un référent humain nommé au journal.
   La couche 3 est une recherche hybride, lexicale d'abord, sémantique
   ensuite, sur les deux premières.
2. **Ancrage.** Toute affirmation normative d'une page de la couche 2 cite
   un texte de la couche 1 ; tout élément rendu par la recherche porte un
   identifiant de la couche 1. Le modèle de langue n'intervient qu'en
   reformulation de la question vers l'index et en résumé d'extraits qu'il
   cite ; il n'écrit jamais une référence.
3. **Séparation.** Le moteur (ingestion, index, recherche, vérification,
   interfaces) vit dans ce dépôt ; le savoir (sources brutes, pages
   compilées, schéma du curateur, banc de questions) vit dans un dépôt
   distinct qui ne contient aucun code, afin que des juristes non
   développeurs puissent le tenir et que toute communauté puisse avoir le
   sien.
4. **Péremption par version.** Une page est périmée quand un texte qu'elle
   cite a changé de version, quel que soit son âge ; seules les pages
   touchées se recompilent, avec trace au journal.
5. **Cloisonnement.** Le savoir ne contient que des sources publiques et des
   cas types fictifs ; une consultation portant sur une personne ou un
   dossier réel reste hors du savoir ; rien ne remonte d'une consultation
   vers le wiki.
6. **Transparence.** Toute page et toute réponse portent leurs sources, la
   date de vérification des textes cités et la mention « aide documentaire,
   sans valeur d'avis » ; aucune ne conclut sur le fond d'un litige concret.

## Alternatives écartées

### Un modèle de langue avec recherche augmentée (RAG) sur les textes

Retrouver des fragments à chaque question et laisser le modèle synthétiser.
Rien ne s'accumule, et surtout la citation reste écrite par le modèle : la
référence plausible et fausse n'est pas exclue, seulement moins fréquente.
L'ancrage exige que la référence vienne de l'index, jamais du modèle.

### Un wiki tenu à la main par des juristes

La valeur est là, mais le coût d'entretien (liens croisés, mises à jour,
cohérence entre des centaines de pages) est ce qui fait abandonner tous les
wikis d'équipe. L'agent-curateur porte ce coût ; le juriste garde le
jugement : il valide, il ne compile pas.

### Moteur et savoir dans un même dépôt

Plus simple au départ, mais le savoir devient dépendant du moteur, sa
licence devient une licence logicielle, et un juriste doit traverser du
code pour corriger une page. La séparation est ce qui permet plusieurs
dépôts de savoir sur un moteur.

## Conséquences

- Ce que cela apporte : une erreur de citation devient détectable (l'élément
  sans identifiant est refusé par la porte) ; le savoir est portable,
  versionnable, relisible par des non-développeurs ; le moteur sert
  plusieurs communautés.
- Ce que cela coûte : un connecteur aux sources officielles avec gestion
  des versions ; une gouvernance éditoriale réelle (référents nommés) ; un
  banc de questions pour mesurer rappel et précision.
- Ce que cela ferme : la génération « libre » de références par un modèle,
  même pour dépanner ; l'ingestion de dossiers réels dans le savoir.

## Vérification

- La porte de traçabilité relie chaque exigence de ce domaine à cet ADR
  (`dsn~trois-couches-et-ancrage~1`).
- À la première livraison du moteur : un test d'intégration qui soumet un
  élément sans identifiant officiel et vérifie son refus ; un test qui
  vérifie qu'une page du savoir citant un identifiant absent de `raw/` est
  refusée par `vérifier`.
- Le dépôt de savoir n'a pas de répertoire de code : vérifié par sa propre
  CI, qui n'installe le moteur que pour se faire vérifier.

## Références

- `spec/01-besoins/recherche-juridique.md`,
  `spec/02-exigences/01-ancrage.md`.
- Loi n° 71-1130 du 31 décembre 1971, art. 54 et suivants (consultation
  juridique).
- Licence ouverte Etalab (Légifrance) ; conditions d'utilisation de l'API
  Judilibre.
