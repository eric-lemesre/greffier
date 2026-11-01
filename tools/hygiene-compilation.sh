#!/bin/sh
# Hygiène des artefacts de compilation. Dans un projet instancié qui compile
# du Rust, la porte vérifie les deux réglages sans lesquels le cache de
# compilation grossit sans limite — constats : 500 Go de target/ sur
# ergonomia (2026-08-08), puis 70 à 80 Go PAR BRANCHE de travail sur un
# poste multi-worktree et un disque plein trois fois en un mois (2026-10-25).
#
#   1. La chaîne de compilation est ÉPINGLÉE : rust-toolchain.toml (ou le
#      fichier hérité rust-toolchain) à la racine, suivi par git, et dont le
#      canal est une version exacte (« 1.NN.P », ou un canal daté
#      « nightly-AAAA-MM-JJ ») — jamais « stable », « beta » ni « nightly »
#      nus, qui avancent à chaque publication de rustc et conservent alors
#      une copie complète des artefacts par version.
#   2. Toute commande de test ou de couverture coupe la compilation
#      incrémentale : l'incrémental n'accélère qu'une boucle d'édition,
#      jamais une exécution complète, et il écrit dans target/*/incremental
#      que rien ne purge — la moitié des 503 Go.
#
# Contrôle 2, règle lue : dans chaque fichier qui invoque `cargo test`,
# `cargo t`, `cargo nextest`, `cargo llvm-cov` ou `cargo tarpaulin` (options
# et chaîne « +… » admises entre `cargo` et la sous-commande ; `$(CARGO)` et
# `${CARGO}` admis ; `cargo-nextest`, `cargo-llvm-cov`, `cargo-tarpaulin`
# admis), le réglage doit être présent sur CHAQUE ligne d'appel, ou sur une
# ligne hors commentaire SITUÉE AVANT le premier appel (`export`, `env:`,
# `variables:`, `export … := "0"` de just…). Formes reconnues :
# `CARGO_INCREMENTAL=0`, `CARGO_INCREMENTAL: 0`, `:= "0"`, avec ou sans
# guillemets. Le réglage natif de Cargo, `incremental = false` dans
# `.cargo/config.toml`, vaut pour tout le dépôt. Les lignes de commentaire,
# et les lignes `echo`/`printf` (qui citent une commande sans la lancer), ne
# comptent ni comme appel ni comme réglage.
# Limite assumée : un `export CARGO_INCREMENTAL=0` écrit SEUL sur une ligne
# de recette just ou Taskfile n'agit pas sur la ligne suivante (un shell par
# ligne) ; la porte ne distingue pas ce cas — préférer le préfixe sur la
# ligne d'appel, ou `export CARGO_INCREMENTAL := "0"` (just) et `env:`
# (Taskfile) en tête de fichier.
#
# Sans manifeste Cargo à la racine, la porte n'a rien à juger et le dit.
# Un autre langage se traite par un bloc de plus, sur le même patron.
#
#   sh tools/hygiene-compilation.sh
#
# POSIX sh strict ; grep -E, sed, awk.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if [ ! -f Cargo.toml ]; then
    echo "hygiène de compilation : aucun manifeste Cargo à la racine, rien à vérifier."
    exit 0
fi

fail=0

# --- 1. Chaîne de compilation épinglée ----------------------------------------
chaine=""
if [ -f rust-toolchain.toml ]; then
    chaine="rust-toolchain.toml"
    canal="$(sed -n 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' rust-toolchain.toml | head -1)"
elif [ -f rust-toolchain ]; then
    chaine="rust-toolchain"
    canal="$(sed -n '1s/^[[:space:]]*//;1s/[[:space:]]*$//;1p' rust-toolchain)"
fi
if [ -z "${chaine}" ]; then
    echo "ÉCHEC : aucune chaîne épinglée (rust-toolchain.toml absent) — chaque changement de rustc duplique les artefacts." >&2
    fail=1
else
    if ! git ls-files --error-unmatch "${chaine}" >/dev/null 2>&1; then
        echo "ÉCHEC : ${chaine} n'est pas suivi par git — la chaîne n'est épinglée que sur ce poste." >&2
        fail=1
    fi
    case "${canal}" in
        "")
            echo "ÉCHEC : ${chaine} ne déclare aucun canal (channel = \"1.NN.P\")." >&2 ; fail=1 ;;
        stable|beta|nightly)
            echo "ÉCHEC : ${chaine} suit le canal flottant « ${canal} » — ce n'est pas un épinglage ; écrire une version exacte (channel = \"1.NN.P\") ou un canal daté." >&2 ; fail=1 ;;
        *)
            echo "ok — chaîne de compilation épinglée (${chaine} : ${canal})" ;;
    esac
