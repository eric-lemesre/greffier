#!/bin/sh
# Exigence servie : req~journal-du-service~1 — porte reprise du gabarit alm-forge (ADR-0022 du gabarit, ADR-0007).
# Porte de journalisation des projets Rust (méthode, ch. 17). Elle constate
# les quatre règles du journal qu'un outil peut juger sans compiler ; les
# autres (corrélation, niveaux, journald, absence de contenu métier) relèvent
# de la revue et des tests du projet.
#
#   A. Une bibliothèque n'installe jamais l'abonné du journal
#      (`set_global_default`, `.init()` d'un abonné `tracing_subscriber`,
#      `env_logger::init`) : seul le binaire le fait — une crate embarquée
#      ne confisque pas le journal de son hôte.
#   B. Tout `#[instrument]` porte `skip_all` : par défaut il enregistre
#      TOUS les arguments par leur Debug, et une fonction qui reçoit un
#      jeton le fait fuir dans le journal.
#   C. Aucun type qui dérive `Debug` ne porte un secret en `String` nue
#      (champ ou nouveau type dont le nom évoque un jeton, un mot de passe,
#      un secret, une clé) : le secret vit dans un type qui masque sa valeur.
#   D. Une bibliothèque n'écrit pas de diagnostic par `println!`,
#      `eprintln!`, `print!`, `eprint!` ou `dbg!` : elle émet par le journal.
#
# Périmètre : les fichiers `src/**/*.rs` de chaque paquet du dépôt (manifeste
# portant `[package]`). Une « bibliothèque » est un paquet qui a un
# `src/lib.rs`, hors `src/main.rs` et `src/bin/` ; un paquet sans `lib.rs`
# est un binaire, libre de ses modules. Les lignes de commentaire sont
# ignorées. Limite assumée : le module de tests est supposé en fin de
# fichier — la lecture s'arrête au premier `#[cfg(test)]`.
#
# Dérogation : un commentaire `journal: admis — <raison>` sur la ligne ou la
# ligne qui la précède (sur la première ligne de l'attribut pour B). La
# raison est obligatoire : sans elle, la dérogation ne compte pas.
#
# Les mots qui désignent un secret (règle C) se règlent par la variable
# JOURNAL_MOTS_SECRETS (alternative de motifs, en minuscules).
#
# Sans manifeste Cargo à la racine, la porte n'a rien à juger et le dit.
#
#   sh tools/journalisation.sh
#
# POSIX sh strict ; find, grep, awk.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if [ ! -f Cargo.toml ]; then
    echo "journalisation : aucun manifeste Cargo à la racine, rien à vérifier."
    exit 0
fi

MOTS="${JOURNAL_MOTS_SECRETS:-jeton|token|password|passwd|mot_de_passe|motdepasse|secret|api_key|apikey|cle_api|private_key|cle_privee}"

# Paquets : manifestes qui déclarent [package]. Dans un dépôt git, seuls les
# fichiers SUIVIS comptent : un worktree d'agent rangé sous un dossier caché,
# des artefacts ou des dépendances vendues ne sont pas le code du dépôt
# (constaté à la mise en place : 23 constats en double venus d'un worktree
# sous .claude/). Hors git, recherche par find, dossiers cachés exclus.
# Chaque commande est rendue non bloquante (porte muette sinon).
lister() {  # $1 : motif de nom de fichier
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git ls-files -- "$1" "*/$1" 2>/dev/null || true
    else
        find . -name "$1" -not -path '*/.*' -not -path '*/target/*' -not -path '*/vendor/*' \
            -not -path '*/node_modules/*' 2>/dev/null | sed 's|^\./||' || true
    fi
}
paquets="$(lister Cargo.toml | while read -r m; do
               grep -q '^\[package\]' "$m" 2>/dev/null && dirname "$m"
           done | sort -u)"
sources="$(lister '*.rs' | sort -u)"

