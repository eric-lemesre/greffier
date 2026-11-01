#!/bin/sh
# [utest->req~anti-derive-generes~1]
# Test de la mécanique anti-dérive, sur des cibles de synthèse. Le cas
# capital est le TROISIÈME : un artefact généré mais non versionné ne produit
# aucune différence — sans le contrôle « suivi par git », la porte serait un
# no-op qui passe toujours, exactement ce que la méthode interdit (ch. 4).
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"
prepare() {
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/build"
    # derive.sh, TOUTES ses cibles remplacées par une seule de synthèse : un
    # générateur trivial et déterministe.
    #
    # Ne neutraliser que le bloc « socle » ne suffit pas. Le fichier prévoit
    # explicitement des cibles PROPRES AU PROJET après ce bloc ; les laisser
    # dans le dépôt de synthèse y fait chercher des artefacts qui n'y existent
    # pas, et le premier cas — « artefact à jour, la porte doit passer » —
    # échoue pour une raison qui n'a rien à voir avec ce qu'il teste. Défaut
    # invisible dans le gabarit, qui n'a aucune cible propre ; constaté sur un
    # projet instancié dès sa première.
    awk '
        /--- socle:debut ---/ { print; print "verifier \"sh tools/generer.sh\" genere.txt"; next }
        /^verifier / { suite = ($0 ~ /\\$/); next }
        suite        { suite = ($0 ~ /\\$/); next }
        { print }
    ' "${ROOT}/tools/derive.sh" > "${D}/tools/derive.sh"
    cat > "${D}/tools/generer.sh" <<'EOF'
#!/bin/sh
printf 'valeur attendue\n' > genere.txt
EOF
    (cd "${D}" && git init -q)
}
commit() {
    (cd "${D}" && git add -A && \
        git -c user.name=t -c user.email=t@t commit -q -m "chore: cas de test")
}
porte() { (cd "${D}" && sh tools/derive.sh >/dev/null 2>&1); }

echo "derive-test — artefact à jour : la porte doit passer"
prepare
printf 'valeur attendue\n' > "${D}/genere.txt"
commit
if ! porte; then
    echo "ÉCHEC : la porte refuse un artefact à jour" >&2
    fail=1
fi

echo "derive-test — artefact édité à la main : la porte doit échouer"
prepare
printf 'valeur bricolée à la main\n' > "${D}/genere.txt"
commit
if porte; then
    echo "ÉCHEC : dérive d'un artefact généré non signalée" >&2
    fail=1
fi

echo "derive-test — artefact NON SUIVI par git : la porte doit échouer"
# Sans ce contrôle, la régénération écrit le fichier, git diff ne voit rien
# (le fichier n'est pas suivi) et la porte passe : un contrôle qui ne
# contrôle rien.
prepare
printf 'valeur attendue\n' > "${D}/genere.txt"
(cd "${D}" && git add tools && \
    git -c user.name=t -c user.email=t@t commit -q -m "chore: sans l artefact")
if porte; then
    echo "ÉCHEC : artefact généré non versionné accepté — porte aveugle" >&2
    fail=1
fi

echo "derive-test — générateur en échec : la porte doit échouer"
prepare
printf 'valeur attendue\n' > "${D}/genere.txt"
printf '#!/bin/sh\nexit 3\n' > "${D}/tools/generer.sh"
commit
if porte; then
    echo "ÉCHEC : échec du générateur non signalé" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "derive-test : ÉCHEC." >&2
    exit 1
fi
echo "derive-test : OK."
