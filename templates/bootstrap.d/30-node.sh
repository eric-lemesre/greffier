# Module bootstrap — Node.js 22+ : socle de l'outillage npm du projet
# (lint Markdown notamment ; markdownlint-cli2 ≥ 0.23 exige Node 22).
# MODÈLE à copier dans tools/bootstrap.d/ d'un projet instancié, puis à
# taguer vers l'ADR/l'exigence du projet qui le justifie (R2).
# Contrat : sourcé par tools/bootstrap.sh, PHASE=annonce puis PHASE=verifie
# (voir l'en-tête de bootstrap.sh pour les variables et aides disponibles).
case "${PHASE}" in
    annonce)
        echo "    - Node.js 22+       — outillage npm (lint Markdown…)"
        ;;
    verifie)
        NV=""
        if command -v node >/dev/null 2>&1; then
            NV="$(node --version | sed 's/^v//; s/\..*//')"
        fi
        if [ "${NV:-0}" -ge 22 ] 2>/dev/null; then
            echo "ok — Node.js ${NV} (22+ requis)"
        else
            echo "MANQUANT — Node.js 22+ (version détectée : ${NV:-aucune})"
            MANQUANTS=$((MANQUANTS + 1))
            ABSENTS="${ABSENTS} node"
            # Les dépôts apt/dnf des distributions stables sont souvent en
            # retard : si la version installée reste < 22, passer par
            # https://nodejs.org/ (ou nvm), puis relancer --verifie.
            installer "Node.js 22+" "nodejs" "nodejs" "node" "OpenJS.NodeJS.LTS"
        fi
        ;;
esac
