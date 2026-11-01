# ADR-0003 — Écrire le moteur en Rust, en binaire unique, et joindre les sources officielles par PISTE

**Statut** : Accepté
**Date** : 2026-11-01
**Décideur** : Eric Lemesre — seul (porteur), sur la suite du lot 0 de la ToDo-0001
**Portée** : durable

## Item de conception

`dsn~connecteur-piste-synchrone~1`

Le moteur est un binaire Rust unique ; il joint Légifrance et Judilibre par
leurs API officielles sur PISTE, en OAuth 2.0 `client_credentials`, avec un
client HTTP synchrone, et lit ses identifiants dans l'environnement.

Covers:

- req~capture-des-sources-officielles~1
- req~textes-authentiques-versionnes~1
- req~chaine-de-verification-du-moteur~1

Needs: impl

## Contexte

Greffier sert des conciliateurs bénévoles, des associations et des
services publics locaux : il doit s'installer sans environnement
d'exécution à gérer (ni Python, ni JVM), sur un poste comme sur un petit
serveur, et rester auditable de bout en bout puisque sa promesse est la
justesse des citations (ADR-0001, ADR-0002). Les textes authentiques
viennent de deux API officielles exposées sur PISTE, la plateforme des API
de l'État : Légifrance (DILA) et Judilibre (Cour de cassation). Toutes deux
exigent une application enregistrée et un jeton OAuth.

Le premier usage est une ligne de commande qui capture des textes un par
un ; le volume d'appels est faible et séquentiel.

## Décision

- Le moteur est écrit en **Rust** (édition 2024), chaîne épinglée par
  `rust-toolchain.toml`, et livré en **un seul binaire** `greffier`.
- Les lints refusent toute panique hors tests (`unwrap`, `expect`, `panic`,
  indexation), exigent la documentation (`missing_docs`) et interdisent le
  code `unsafe`.
- Les sources sont jointes par **PISTE**, en `client_credentials` ; le
  jeton est réutilisé jusqu'à son expiration. Les identifiants de
  l'application sont lus dans `GREFFIER_PISTE_CLIENT_ID` et
  `GREFFIER_PISTE_CLIENT_SECRET`, jamais écrits ni affichés.
- Le client HTTP est **synchrone** (`ureq`, TLS rustls) derrière un port
  (`SourcePiste`) : la lecture des réponses s'éprouve sans réseau, et un
  client asynchrone pourra le remplacer quand l'exposition HTTP (lot 4) le
  demandera, sans toucher aux connecteurs.
- La forme des réponses suit les spécifications publiées (OpenAPI
  « Légifrance » 2.4.2 de la DILA, spécification publique de Judilibre) ;
  seuls les champs qui ancrent une citation sont lus, et un champ requis
  absent est une erreur.

## Alternatives écartées

### Python

Écosystème riche pour le traitement du texte, mais un environnement
d'exécution à installer et à maintenir chez chaque utilisateur, et des
erreurs de type découvertes à l'exécution sur une chaîne dont la justesse
est le produit.

### Client asynchrone (tokio, reqwest) dès le premier lot

Utile pour servir des requêtes concurrentes, inutile pour une capture
séquentielle ; il imposerait un exécuteur à toute la ligne de commande. Le
port `SourcePiste` laisse la bascule ouverte.

### Moissonner les sites publics plutôt que les API

Les pages publiques changent de forme sans préavis et ne rendent pas les
métadonnées de version (identifiant de version, période de vigueur) de
manière fiable ; les conditions d'usage des API officielles encadrent la
réutilisation.

## Conséquences

- Ce que cela apporte : une installation sans dépendance, une chaîne de
  citation vérifiée par le compilateur et par les tests, des secrets qui ne
  sortent d'aucun message.
- Ce que cela coûte : une application PISTE à enregistrer par le porteur
  (production et bac à sable ont des identifiants distincts) ; une
  compilation Rust dans la CI.
- Ce que cela ferme : rien d'irréversible ; le port permet de changer de
  client HTTP.

## Vérification

- `tools/ci.sh`, voie complète : `cargo fmt --check`, `cargo clippy
  --all-targets -D warnings` (les lints du manifeste en font des erreurs),
  tests unitaires et d'intégration (faux serveur PISTE local, sans réseau).
- La porte d'hygiène de compilation refuse une chaîne non épinglée.
- Le test d'intégration `le_secret_n_apparait_jamais_dans_une_sortie`
  vérifie qu'une erreur de la source ne révèle pas la clé.

## Références

- ADR-0001, ADR-0002.
- Spécification OpenAPI Légifrance 2.4.2 (DILA), servie sur PISTE :
  <https://piste.gouv.fr>.
- Spécification publique de Judilibre :
  <https://github.com/Cour-de-cassation/judilibre-search>.
