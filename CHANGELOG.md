# Journal des changements

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versionnement : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté

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

## [0.1.0] - 2026-11-01

### Ajouté

- Instanciation de greffier depuis le gabarit alm-forge.
