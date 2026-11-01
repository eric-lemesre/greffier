#!/bin/sh
# [utest->req~donnees-hors-depot~1]
# Test de la porte des données, chaque refus sur son cas d'échec (R3).
#
# Une porte qui protège d'une fuite est celle qu'on éprouve le plus mal : le
# jour où elle manque, rien ne le signale — c'est ce qui définit une fuite.
# Les trois refus sont donc joués sur un dépôt de synthèse, avec leurs deux
# contreparties : un schéma exporté reste admis, et un jeu d'essai déclaré
# aussi — mais lui seul, et seulement là où il est déclaré.
#
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"
# $1 (facultatif) : contenu du bloc « fixtures » de la porte de synthèse.
prepare() {
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/src/sql"
    if [ -n "${1:-}" ]; then
        awk -v decl="$1" '
            /--- fixtures:debut ---/ { print; print "FIXTURES=\"" decl "\""; saute = 1; next }
            /--- fixtures:fin ---/   { saute = 0 }
            !saute { print }
        ' "${ROOT}/tools/donnees.sh" > "${D}/tools/donnees.sh"
    else
        cp "${ROOT}/tools/donnees.sh" "${D}/tools/"
    fi
    # Un schéma légitime : du DDL, aucune donnée.
    printf 'CREATE TABLE t (id int);\n' > "${D}/src/sql/010-schema.sql"
    printf '# Dépôt de synthèse\n' > "${D}/README.md"
    (cd "${D}" && git init -q && git add -A &&
        git -c user.name=t -c user.email=t@t -c commit.gpgsign=false \
            commit -q -m "chore: état initial")
}
porte() { (cd "${D}" && sh tools/donnees.sh >/dev/null 2>&1); }
indexer() { (cd "${D}" && git add -A -f); }
# Un SQL porteur de données, écrit à l'endroit demandé.
sql_avec_donnees() {
    mkdir -p "$(dirname "$1")"
    { printf 'CREATE TABLE personne (id int, nom text);\n'
      printf 'INSERT INTO personne VALUES (1, %s);\n' "'NOM Prenom'"; } > "$1"
}

echo "donnees-test — dépôt sain : la porte doit passer"
prepare
if ! porte; then
    echo "ÉCHEC : la porte refuse un dépôt sain" >&2
    (cd "${D}" && sh tools/donnees.sh 2>&1 | sed 's/^/        /') >&2
    fail=1
fi

echo "donnees-test — export versionné : la porte doit échouer"
prepare
printf 'contenu binaire simulé\n' > "${D}/prod.table_data.sql.zip"
indexer
if porte; then
    echo "ÉCHEC : une archive d'export versionnée n'est pas signalée" >&2
    fail=1
fi

echo "donnees-test — tableur versionné : la porte doit échouer"
prepare
printf 'colonne\n' > "${D}/effectifs.csv"
indexer
if porte; then
    echo "ÉCHEC : un tableur versionné n'est pas signalé" >&2
    fail=1
fi

echo "donnees-test — SQL porteur de données : la porte doit échouer"
# Le cas le plus insidieux : extension légitime, nom légitime, bon
# répertoire. Seul le CONTENU le trahit.
prepare
sql_avec_donnees "${D}/src/sql/020-personnes.sql"
indexer
if porte; then
    echo "ÉCHEC : un SQL versionné porteur d'INSERT n'est pas signalé" >&2
    fail=1
fi

echo "donnees-test — COPY … FROM stdin : la porte doit échouer"
prepare
{ printf 'CREATE TABLE t (id int);\n'
  printf 'COPY t (id) FROM stdin;\n1\n2\n%s\n' '\.'; } > "${D}/src/sql/030-copie.sql"
indexer
if porte; then
    echo "ÉCHEC : un COPY … FROM stdin versionné n'est pas signalé" >&2
    fail=1
fi

echo "donnees-test — chemin de partage réseau : la porte doit échouer"
# Le chemin est ASSEMBLÉ : écrit en clair, il ferait de ce fichier de test une
# vraie occurrence, et la porte du dépôt réel échouerait sur son propre test.
prepare
bs='\\'
printf 'Source : %s%sserveur42.exemple.invalid%spartage%sdossier\n' \
    "${bs}" "${bs}" "${bs}" "${bs}" > "${D}/source.md"
indexer
if porte; then
    echo "ÉCHEC : un chemin de partage réseau qualifié n'est pas signalé" >&2
    fail=1
fi

echo "donnees-test — schéma exporté : la porte doit passer"
# Contrepartie du deuxième refus : un DDL exporté depuis une base a sa place
# au dépôt. Sans ce cas, la porte pourrait tout refuser et paraître efficace.
prepare
printf 'CREATE TABLE prod.p3c (annee integer, montant numeric);\n' \
    > "${D}/prod.p3c_ddl.sql"
indexer
if ! porte; then
    echo "ÉCHEC : la porte refuse un schéma exporté, qui est admis" >&2
    (cd "${D}" && sh tools/donnees.sh 2>&1 | sed 's/^/        /') >&2
    fail=1
fi

echo "donnees-test — jeu d'essai déclaré : la porte doit passer"
prepare "tests/fixtures"
sql_avec_donnees "${D}/tests/fixtures/jeu.sql"
indexer
if ! porte; then
    echo "ÉCHEC : la porte refuse un jeu d'essai pourtant déclaré" >&2
    (cd "${D}" && sh tools/donnees.sh 2>&1 | sed 's/^/        /') >&2
    fail=1
fi

echo "donnees-test — hors du chemin déclaré : la porte doit échouer"
# La contrepartie de la contrepartie, et le vrai risque de l'exception : une
# déclaration qui vaudrait pour tout le dépôt rouvrirait la porte en grand
# sans que rien ne le dise.
prepare "tests/fixtures"
sql_avec_donnees "${D}/src/sql/040-ailleurs.sql"
indexer
if porte; then
    echo "ÉCHEC : la déclaration de jeux d'essai couvre plus que son chemin" >&2
    fail=1
fi

if [ "${fail}" -ne 0 ]; then
    echo "donnees-test : ÉCHEC." >&2
    exit 1
fi
echo "donnees-test : OK."
