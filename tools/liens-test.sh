#!/bin/sh
# [utest->req~integrite-liens~1]
# Test mécanisé de la porte des liens de documentation. Les cas NÉGATIFS sont
# les plus importants : une porte qui ne signale jamais rien passe toujours.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

prepare() {
    rm -rf "${TMP}/depot"
    mkdir -p "${TMP}/depot/tools" "${TMP}/depot/docs" "${TMP}/depot/.github/ISSUE_TEMPLATE"
    cp "${ROOT}/tools/liens.sh" "${TMP}/depot/tools/"
    (cd "${TMP}/depot" && git init -q && \
        git remote add origin https://github.com/une-org/un-depot.git)
}
commit() {
    (cd "${TMP}/depot" && git add -A && \
        git -c user.name=t -c user.email=t@t commit -q -m "docs: cas de test")
}
porte() { (cd "${TMP}/depot" && sh tools/liens.sh >/dev/null 2>&1); }

echo "liens-test — dépôt sain : liens, ancres, répertoire et bloc de code"
prepare
cat > "${TMP}/depot/docs/cible.md" <<'EOF'
# Titre principal

## Vérification de la chose

Contenu.
EOF
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

- [Fichier voisin](docs/cible.md)
- [Ancre accentuée](docs/cible.md#vérification-de-la-chose)
- [Répertoire](docs/)
- [Externe](https://example.org/inexistant.md)
- [Renvoi interne](#accueil)

```markdown
- [Exemple mort dans un bloc de code](docs/jamais-versé.md)
```
EOF
commit
if ! porte; then
    echo "ÉCHEC : la porte refuse un dépôt sain" >&2
    fail=1
fi

echo "liens-test — cible absente : la porte doit échouer"
prepare
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Spécification jamais versée](docs/29-materiel.md)
EOF
commit
if porte; then
    echo "ÉCHEC : lien vers un fichier inexistant non signalé" >&2
    fail=1
fi

echo "liens-test — fichier présent mais NON versionné : la porte doit échouer"
# Cas subtil et vécu : le fichier existe sur le poste de celui qui écrit le
# lien, mais n'a jamais été ajouté — le lien est mort pour tous les autres.
prepare
printf '# Brouillon\n' > "${TMP}/depot/docs/brouillon.md"
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Brouillon local](docs/brouillon.md)
EOF
(cd "${TMP}/depot" && git add README.md tools && \
    git -c user.name=t -c user.email=t@t commit -q -m "docs: sans le brouillon")
if porte; then
    echo "ÉCHEC : lien vers un fichier non versionné non signalé" >&2
    fail=1
fi

echo "liens-test — ancre absente : la porte doit échouer"
prepare
printf '# Titre principal\n\n## Section existante\n' > "${TMP}/depot/docs/cible.md"
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Section disparue](docs/cible.md#section-renommée)
EOF
commit
if porte; then
    echo "ÉCHEC : ancre inexistante non signalée" >&2
    fail=1
fi

echo "liens-test — URL « blob » du dépôt : contrôlée comme un lien interne"
# Angle mort d'ergonomia (FIX-#846) : ces URL désignent un chemin de CE dépôt.
# Un renommage de répertoire les tue sans qu'aucune porte ne bronche.
prepare
printf '# Cible\n' > "${TMP}/depot/docs/cible.md"
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Vers la doc](https://github.com/une-org/un-depot/blob/main/docs/cible.md)
EOF
commit
if ! porte; then
    echo "ÉCHEC : URL blob valide refusée" >&2
    fail=1
fi

echo "liens-test — URL « blob » vers un fichier disparu : la porte doit échouer"
prepare
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Vers la doc](https://github.com/une-org/un-depot/blob/main/docs/renomme.md)
EOF
commit
if porte; then
    echo "ÉCHEC : URL blob vers un fichier absent non signalée" >&2
    fail=1
fi

echo "liens-test — URL NUE dans un gabarit d'issue (.yml) : la porte doit échouer"
# Second angle mort : les fichiers de forge n'étaient pas parcourus, et un
# gabarit d'issue ne sait pas écrire de lien relatif — c'est sa seule forme.
prepare
cat > "${TMP}/depot/.github/ISSUE_TEMPLATE/anomalie.yml" <<'EOF'
name: Anomalie
body:
  - type: markdown
    attributes:
      value: |
        Avant d ouvrir, lire la procédure :
        https://github.com/une-org/un-depot/blob/main/docs/procedure-disparue.md
EOF
printf '# Accueil\n' > "${TMP}/depot/README.md"
commit
if porte; then
    echo "ÉCHEC : lien mort d'un gabarit de forge non signalé" >&2
    fail=1
fi

echo "liens-test — lien vers un AUTRE dépôt : ne doit produire aucun faux positif"
prepare
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

- [Dépôt tiers](https://github.com/autre-org/autre-depot/blob/main/nimporte-quoi.md)
- [URL à variable](https://github.com/${GITHUB_REPOSITORY}/blob/main/aussi-inexistant.md)
EOF
commit
if ! porte; then
    echo "ÉCHEC : faux positif sur un lien externe ou une URL interpolée" >&2
    fail=1
fi

echo "liens-test — commentaire YAML : ne doit pas être pris pour un titre"
prepare
printf '# Cible\n\n## Section réelle\n' > "${TMP}/depot/docs/cible.md"
cat > "${TMP}/depot/.github/ISSUE_TEMPLATE/config.yml" <<'EOF'
# Section inventée par un commentaire
blank_issues_enabled: false
EOF
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Ancre qui n existe pas](docs/cible.md#section-inventée-par-un-commentaire)
EOF
commit
if porte; then
    echo "ÉCHEC : un commentaire YAML a été pris pour un titre Markdown" >&2
    fail=1
fi

echo "liens-test — chemin à espace : le fichier doit être vu, pas coupé en deux"
# Constat de revue n° 2 : un « $(git ls-files) » non quoté découpe « mon
# document.md » en deux mots. La porte ne signalait alors RIEN — elle ne
# voyait simplement pas le fichier.
prepare
cat > "${TMP}/depot/docs/mon document.md" <<'EOF'
# Document à espace

[Renvoi mort](../docs/jamais-verse.md)
EOF
printf '# Accueil\n' > "${TMP}/depot/README.md"
commit
if porte; then
    echo "ÉCHEC : lien mort d\'un fichier au nom espacé non signalé" >&2
    fail=1
fi

echo "liens-test — parenthèses dans le chemin : aucun faux positif"
# Constat de revue n° 3 : une extraction qui s\'arrête à la première
# parenthèse tronque « guide-(v2).md » et le déclare mort à tort.
prepare
printf '# Guide v2\n' > "${TMP}/depot/docs/guide-(v2).md"
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Guide](docs/guide-(v2).md)
EOF
commit
if ! porte; then
    echo "ÉCHEC : faux positif sur un chemin contenant des parenthèses" >&2
    fail=1
fi

echo "liens-test — ancre GitHub d'un titre à tiret cadratin et sigle parenthésé"
# GitHub retire la ponctuation typographique et transforme chaque espace en
# tiret sans fusion : « ## 2. AI Act — obligations (SIGLE) » donne l'ancre
# « #2-ai-act--obligations-sigle ». L'ancienne slug() gardait le cadratin,
# fusionnait les espaces et avalait « (SIGLE) » : faux positif systématique.
prepare
cat > "${TMP}/depot/docs/cible.md" <<'EOF'
# Document

## 2. AI Act — obligations (SIGLE)

Contenu.
EOF
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Obligations](docs/cible.md#2-ai-act--obligations-sigle)
EOF
commit
if ! porte; then
    echo "ÉCHEC : faux positif sur l'ancre GitHub d'un titre à tiret cadratin" >&2
    fail=1
fi

echo "liens-test — la même ancre mal orthographiée doit toujours échouer"
prepare
cat > "${TMP}/depot/docs/cible.md" <<'EOF'
# Document

## 2. AI Act — obligations (SIGLE)
EOF
cat > "${TMP}/depot/README.md" <<'EOF'
# Accueil

[Obligations](docs/cible.md#2-ai-act-obligations)
EOF
commit
if porte; then
    echo "ÉCHEC : ancre inexistante non signalée après l'alignement GitHub" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "liens-test : ÉCHEC." >&2
    exit 1
fi
echo "liens-test : OK."
