# Matrice de traçabilité

<!-- GÉNÉRÉ par tools/matrice.sh — ne pas éditer à la main (R8). -->

Vue de synthèse, informative : elle n'ajoute aucun contrôle à `task trace` (OpenFastTrace) ni à `task ci` (`tools/classification.sh`) et ne peut jamais faire échouer une porte. Section 1 : chaque exigence des spécifications, avec ses couvertures RÉELLEMENT trouvées par balayage du dépôt (pas seulement les `Needs:` déclarés). Section 2 : son inverse, les fichiers d'outillage sans aucune trace de traçabilité — une liste de revue, pas un verdict.

## 1. Exigences → couvertures

### spec/02-exigences/coordination-issues.md

#### `req~issues-etat-attente-acte~2`

- Niveau normatif : DOIT
- Needs: dsn, impl, mtest
- Couvertures réelles (1) :
  - `impl` — docs/methode/11-cycle-de-vie-issues.md:3

#### `req~issues-flux-avancement~2`

- Niveau normatif : DOIT
- Needs: dsn, impl, mtest
- Couvertures réelles (4) :
  - `impl` — .github/ISSUE_TEMPLATE/proposition-exigence.yml:1
  - `impl` — .github/ISSUE_TEMPLATE/proposition-organisation.yml:1
  - `impl` — docs/methode/11-cycle-de-vie-issues.md:4
  - `impl` — tools/init.sh:392

#### `req~issues-triage-priorites~2`

- Niveau normatif : DOIT
- Needs: dsn, impl, mtest
- Couvertures réelles (3) :
  - `impl` — .github/ISSUE_TEMPLATE/anomalie.yml:1
  - `impl` — .gitlab/issue_templates/Anomalie.md:1
  - `impl` — docs/methode/11-cycle-de-vie-issues.md:5

#### `req~conformite-issues~1`

- Niveau normatif : DOIT
- Needs: impl, mtest
- Couvertures réelles (2) :
  - `impl` — docs/methode/11-cycle-de-vie-issues.md:287
  - `impl` — tools/issues.sh:2

#### `req~automatismes-forge~1`

- Niveau normatif : DOIT
- Needs: impl, mtest
- Couvertures réelles (1) :
  - `impl` — docs/methode/11-cycle-de-vie-issues.md:253

### spec/02-exigences/decisions.md

#### `req~registre-adr~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/adr/README.md:3
  - `utest` — tools/checks-test.sh:5
  - `impl` — tools/checks.sh:80

#### `req~adr-verification~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/checks-test.sh:2
  - `impl` — tools/checks.sh:38

#### `req~statut-specification~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/methode/13-statuts-de-specification.md:3
  - `utest` — tools/gouvernance-test.sh:2
  - `impl` — tools/statuts.sh:2

#### `req~releves-de-decision~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/gouvernance-test.sh:4
  - `impl` — tools/releves.sh:2

#### `req~journaux-depot-et-logiciel~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/methode/08-versionnement-release.md:22
  - `utest` — tools/gouvernance-test.sh:10
  - `impl` — tools/journaux.sh:2

### spec/02-exigences/documentation.md

#### `req~integrite-liens~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/liens-test.sh:2
  - `impl` — tools/liens.sh:2

#### `req~feuille-de-route-outillee~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/methode/12-feuille-de-route.md:3
  - `utest` — tools/gouvernance-test.sh:7
  - `impl` — tools/todo.sh:2

#### `req~suivi-constats-revue~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/methode/07-revue-et-recette.md:27
  - `utest` — tools/gouvernance-test.sh:8
  - `impl` — tools/revues.sh:2

#### `req~badges-autonomes~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `impl` — tools/badges.sh:2
  - `utest` — tools/gouvernance-test.sh:11

#### `req~avancement-calcule~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `impl` — tools/avancement.sh:2
  - `utest` — tools/gouvernance-test.sh:13

#### `req~kit-lint-markdown~1`

- Niveau normatif : PEUT
- Needs : (absent)
- Couvertures réelles : aucune (niveau non exigé)

