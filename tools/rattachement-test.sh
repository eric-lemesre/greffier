#!/bin/sh
# Test de la porte du rattachement (tools/rattachement.sh). Chaque cas part
# d'un dépôt jetable qui définit deux exigences, y pose un fichier de code
# et vérifie le verdict de la porte — ses cas d'échec d'abord (R3).
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

# Identifiants assemblés à l'exécution : écrits en clair, OpenFastTrace et la
# porte elle-même les liraient dans ce fichier comme des couvertures d'items
# inexistants (même précaution que tools/socle-test.sh).
R='req~essai'
A='`'

D="${TMP}/depot"
prepare() {
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/spec" "${D}/src" "${D}/templates"
    # L'étiquette de la porte viserait ici un item absent : on la remplace
    # par une étiquette vers l'exigence du dépôt jetable.
    sed '/^# \[impl->/d' "${ROOT}/tools/rattachement.sh" > "${D}/tools/rattachement.sh"
    printf '# [impl->%s-seconde~1]\n' "${R}" >> "${D}/tools/rattachement.sh"
    cat > "${D}/spec/essai.md" <<SPEC
# Essai

${A}${R}-premiere~2${A}

Première exigence.

${A}${R}-seconde~1${A}

Seconde exigence, et la porte elle-même s'y rattache.
SPEC
    printf '// [impl->%s-premiere~2]\nfn a() {}\n' "${R}" > "${D}/src/a.rs"
    (cd "${D}" && git init -q && git add -A)
}
ajoute() { (cd "${D}" && git add -A); }
porte() { (cd "${D}" && sh tools/rattachement.sh >"${TMP}/sortie" 2>&1); }
attendu() {
    # $1 = libellé, $2 = passe|echoue, $3 = texte attendu dans la sortie (option)
    if porte; then obtenu=passe; else obtenu=echoue; fi
    if [ "${obtenu}" != "$2" ]; then
        echo "ÉCHEC : $1 — la porte ${obtenu}, attendu : $2" >&2
        sed 's/^/    /' "${TMP}/sortie" >&2
        fail=1
    elif [ -n "${3:-}" ] && ! grep -qF -- "$3" "${TMP}/sortie"; then
        echo "ÉCHEC : $1 — la sortie ne nomme pas « $3 »" >&2
        fail=1
    fi
}

echo "rattachement-test — tout fichier étiqueté : la porte doit passer"
prepare
attendu "étiquette valide" passe

echo "rattachement-test — étiquette de forme complète : la porte doit passer"
prepare
printf '# [impl~notify~1->%s-premiere~2]\nexit 0\n' "${R}" > "${D}/src/complete.sh"
ajoute
attendu "forme complète" passe

echo "rattachement-test — mention d'une exigence existante : la porte doit passer"
prepare
printf '# Exigence servie : %s-seconde~1 — outil\necho ok\n' "${R}" > "${D}/src/b.sh"
ajoute
attendu "mention valide" passe

echo "rattachement-test — fichier de code sans trace : la porte doit échouer en le nommant"
prepare
printf 'export const x = 1;\n' > "${D}/src/c.ts"
ajoute
attendu "fichier sans trace" echoue "src/c.ts"

echo "rattachement-test — matériel prêt à copier sans trace : la porte doit échouer"
prepare
mkdir -p "${D}/templates/kit"
printf '#!/bin/sh\necho kit\n' > "${D}/templates/kit/kit.sh"
ajoute
attendu "templates sans trace" echoue "templates/kit/kit.sh"

echo "rattachement-test — fichier non suivi par git : ignoré"
prepare
printf 'export const x = 1;\n' > "${D}/src/d.ts"
attendu "fichier non suivi" passe

echo "rattachement-test — fichier hors code sans trace : ignoré"
prepare
printf 'note\n' > "${D}/src/notes.txt"
ajoute
attendu "fichier hors code" passe

echo "rattachement-test — mention d'une exigence inconnue seule : la porte doit échouer"
prepare
printf -- '-- Exigence servie : %s-fantome~9\nSELECT 1;\n' "${R}" > "${D}/src/e.sql"
ajoute
attendu "mention inconnue" echoue "src/e.sql"

echo "rattachement-test — étiquette d'une révision périmée : la porte doit échouer malgré une mention valide"
prepare
printf '// [impl->%s-premiere~1]\n// Exigence servie : %s-seconde~1\nfn f() {}\n' "${R}" "${R}" > "${D}/src/f.rs"
ajoute
attendu "révision périmée" echoue "premiere~1"

echo "rattachement-test — item défini dans un bloc de code : il n'existe pas"
prepare
printf '# Doc\n\n```\n%s-exemple~1%s\n```\n' "${A}${R}" "${A}" > "${D}/spec/doc.md"
printf '# [impl->%s-exemple~1]\nexit 0\n' "${R}" > "${D}/src/g.sh"
ajoute
attendu "item en bloc de code" echoue "src/g.sh"

echo "rattachement-test — item défini dans un modèle (templates/) : il n'existe pas"
prepare
printf '# Modèle\n\n%s-modele~1%s\n' "${A}${R}" "${A}" > "${D}/templates/exigence.md"
printf '# [impl->%s-modele~1]\nexit 0\n' "${R}" > "${D}/src/h.sh"
ajoute
attendu "item de modèle" echoue "src/h.sh"

echo "rattachement-test — code hérité déclaré : la porte doit passer"
prepare
printf 'export const x = 1;\n' > "${D}/src/herite.ts"
printf '# hérités\nsrc/herite.ts\n' > "${D}/tools/rattachement-herites.txt"
ajoute
attendu "hérité déclaré" passe

echo "rattachement-test — déclaration d'un fichier absent : la porte doit échouer"
prepare
printf 'src/disparu.ts\n' > "${D}/tools/rattachement-herites.txt"
ajoute
attendu "déclaration absente" echoue "src/disparu.ts"

echo "rattachement-test — déclaration d'un fichier déjà tracé : la porte doit échouer"
prepare
printf 'src/a.rs\n' > "${D}/tools/rattachement-herites.txt"
ajoute
attendu "déclaration redondante" echoue "porte déjà sa trace"

echo "rattachement-test — déclaration dans le gabarit (tools/init.sh présent) : la porte doit échouer"
prepare
printf 'export const x = 1;\n' > "${D}/src/herite.ts"
printf 'src/herite.ts\n' > "${D}/tools/rattachement-herites.txt"
printf '#!/bin/sh\n# [impl->%s-seconde~1]\n' "${R}" > "${D}/tools/init.sh"
ajoute
attendu "déclaration dans le gabarit" echoue "le gabarit n'hérite de rien"

echo "rattachement-test — mode liste : n'échoue jamais, nomme le seul fichier sans trace"
prepare
printf 'export const x = 1;\n' > "${D}/src/i.ts"
ajoute
if ! liste="$(cd "${D}" && sh tools/rattachement.sh --liste)"; then
    echo "ÉCHEC : mode liste — la porte a échoué" >&2
    fail=1
elif [ "${liste}" != "src/i.ts" ]; then
    echo "ÉCHEC : mode liste — obtenu « ${liste} », attendu « src/i.ts »" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    exit 1
fi
echo "rattachement-test : OK."
