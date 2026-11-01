#!/bin/sh
# [impl->req~onboarding-outille~2]
# [impl->req~accueil-informatif~1]
# « Scripts to Rule Them All » — setup : accueillir un contributeur qui vient
# de cloner. Dépendances (bootstrap), garde-fous, portes, puis orientation.
# Idempotent : relançable sans dégât. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

echo "Accueil 1/3 — dépendances (bootstrap)"
sh tools/bootstrap.sh

echo "Accueil 2/3 — garde-fous locaux (hooks git)"
git config core.hooksPath .githooks
echo "Hooks installés (core.hooksPath = .githooks)."

echo "Accueil 3/3 — état du dépôt (portes)"
# L'accueil RENSEIGNE, il ne sanctionne pas. Un dépôt dont la spécification
# précède la réalisation a des portes légitimement rouges ; en faire échouer
# l'accueil ferait porter à un arrivant un défaut qui n'est pas le sien et
# qu'il ne peut pas corriger. Le silence serait pire encore : la voie
# documentaire complète est jouée, et son bilan nomme ce qui ne passe pas.
# « task ci » sanctionne, « task setup » renseigne.
if CI_COMPLET=0 sh tools/ci.sh --rapide; then
    ETAT="toutes les portes documentaires passent."
else
    ETAT="des portes sont en ÉCHEC — voir le bilan ci-dessus, et « task ci »."
fi

cat <<EOF

État du dépôt : ${ETAT}
EOF

cat <<'EOF'
Poste prêt. Pour s'orienter :
  - AGENTS.md            — le contrat de travail (règles, boucle, commandes)
  - docs/methode/        — la méthode, du besoin aux tests mécanisés
  - spec/                — besoins et exigences tracés du projet
  - docs/adr/            — les décisions et leur pourquoi
  - task --list          — les commandes (ou sh tools/*.sh sans façade)
Première contribution : lire AGENTS.md §2 (boucle de travail), puis choisir
une exigence et suivre la chaîne exigence → tags → tests → task ci.
EOF
