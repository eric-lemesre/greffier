# Revue de code — hygiène des artefacts de compilation — 2026-10-25

- **Périmètre** : git diff origin/main...HEAD de la branche
  `feat/hygiene-artefacts-compilation` (PR #14) — `req~hygiene-artefacts-compilation~1`,
  porte `tools/hygiene-compilation.sh` et son test, kit Rust
  `templates/bootstrap.d/`, méthode ch. 4, façades.
- **Relecteur** : Claude Opus 5.5 (sous-agent indépendant du modèle auteur,
  lecture seule, constats reproduits sur fixtures jetables).
- **Verdict global** : approuvé avec réserves — **les quinze constats sont
  soldés** (treize corrigés, deux rejetés motivés), plus un défaut trouvé en
  corrigeant.

## Constats

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | haute | `templates/bootstrap.d/rust/rust.sh` : la garde acceptait tout chemin dont un composant porte le nom du worktree (`*/"${nom}"/*`). Reproduit : tree principal `…/main/proj`, worktree `…/wt/proj`, `CARGO_TARGET_DIR=…/main/proj/target` → accepté ; `/var/cache/feature/shared` pour le worktree `feature` → accepté. C'est le cache partagé que la garde doit refuser. | Corrigé | Seuls `*/cargo-target-<nom>` et `*/cargo-target-<nom>/*` sont admis, et tout répertoire sous le tree principal (`git rev-parse --git-common-dir`/..) est refusé d'abord. Cas [D] et [E] de `tools/rust-kit-test.sh` rejouent les deux chemins du constat. |
| 2 | haute | `templates/bootstrap.d/README.md` recommandait `channel = "stable"`, qui avance à chaque rustc et n'épingle rien ; la porte n'exigeait que la présence du fichier (un `stable`, un fichier vide ou non suivi par git passaient). | Corrigé | La porte exige le fichier suivi par git (`git ls-files --error-unmatch`) et un canal exact ou daté ; `stable`, `beta`, `nightly` nus sont refusés en le disant. README : version exacte, monter de version = un commit. Cas [B2], [B3], [B4] du test. L'exigence précise « fichier suivi par git dont le canal est une version exacte ou datée ». |
| 3 | moyenne | `tools/hygiene-compilation.sh` : `grep -q 'CARGO_INCREMENTAL=0'` sur tout le fichier, commentaires compris, sans ordre ni portée. Faux négatifs reproduits : (a) réglage en commentaire puis `cargo test` nu ; (b) réglage dans une autre recette après l'appel ; (c) `export` seul sur une ligne de recette just/Taskfile, sans effet sur la ligne suivante. | Corrigé pour (a) et (b), (c) rejeté | Les lignes de commentaire sont exclues des réglages comme des appels ; le réglage vaut s'il est sur chaque ligne d'appel, ou sur une ligne située avant le premier appel. Cas [C2] et [C3] du test. (c) rejeté : distinguer la sémantique « un shell par ligne » de just et Taskfile de celle d'un script demanderait un analyseur par outil ; la limite est écrite en tête de la porte et dans le README du kit, avec les formes à employer (`export … := "0"` de just, `env:` de Taskfile, préfixe sur la ligne). |
| 4 | moyenne | Faux positifs sur des réglages corrects : `env:\n  CARGO_INCREMENTAL: 0` (GitHub), `variables:` (GitLab), `env:` (Taskfile), `export CARGO_INCREMENTAL := "0"` (just), `export CARGO_INCREMENTAL="0"` ; réglage natif `.cargo/config.toml` ignoré. | Corrigé | Motif `CARGO_INCREMENTAL[[:space:]]*(=\|:=\|:)[[:space:]]*["']?0["']?` et prise en compte de `incremental = false` dans `.cargo/config.toml` (vaut pour tout le dépôt). Cas [E2] (quatre formes) et [E3] du test. |
| 5 | moyenne | Appels ratés : `cargo +nightly test`, `$(CARGO) test`, `cargo --locked test`, `cargo t`, `cargo-nextest nextest run` ; répertoires non balayés (`.gitea/workflows`, `.forgejo/workflows`, `scripts/`, sous-dossiers de `tools/`, `makefile`, `GNUmakefile`, `.justfile`) ; `echo "lancer cargo test"` compté comme appel. | Corrigé | Motif étendu (options et chaîne `+…` entre `cargo` et la sous-commande, `$(CARGO)`/`${CARGO}`, formes `cargo-…`, `cargo t`), liste de fichiers étendue (`find` récursif sur `tools/` et `scripts/`, trois forges), lignes `echo`/`printf` inertes. Cas [C] (huit formes), [F], [G gitea], [H] (`cargo tree`, `cargo build` non comptés) du test. |
| 6 | moyenne | `rust.sh test` : `cargo test --workspace --doc` échoue sur un espace de travail sans bibliothèque (« no library targets found ») ; dans le repli sans nextest, les doctests passaient deux fois. | Corrigé | `--doc` seulement sur la branche nextest et seulement si `cargo metadata` liste une cible de bibliothèque (`a_une_bibliotheque`). |
| 7 | moyenne | `rust.sh etat` : `du -sh … \| awk '{s+=$1}'` additionnait des tailles lisibles (« 590 » pour 2,9M + 588K) ; le repli `\|\| echo 0` après un tube ne s'exécutait jamais ; `rust-toolchain` hérité ignoré. | Corrigé | `du -sk` additionné et rendu en Gio ; fonction `poids` qui teste l'existence du dossier et dit « absent » ; `rust-toolchain` reconnu. Cas [J] du test du kit. |
| 8 | moyenne | `rust.sh clean` balayait le répertoire résolu sans regarder s'il est partagé : sur un poste à `target-dir` global, un `clean` de dépôt balaie les artefacts de tous les projets (anti-patron « recettes clean devenues globales »). | Corrigé | `clean` refuse un répertoire ni confiné ni nommé `cargo-target-<nom>` sans `--partage` explicite, en le disant. Cas [I] du test du kit ; critère ajouté à l'exigence de confinement. |
| 9 | moyenne | Exigence non singulière (quatre DOIT + une porte), motif EARS « Quand » pour une fonctionnalité optionnelle, deux obligations (confinement, nettoyage par l'âge) sans réalisation ni test dans le périmètre tracé alors que l'audit disait « conforme », « ou l'équivalent d'un autre outil » invérifiable, « intégration continue » plus large que la porte. | Corrigé | Découpage : `req~hygiene-artefacts-compilation~1` (« Là où le projet compile du Rust… », chaîne + incrémental, porte) et `req~confinement-artefacts-worktree~1` (garde, nettoyage par l'âge, refus du partagé), cette dernière éprouvée par `tools/rust-kit-test.sh` (talons cargo et cargo-sweep, `Needs: utest`). Texte restreint à Rust et aux commandes de test et de couverture. Audit : deux lignes, preuves distinctes. |
| 10 | basse | Test : échec de `cargo test` simple et de `cargo tarpaulin` non joués ; « nommant la ligne » non vérifié ; messages des cas [A] et [B] non vérifiés ; garde sans test. | Corrigé | Cas [C] sur huit formes d'appel avec vérification de la ligne (`^    2:`) et du fichier ; [A] vérifie « rien à vérifier », [B] « rust-toolchain.toml absent » ; garde testée dans `tools/rust-kit-test.sh`. |
| 11 | basse | La porte balaie `tools/hygiene-compilation-test.sh` dans un projet instancié ; ses `printf '…cargo nextest run…'` comptaient comme appels et le fichier ne passait que par la présence de la chaîne `CARGO_INCREMENTAL=0` dans un autre `printf`. | Corrigé | Les lignes `echo`/`printf` sont inertes (constat 5) ; le test lui-même ne passe plus par chance : cas [F]. |
| 12 | basse | `50-rust.sh` : `cargo metadata` lancé depuis le répertoire courant et non depuis `RACINE` ; une chaîne épinglée absente serait installée par rustup à cet appel, contre « `--verifie` n'installe jamais » (ADR-0014). | Corrigé | `--manifest-path "${RACINE}/Cargo.toml"` et `RUSTUP_AUTO_INSTALL=0` quand l'installation n'est pas accordée ; message dédié quand l'emplacement n'est pas résolu. |
| 13 | basse | `50-rust.sh` : un outil cargo manquant n'incrémentait pas `MANQUANTS` en mode installation (bilan faux après installation ou échec) ; nextest et sweep ni signalés ni comptés sans cargo. | Corrigé | `MANQUANTS` et `ABSENTS` incrémentés avant l'installation, comme `verifier()` ; sans cargo, une ligne dit que ces vérifications ne sont pas possibles. |
| 14 | basse | `rust.sh garde` : `[ -f .git ]` vrai aussi pour un sous-module ; message « cache PARTAGÉ » même quand `cargo metadata` ne rend rien ; chemin Windows du JSON non normalisé. | Corrigé | Détection par `git rev-parse --git-dir` ≠ `--git-common-dir` sous `worktrees/` ; erreur dédiée quand le répertoire n'est pas résolu (cas [G] du test du kit) ; antislashs du JSON ramenés et `cygpath -u` quand il existe. |
| 15 | basse | CHANGELOG : « tout fichier qui lance … une CI Cargo porte `CARGO_INCREMENTAL=0` » disait plus que la porte. | Corrigé | Formulation alignée sur le critère : commandes de test et de couverture, réglage sur la ligne ou avant le premier appel, formes reconnues. |
| 16 | haute | Trouvé en corrigeant le constat 5 : sous `set -e`, le groupe `{ ls …; find …; find …; }` qui liste les fichiers s'arrêtait à la première commande en échec (façade absente, dossier `scripts/` absent) ; la liste restait vide et la porte se taisait — un contrôle qui passe toujours (R3), masqué jusque-là parce que les fixtures du test avaient toutes un `justfile`. | Corrigé | `\|\| true` sur chaque commande du groupe, commentaire en tête ; les cas [C2], [E], [G] du test n'ont plus de `justfile` et éprouvent ce chemin. |

## Suite donnée

Treize constats corrigés, un partiellement (3c rejeté avec la limite écrite),
plus un défaut haut trouvé en corrigeant (16). Deux leçons promues en règle :

- La garde d'un worktree n'accepte qu'un **nom convenu exact**
  (`cargo-target-<nom>`), jamais une ressemblance de chemin : c'est l'objet
  de `req~confinement-artefacts-worktree~1`, désormais testée par le gabarit
  avec des talons — le kit ne vit plus sur une promesse de test « à la mise
  en place ».
- Une **liste de fichiers construite sous `set -e`** se protège commande par
  commande, sinon la porte devient muette sur les dépôts qui n'ont pas
  exactement la forme des fixtures. Le test porte maintenant des fixtures
  sans façade pour tenir ce chemin.

## Points vérifiés hors constats

- Conformité EARS des exigences nouvelles : ok (« Là où… DOIT », une
  obligation par exigence, critères Étant donné / quand / alors).
- Absence de tag de complaisance : ok — la porte réalise les critères 1 à 4
  de la première exigence, le test du kit les cinq critères de la seconde.
- Niveau de test conforme au Needs déclaré : ok (`impl, utest` pour la porte ;
  `utest` pour le confinement, dont la réalisation vit hors périmètre tracé,
  dans `templates/`).
- `sh tools/ci.sh --complet` : toutes les portes vertes après corrections ;
  traçabilité sans doublon d'identifiant ; façades en délégation pure ;
  AGENTS.md non modifié ; R9 respectée (aucun terme du lexique lu par la
  porte).