fail=0
examines=0
IFS='
'
set -f
for p in ${paquets}; do
    if [ "${p}" = "." ]; then s="src" ; else s="${p}/src" ; fi
    [ -d "${s}" ] || continue
    lib=0
    [ -f "${s}/lib.rs" ] && lib=1
    for f in $(printf '%s\n' "${sources}" | grep -F "${s}/" | awk -v s="${s}/" 'index($0, s) == 1'); do
        [ -f "${f}" ] || continue
        examines=$((examines + 1))
        case "${f}" in
            "${s}/main.rs"|"${s}/bin/"*) estlib=0 ;;
            *) estlib="${lib}" ;;
        esac
        constats="$(awk -v estlib="${estlib}" -v mots="${MOTS}" '
            function admis(l, p) { return (l ~ /journal: admis —[[:space:]]*[^[:space:]]/ || p ~ /journal: admis —[[:space:]]*[^[:space:]]/) }
            BEGIN { abonne = 0; init = 0; enattr = 0; attente = 0; enstruct = 0; prec = "" }
            /^[[:space:]]*#\[cfg\(test\)\]/ { exit }
            /^[[:space:]]*\/\// { prec = $0 ; next }
            {
                l = $0 ; m = tolower($0)
                # A — abonné installé hors du binaire
                if (estlib == 1) {
                    if (l ~ /tracing_subscriber/) abonne = 1
                    if (l ~ /set_global_default|env_logger::(try_)?init|env_logger::Builder/) {
                        if (!admis(l, prec)) printf "A:%d:%s\n", NR, l
                    } else if (l ~ /\.(try_)?init\(\)/ && init == 0 && !admis(l, prec)) {
                        init = NR ; texteinit = l
                    }
                }
                # B — #[instrument] sans skip_all
                if (enattr == 0 && l ~ /#\[(tracing::)?instrument([^[:alnum:]_]|$)/) {
                    enattr = 1 ; attr = "" ; ligneattr = NR ; attradmis = admis(l, prec)
                }
                if (enattr == 1) {
                    attr = attr " " l
                    if (l ~ /\][[:space:]]*$/ || l ~ /\][[:space:]]*(pub[[:space:]]+)?(async[[:space:]]+)?fn/) {
                        enattr = 0
                        if (attr !~ /skip_all/ && !attradmis) printf "B:%d:%s\n", ligneattr, attr
                    }
                }
                # C — secret en String dans un type qui dérive Debug
                if (l ~ /#\[derive\(/ && l ~ /Debug/) {
                    attente = 1
                } else if (attente == 1 && l ~ /(^|[[:space:]])(struct|enum)[[:space:]]/) {
                    attente = 0
                    if (m ~ ("(struct|enum)[[:space:]]+[a-z0-9_]*(" mots ")[a-z0-9_]*[[:space:]]*\\((pub[[:space:]]+)?(std::string::)?string\\)") && !admis(l, prec))
                        printf "C:%d:%s\n", NR, l
                    if (l ~ /\{/) { enstruct = 1 ; prof = 0 }
                } else if (attente == 1 && l !~ /^[[:space:]]*#\[/) {
                    attente = 0
                }
                if (enstruct == 1) {
                    c = l ; ouv = gsub(/\{/, "{", c) ; fer = gsub(/\}/, "}", c) ; prof += ouv - fer
                    if (m ~ ("(^|[^a-z0-9_])[a-z0-9_]*(" mots ")[a-z0-9_]*[[:space:]]*:[[:space:]]*(option<[[:space:]]*)?(std::string::)?string([^a-z0-9_]|$)") && !admis(l, prec))
                        printf "C:%d:%s\n", NR, l
                    if (prof <= 0) enstruct = 0
                }
                # D — diagnostic hors journal dans une bibliothèque
                if (estlib == 1 && l ~ /(^|[^[:alnum:]_])(println|eprintln|print|eprint|dbg)!/ && !admis(l, prec))
                    printf "D:%d:%s\n", NR, l
                prec = l
            }
            END { if (estlib == 1 && abonne == 1 && init > 0) printf "A:%d:%s\n", init, texteinit }
        ' "${f}")"
        [ -n "${constats}" ] || continue
        fail=1
        for c in ${constats}; do
            regle="${c%%:*}" ; reste="${c#*:}" ; ligne="${reste%%:*}" ; texte="${reste#*:}"
            case "${regle}" in
                A) motif="bibliothèque qui installe l'abonné du journal (seul le binaire le fait)" ;;
                B) motif="#[instrument] sans skip_all (les arguments partiraient au journal)" ;;
                C) motif="secret en String dans un type qui dérive Debug (le masquer par son type)" ;;
                D) motif="diagnostic hors journal dans une bibliothèque" ;;
            esac
            echo "ÉCHEC : ${f}:${ligne} — ${motif} :" >&2
            printf '    %s\n' "$(printf '%s' "${texte}" | sed 's/^[[:space:]]*//' | cut -c1-160)" >&2
        done
    done
done
set +f
unset IFS

if [ "${examines}" -eq 0 ]; then
    echo "note — aucun fichier src/**/*.rs dans les paquets du dépôt."
fi
if [ "${fail}" -ne 0 ]; then
    echo "journalisation : ÉCHEC (méthode, ch. 17 ; dérogation : « journal: admis — <raison> »)." >&2
    exit 1
fi
echo "journalisation : OK (${examines} fichier(s) Rust examiné(s))."