### spec/02-exigences/gouvernance.md

#### `req~gouvernance-agents~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, mtest
- Couvertures réelles (1) :
  - `impl` — AGENTS.md:3

#### `req~bilinguisme-templates~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/checks-test.sh:3
  - `impl` — tools/checks.sh:14

#### `req~instanciation-outillee~2`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/init-test.sh:2
  - `impl` — tools/init.sh:2

#### `req~accueil-informatif~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/setup-test.sh:3
  - `impl` — tools/setup.sh:3

#### `req~onboarding-outille~2`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (8) :
  - `utest` — tools/bootstrap-test.sh:2
  - `impl` — tools/bootstrap.d/10-curl.sh:1
  - `impl` — tools/bootstrap.d/20-java.sh:1
  - `impl` — tools/bootstrap.sh:2
  - `impl` — tools/install-git.ps1:1
  - `impl` — tools/install-git.sh:2
  - `utest` — tools/setup-test.sh:2
  - `impl` — tools/setup.sh:2

#### `req~politique-attribution-agents~2`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — tools/hooks/commit-msg.sh:25
  - `utest` — tools/init-test.sh:3
  - `impl` — tools/init.sh:199

#### `req~politique-langue~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/init-test.sh:4
  - `impl` — tools/init.sh:241

#### `req~portabilite-forges~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — .gitlab-ci.yml:1
  - `utest` — tools/checks-test.sh:6
  - `impl` — tools/checks.sh:109

#### `req~nettoyage-outille~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/clean-test.sh:2
  - `impl` — tools/clean.sh:2

#### `req~hygiene-artefacts-compilation~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/hygiene-compilation-test.sh:2
  - `impl` — tools/hygiene-compilation.sh:2

#### `req~confinement-artefacts-worktree~1`

- Niveau normatif : DOIT
- Needs: utest
- Couvertures réelles (1) :
  - `utest` — tools/rust-kit-test.sh:2

#### `req~versionnement-release~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/methode/08-versionnement-release.md:3
  - `utest` — tools/checks-test.sh:4
  - `impl` — tools/checks.sh:64

#### `req~lexique-outille~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (4) :
  - `utest` — tools/checks-test.sh:7
  - `impl` — tools/checks.sh:131
  - `utest` — tools/gouvernance-test.sh:12
  - `impl` — tools/lexique.sh:2

#### `req~coherence-choix-instanciation~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (6) :
  - `impl` — tools/checks-test.sh:69
  - `utest` — tools/init-test.sh:207
  - `utest` — tools/init-test.sh:242
  - `impl` — tools/init.sh:223
  - `impl` — tools/init.sh:517
  - `impl` — tools/socle-test.sh:88

### spec/02-exigences/ingenierie-exigences.md

#### `req~expression-du-besoin~1`

- Niveau normatif : DOIT
- Needs: impl, mtest
- Couvertures réelles (1) :
  - `impl` — docs/methode/01-expression-du-besoin.md:3

#### `req~format-exigence-ears~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, mtest
- Couvertures réelles (3) :
  - `impl` — docs/methode/02-exigences.md:3
  - `impl` — tools/classification.sh:3
  - `utest` — tools/gouvernance-test.sh:6

#### `req~cycle-de-vie-exigence~2`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest, mtest
- Couvertures réelles (3) :
  - `impl` — docs/methode/02-exigences.md:4
  - `utest` — tools/gouvernance-test.sh:3
  - `impl` — tools/statuts.sh:3

#### `req~questions-ouvertes~1`

- Niveau normatif : DOIT
- Needs: impl, mtest
- Couvertures réelles (1) :
  - `impl` — spec/open-questions.md:3

### spec/02-exigences/securite.md

#### `req~detection-secrets~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — .github/workflows/security.yml:1
  - `utest` — tools/secrets-test.sh:2
  - `impl` — tools/secrets.sh:2

#### `req~donnees-hors-depot~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `utest` — tools/donnees-test.sh:2
  - `impl` — tools/donnees.sh:2

#### `req~securite-continue~1`