fi

# --- 2. Incrémental coupé sur test et couverture ------------------------------
APPEL='((^|[^[:alnum:]_-])cargo([[:space:]]+(\+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+(t|test|nextest|llvm-cov|tarpaulin)([[:space:]]|$)|\$[({]CARGO[)}]([[:space:]]+-[^[:space:]]+)*[[:space:]]+(t|test|nextest|llvm-cov|tarpaulin)([[:space:]]|$)|(^|[^[:alnum:]_-])cargo-(nextest|llvm-cov|tarpaulin)([[:space:]]|$))'
REGLAGE='CARGO_INCREMENTAL[[:space:]]*(=|:=|:)[[:space:]]*["'"'"']?0["'"'"']?([^[:digit:]]|$)'
INERTE='^[[:space:]]*(#|echo[[:space:]]|printf[[:space:]])'

natif=0
if [ -f .cargo/config.toml ] && grep -qE '^[[:space:]]*incremental[[:space:]]*=[[:space:]]*false' .cargo/config.toml; then
    natif=1
    echo "ok — .cargo/config.toml : incremental = false (vaut pour tout le dépôt)"
fi

# Fichiers examinés : façades, scripts, CI des forges courantes. Chaque
# commande est rendue non bloquante : sous « set -e », un ls de façade
# absente ou un find de dossier absent arrêterait le groupe et la liste
# resterait VIDE — porte muette (constaté à la mise en place, cas d'échec
# du test joué sur un dépôt sans justfile).
# Le test de cette porte (tools/hygiene-compilation-test.sh) est exclu : ses
# appels sont des JEUX D'ESSAI écrits dans des dépôts jetables, jamais lancés
# sur le dépôt ; copié dans un projet instancié, il faisait échouer la porte
# (constaté sur un projet instancié).
fichiers="$( { ls justfile Justfile .justfile Taskfile.yml Makefile makefile GNUmakefile .gitlab-ci.yml 2>/dev/null || true
               find tools scripts -type f -name '*.sh' ! -path tools/hygiene-compilation-test.sh 2>/dev/null || true
               find .github/workflows .gitea/workflows .forgejo/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null || true
             } | sort -u )"

trouve=0
IFS='
'
set -f
for f in ${fichiers}; do
    [ -f "$f" ] || continue
    # Lignes utiles : numérotées, hors commentaires et hors echo/printf.
    utiles="$(grep -nE "${APPEL}|${REGLAGE}" "$f" 2>/dev/null | grep -vE "^[0-9]+:${INERTE#^}" || true)"
    appels="$(printf '%s\n' "${utiles}" | grep -E "${APPEL}" || true)"
    [ -n "${appels}" ] || continue
    trouve=1
    if [ "${natif}" -eq 1 ]; then
        echo "ok — ${f} : réglage natif du dépôt"
        continue
    fi
    premier="$(printf '%s\n' "${appels}" | head -1 | cut -d: -f1)"
    # Réglage posé avant le premier appel ?
    amont="$(printf '%s\n' "${utiles}" | grep -E "${REGLAGE}" | awk -F: -v p="${premier}" '$1 < p' || true)"
    # Sinon, chaque ligne d'appel doit le porter.
    nus="$(printf '%s\n' "${appels}" | grep -vE "${REGLAGE}" || true)"
    if [ -n "${amont}" ] || [ -z "${nus}" ]; then
        echo "ok — ${f} : commandes de test Cargo avec CARGO_INCREMENTAL=0"
    else
        echo "ÉCHEC : ${f} lance des tests Cargo sans CARGO_INCREMENTAL=0 (ni sur la ligne, ni avant le premier appel) :" >&2
        printf '%s\n' "${nus}" | sed 's/^/    /' >&2
        fail=1
    fi
done
set +f
unset IFS

if [ "${trouve}" -eq 0 ]; then
    echo "note — aucune commande de test Cargo trouvée dans les façades, scripts et CI."
fi

if [ "${fail}" -ne 0 ]; then
    echo "hygiène de compilation : ÉCHEC." >&2
    exit 1
fi
echo "hygiène de compilation : OK."
