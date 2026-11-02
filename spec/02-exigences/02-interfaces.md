# Exigences — domaine interfaces

**Statut : ACTIVE** — domaine acté le 2026-11-01 (D-2026-11-06).

Ce domaine expose le moteur aux agents logiciels et aux outils métier :
serveur MCP et API HTTP, sur les opérations déjà tenues par la ligne de
commande. Il n'ajoute aucune règle d'ancrage — celles du domaine
« ancrage » s'appliquent telles quelles à chaque interface — mais il
ajoute ce qu'une interface réseau impose : le lien vers la source de
chaque élément, la forme des réponses et la protection d'un savoir dont
le contenu est sous licence fermée.

## Tout élément rendu porte le lien vers la source officielle de ses identifiants

`req~source-de-chaque-element~1`
**Statut : approuvée**

Le système DOIT rendre, pour chaque identifiant officiel d'un élément de
réponse, le lien vers sa source officielle tel qu'il a été conservé à la
capture (en-tête `source` de la couche des textes), quelle que soit
l'interface (ligne de commande, MCP, HTTP).

Rationale:
Le lecteur vérifie une citation d'un clic ; un identifiant sans lien
oblige à le rechercher, et l'outil métier qui reçoit l'élément exige une
référence ET un lien.

Critères d'acceptation :

- Étant donné une page qui cite un article conservé, quand la recherche la
  rend, alors l'élément porte l'identifiant de l'article et l'adresse
  Légifrance conservée pour lui.
- Étant donné une décision conservée, quand la recherche la rend, alors
  l'élément porte son ECLI et l'adresse de la décision conservée.

Covers:

- feat~recherche-ancree~1
- feat~source-pour-agents~1

Needs: impl, utest

## Un serveur MCP offre la recherche ancrée aux agents

`req~outils-mcp~1`
**Statut : approuvée**

Le système DOIT offrir, en serveur MCP sur l'entrée et la sortie standard
et sur HTTP, les outils `chercher` (question, date), `lire_texte`
(identifiant ou identifiant chronologique, date), `verifier_citation`
(texte) et `verifier_savoir`, chacun en lecture seule sur le dépôt de
savoir désigné au lancement ; chaque réponse de `chercher` et de
`lire_texte` DOIT porter la date du droit applicable et la mention « aide
documentaire, sans valeur d'avis ».

Rationale:
L'ancrage ne sert que s'il est disponible là où l'agent répond ; MCP est
le protocole par lequel les agents découvrent et appellent leurs outils.

Critères d'acceptation :

- Étant donné un client MCP connecté, quand il liste les outils, alors il
  obtient les quatre outils et le schéma de leurs paramètres.
- Étant donné un texte d'agent qui cite un identifiant absent de la couche
  des textes, quand `verifier_citation` le juge, alors la réponse le
  refuse et nomme l'identifiant absent.
- Étant donné une recherche qui rencontre un élément sans ancrage, quand
  `chercher` répond, alors l'élément n'y figure pas.

Covers:

- feat~source-pour-agents~1

Needs: dsn, impl, utest, itest

## Une API HTTP offre les mêmes opérations aux outils métier

`req~api-http~1`
**Statut : approuvée**

Le système DOIT offrir les opérations `chercher`, `lire_texte`,
`verifier_citation` et `verifier_savoir` en API HTTP à réponses JSON, avec
une route de santé, et DOIT rendre une erreur JSON qui ne révèle ni chemin
du serveur ni secret.

Rationale:
Un outil métier (un service web, une application de gestion de dossiers)
consomme une API HTTP plus simplement qu'un protocole d'agent.

Critères d'acceptation :

- Étant donné un serveur lancé sur un savoir, quand on demande une
  recherche avec une date, alors la réponse JSON rend les éléments ancrés
  en vigueur à cette date et le nombre d'éléments écartés.
- Étant donné une date mal formée, quand on demande une recherche, alors
  la réponse est une erreur 400 en JSON.

Covers:

- feat~source-pour-agents~1

Needs: dsn, impl, itest

## L'API n'est joignable hors du poste qu'avec un jeton

