# Exigences — domaine ancrage

**Statut : PROPOSITION** — passe ACTIVE quand une décision du registre l'acte.

Ce domaine pose ce qui fait Greffier : rien n'est rendu sans texte
authentique. Les domaines suivants (ingestion, wiki, recherche, interfaces)
viendront avec leurs lots. Convention : une exigence non encore réalisée ne
déclare que la couverture qui existe (`Needs: dsn` quand un ADR la couvre) ;
les couvertures de réalisation (`impl`, `utest`, `itest`) s'ajoutent à son
`Needs:` avec le lot qui les livre, et la porte de classification les compte
« à planifier » d'ici là.

## Tout élément rendu porte l'identifiant d'un texte authentique

`req~citation-ancree~1`

**Statut : proposée**

Le système DOIT rendre uniquement des éléments de réponse qui portent
l'identifiant officiel d'un texte ou d'une décision présent dans la couche
des textes authentiques (`LEGIARTI…`, `LEGITEXT…`, `ECLI…`), et DOIT refuser
tout élément qui n'en porte pas, y compris s'il provient d'un modèle de
langue.

Rationale:
C'est la seule manière de rendre une erreur de citation détectable par le
lecteur.

Critères d'acceptation :

- Étant donné une réponse candidate dont un élément ne porte aucun
  identifiant, quand la recherche la rend, alors l'élément est écarté et
  le refus est journalisé.
- Étant donné un identifiant absent de la couche des textes, quand un
  élément le cite, alors l'élément est écarté.

Covers:

- feat~recherche-ancree~1
- feat~source-pour-agents~1

Needs: dsn

## Les textes authentiques sont immuables et versionnés dans le temps

`req~textes-authentiques-versionnes~1`

**Statut : proposée**

Le système DOIT conserver chaque texte authentique avec son identifiant
officiel, sa source, sa version (en vigueur du / au) et sa date de capture ;
il NE DOIT PAS modifier un texte conservé, ni en écrire un à partir d'un
modèle de langue ; quand une nouvelle version d'un texte paraît, le système
DOIT la conserver à côté des précédentes.

Critères d'acceptation :

- Étant donné un article conservé en deux versions, quand on demande le
  droit applicable à une date, alors la version en vigueur à cette date
  est rendue, et elle seule.
- Étant donné une tentative d'écriture dans la couche des textes par le
  curateur, quand elle survient, alors elle est refusée.

Covers:

- feat~recherche-ancree~1
- feat~savoir-de-situations~1

Needs: dsn, impl, utest, itest

## Les textes authentiques sont capturés depuis leur source officielle, par leur identifiant

`req~capture-des-sources-officielles~1`

**Statut : proposée**

Le système DOIT capturer un article de Légifrance ou une décision de
Judilibre par son identifiant officiel, depuis l'API officielle
authentifiée, et DOIT refuser une réponse qui ne porte pas l'identifiant
demandé, son texte ou sa date (de vigueur ou de décision) ; si
l'identifiant demandé est mal formé, alors le système NE DOIT PAS
interroger la source ; les identifiants de l'application NE DOIVENT
apparaître dans aucune sortie.

Rationale:
Un texte capturé sans son identifiant ou sans sa version ne peut plus
ancrer une citation ; un texte écrit de mémoire ou par un modèle n'est pas
un texte authentique.

Critères d'acceptation :

- Étant donné un identifiant d'article valide, quand on le capture, alors
  le fichier conservé porte l'identifiant, l'identifiant chronologique,
  la source, la période de vigueur et la date de capture.
- Étant donné une décision sans ECLI, quand on la capture, alors elle est
  refusée.
- Étant donné une source qui répond par une erreur, quand on la capture,
  alors l'erreur cite l'adresse sans jamais citer la clé.

Covers:

- feat~recherche-ancree~1

Needs: dsn, impl, utest, itest

## Le moteur signale les changements de version d'un article depuis une date

`req~detection-des-versions~1`

**Statut : proposée**

