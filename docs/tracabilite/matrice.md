# Matrice de traçabilité

<!-- GÉNÉRÉ par tools/matrice.sh — ne pas éditer à la main (R8). -->

Vue de synthèse, informative : elle n'ajoute aucun contrôle à `task trace` (OpenFastTrace) ni à `task ci` (`tools/classification.sh`) et ne peut jamais faire échouer une porte. Section 1 : chaque exigence des spécifications, avec ses couvertures RÉELLEMENT trouvées par balayage du dépôt (pas seulement les `Needs:` déclarés). Section 2 : son inverse, les fichiers d'outillage sans aucune trace de traçabilité — une liste de revue, pas un verdict.

## 1. Exigences → couvertures

### spec/02-exigences/01-ancrage.md

#### `req~citation-ancree~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (7) :
  - `impl` — src/banc.rs:10
  - `utest` — src/banc.rs:254
  - `impl` — src/recherche.rs:18
  - `utest` — src/recherche.rs:764
  - `utest` — src/recherche.rs:783
  - `utest` — src/recherche.rs:802
  - `utest` — src/recherche.rs:822

#### `req~textes-authentiques-versionnes~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, itest
- Couvertures réelles (6) :
  - `impl` — src/couche.rs:13
  - `utest` — src/couche.rs:282
  - `utest` — src/couche.rs:314
  - `utest` — src/couche.rs:346
  - `impl` — src/recherche.rs:19
  - `utest` — src/recherche.rs:840

#### `req~capture-des-sources-officielles~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, itest
- Couvertures réelles (5) :
  - `impl` — src/judilibre.rs:77
  - `utest` — src/judilibre.rs:151
  - `impl` — src/legifrance.rs:90
  - `utest` — src/legifrance.rs:377
  - `utest` — src/legifrance.rs:456

#### `req~detection-des-versions~1`

- Niveau normatif : DOIT
- Needs: impl, utest, itest
- Couvertures réelles (4) :
  - `impl` — src/versions.rs:8
  - `utest` — src/versions.rs:66
  - `utest` — src/versions.rs:78
  - `utest` — src/versions.rs:85

#### `req~chaine-de-verification-du-moteur~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (4) :
  - `impl` — tools/bootstrap.d/50-rust.sh:2
  - `impl` — tools/rust.sh:2
  - `utest` — tools/spdx-test.sh:2
  - `impl` — tools/spdx.sh:2

#### `req~moteur-separe-du-savoir~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, itest
- Couvertures réelles (5) :
  - `impl` — src/verifier.rs:17
  - `utest` — src/verifier.rs:668
  - `utest` — src/verifier.rs:677
  - `utest` — src/verifier.rs:696
  - `utest` — src/verifier.rs:713

#### `req~peremption-par-version~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles : — À COUVRIR

#### `req~cloisonnement-du-savoir~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles : — À COUVRIR

### spec/02-exigences/02-interfaces.md

#### `req~source-de-chaque-element~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — src/recherche.rs:20
  - `utest` — src/recherche.rs:856
  - `utest` — src/recherche.rs:882

#### `req~outils-mcp~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, itest
- Couvertures réelles (5) :
  - `impl` — src/mcp.rs:11
  - `impl` — src/service.rs:13
  - `utest` — src/service.rs:451
  - `utest` — src/service.rs:465
  - `utest` — src/service.rs:488

#### `req~api-http~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, itest
- Couvertures réelles (2) :
  - `impl` — src/http.rs:20
  - `impl` — src/service.rs:14

#### `req~acces-http-protege~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, itest
- Couvertures réelles (3) :
  - `impl` — src/http.rs:21
  - `utest` — src/http.rs:263
  - `utest` — src/http.rs:275

### Bilan (couvertures réelles)

10/12 exigence(s) testable(s) couverte(s) par au moins une trace réelle (83.3 %) — 2 à couvrir.

## 2. L'inverse — outillage sans exigence

Fichiers d'outillage (`tools/`, hooks git, gabarits de forge) qui ne portent AUCUN tag de traçabilité (`->req~…`). **Avertissement honnête** : l'absence de tag ne prouve PAS l'absence d'exigence — un fichier peut très bien servir une exigence couverte ailleurs. Cette liste est une liste DE REVUE, pas un verdict. `examples/` et `templates/` en sont exclus (spécification propre, ou identifiants d'exemple seulement — même exclusion qu'OpenFastTrace, `tools/oft.sh`).

### `.githooks` (2)

- `.githooks/commit-msg`
- `.githooks/pre-commit`

### `.github` (2)

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/dependabot.yml`

### `.github/ISSUE_TEMPLATE` (4)

- `.github/ISSUE_TEMPLATE/amelioration.yml`
- `.github/ISSUE_TEMPLATE/anomalie.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/question-ouverte.yml`

### `.github/workflows` (2)

- `.github/workflows/ci.yml`
- `.github/workflows/security.yml`

### `tools` (49)

- `tools/adr-new.sh`
- `tools/audit.sh`
- `tools/automatismes-test.sh`
- `tools/badges.sh`
- `tools/bootstrap-test.sh`
- `tools/bootstrap.sh`
- `tools/bump.sh`
- `tools/checks-test.sh`
- `tools/checks.sh`
- `tools/ci-test.sh`
- `tools/ci.sh`
- `tools/classification.sh`
- `tools/clean-test.sh`
- `tools/clean.sh`
- `tools/derive-test.sh`
- `tools/derive.sh`
- `tools/donnees-test.sh`
- `tools/donnees.sh`
- `tools/gouvernance-test.sh`
- `tools/hygiene-compilation-test.sh`
- `tools/hygiene-compilation.sh`
- `tools/install-git.ps1`
- `tools/install-git.sh`
- `tools/issues.sh`
- `tools/journaux-revisions-editoriales.txt`
- `tools/journaux.sh`
- `tools/lexique.sh`
- `tools/liens-test.sh`
- `tools/liens.sh`
- `tools/locale-test.sh`
- `tools/oft-doublons-test.sh`
- `tools/oft-test.sh`
- `tools/oft.sh`
- `tools/paralleles-test.sh`
- `tools/paralleles.sh`
- `tools/perimetre-test.sh`
- `tools/perimetre.sh`
- `tools/rattachement-herites.txt`
- `tools/rattachement-test.sh`
- `tools/releves.sh`
- `tools/revues.sh`
- `tools/rust-kit-test.sh`
- `tools/secrets-test.sh`
- `tools/secrets.sh`
- `tools/setup-test.sh`
- `tools/setup.sh`
- `tools/socle-test.sh`
- `tools/statuts-test.sh`
- `tools/todo.sh`

### `tools/bootstrap.d` (2)

- `tools/bootstrap.d/10-curl.sh`
- `tools/bootstrap.d/20-java.sh`

### `tools/hooks` (2)

- `tools/hooks/commit-msg.sh`
- `tools/hooks/pre-commit.sh`

**Total : 63/71 fichier(s) d'outillage sans trace de traçabilité.**