`req~acces-http-protege~1`
**Statut : approuvée**

Si le serveur HTTP écoute sur une adresse autre que la boucle locale,
alors le système DOIT exiger un jeton porteur fourni par l'environnement
et DOIT refuser de démarrer sans lui ; quand un jeton est configuré, le
système DOIT refuser (401) toute requête qui ne le porte pas, sans rien
rendre du savoir, hors la route de santé ; le jeton NE DOIT apparaître
dans aucune sortie.

Rationale:
Le contenu du savoir est sous licence fermée : l'exposer sur un réseau
sans contrôle reviendrait à le publier.

Critères d'acceptation :

- Étant donné une écoute sur toutes les interfaces sans jeton configuré,
  quand le serveur démarre, alors il refuse et dit pourquoi.
- Étant donné un jeton configuré, quand une requête arrive sans jeton ou
  avec un jeton faux, alors la réponse est 401 et ne contient aucun
  élément du savoir.
- Étant donné un jeton configuré, quand le serveur journalise ou échoue,
  alors le jeton n'apparaît dans aucune sortie.

Covers:

- feat~source-pour-agents~1

Needs: dsn, impl, utest, itest

## Une instance sert plusieurs dépôts de savoir, chacun sous son nom

`req~savoirs-multiples~1`
**Statut : approuvée**

Le système DOIT servir un ou plusieurs dépôts de savoir déclarés chacun par
un nom et un chemin, sous des routes qui nomment le dépôt
(`/savoirs/{nom}/…`, MCP compris), chacun avec son index propre ; le dépôt
déclaré par `--savoir` ou `GREFFIER_SAVOIR` DOIT rester servi sous les
routes de la version 0.2.0.

Rationale:
Plusieurs communautés tiennent chacune leur savoir, sous des licences
différentes ; une instance par dépôt multiplierait ports, services et
secrets.

Critères d'acceptation :

- Étant donné deux dépôts déclarés, quand on cherche sous le nom de l'un,
  alors seuls les éléments de ce dépôt sont rendus.
- Étant donné un nom de dépôt inconnu, quand on l'interroge, alors la
  réponse est une erreur 404 en JSON.
- Étant donné un dépôt déclaré par `--savoir`, quand on interroge
  `/recherche`, alors il répond comme en 0.2.0.
- Étant donné un nom de dépôt hors de `[a-z0-9-]` ou de plus de 40
  caractères, quand le serveur démarre, alors il refuse et nomme le dépôt.

Covers:

- feat~source-pour-agents~1

Needs: dsn, impl, utest, itest

## Chaque client ne lit que les dépôts de sa portée

`req~jetons-a-portee~1`
**Statut : approuvée**

Le système DOIT reconnaître des clients nommés, chacun avec son jeton porteur
et sa portée (liste de dépôts, ou tous), déclarés par l'environnement ou par
le fichier de configuration ; quand au moins un client est déclaré, le
système DOIT refuser (401) toute requête hors santé sans jeton connu, et
DOIT répondre à un dépôt hors de la portée du client exactement comme à un
dépôt inconnu (404) ; la liste des dépôts rendue à un client NE DOIT nommer
que ceux de sa portée.

Rationale:
Un jeton unique ouvrirait au client d'un savoir ouvert le savoir sous
licence fermée ; un refus distinct révélerait l'existence d'un dépôt à qui
n'a pas à la connaître.

Critères d'acceptation :

- Étant donné un client dont la portée nomme le seul dépôt A, quand il
  interroge B, alors la réponse est la même 404 que pour un dépôt inconnu,
  et `/savoirs` ne nomme que A.
- Étant donné `GREFFIER_JETON` défini, quand son jeton est présenté, alors
  tous les dépôts sont lisibles (comportement de la 0.2.0).
- Étant donné un client déclaré par l'empreinte SHA-256 de son jeton, quand
  il présente le jeton, alors il est reconnu.
- Étant donné un même nom de client dans l'environnement et dans le
  fichier, quand le serveur démarre, alors l'environnement l'emporte et le
  journal le signale sans citer de jeton.

Covers:

- feat~source-pour-agents~1

Needs: dsn, impl, itest
