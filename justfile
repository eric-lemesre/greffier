# Façade d'orchestration « just » — variante interchangeable (ADR-0007).
# Pour l'adopter : copier ce fichier à la racine du projet à la place de
# Taskfile.yml. PURE DÉLÉGATION : la logique vit dans tools/*.sh ; une
# logique qui apparaît ici est un défaut à corriger en revue.
# Note : just exécute ses recettes via un shell sh (voir `windows-shell` dans
# le manuel just pour les postes Windows sans Git Bash).

# Liste des recettes disponibles
default:
    @just --list

# Traçabilité complète (échoue si un maillon manque)
trace:
    sh tools/oft.sh trace

# Rapport HTML de traçabilité dans build/tracabilite.html
report:
    sh tools/oft.sh report

# Contrôles de cohérence (ADR, templates, version)
check:
    sh tools/checks.sh

# Porte anti-secrets (balayage complet du dépôt)
secrets:
    sh tools/secrets.sh scan

# Tout ce que la CI exécute (voie constatée) : just ci [--complet|--rapide]
ci *args:
    sh tools/ci.sh {{args}}

# Intégrité des liens internes de la documentation
liens:
    sh tools/liens.sh

# Périmètre de l'audit de réalisation : just audit [--ecrire|--squelette <dom>]
audit *args:
    sh tools/audit.sh {{args}}

# Anti-dérive des artefacts générés
derive:
    sh tools/derive.sh

# Matrice de traçabilité (informative, absente de `just ci`)
matrice:
    sh tools/matrice.sh

# Régénère tous les artefacts dérivés
regen:
    sh tools/todo.sh --ecrire
    sh tools/revues.sh --ecrire
    sh tools/audit.sh --ecrire
    sh tools/badges.sh --ecrire
    sh tools/avancement.sh --ecrire
    sh tools/matrice.sh

# Conformité des issues au cycle de vie (hors porte : réseau requis)
issues:
    sh tools/issues.sh

# Installe les hooks git du dépôt
hooks:
    git config core.hooksPath .githooks
    @echo "Hooks installés (core.hooksPath = .githooks)."

# Tout fichier de code se rattache à une exigence (étiquette de couverture ou mention)
rattachement:
    sh tools/rattachement.sh

# Hygiène des artefacts de compilation (chaîne épinglée, incrémental coupé sur tests et CI)
hygiene:
    sh tools/hygiene-compilation.sh

# Journalisation Rust (abonné dans le seul binaire, instrument sans arguments, secrets masqués, aucun println! de bibliothèque)
journalisation:
    sh tools/journalisation.sh

# Nettoie les artefacts locaux (chemins déclarés) : just clean [--all]
clean *args:
    sh tools/clean.sh {{args}}

# Vérifie/installe les dépendances (socle + point d'extension projet)
bootstrap:
    sh tools/bootstrap.sh

# Accueil d'un contributeur qui vient de cloner (bootstrap + hooks + portes)
setup:
    sh tools/setup.sh

# Crée l'ADR suivant depuis le modèle : just adr-new titre-en-kebab
adr-new titre:
    sh tools/adr-new.sh {{titre}}

# Met à jour VERSION (compléter le CHANGELOG) : just bump X.Y.Z
bump version:
    sh tools/bump.sh {{version}}
