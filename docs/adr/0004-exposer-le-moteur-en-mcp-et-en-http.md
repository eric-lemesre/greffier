# ADR-0004 — Exposer le moteur en serveur MCP et en API HTTP, sur axum et rmcp, local par défaut

**Statut** : Accepté
**Date** : 2026-11-01
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-06 au registre
**Portée** : durable

## Item de conception

`dsn~exposition-mcp-http~1`

Le binaire `greffier` sert le même cœur synchrone (recherche, porte de
l'ancrage, lecture des textes, vérification) par deux interfaces : un
serveur MCP (SDK officiel `rmcp`, en stdio et en HTTP « streamable ») et
une API HTTP JSON (`axum`), sur un exécuteur `tokio`. L'API écoute sur la
boucle locale par défaut ; toute autre adresse exige un jeton porteur.

Covers:

- req~outils-mcp~1
- req~api-http~1
- req~acces-http-protege~1

Needs: impl

## Contexte

Les lots 1 à 3 ont livré une ligne de commande : capture, vérification,
recherche ancrée, banc. Le besoin « source pour agents » demande qu'un
agent ou un outil métier interroge Greffier comme un outil, là où il
répond. L'ADR-0003 a gardé un client HTTP synchrone derrière un port et
renvoyé à ce lot le choix d'un exécuteur asynchrone.

Le contenu du savoir est sous licence fermée : un serveur qui l'expose
sur un réseau le publie, sauf contrôle d'accès.

## Décision

1. **Pile** : `tokio` (exécuteur), `axum` 0.8 (API HTTP), `rmcp` 3 (SDK
   officiel du protocole MCP), `schemars` pour le schéma des paramètres
   des outils. La capture PISTE reste synchrone (`ureq`) : elle ne sert
   que la ligne de commande.
2. **Un seul cœur** : une façade (`service`) offre `chercher`,
   `lire_texte`, `verifier_citation` et `verifier_savoir` ; MCP, HTTP et
   ligne de commande l'appellent, le travail de disque passe par
   `spawn_blocking`. Aucune règle d'ancrage n'est réécrite dans une
   interface.
3. **Index** : construit au démarrage en mémoire, reconstruit dès que le
   savoir change (empreinte des fichiers indexés : chemin, taille, date de
   modification) ; rien n'est écrit dans le savoir (ADR-0001, point 3).
4. **Commandes** : `greffier mcp --savoir S` (stdio, pour un agent local)
   et `greffier servir --savoir S [--ecoute ADRESSE]` (API sous `/`, MCP
   sous `/mcp`).
5. **Accès** : écoute par défaut sur `127.0.0.1` sans jeton ; une adresse
   hors boucle locale exige `GREFFIER_JETON` (jeton porteur, comparé à
   temps constant), faute de quoi le serveur refuse de démarrer ; la route
   de santé reste ouverte ; le jeton ne paraît dans aucune sortie. Sur
   tout le routeur, l'en-tête `Host` doit nommer la boucle locale,
   l'adresse d'écoute ou un hôte déclaré (`--hote`), sinon 403 : sans ce
   contrôle, une page web pourrait lire par rattachement DNS le savoir
   d'un serveur local sans jeton.

## Alternatives écartées

### Serveur synchrone, MCP écrit à la main

Un JSON-RPC ligne à ligne et un petit serveur HTTP synchrone garderaient
le binaire sans exécuteur, mais la conformité au protocole MCP (version,
négociation des capacités, transport HTTP) resterait à notre charge et à
nos tests ; le SDK officiel la porte et suit les révisions du protocole.

### Aucune protection, confiée au proxy inverse

Simple, mais une erreur de configuration du proxy publie le savoir ; le
moteur doit refuser par lui-même d'écouter au-dehors sans jeton.

### Jeton exigé même en local

Ajoute un secret à gérer pour l'usage le plus courant (un agent sur le
poste du praticien) sans protéger davantage : qui accède à la boucle
locale accède aussi aux fichiers du savoir.

## Conséquences

- Ce que cela apporte : Greffier se branche sur tout agent compatible MCP
  et sur tout outil métier par HTTP, avec la même porte de l'ancrage.
- Ce que cela coûte : un exécuteur et des dépendances de plus dans le
  binaire ; un jeton à gérer pour un déploiement en réseau.
- Ce que cela ferme : l'exposition d'un savoir sur un réseau sans contrôle
  d'accès.

## Vérification

- Tests d'intégration : le binaire `servir` interrogé en HTTP (routes,
  refus 401 sans jeton, refus de démarrer hors boucle locale sans jeton,
  élément non ancré absent, jeton absent des sorties) ; le binaire `mcp`
  piloté en stdio (`initialize`, `tools/list`, `tools/call`).
- La traçabilité relie chaque exigence du domaine « interfaces » à cet
  item de conception et à ses tests.

## Références

- ADR-0001, ADR-0003.
- `spec/02-exigences/02-interfaces.md`.
- Spécification du Model Context Protocol : <https://modelcontextprotocol.io>.
