#!/bin/sh
# Test d'indépendance à la locale des générateurs qui trient ou mesurent du
# texte (R3) : un artefact généré sur le poste (fr_FR.UTF-8) doit être
# identique à celui de la CI (C.UTF-8, ou C), sans quoi l'anti-dérive le dit
# périmé. Constaté sur un projet instancié : le suivi de revue sortait dans
# un autre ordre selon la locale.
#
# Les données sont choisies pour que les deux ordres diffèrent : sous une
# locale de langue, « - » est ignoré au premier niveau (« z-a-c » après
# « z-ab ») ; en ordre des octets, il passe avant les lettres. La largeur des
# badges est mesurée sur un libellé accentué.
#
# Il faut une locale de langue installée (fr_FR.UTF-8 ou en_US.UTF-8) : sans
# elle, le test le dit et s'arrête sans rien prouver.
#
#   sh tools/locale-test.sh
#
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

LANGUE=""
for l in fr_FR.UTF-8 fr_FR.utf8 en_US.UTF-8 en_US.utf8; do
    if locale -a 2>/dev/null | grep -qix "${l}"; then LANGUE="${l}"; break; fi
done
if [ -z "${LANGUE}" ]; then
    echo "locale-test : SAUTÉ — aucune locale fr_FR ni en_US installée, l'indépendance à la locale n'est pas éprouvée." >&2
    exit 0
fi
echo "locale-test — comparaison ${LANGUE} / C"

D="${TMP}/depot"
mkdir -p "${D}"
for entree in "${ROOT}"/* "${ROOT}"/.[!.]* "${ROOT}"/..?*; do
    [ -e "${entree}" ] || continue
    case "${entree##*/}" in .git | build) continue ;; esac
    cp -R "${entree}" "${D}/"
done

# Deux fiches de revue dont les noms se trient différemment selon la locale.
for fiche in z-a-c z-ab; do
    cat > "${D}/docs/revues/2026-01-01-${fiche}.md" <<FIN
# Revue de synthèse — ${fiche}

## Constats

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | basse | Constat de ${fiche} | Corrigé | — |
FIN
done
# Deux fichiers d'outillage sans trace, dans des répertoires qui se trient
# différemment selon la locale (liste de revue de la matrice).
for rep in a-c ab; do
    mkdir -p "${D}/tools/${rep}"
    printf '#!/bin/sh\necho %s\n' "${rep}" > "${D}/tools/${rep}/outil.sh"
done
(cd "${D}" && git init -q && git add -A)

# generer <locale> <suffixe> : régénère les artefacts, les met de côté.
generer() {
    (
        cd "${D}"
        # LANG aussi : les générateurs annulent LC_ALL, et retomberaient
        # sinon sur le LANG du poste, le même dans les deux passes.
        LANG="$1" LC_ALL="$1" sh tools/revues.sh --ecrire
        LANG="$1" LC_ALL="$1" sh tools/matrice.sh
    ) > "${TMP}/journal-$2" 2>&1 || {
        echo "ÉCHEC : génération sous $1 en échec :" >&2
        sed 's/^/  | /' "${TMP}/journal-$2" >&2 ; fail=1
    }
    cp "${D}/docs/revues/SUIVI.md" "${TMP}/suivi-$2"
    cp "${D}/docs/tracabilite/matrice.md" "${TMP}/matrice-$2"
}
generer "${LANGUE}" langue
generer C octets

echo "locale-test — suivi de revue identique sous les deux locales"
if ! cmp -s "${TMP}/suivi-langue" "${TMP}/suivi-octets"; then
    echo "ÉCHEC : docs/revues/SUIVI.md dépend de la locale :" >&2
    diff "${TMP}/suivi-langue" "${TMP}/suivi-octets" | head -n 10 | sed 's/^/  | /' >&2 ; fail=1
fi
echo "locale-test — matrice identique sous les deux locales"
if ! cmp -s "${TMP}/matrice-langue" "${TMP}/matrice-octets"; then
    echo "ÉCHEC : docs/tracabilite/matrice.md dépend de la locale :" >&2
    diff "${TMP}/matrice-langue" "${TMP}/matrice-octets" | head -n 10 | sed 's/^/  | /' >&2 ; fail=1
fi
# Le test ne prouve rien si les données ne départagent pas les locales.
if ! grep -q 'z-a-c' "${TMP}/suivi-octets" || ! grep -q 'tools/a-c' "${TMP}/matrice-octets"; then
    echo "ÉCHEC : données de synthèse absentes des artefacts — le test ne compare rien." >&2 ; fail=1
fi

echo "locale-test — largeur d'un badge accentué identique sous les deux locales"
sed -n '/^largeur() {/,/^}/p' "${ROOT}/tools/badges.sh" > "${TMP}/largeur.sh"
if [ ! -s "${TMP}/largeur.sh" ]; then
    echo "ÉCHEC : fonction largeur() introuvable dans tools/badges.sh." >&2 ; fail=1
else
    l1="$(LC_ALL="${LANGUE}" sh -c '. "$1"; largeur "réalisé"' _ "${TMP}/largeur.sh")"
    l2="$(LC_ALL=C sh -c '. "$1"; largeur "réalisé"' _ "${TMP}/largeur.sh")"
    if [ "${l1}" != "${l2}" ] || [ "${l1}" != "59" ]; then
        echo "ÉCHEC : largeur de « réalisé » : ${l1} sous ${LANGUE}, ${l2} sous C, attendu 59 (7 caractères)." >&2 ; fail=1
    fi
fi

if [ "${fail}" -ne 0 ]; then
    echo "locale-test : ÉCHEC." >&2
    exit 1
fi
echo "locale-test : OK."
