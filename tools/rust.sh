#!/bin/sh
# [impl->req~chaine-de-verification-du-moteur~1]
# Kit Rust — recettes de compilation hygiéniques, prêtes à copier dans tools/
# d'un projet instancié, puis à taguer vers l'exigence du projet (R2). Dans
# le gabarit, ce fichier n'est pas dans le périmètre tracé (templates/) :
# il est éprouvé par tools/rust-kit-test.sh, qui réalise
# `req~confinement-artefacts-worktree~1` ; la porte compagne est
# tools/hygiene-compilation.sh (`req~hygiene-artefacts-compilation~1`).
#
#   sh tools/rust.sh garde        # worktree lié : artefacts confinés, ou dossier cargo-target-<nom du worktree>
#   sh tools/rust.sh test         # nextest (ou cargo test) + doctests s'il y a une bibliothèque, incrémental coupé
#   sh tools/rust.sh couverture   # cargo llvm-cov, incrémental coupé
#   sh tools/rust.sh clean [N]    # artefacts inutilisés depuis N jours (défaut 2), par l'âge seulement
#   sh tools/rust.sh clean --partage [N]   # idem sur un cache PARTAGÉ entre projets (explicite)
#   sh tools/rust.sh etat         # où vont les artefacts, et leur poids
#
# Pourquoi (constats, pas théorie) :
# - CARGO_INCREMENTAL=0 sur tests et couverture : l'incrémental n'accélère
#   qu'une boucle d'édition et écrit dans target/*/incremental que rien ne
#   purge — la moitié des 503 Go d'ergonomia (2026-08-08).
# - Les chemins d'artefacts se RÉSOLVENT par `cargo metadata`, jamais en dur :
#   un poste qui déplace le cache (target-dir partagé, CARGO_TARGET_DIR) rend
#   muet tout `./target` écrit dans un script (méthode, ch. 4).
# - Un worktree lié qui compile dans le cache du tree principal sert les
#   artefacts de l'autre copie (symbole « introuvable » pourtant présent,
#   fichier généré vidé — ergonomia, 2026-08-14) : la garde l'interdit. Seule
#   exception : un dossier nommé EXACTEMENT cargo-target-<nom du worktree>
#   (hors du tree principal), qu'un balayage du poste sait reconnaître et
#   retirer quand le worktree disparaît. Un simple composant de chemin qui
#   porte le nom du worktree ne suffit pas (…/main/<nom>/target est le cache
#   du tree principal : constat de revue n° 1, 2026-10-25).
# - Le nettoyage se fait PAR L'ÂGE (`cargo sweep --time`), jamais par un
#   plafond de taille pendant une compilation : `--maxsize` efface les plus
#   anciens jusqu'à repasser sous la limite, artefacts de quelques minutes
#   compris — build cassé en plein vol (2026-10-25). Et jamais à l'insu de
#   l'utilisateur sur un cache partagé entre projets : `clean` le refuse
#   sans `--partage` (anti-patron « recettes clean devenues globales »).
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
NOM="$(basename "${ROOT}")"

cible() {  # répertoire d'artefacts effectif, résolu par cargo (chemin normalisé)
    _c="$(cargo metadata --format-version 1 --no-deps 2>/dev/null \
        | tr ',' '\n' | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p' | head -1)"
    # JSON : les antislashs sont doublés (chemins Windows) ; Git Bash sait
    # les ramener en forme POSIX.
    _c="$(printf '%s' "${_c}" | sed 's/\\\\/\\/g')"
    if command -v cygpath >/dev/null 2>&1 && [ -n "${_c}" ]; then
        _c="$(cygpath -u "${_c}" 2>/dev/null || printf '%s' "${_c}")"
    fi
    printf '%s' "${_c}"
}

worktree_lie() {  # vrai dans un worktree lié (pas le tree principal, pas un sous-module)
    _gd="$(git rev-parse --path-format=absolute --git-dir 2>/dev/null || true)"
    _cd="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "${_gd}" ] && [ -n "${_cd}" ] && [ "${_gd}" != "${_cd}" ] \
        && case "${_gd}" in "${_cd}"/worktrees/*) return 0 ;; esac
    return 1
}

