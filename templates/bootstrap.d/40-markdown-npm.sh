# Module bootstrap — dépendances npm du lint Markdown : markdownlint-cli2
# (porte tools/markdown.sh) et string-width (formateur format-tables.mjs).
# L'installation est un simple `npm install` à la racine, idempotent et
# piloté par package.json (versionner le package-lock.json produit).
# MODÈLE à copier dans tools/bootstrap.d/ d'un projet instancié, puis à
# taguer vers l'ADR/l'exigence du projet qui le justifie (R2).
# Exigence servie : req~kit-lint-markdown~1 (module de bootstrap, req~onboarding-outille~2).
# Contrat : sourcé par tools/bootstrap.sh, PHASE=annonce puis PHASE=verifie.
case "${PHASE}" in
    annonce)
        echo "    - dépendances npm   — markdownlint-cli2 + normalisation des tableaux (npm install)"
        ;;
    verifie)
        if [ -d "${RACINE}/node_modules/markdownlint-cli2" ] && [ -d "${RACINE}/node_modules/string-width" ]; then
            echo "ok — dépendances npm (markdownlint-cli2, string-width)"
        elif ! command -v npm >/dev/null 2>&1; then
            echo "MANQUANT — dépendances npm (npm absent : installer Node.js d'abord)"
            MANQUANTS=$((MANQUANTS + 1))
            ABSENTS="${ABSENTS} npm"
            AVERTISSEMENTS=$((AVERTISSEMENTS + 1))
        else
            echo "MANQUANT — dépendances npm (lint Markdown + tableaux)"
            MANQUANTS=$((MANQUANTS + 1))
            ABSENTS="${ABSENTS} deps-npm"
            if [ "${INSTALLE}" -eq 1 ]; then
                (cd "${RACINE}" && npm install --no-audit --no-fund)
            else
                echo "  → manquant (installation non demandée : npm install)"
            fi
        fi
        ;;
esac
