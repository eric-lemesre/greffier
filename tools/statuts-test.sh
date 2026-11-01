#!/bin/sh
# Test mécanisé de la porte des statuts, centré sur la concordance entre le
# statut déclaré d'une exigence et le statut lu par OpenFastTrace (ADR-0020).
# Les cas NÉGATIFS sont les plus importants : une porte qui ne signale jamais
# rien passe toujours.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT}/tools/lexique.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0
# En dépôt bilingue, lex renvoie « fr|en » : un terme concret suffit ici.
un() { lex "$1" | cut -d'|' -f1; }
S="$(un SECTION_STATUT)"

prepare() {
    rm -rf "${TMP}/depot"
    mkdir -p "${TMP}/depot/tools" "${TMP}/depot/spec/02-exigences" "${TMP}/depot/docs/decisions"
    cp "${ROOT}/tools/statuts.sh" "${ROOT}/tools/lexique.sh" "${TMP}/depot/tools/"
    : > "${TMP}/depot/docs/decisions/registre.md"
    printf '| [dom](dom.md) | %s |\n' "$(un SPEC_PROPOSITION)" > "${TMP}/depot/spec/02-exigences/README.md"
    (cd "${TMP}/depot" && git init -q)
}
# domaine <ligne sous l'identifiant, vide pour aucune> <statut déclaré>
domaine() {
    {
        printf '# dom\n\n**%s : %s**\n\n## Exigence\n\n`req~exemple~1`\n' "${S}" "$(un SPEC_PROPOSITION)"
        [ -z "$1" ] || printf '%s\n' "$1"
        printf '\n**%s : %s**\n\nLe système DOIT faire.\n' "${S}" "$2"
    } > "${TMP}/depot/spec/02-exigences/dom.md"
    (cd "${TMP}/depot" && git add -A && \
        git -c user.name=t -c user.email=t@t commit -q -m "docs: cas de test")
}
porte() { (cd "${TMP}/depot" && sh tools/statuts.sh >/dev/null 2>&1); }
attendu() {  # attendu ok|echec <libellé>
    if porte; then r=ok; else r=echec; fi
    if [ "${r}" != "$1" ]; then
        echo "ÉCHEC : $2 — attendu ${1}, obtenu ${r}" >&2
        fail=1
    fi
}

echo "statuts-test — brouillon marqué « Status: draft » : accepté"
prepare; domaine "Status: draft" "$(un EXIGENCE_BROUILLON)"
attendu ok "brouillon + draft"

echo "statuts-test — proposée marquée « Status: proposed » : acceptée"
prepare; domaine "Status: proposed" "$(un EXIGENCE_PROPOSEE)"
attendu ok "proposée + proposed"

echo "statuts-test — brouillon sans « Status: » : la porte doit échouer"
prepare; domaine "" "$(un EXIGENCE_BROUILLON)"
attendu echec "brouillon sans statut OpenFastTrace"

echo "statuts-test — « Status: draft » séparé de l'identifiant : la porte doit échouer"
prepare
domaine "" "$(un EXIGENCE_BROUILLON)"
sed -i 's/^\*\*'"${S}"' : '"$(un EXIGENCE_BROUILLON)"'\*\*$/Status: draft\n\n&/' "${TMP}/depot/spec/02-exigences/dom.md"
(cd "${TMP}/depot" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "docs: cas")
attendu echec "Status: hors de la place lue par OpenFastTrace"

echo "statuts-test — brouillon marqué « Status: proposed » : la porte doit échouer"
prepare; domaine "Status: proposed" "$(un EXIGENCE_BROUILLON)"
attendu echec "brouillon + proposed"

echo "statuts-test — approuvée marquée « Status: draft » : la porte doit échouer"
prepare
printf '| [dom](dom.md) | %s |\n' "$(un SPEC_ACTIVE)" > "${TMP}/depot/spec/02-exigences/README.md"
echo "| D-1 | dom |" > "${TMP}/depot/docs/decisions/registre.md"
domaine "Status: draft" "$(un EXIGENCE_APPROUVEE)"
sed -i "s/^\*\*${S} : $(un SPEC_PROPOSITION)\*\*/**${S} : $(un SPEC_ACTIVE)**/" "${TMP}/depot/spec/02-exigences/dom.md"
(cd "${TMP}/depot" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "docs: cas")
attendu echec "approuvée + draft (échapperait à la traçabilité)"

echo "statuts-test — approuvée sans « Status: » dans un domaine actif : acceptée"
sed -i '/^Status: draft$/d' "${TMP}/depot/spec/02-exigences/dom.md"
(cd "${TMP}/depot" && git add -A && git -c user.name=t -c user.email=t@t commit -q -m "docs: cas")
attendu ok "approuvée sans Status"

[ "${fail}" -eq 0 ] && echo "statuts-test : OK" || { echo "statuts-test : ÉCHEC" >&2; exit 1; }
