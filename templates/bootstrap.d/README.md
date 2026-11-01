# Modules de bootstrap prêts à copier

Le bootstrap du gabarit est **modulaire** (ADR-0014) : chaque outil vit dans
son module `tools/bootstrap.d/NN-outil.sh`, et le point d'extension d'un
projet instancié est l'**ajout d'un module** — jamais l'édition de
l'orchestrateur. Ce répertoire fournit des modules **prêts à copier**, avec
l'outillage qu'ils installent. C'est du matériel **post-instanciation** : le
gabarit lui-même ne les exécute pas et n'en dépend pas.

Comme `templates/orchestrators/`, ce répertoire n'est pas scanné par la
traçabilité (`templates/` est exclu du périmètre, ADR-0002) : les fichiers
copiés se taguent **vers les exigences du projet instancié** (R2, R7).

## Kit Rust (hygiène des artefacts de compilation)

Matériel de `req~hygiene-artefacts-compilation~1` et de
`req~confinement-artefacts-worktree~1` : la porte du gabarit
(`tools/hygiene-compilation.sh`, câblée dans `tools/ci.sh`) constate que la
chaîne est épinglée (suivie par git, canal exact) et que tests et couverture
coupent l'incrémental ; ce kit fournit de quoi s'y conformer et de quoi tenir
le cache à sa place. Le gabarit l'éprouve par `tools/rust-kit-test.sh`
(talons cargo et cargo-sweep : aucune compilation).

| Fichier | Copier vers | Rôle |
| --- | --- | --- |
| `50-rust.sh` | `tools/bootstrap.d/` | module bootstrap : cargo (rustup), cargo-nextest, cargo-sweep, chaîne épinglée, emplacement effectif des artefacts |
| `rust/rust.sh` | `tools/` | `garde` (worktree lié : artefacts dans le worktree ou dans `cargo-target-<nom>` seulement), `test` et `couverture` (`CARGO_INCREMENTAL=0`), `clean [--partage] [jours]` (par l'âge, jamais par la taille ; refus du cache partagé sans `--partage`), `etat` |

## Mise en place (projet Rust instancié)

1. Copier les deux fichiers ; poser `rust-toolchain.toml` à la racine avec
   une **version exacte** (`[toolchain] channel = "1.95.0"`, ou un canal
   daté `nightly-AAAA-MM-JJ`) et le versionner : `stable` avance à chaque
   publication de rustc et n'épingle rien — la porte le refuse. Monter de
   version est alors un commit, visible et daté.
2. Faire passer les recettes de test et de couverture par
   `sh tools/rust.sh test` / `couverture` — ou poser le réglage : préfixe
   `CARGO_INCREMENTAL=0` sur la ligne d'appel, `export` en tête de
   `tools/ci.sh`, `env:` d'un workflow, `variables:` GitLab,
   `export CARGO_INCREMENTAL := "0"` en tête de justfile, ou
   `[build] incremental = false` dans `.cargo/config.toml`. Un `export` seul
   sur une ligne de recette just ou Taskfile n'agit pas (un shell par
   ligne) : la porte ne le voit pas, ne comptez pas dessus. Appeler
   `sh tools/rust.sh garde` avant toute compilation lancée depuis un worktree
   lié.
3. Déclarer le nettoyage : `sh tools/rust.sh clean` depuis `tools/clean.sh`
   (point d'extension), qui résout le répertoire d'artefacts par
   `cargo metadata` — jamais `./target` en dur (méthode, ch. 4) — et refuse
   un cache partagé entre projets sans `--partage` explicite.
4. Câbler et taguer (R2, R7) : la porte du gabarit est déjà dans `tools/ci.sh` ;
   `rust.sh` se tague vers l'exigence du projet, et `tools/rust-kit-test.sh`
   se copie avec lui pour garder le test du cas d'échec de la garde (R3).
5. Poste multi-worktree : un cache par worktree, **nommé exactement**
   `cargo-target-<nom-du-worktree>` et hors du tree principal
   (`CARGO_TARGET_DIR=<disque>/cargo-target-<nom>`, ou un lien
   `<worktree>/target` vers ce dossier) — c'est ce nom qui permet à un
   balayage du poste de le reconnaître et de le retirer quand le worktree
   disparaît ; un simple composant de chemin homonyme ne suffit pas. Le
   balayage lui-même sélectionne par l'âge (`cargo sweep --time`) ; un
   plafond de taille ne s'applique qu'à froid. Piège du lien :
   un motif `.gitignore` terminé par une barre (`target/`) ne couvre que les
   dossiers, et git voit le lien comme un fichier nouveau (`?? target`) qu'un
   `git add -A` committerait — écrire `target` sans barre finale dans
   `.gitignore`, ou localement dans
   `$(git rev-parse --git-common-dir)/info/exclude` (vaut pour tous les
   worktrees, non versionné) ; `git status --short` doit redevenir vide.

Allègement optionnel du profil de développement, à arbitrer par le projet :
`[profile.dev] debug = "line-tables-only"` dans `Cargo.toml` divise le poids
des artefacts de debug sans changer le comportement des tests.

## Kit lint Markdown (tableaux normalisés)

Porte `markdownlint-cli2` avec la règle **MD060** (tableaux GFM alignés,
pipes et séparateurs) et formateur `format-tables.mjs` fondé sur
`string-width` — la **même mesure de largeur que MD060** (emoji et
caractères larges compris), donc formateur et porte toujours d'accord.

| Fichier | Copier vers | Rôle |
| --- | --- | --- |
| `30-node.sh` | `tools/bootstrap.d/` | module bootstrap : Node.js 22+ |
| `40-markdown-npm.sh` | `tools/bootstrap.d/` | module bootstrap : dépendances npm du lint |
| `markdown/markdown.sh` | `tools/` | la porte : `lint` (gate) et `fix` (normalisation) |
| `markdown/format-tables.mjs` | `tools/` | formateur de tableaux (périmètre à adapter) |
| `markdown/markdownlint-cli2.jsonc` | `.markdownlint-cli2.jsonc` (racine) | configuration (globs à adapter) |
| `markdown/package.json` | `package.json` (racine, ou fusionner) | dépendances épinglées |

## Mise en place (projet instancié)

1. Copier les fichiers selon le tableau ci-dessus ; adapter les **globs** de
   la configuration et le **périmètre** de `format-tables.mjs` à votre
   arborescence.
2. `npm install --no-audit --no-fund` — versionner le `package-lock.json`
   produit (installations reproductibles) et ignorer `node_modules/`.
3. Câbler la porte (R7 : toute porte documentée est câblée) : une étape
   `sh tools/markdown.sh lint` dans la CI, une cible dans la façade
   d'orchestration, le hook pre-commit si souhaité — et **taguer**
   `markdown.sh` vers l'exigence de qualité documentaire du projet (R2).
   Prévoir le test du cas d'échec à la mise en place (R3).
4. Normaliser l'existant : `sh tools/markdown.sh fix` (idempotent), puis
   relancer la CI locale.

Prérequis : Node.js **22+** (`markdownlint-cli2` ≥ 0.23 l'exige) — vérifié
par le module `30-node.sh` et revérifié par la porte, qui échoue avec un
message explicite plutôt qu'une erreur cryptique.