- Niveau normatif : DOIT
- Needs: impl, mtest
- Couvertures réelles (1) :
  - `impl` — docs/methode/10-securite-continue.md:3

### spec/02-exigences/tracabilite.md

#### `req~tracabilite-outillee~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — tools/matrice.sh:3
  - `impl` — tools/oft.sh:2
  - `utest` — tools/socle-test.sh:2

#### `req~porte-ci~2`

- Niveau normatif : DOIT
- Needs: impl, utest, mtest
- Couvertures réelles (5) :
  - `impl` — .github/workflows/ci.yml:1
  - `utest` — tools/ci-test.sh:2
  - `impl` — tools/ci.sh:3
  - `utest` — tools/paralleles-test.sh:2
  - `impl` — tools/paralleles.sh:2

#### `req~garde-fous-locaux~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (4) :
  - `impl` — tools/checks.sh:151
  - `impl` — tools/hooks/commit-msg.sh:2
  - `impl` — tools/hooks/pre-commit.sh:2
  - `utest` — tools/socle-test.sh:3

#### `req~tests-mecanises~1`

- Niveau normatif : DOIT
- Needs: impl, mtest
- Couvertures réelles (1) :
  - `impl` — docs/methode/05-tests-et-verification.md:3

#### `req~exemple-multilangage~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (2) :
  - `impl` — examples/demo-multi-langages/README.md:3
  - `utest` — tools/socle-test.sh:4

#### `req~perimetre-constate~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — tools/ci.sh:2
  - `utest` — tools/perimetre-test.sh:2
  - `impl` — tools/perimetre.sh:2

#### `req~anti-derive-generes~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `utest` — tools/derive-test.sh:2
  - `impl` — tools/derive.sh:2
  - `utest` — tools/locale-test.sh:2

#### `req~classification-exigences~2`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (3) :
  - `impl` — tools/classification.sh:2
  - `utest` — tools/gouvernance-test.sh:5
  - `impl` — tools/matrice.sh:2

#### `req~audit-de-realisation~1`

- Niveau normatif : DOIT
- Needs: dsn, impl, utest
- Couvertures réelles (3) :
  - `impl` — docs/methode/14-audit-de-realisation.md:3
  - `impl` — tools/audit.sh:2
  - `utest` — tools/gouvernance-test.sh:9

#### `req~rattachement-code-exigence~1`

- Niveau normatif : DOIT
- Needs: impl, utest
- Couvertures réelles (4) :
  - `utest` — tools/init-test.sh:5
  - `impl` — tools/init.sh:596
  - `utest` — tools/rattachement-test.sh:2
  - `impl` — tools/rattachement.sh:2

### Bilan (couvertures réelles)

46/46 exigence(s) testable(s) couverte(s) par au moins une trace réelle (100.0 %).

## 2. L'inverse — outillage sans exigence

Fichiers d'outillage (`tools/`, hooks git, gabarits de forge) qui ne portent AUCUN tag de traçabilité (`->req~…`). **Avertissement honnête** : l'absence de tag ne prouve PAS l'absence d'exigence — un fichier peut très bien servir une exigence couverte ailleurs. Cette liste est une liste DE REVUE, pas un verdict. `examples/` et `templates/` en sont exclus (spécification propre, ou identifiants d'exemple seulement — même exclusion qu'OpenFastTrace, `tools/oft.sh`).

### `.githooks` (2)

- `.githooks/commit-msg`
- `.githooks/pre-commit`

### `.github` (2)

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/dependabot.yml`

### `.github/ISSUE_TEMPLATE` (3)

- `.github/ISSUE_TEMPLATE/amelioration.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/ISSUE_TEMPLATE/question-ouverte.yml`

### `.gitlab/issue_templates` (1)

- `.gitlab/issue_templates/Amelioration.md`

### `.gitlab/merge_request_templates` (1)

- `.gitlab/merge_request_templates/Default.md`

### `tools` (3)

- `tools/adr-new.sh`
- `tools/bump.sh`
- `tools/journaux-revisions-editoriales.txt`

**Total : 12/70 fichier(s) d'outillage sans trace de traçabilité.**

