# Nouveautés de Greffier

Ce qui change pour qui utilise ou exploite Greffier. Le journal du dépôt
(méthode, outillage) est dans [CHANGELOG.md](CHANGELOG.md).

## [Non publié]

## [0.1.0] - 2026-11-01

Première version : un moteur de recherche juridique qui ne rend rien sans
texte authentique.

### Ajouté

- **Capture des textes authentiques** : `greffier capturer article
  LEGIARTI…` (Légifrance) et `greffier capturer decision <identifiant>`
  (Judilibre), par les API officielles sur PISTE (identifiants
  `GREFFIER_PISTE_CLIENT_ID` et `GREFFIER_PISTE_CLIENT_SECRET`, jamais
  affichés). Chaque texte est conservé, immuable et daté, dans le dossier
  `raw/` d'un dépôt de savoir, avec son identifiant officiel, sa source et
  sa période de vigueur ; une nouvelle version se range à côté des
  précédentes.
- **Suivi des versions** : `greffier versions LEGIARTI… --depuis
  AAAA-MM-JJ` signale toute version entrée en vigueur ou toute fin de
  vigueur depuis la date (sortie 3) ; `greffier en-vigueur` rend, hors
  ligne, la version conservée en vigueur à une date.
- **Vérification d'un dépôt de savoir** : `greffier verifier`, en lecture
  seule (en-têtes des pages, sources, identifiants cités, liens, index,
  journal, absence de code).
- **Recherche ancrée** : `greffier chercher "<question>" --le AAAA-MM-JJ`
  cherche dans les textes et les pages du savoir, dans le droit en vigueur
  à la date ; chaque élément porte ses identifiants officiels et le lien
  vers leur source ; tout élément sans ancrage est écarté, motif à l'appui.
  `greffier banc` mesure la recherche sur le banc de questions du savoir.
- **Pour les agents et les outils métier** : `greffier mcp` (serveur MCP
  sur l'entrée et la sortie standard) et `greffier servir` (API HTTP JSON
  sur `127.0.0.1:8370`, MCP sous `/mcp`) ; outils `chercher`,
  `lire_texte`, `verifier_citation`, `verifier_savoir`. Hors de la boucle
  locale, le jeton porteur `GREFFIER_JETON` est exigé.

### Installation

Binaire Linux x86-64 joint à la release, avec son empreinte SHA-256 ; ou
`cargo install --git https://github.com/eric-lemesre/greffier --tag
v0.1.0`.