Quand on lui donne un article et une date, le système DOIT signaler toute
version de l'article entrée en vigueur après cette date et toute fin de
vigueur de la version citée postérieure à cette date, et DOIT dire
explicitement quand rien n'a changé.

Rationale:
C'est le matériau de la péremption (`req~peremption-par-version~1`) : une
page vérifiée à une date est à revoir dès que l'un de ses textes a bougé.

Critères d'acceptation :

- Étant donné un article qui a une version entrée en vigueur après la
  date, quand on constate, alors cette version est signalée et la
  commande sort en 3.
- Étant donné un article inchangé depuis la date, quand on constate, alors
  « inchangé » est rendu et la commande sort en 0.

Covers:

- feat~savoir-de-situations~1

Needs: impl, utest, itest

## Le code du moteur est vérifiable de bout en bout

`req~chaine-de-verification-du-moteur~1`

**Statut : proposée**

Le système DOIT être construit par une chaîne de compilation épinglée, et
chaque fichier de son code DOIT porter l'en-tête de licence
`SPDX-License-Identifier: EUPL-1.2` ; la CI DOIT refuser un code mal
formaté, un avertissement de lints, un test en échec ou un en-tête absent.

Rationale:
La promesse d'ancrage ne vaut que si l'on peut la vérifier (ADR-0002) : un
moteur public dont la construction n'est pas reproductible ou dont la
licence est ambiguë ne s'audite pas.

Critères d'acceptation :

- Étant donné un fichier Rust sans en-tête de licence, quand la CI
  s'exécute, alors la porte des en-têtes échoue.
- Étant donné une chaîne non épinglée, quand la CI s'exécute, alors la
  porte d'hygiène de compilation échoue.

Covers:

- feat~recherche-ancree~1

Needs: dsn, impl, utest

## Le moteur et le savoir sont deux dépôts distincts, et le savoir ne contient aucun code

`req~moteur-separe-du-savoir~1`

**Statut : proposée**

Le système DOIT lire un dépôt de savoir qui ne contient que du texte
(sources brutes, pages compilées, schéma du curateur, banc de questions)
et DOIT pouvoir en vérifier la cohérence (liens, orphelins, identifiants,
versions périmées) sans qu'aucun programme n'y soit versionné ; les dérivés
de recherche (index, vecteurs, caches) DOIVENT être reconstructibles et NE
DOIVENT PAS être versionnés dans le dépôt de savoir.

Critères d'acceptation :

- Étant donné un dépôt de savoir conforme, quand `vérifier` s'exécute,
  alors il rend un rapport sans modifier aucun fichier.
- Étant donné une page du savoir qui cite un identifiant absent des
  sources brutes, quand `vérifier` s'exécute, alors la page est signalée
  et le rapport est en échec.

Covers:

- feat~savoir-de-situations~1
- feat~source-pour-agents~1

Needs: dsn

## Une page est périmée quand un texte qu'elle cite a changé de version

`req~peremption-par-version~1`

**Statut : proposée**

Quand la vérification constate qu'un texte cité par une page a une version
en vigueur postérieure à la date de vérification de la page, le système
DOIT marquer la page « à recompiler » et DOIT limiter la recompilation aux
pages touchées, avec une trace au journal du savoir.

Covers:

- feat~savoir-de-situations~1

## Aucune donnée d'un dossier réel n'entre dans le savoir

`req~cloisonnement-du-savoir~1`

**Statut : proposée**

Le système DOIT tenir les consultations (questions et réponses portant sur
une personne ou un dossier réel) hors du dépôt de savoir, et NE DOIT PAS
y réintroduire le contenu d'une consultation, d'un dossier ou d'une
réponse ; seules les sources publiques et les cas types fictifs entrent
dans les sources brutes.

Rationale:
Le savoir est partagé et durable ; une donnée personnelle qui y entrerait
deviendrait un « savoir » impossible à effacer.

Covers:

- feat~savoir-de-situations~1
- feat~source-pour-agents~1

