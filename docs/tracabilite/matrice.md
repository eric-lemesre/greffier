# Matrice de traçabilité

<!-- GÉNÉRÉ par tools/matrice.sh — ne pas éditer à la main (R8). -->

Vue de synthèse, informative : elle n'ajoute aucun contrôle à `task trace` (OpenFastTrace) ni à `task ci` (`tools/classification.sh`) et ne peut jamais faire échouer une porte. Section 1 : chaque exigence des spécifications, avec ses couvertures RÉELLEMENT trouvées par balayage du dépôt (pas seulement les `Needs:` déclarés). Section 2 : son inverse, les fichiers d'outillage sans aucune trace de traçabilité — une liste de revue, pas un verdict.

## 1. Exigences → couvertures

### spec/02-exigences/01-ancrage.md

#### `req~citation-ancree~1`

- Niveau normatif : DOIT
- Needs: dsn
- Couvertures réelles : — À COUVRIR

#### `req~textes-authentiques-versionnes~1`

- Niveau normatif : DOIT
- Needs: dsn
- Couvertures réelles : — À COUVRIR

#### `req~moteur-separe-du-savoir~1`

- Niveau normatif : DOIT
- Needs: dsn
- Couvertures réelles : — À COUVRIR

#### `req~peremption-par-version~1`

- Niveau normatif : DOIT
- Needs : (absent)
- Couvertures réelles : — À COUVRIR

#### `req~cloisonnement-du-savoir~1`

- Niveau normatif : DOIT
- Needs : (absent)
- Couvertures réelles : — À COUVRIR

### Bilan (couvertures réelles)

0/5 exigence(s) testable(s) couverte(s) par au moins une trace réelle (0.0 %) — 5 à couvrir.

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

### `tools` (45)

- `tools/adr-new.sh`
- `tools/audit.sh`
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
- `tools/todo.sh`

### `tools/bootstrap.d` (2)

- `tools/bootstrap.d/10-curl.sh`
- `tools/bootstrap.d/20-java.sh`

### `tools/hooks` (2)

- `tools/hooks/commit-msg.sh`
- `tools/hooks/pre-commit.sh`

**Total : 59/63 fichier(s) d'outillage sans trace de traçabilité.**

