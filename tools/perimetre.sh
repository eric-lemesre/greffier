#!/bin/sh
# [impl->req~perimetre-constate~1]
# Périmètre de la porte, CONSTATÉ et jamais déclaré. Imprime sur la sortie
# standard la voie que `tools/ci.sh` doit emprunter : « docs » ou « complet ».
#
# Pourquoi constater plutôt que déclarer. Une voie rapide choisie à la main
# (« ce n'est que de la doc ») est un contrôle qui passe toujours dès que le
# jugement se trompe. Ici, c'est le CHANGEMENT RÉEL qui décide, et le doute
# tranche systématiquement en faveur de la voie complète.
#
# L'empreinte est prise LARGE — commits depuis la base de fusion, index,
# arbre de travail ET fichiers non suivis. `git diff` seul ne voit pas un
# fichier jamais ajouté : angle mort déjà payé une fois sur ergonomia, où un
# nouveau script d'outillage échappait au classement.
#
#   sh tools/perimetre.sh        # imprime « docs » ou « complet »
#
# POSIX sh strict.
set -eu

# Chemins portant espaces ou métacaractères (constat de revue n° 2) : le
# découpage par défaut d'un « $(git ls-files) » non quoté coupe « mon
# document.md » en deux et laisse un glob s'expanser. Une porte qui rate un
# fichier ne signale rien — elle se contente de ne pas le voir. On découpe
# donc sur les seules fins de ligne, globbing désactivé.
IFS='
'
set -f

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

complet() { echo "complet"; exit 0; }

# Branche de référence : la tête distante déclarée, sinon les noms d'usage.
# Aucune des trois n'existe (clone superficiel, dépôt neuf) → voie complète.
base=""
for ref in "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)" \
           origin/main origin/master main master; do
    [ -n "${ref}" ] || continue
    if git rev-parse --verify -q "${ref}" >/dev/null 2>&1; then
        base="$(git merge-base HEAD "${ref}" 2>/dev/null || true)"
        [ -n "${base}" ] && break
    fi
done
[ -n "${base}" ] || complet

EMPREINTE="$(
    {
        git diff --name-only "${base}"...HEAD 2>/dev/null || true
        git diff --name-only 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
        git ls-files --others --exclude-standard 2>/dev/null || true
    } | sort -u
)"

# Empreinte vide : rien à classer, donc rien qui prouve que la voie rapide
# suffit. On ne prend jamais ce pari.
[ -n "${EMPREINTE}" ] || complet

# --- Classement -------------------------------------------------------------
# Un chemin est « documentaire » s'il ne peut modifier NI le comportement des
# portes, NI le produit. Tout le reste — outillage, façades, CI, code du
# projet — bascule en voie complète. La liste est une ALLOWLIST : ce qui n'y
# figure pas est complet par défaut, jamais l'inverse.
est_documentaire() {
    case "$1" in
        # Documentation, méthode, ADR, spécification, registres.
        docs/*|spec/*)            return 0 ;;
        # Modèles d'artefacts : du Markdown, hors périmètre de traçabilité.
        templates/*.md|templates/*/*.md) return 0 ;;
        # Documents racine.
        README.md|README.en.md|CONTRIBUTING.md|CHANGELOG.md|NEWS.md|AGENTS.md|CLAUDE.md|LICENSE)
            return 0 ;;

        # --- Point d'extension du projet instancié ---------------------------
        # Déclarer ici les chemins purement documentaires de VOTRE projet.
        # Règle : dans le doute, ne rien ajouter — un chemin oublié coûte une
        # porte complète (quelques minutes), un chemin ajouté à tort laisse
        # passer un défaut. Exemples :
        #   docs-site/*)  return 0 ;;      # site statique
        #   *.adoc)       return 0 ;;      # documentation AsciiDoc
        # NE JAMAIS y placer : outillage (tools/), façades (Taskfile, CI),
        # configuration, ni aucun fichier de code — même « juste un
        # commentaire » : le classement lit des chemins, pas des diffs.
        # ---------------------------------------------------------------------

        *) return 1 ;;
    esac
}

for chemin in ${EMPREINTE}; do
    est_documentaire "${chemin}" || complet
done

echo "docs"
