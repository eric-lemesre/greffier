#!/bin/sh
# Test mécanisé du filtre de statut de la porte de traçabilité (ADR-0020) et
# de la tolérance des exigences approuvées à réaliser (ADR-0020) : un item non
# approuvé sort de la porte ; une exigence approuvée sans aucun maillon aval
# passe ; une couverture commencée mais incomplète, un lien amont rompu, un
# besoin approuvé sans exigence approuvée la font échouer. Les cas NÉGATIFS
# sont les plus importants : une tolérance trop large rendrait la porte muette.
# POSIX sh strict. Requiert Java (comme tools/oft.sh).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

prepare() {
    rm -rf "${TMP}/depot"
    mkdir -p "${TMP}/depot/tools" "${TMP}/depot/spec" "${TMP}/depot/src"
    # Les tags de couverture de la porte elle-même pointeraient vers des
    # exigences absentes du dépôt de test : on les retire de la copie.
    grep -v '^# \[[a-z]*->' "${ROOT}/tools/oft.sh" > "${TMP}/depot/tools/oft.sh"
    # Réutilise le jar déjà vérifié du dépôt : pas de téléchargement par cas.
    if [ -d "${ROOT}/.cache" ]; then cp -R "${ROOT}/.cache" "${TMP}/depot/"; fi
}
porte() { (cd "${TMP}/depot" && sh tools/oft.sh trace >/dev/null 2>&1); }
attendu() {
    if porte; then r=ok; else r=echec; fi
    if [ "${r}" != "$1" ]; then
        echo "ÉCHEC : $2 — attendu ${1}, obtenu ${r}" >&2
        fail=1
    fi
}

echo "oft-test — besoin et exigence en brouillon, non réalisés : acceptés"
prepare
cat > "${TMP}/depot/spec/s.md" <<'SPEC'
`feat~besoin~1`
Status: draft

Texte.

Needs: req

`req~exigence~1`
Status: draft

Texte.

Covers:

- feat~besoin~1

Needs: impl
SPEC
attendu ok "items en brouillon"

echo "oft-test — besoin et exigence approuvés, aucun maillon aval : acceptés (à réaliser)"
sed -i '/^Status: draft$/d' "${TMP}/depot/spec/s.md"
attendu ok "exigence approuvée à réaliser"
if ! (cd "${TMP}/depot" && sh tools/oft.sh report >/dev/null 2>&1); then
    echo "ÉCHEC : rapport — refuse une exigence approuvée à réaliser" >&2
    fail=1
fi

echo "oft-test — exigence approuvée couverte en partie : la porte doit échouer"
sed -i 's/^Needs: impl$/Needs: impl, utest/' "${TMP}/depot/spec/s.md"
# Tags assemblés à l'exécution : écrits en clair, ils deviendraient des items
# du dépôt réel, orphelins.
printf '// [%s->%s]\n' impl 'req~exigence~1' > "${TMP}/depot/src/a.rs"
attendu echec "implémentation sans son test"

echo "oft-test — exigence approuvée entièrement couverte : acceptée"
printf '// [%s->%s]\n' utest 'req~exigence~1' >> "${TMP}/depot/src/a.rs"
attendu ok "exigence réalisée et testée"

echo "oft-test — exigence approuvée à réaliser au lien amont rompu : la porte doit échouer"
prepare
cat > "${TMP}/depot/spec/s.md" <<'SPEC'
`req~exigence~1`

Texte.

Covers:

- feat~absent~1

Needs: impl
SPEC
attendu echec "exigence couvrant un besoin inexistant"

echo "oft-test — besoin approuvé couvert seulement par un brouillon : la porte doit échouer"
prepare
cat > "${TMP}/depot/spec/s.md" <<'SPEC'
`feat~besoin~1`

Texte.

Needs: req

`req~exigence~1`
Status: draft

Texte.

Covers:

- feat~besoin~1

Needs: impl
SPEC
attendu echec "besoin approuvé sans exigence approuvée"

echo "oft-test — tag de code vers une exigence proposée : la porte doit échouer (on ne réalise que l'approuvé)"
prepare
cat > "${TMP}/depot/spec/s.md" <<'SPEC'
`feat~besoin~1`

Texte.

Needs: req

`req~approuvee~1`

Texte.

Covers:

- feat~besoin~1

Needs: impl

`req~proposee~1`
Status: proposed

Texte.

Covers:

- feat~besoin~1

Needs: impl
SPEC
printf '// [%s->%s]\n' impl 'req~approuvee~1' > "${TMP}/depot/src/a.rs"
attendu ok "exigence proposée sans maillon, à côté d'une approuvée réalisée"
printf '// [%s->%s]\n' impl 'req~proposee~1' > "${TMP}/depot/src/p.rs"
attendu echec "tag de code vers une exigence proposée"
rm "${TMP}/depot/src/p.rs"

echo "oft-test — item de conception approuvé couvrant une exigence proposée : la porte doit échouer"
cat > "${TMP}/depot/spec/adr.md" <<'SPEC'
`dsn~decision~1`

Texte.

Covers:

- req~proposee~1
SPEC
attendu echec "item de conception approuvé vers une exigence proposée"

echo "oft-test — item de conception au même statut que l'exigence proposée qu'il couvre : accepté"
sed -i 's/^`dsn~decision~1`$/`dsn~decision~1`\nStatus: proposed/' "${TMP}/depot/spec/adr.md"
attendu ok "item de conception proposé vers une exigence proposée"

[ "${fail}" -eq 0 ] && echo "oft-test : OK" || { echo "oft-test : ÉCHEC" >&2; exit 1; }
