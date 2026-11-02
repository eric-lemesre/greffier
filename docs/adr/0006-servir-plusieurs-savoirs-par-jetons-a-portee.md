# ADR-0006 — Servir plusieurs dépôts de savoir, par jetons à portée, réglés par l'environnement ou un fichier

**Statut** : Accepté
**Date** : 2026-11-02
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-08 au registre
**Portée** : durable

## Item de conception

`dsn~savoirs-multiples~1`

`greffier servir` sert un ou plusieurs dépôts de savoir nommés, chacun sous
`/savoirs/{nom}/…` avec son index propre. L'accès se règle par client :
chaque client présente son jeton porteur et ne voit que les dépôts que sa
portée nomme ; un dépôt hors portée répond comme un dépôt inconnu. Tout
réglage — dépôts, écoute, hôtes, clients, identifiants PISTE — se donne par
l'environnement ou par un fichier de configuration, l'option de commande
l'emportant sur l'environnement, et l'environnement sur le fichier.

Covers:

- req~savoirs-multiples~1
- req~jetons-a-portee~1
- req~configuration-environnement-et-fichier~1

Needs: impl

## Contexte

Un Greffier sert aujourd'hui un seul dépôt : `servir` prend un seul chemin
(`--savoir`, `GREFFIER_SAVOIR`), le service n'a qu'un index, les routes ne
nomment aucun dépôt, et un seul jeton (`GREFFIER_JETON`) ouvre tout. Or
plusieurs communautés tiendront chacune leur savoir, de licences
différentes (le savoir des conciliateurs est sous licence fermée), et une
même instance doit pouvoir les servir sans que le client de l'un lise
l'autre.

Les identifiants PISTE ne se règlent que par l'environnement, que
l'opérateur charge à la main avant chaque capture.

## Décision

1. **Dépôts nommés.** Un dépôt se déclare par un nom court
   (`[a-z0-9-]`, 1 à 40 caractères) et un chemin, dans la section
   `[savoirs]` du fichier. `--savoir` (ou `GREFFIER_SAVOIR`) déclare le
   dépôt `defaut`, comme avant. Chaque dépôt a son index et son
   rechargement propres.
2. **Routes.** `/savoirs` liste les dépôts que le client peut lire ;
   `/savoirs/{nom}/recherche`, `/savoirs/{nom}/textes/{identifiant}`,
   `/savoirs/{nom}/citations/verification`, `/savoirs/{nom}/verification`
   et `/savoirs/{nom}/mcp` servent un dépôt. Les routes de la version
   0.2.0 (`/recherche`, `/textes/…`, `/citations/verification`,
   `/savoir/verification`, `/mcp`) restent et servent le dépôt `defaut`
   quand il existe. `/sante` ne nomme aucun dépôt.
3. **Clients et portée.** Un client a un nom, un jeton et une portée (liste
   de dépôts, ou `*`). Sources :
   - `GREFFIER_JETON` : client `defaut`, portée `*` (cas de la 0.2.0) ;
   - `GREFFIER_JETON_<CLIENT>` et `GREFFIER_SAVOIRS_<CLIENT>` (liste
     séparée par des virgules ; absente, la portée est vide) ;
   - `[[client]]` du fichier : `nom`, `jeton` en clair ou `empreinte`
     (`sha256:<hex>`), `savoirs`.

   Les deux sources s'additionnent ; un même nom défini des deux côtés
   prend la valeur de l'environnement, ce que le journal signale sans
   citer de jeton. Les jetons se comparent par leur empreinte SHA-256, à
   temps constant.
4. **Accès.** Dès qu'un client est déclaré, toute requête hors `/sante`
   exige un jeton connu ; sans client, seule la boucle locale est servie
   (règle de la 0.2.0, inchangée). Un dépôt hors de la portée du client
   répond 404, comme un dépôt inconnu : le client n'apprend pas qu'il
   existe.
5. **Configuration.** Fichier TOML désigné par `--config` ou
   `GREFFIER_CONFIG`, sinon cherché à `/etc/greffier/greffier.toml` pour
   `servir` et à `~/.config/greffier/greffier.toml` pour la ligne de
   commande ; absent, rien n'est requis. Priorité : option, puis
   environnement, puis fichier, puis défaut. Un fichier qui porte un
   secret (jeton en clair, secret PISTE) et reste lisible par le groupe ou
   par tous empêche le démarrage (Unix), comme `ssh` avec une clé privée ;
   le message nomme le fichier, jamais le secret.
6. **PISTE.** Section `[piste]` (`client_id`, `client_secret`,
   `bac_a_sable`, adresses de remplacement) dans le fichier de
   l'opérateur ; les variables `GREFFIER_PISTE_*` restent prioritaires. Le
   service n'a pas d'identifiants PISTE : il ne capture pas.
7. **Secrets typés.** Jetons et secret PISTE vivent dans un type qui masque
   sa valeur à l'affichage et au `Debug` (méthode d'alm-forge, ch. 17).

## Alternatives écartées

### Une instance par dépôt

Aucune ligne de code, mais un port, une unité systemd et un jeu de jetons
par dépôt : le coût d'exploitation croît avec chaque communauté, et un
client qui lit deux dépôts gère deux adresses et deux secrets.

### Des clés propres à chaque dépôt, rangées dans le dépôt

Un dépôt de savoir est un dépôt git, cloné et partagé ; y ranger un secret,
même son empreinte, le diffuse avec le contenu. Et un client qui lit trois
dépôts gérerait trois secrets, révoqués en trois endroits.

### Un jeton unique pour l'instance

Il suffit tant qu'un seul client existe ; dès le second, le client d'un
savoir ouvert lirait le savoir sous licence fermée.

### Un refus 403 pour un dépôt hors portée

Plus parlant pour le client, mais il confirme l'existence du dépôt à qui
n'a pas à la connaître.

## Conséquences

- Ce que cela apporte : une instance sert plusieurs communautés, chaque
  client limité à ce qu'il doit lire ; un déploiement se règle par un seul
  fichier protégé, ou par l'environnement d'un conteneur.
- Ce que cela coûte : un fichier de configuration et son analyseur
  (`toml`), le calcul d'empreinte (`sha2`), une table d'index par dépôt.
- Ce que cela ferme : un client qui lit un dépôt hors de sa portée ; un
  secret posé dans un fichier lisible par tous.

## Vérification

- Tests d'intégration du binaire `servir` : deux dépôts servis ; un client
  à portée limitée lit l'un, reçoit 404 sur l'autre et ne le voit pas dans
  `/savoirs` ; un jeton inconnu reçoit 401 ; les routes de la 0.2.0
  servent le dépôt `defaut` ; un client de l'environnement l'emporte sur
  son homonyme du fichier ; un fichier à secret lisible par tous empêche le
  démarrage sans citer le secret ; un jeton déclaré par son empreinte est
  accepté.
- Tests unitaires de la configuration : priorité option, environnement,
  fichier, défaut ; noms de dépôt refusés ; `Debug` des réglages sans
  secret.

## Références

- ADR-0004 (exposition MCP et HTTP, accès local ou par jeton).
- `spec/02-exigences/02-interfaces.md`, `spec/02-exigences/04-exploitation.md`.
- Méthode d'alm-forge, chapitre 17 (journalisation, secrets typés).