confine() {  # vrai si le répertoire $1 est admis pour ce worktree
    _d="$1"
    _principal="$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." 2>/dev/null && pwd || true)"
    case "${_d}" in
        "${ROOT}"|"${ROOT}"/*) return 0 ;;                 # dans le worktree
    esac
    if [ -n "${_principal}" ]; then
        case "${_d}" in
            "${_principal}"|"${_principal}"/*) return 1 ;;  # dans le tree principal : refusé
        esac
    fi
    case "${_d}" in
        */cargo-target-"${NOM}"|*/cargo-target-"${NOM}"/*) return 0 ;;  # nommé d'après le worktree
    esac
    return 1
}

garde() {
    if ! worktree_lie; then
        echo "tree principal : garde sans objet."
        return 0
    fi
    dir="$(cible)"
    if [ -z "${dir}" ]; then
        echo "ERREUR : cargo metadata ne rend aucun répertoire d'artefacts (cargo absent, ou manifeste invalide)." >&2
        exit 1
    fi
    if confine "${dir}"; then
        case "${dir}" in
            "${ROOT}"|"${ROOT}"/*) echo "worktree isolé : artefacts dans le worktree." ;;
            *) echo "worktree isolé : artefacts hors du dépôt, dans cargo-target-${NOM} (${dir})." ;;
        esac
        return 0
    fi
    echo "ERREUR : worktree lié « ${NOM} » dont les artefacts iraient dans « ${dir} »," >&2
    echo "cache PARTAGÉ avec le tree principal ou avec d'autres projets : artefacts croisés garantis." >&2
    echo "Remède : export CARGO_TARGET_DIR=\"\$PWD/target\", ou un dossier nommé exactement" >&2
    echo "cargo-target-${NOM} sur le disque de votre choix, avant tout cargo." >&2
    exit 1
}

a_une_bibliotheque() {  # vrai si une cible lib existe dans l'espace de travail
    cargo metadata --format-version 1 --no-deps 2>/dev/null \
        | tr '{' '\n' | grep -qE '"kind":\[("lib"|"rlib"|"dylib"|"cdylib"|"staticlib"|"proc-macro")'
}

test_() {
    garde
    export CARGO_INCREMENTAL=0
    if command -v cargo-nextest >/dev/null 2>&1; then
        cargo nextest run --workspace
        # nextest ne joue pas les doctests ; cargo test --doc exige une
        # bibliothèque (échec « no library targets » sinon).
        if a_une_bibliotheque; then
            cargo test --workspace --doc
        fi
    else
        echo "note : cargo-nextest absent (cargo install --locked cargo-nextest) — cargo test, binaires un à un, doctests compris." >&2
        cargo test --workspace --no-fail-fast
    fi
}

couverture() {
    garde
    export CARGO_INCREMENTAL=0
    command -v cargo-llvm-cov >/dev/null 2>&1 \
        || { echo "ERREUR : cargo-llvm-cov requis (cargo install --locked cargo-llvm-cov)." >&2 ; exit 1 ; }
    cargo llvm-cov --workspace "$@"
}

poids() {  # taille lisible de $1, ou « absent »
    if [ -d "$1" ]; then du -sh "$1" 2>/dev/null | cut -f1; else echo "absent"; fi
}

clean() {
    partage=0
    if [ "${1:-}" = "--partage" ]; then partage=1 ; shift ; fi
    jours="${1:-2}"
    dir="$(cible)"
    [ -n "${dir}" ] || { echo "cargo metadata muet : rien à nettoyer." ; return 0 ; }
    if [ "${partage}" -eq 0 ] && ! confine "${dir}"; then
        echo "REFUS : ${dir} est un cache partagé (ni dans le dépôt, ni cargo-target-${NOM})." >&2
        echo "Un balayage y toucherait aux artefacts de tous les projets du poste." >&2
        echo "Si c'est voulu : sh tools/rust.sh clean --partage [jours]." >&2
        exit 1
    fi
    echo "artefacts : ${dir} ($(poids "${dir}"))"
    if command -v cargo-sweep >/dev/null 2>&1; then
        # Par l'âge, jamais par la taille : un plafond efface des artefacts
        # tout frais dès que le cache frôle la limite.
        cargo sweep --time "${jours}"
    else
        echo "note : cargo-sweep absent (cargo install --locked cargo-sweep) — balayage ignoré." >&2
    fi
    echo "état final : $(poids "${dir}")"
}

etat() {
    dir="$(cible)"
    echo "artefacts   : ${dir:-?}"
    echo "poids       : $(poids "${dir:-/nonexistent}")"
    if [ -n "${dir}" ] && [ -d "${dir}" ]; then
        inc="$(find "${dir}" -maxdepth 2 -type d -name incremental -exec du -sk '{}' + 2>/dev/null \
               | awk '{s+=$1} END{printf "%.1f Gio\n", s/1048576}')"
    else
        inc="absent"
    fi
    echo "incrémental : ${inc}"
    if [ -f rust-toolchain.toml ] || [ -f rust-toolchain ]; then
        echo "chaîne      : épinglée ($( [ -f rust-toolchain.toml ] && echo rust-toolchain.toml || echo rust-toolchain))"
    else
        echo "chaîne      : NON épinglée (rust-toolchain.toml absent)"
    fi
}

case "${1:-}" in
    garde)      garde ;;
    test)       test_ ;;
    couverture) shift ; couverture "$@" ;;
    clean)      shift ; clean "$@" ;;
    etat)       etat ;;
    *) echo "Usage : sh tools/rust.sh garde | test | couverture [args] | clean [--partage] [jours] | etat" >&2 ; exit 2 ;;
esac
