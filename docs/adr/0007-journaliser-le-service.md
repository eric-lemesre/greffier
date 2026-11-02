# ADR-0007 — Journaliser le service par tracing, corrélé, sans secret ni question

**Statut** : Accepté
**Date** : 2026-11-02
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-09 au registre
**Portée** : durable

## Item de conception

`dsn~journal-du-service~1`

Greffier journalise par `tracing`, installé par le seul binaire : une
ligne par requête (identifiant de corrélation, route générique, dépôt,
client, statut, durée), les refus d'accès sous la cible `greffier::acces`,
le cycle de vie et les rechargements d'index. Aucun jeton ni aucune
question n'y paraît. Sous systemd, le journal part à journald avec sa
priorité ; ailleurs, sur la sortie d'erreur, en texte ou en JSON.

Covers:

- req~journal-du-service~1

Needs: impl

## Contexte

Le service n'écrit qu'une ligne au démarrage et l'erreur finale d'une
commande (`src/http.rs`, `src/main.rs`) : ni requête, ni refus de jeton ou
d'hôte, ni rechargement, ni durée. Avec plusieurs clients et plusieurs
dépôts (ADR-0006), on ne saurait plus qui interroge quoi, ni repérer une
attaque sur les jetons. Les questions viennent de dossiers réels : un
journal qui les garderait sortirait des données de personnes.

La méthode d'alm-forge (chapitre 17, ADR-0022 du gabarit) fixe les règles
communes des projets Rust et une porte qui en vérifie quatre.

## Décision

1. **Pile.** `tracing`, `tracing-subscriber` (`env-filter`, `json`),
   `tracing-journald`, `tower-http` (`trace`, `request-id`). L'abonné est
   installé dans `main.rs` ; la bibliothèque émet seulement.
2. **Requêtes.** Un span par requête porte `id_requete`, la méthode et la
   route générique ; le dépôt et le client s'y ajoutent une fois l'accès
   contrôlé. `X-Request-Id` entrant est repris, sinon un UUID est créé, et
   il revient dans la réponse. Une ligne `info` clôt la requête (statut,
   durée) ; en-têtes et corps ne sont jamais journalisés.
3. **Accès.** Les refus (jeton absent ou inconnu, hôte refusé) sont des
   `warn` sous la cible `greffier::acces`, avec le motif et l'adresse du
   pair ; ni jeton ni fragment de jeton.
4. **Contenu.** La question, le texte d'un article et la citation soumise
   ne sont jamais journalisés ; seulement leurs mesures (longueur, nombre
   d'éléments rendus et écartés, date demandée).
5. **Réglage.** Filtre `EnvFilter` par `--journal`, `GREFFIER_JOURNAL` ou
   `[journal] filtre` du fichier, défaut `info` ; format `texte` ou `json`
   par `GREFFIER_JOURNAL_FORMAT` ou `[journal] format`.
6. **journald.** Quand `JOURNAL_STREAM` est défini, la couche
   `tracing-journald` transmet priorité et champs ; si elle ne s'ouvre pas,
   le journal revient à la sortie d'erreur et le dit.
7. **Porte.** `tools/journalisation.sh` du gabarit est reprise et câblée
   dans `tools/ci.sh`.

## Alternatives écartées

### `log` et `env_logger`

Plus léger, mais sans span : impossible de rattacher les événements d'une
requête à son identifiant et à son client sans les répéter partout.

### Un fichier de journal géré par l'application

Rotation, droits et rétention seraient à notre charge ; journald, le
conteneur ou le collecteur le font déjà, et mieux.

### Journaliser la question pour le diagnostic

Utile au réglage de la recherche, mais elle vient d'un dossier réel ; le
banc de questions (`greffier banc`) sert ce besoin sans donnée réelle.

## Conséquences

- Ce que cela apporte : savoir qui interroge quel dépôt, combien de temps,
  et suivre une requête d'un client jusqu'à Greffier.
- Ce que cela coûte : quatre dépendances de plus dans le binaire.
- Ce que cela ferme : un jeton ou une question dans le journal.

## Vérification

- Tests d'intégration : le journal capturé d'une requête refusée et d'une
  recherche réussie ne contient ni le jeton ni la question ; un
  `X-Request-Id` entrant ressort dans la réponse et dans le journal ; le
  refus porte la cible `greffier::acces`.
- `tools/journalisation.sh` dans `tools/ci.sh`.

## Références

- ADR-0004, ADR-0006.
- Méthode d'alm-forge, chapitre 17 ; ADR-0022 d'alm-forge.
- `spec/02-exigences/04-exploitation.md`.
