#!/bin/sh
# Test de l'automatisme « lecture » de templates/forge/tools/automatismes.sh,
# sur une forge simulée (un faux « gh » sur le PATH) : le login du lecteur se
# compare entier, et une seule case est cochée par lecture. Cas d'échec
# joués : un login qui n'est qu'un préfixe d'un autre, un lecteur sans case.
# POSIX sh strict.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

# Projet de synthèse : l'automatisme copié dans tools/, comme à son câblage.
D="${TMP}/projet"
mkdir -p "${D}/tools" "${TMP}/bin"
cp "${ROOT}/tools/lexique.sh" "${D}/tools/lexique.sh"
cp "${ROOT}/templates/forge/tools/automatismes.sh" "${D}/tools/automatismes.sh"

# Faux gh : « issue view » rend le corps de la fixture, « issue edit
# --body-file - » capture le corps réécrit, « issue comment » journalise.
cat > "${TMP}/bin/gh" <<'GH'
#!/bin/sh
case "${1:-} ${2:-}" in
    "issue view")    cat "${FIXTURE}" ;;
    "issue edit")    if [ "${4:-}" = "--body-file" ]; then cat > "${RESULTAT}"; fi ;;
    "issue comment") printf '%s\n' "$*" >> "${COMMENTAIRES}" ;;
esac
GH
chmod +x "${TMP}/bin/gh"
export PATH="${TMP}/bin:${PATH}"
export FIXTURE="${TMP}/corps.md" RESULTAT="${TMP}/resultat.md" COMMENTAIRES="${TMP}/commentaires.txt"

corps() {
    cat > "${FIXTURE}" <<'CORPS'
Consultation de la spécification.

- [ ] @eric2 — relecture
- [ ] @ericlemesre — relecture
- [ ] @eric — arbitrage
- [ ] @eric — seconde case du même lecteur
CORPS
    rm -f "${RESULTAT}" "${COMMENTAIRES}"
}

echo "automatismes-test — lecture : le login se compare entier, une seule case cochée"
corps
(cd "${D}" && sh tools/automatismes.sh lecture 7 eric) >/dev/null 2>&1 || {
    echo "ÉCHEC : la lecture de « eric » devait aboutir" >&2; fail=1
}
if [ -f "${RESULTAT}" ]; then
    if grep -q '^- \[x\] @eric2' "${RESULTAT}"; then
        echo "ÉCHEC : la case de @eric2 a été cochée pour le lecteur eric" >&2; fail=1
    fi
    if grep -q '^- \[x\] @ericlemesre' "${RESULTAT}"; then
        echo "ÉCHEC : la case de @ericlemesre a été cochée pour le lecteur eric" >&2; fail=1
    fi
    if ! grep -q '^- \[x\] @eric — arbitrage  — [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$' "${RESULTAT}"; then
        echo "ÉCHEC : la case de @eric n'est pas cochée et horodatée" >&2; fail=1
    fi
    if [ "$(grep -c '^- \[x\]' "${RESULTAT}")" -ne 1 ]; then
        echo "ÉCHEC : une seule case devait être cochée" >&2; fail=1
    fi
else
    echo "ÉCHEC : aucun corps réécrit transmis à la forge" >&2; fail=1
fi

echo "automatismes-test — lecture : un lecteur sans case ne coche rien et est signalé"
corps
(cd "${D}" && sh tools/automatismes.sh lecture 7 eri) >/dev/null 2>&1 || true
if [ -f "${RESULTAT}" ]; then
    echo "ÉCHEC : le lecteur « eri » (préfixe de eric) a réécrit le corps" >&2; fail=1
fi
if ! grep -q 'Aucune case de lecture au nom de @eri ' "${COMMENTAIRES}" 2>/dev/null; then
    echo "ÉCHEC : l'absence de case pour « eri » n'a pas été commentée" >&2; fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "automatismes-test : ÉCHEC." >&2
    exit 1
fi
echo "automatismes-test : OK."
