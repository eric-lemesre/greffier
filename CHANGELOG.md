# Journal des changements

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versionnement : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

## [0.2.0] - 2026-11-02

### Ajouté

- Paquets natifs (ADR-0005, D-2026-11-07, domaine « distribution ») :
  `.github/workflows/paquets.yml`, réutilisable, construit sur runners
  natifs le binaire Linux statique (musl) et ses paquets deb (cargo-deb)
  et rpm (cargo-generate-rpm), le dmg macOS universel
  (`packaging/macos/construire-dmg.sh`) et le MSI Windows (WiX v5,
  `packaging/windows/greffier.wxs`), puis installe chaque paquet sur un
  système de sa famille avant de le livrer ; joué aussi sur les pull
  requests qui touchent à la construction des paquets. Unité systemd
  durcie et scripts d'installation dans `packaging/linux/`. Trois
  exigences nouvelles.
- OpenFastTrace balaie aussi `packaging/`.

### Modifié

- `release.yml` publie les paquets éprouvés par `paquets.yml` et
  revérifie leurs empreintes avant de créer la release.

## [0.1.0] - 2026-11-01

### Ajouté

- Lot 4, exposition (ADR-0004, D-2026-11-06, domaine « interfaces ») :
  `greffier mcp` (serveur MCP, SDK officiel `rmcp`, sur l'entrée et la
  sortie standard) et `greffier servir` (API HTTP JSON sur `axum`, MCP sous
  `/mcp`) ; outils `chercher`, `lire_texte`, `verifier_citation`,
  `verifier_savoir` ; lien vers la source officielle de chaque élément
  rendu ; écoute locale par défaut, jeton porteur `GREFFIER_JETON` exigé
  hors boucle locale, en-tête `Host` contrôlé sur tout le routeur (contre
  le rattachement DNS). Quatre exigences nouvelles.
- Lot 3, recherche ancrée : `greffier chercher` (BM25 sur les textes
  authentiques et le wiki, droit en vigueur à une date, tout élément non
  ancré écarté et journalisé) et `greffier banc` (rappel, précision, délai,
  échec au premier élément non ancré). Réalise `req~citation-ancree~1`.
- Chaîne de publication : `.github/workflows/release.yml`, déclenchée par
  un tag `vX.Y.Z` égal à `VERSION`, construit le binaire Linux x86-64 et
  publie la release avec son empreinte SHA-256 et la section de `NEWS.md`.
  Journal des utilisateurs `NEWS.md`.

- Capture : le texte d'un article est conservé en paragraphes, lu depuis
  `texteHtml` (les deux formes rencontrées à la source : paragraphes
  encadrés, ou séparés par des balises vides) ; le champ `texte`, aplati en
  un bloc, ne sert plus qu'à défaut. Recette sur l'API de production.

- Lot 2 : `greffier verifier --savoir <dossier>`, vérification en lecture
  seule d'un dépôt de savoir — en-têtes des pages (type, sources,
  `verifie_le`, référent), sources présentes dans `raw/` et hors
  propositions, identifiants officiels cités portés par une source brute,
  liens `[[…]]`, index, journal (ingestion validée par un référent),
  programmes et dérivés versionnés ; pages orphelines ou sur-connectées en
  avertissement ; sortie 1 sur erreur. Réalise
  `req~moteur-separe-du-savoir~1`.

- Adoption de la révision ADR-0021 du gabarit : une exigence ou un item de
  conception approuvés sans code ni test sont listés « à réaliser », même
  conçus. « Citation ancrée » et « moteur séparé du savoir » approuvées
  (D-2026-11-05), à réaliser ; item de conception de l'ADR-0001 et besoin
  « source pour agents » rentrés dans la traçabilité.

- Adoption de la révision du gabarit alm-forge (ADR-0020 du gabarit) : la
  traçabilité ne retient que les items approuvés, une exigence approuvée
  sans maillon aval est listée « à réaliser », un item non approuvé porte
  `Status:` collé sous son identifiant (concordance vérifiée par
  `tools/statuts.sh`). Domaine « ancrage » actif (D-2026-11-04) : quatre
  exigences approuvées, quatre proposées avec leur `Needs:` complet ; item
  de conception de l'ADR-0001 en `Status: proposed`. Outillage reporté :
  définitions en double nommées avant la trace, porte d'hygiène qui ignore
  le matériel du gabarit, tests `oft-test`, `statuts-test`,
  `oft-doublons-test`, `automatismes-test` ; verdicts d'audit du domaine.

- Cadrage fondateur : ADR-0001 (trois couches, ancrage, séparation moteur /
  savoir), ADR-0002 (EUPL 1.2) ; besoin « recherche juridique » et domaine
  d'exigences « ancrage » en proposition ; fiche ToDo-0001 ; licence EUPL 1.2,
  façade just, forge GitHub seule.
- Lot 1, couche des textes authentiques : binaire `greffier` (Rust,
  ADR-0003) ; capture d'un article Légifrance (`consult/getArticle`) et
  d'une décision Judilibre (`/decision`) par PISTE en OAuth
  `client_credentials` ; conservation immuable et versionnée dans `raw/`
  du dépôt de savoir ; constat des changements de version (`versions`,
  sortie 3) ; version en vigueur à une date (`en-vigueur`). Trois
  exigences nouvelles : capture des sources officielles, détection des
  versions, chaîne de vérification du moteur.
- Outillage : kit Rust du gabarit (`tools/rust.sh`, module bootstrap),
  étapes format, lints et tests dans la voie complète de la CI, porte des
  en-têtes de licence `SPDX-License-Identifier: EUPL-1.2` (`tools/spdx.sh`,
  promise par ADR-0002) et son test d'échec.

- Instanciation de greffier depuis le gabarit alm-forge.
