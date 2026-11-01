#!/bin/sh
# Test du socle : la traçabilité échoue-t-elle vraiment sur un maillon
# manquant, les garde-fous locaux refusent-ils vraiment un commit non
# conforme, et l'exemple multi-langage s'exécute-t-il ?
#
# Ces trois exigences reposaient sur des portes réputées efficaces sans que
# rien ne l'ait jamais vérifié. Une traçabilité qui ne casse pas sur une
# exigence orpheline serait la pire des portes : elle certifierait le vide.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0
D="${TMP}/depot"

# --- Traçabilité -------------------------------------------------------------
echo "socle-test — traçabilité : exigence réalisée sans son test, la porte doit échouer"
if ! command -v java >/dev/null 2>&1; then
    echo "  (java absent — contrôle de traçabilité ignoré)"
else
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/spec" "${D}/.cache"
    # Le tag de couverture porté par oft.sh lui-même deviendrait un item
    # orphelin dans le dépôt de synthèse : on le retire de la copie.
    sed '/^# \[impl->/d' "${ROOT}/tools/oft.sh" > "${D}/tools/oft.sh"
    cp "${ROOT}"/.cache/openfasttrace-*.jar "${D}/.cache/" 2>/dev/null || true
    # Identifiants assemblés à l'exécution : écrits en clair dans ce fichier,
    # ils y deviendraient de VRAIES définitions d'items du dépôt — le
    # scanneur ne fait pas la différence entre un exemple et une définition.
    id_besoin='feat~besoin~1'
    id_orphelin='req~exigence-orpheline~1'
    cat > "${D}/spec/exigences.md" <<EOF
# Exigences

\`${id_besoin}\`

Un besoin.

Needs: req

\`${id_orphelin}\`

Le produit DOIT faire quelque chose que rien ne réalise.

Covers:
- ${id_besoin}

Needs: impl, utest
EOF
    # Une exigence approuvée SANS aucun maillon aval est « à réaliser » et
    # passe (ADR-0021) : le maillon manquant se teste sur une réalisation
    # commencée. Tag assemblé à l'exécution, pour la même raison qu'en bas.
    printf '# [impl->%s]\necho fait\n' "${id_orphelin}" > "${D}/tools/chose.sh"
    if (cd "${D}" && sh tools/oft.sh trace >/dev/null 2>&1); then
        echo "ÉCHEC : la traçabilité accepte une exigence sans son test" >&2
        fail=1
    fi

    echo "socle-test — traçabilité : maillon posé, la porte doit passer"
    # Le périmètre scanné par oft.sh couvre tools/ : c'est là qu'on tague.
    # Le tag est assemblé à l'exécution : écrit en clair, il ferait de CE
    # fichier un item de couverture du dépôt réel, vers une exigence qui n'y
    # existe pas.
    printf '# [utest->%s]\necho teste\n' "${id_orphelin}" > "${D}/tools/chose-test.sh"
    if ! (cd "${D}" && sh tools/oft.sh trace >/dev/null 2>&1); then
        echo "ÉCHEC : la traçabilité refuse une exigence pourtant couverte" >&2
        (cd "${D}" && sh tools/oft.sh trace 2>&1 | sed 's/^/        /') >&2
        fail=1
    fi
fi

# --- Garde-fous locaux -------------------------------------------------------
prepare_hooks() {
    rm -rf "${D}"
    mkdir -p "${D}/tools/hooks" "${D}/.githooks"
    cp "${ROOT}/tools/hooks/commit-msg.sh" "${D}/tools/hooks/"
    cp "${ROOT}/.githooks/commit-msg" "${D}/.githooks/"
    chmod +x "${D}/tools/hooks/commit-msg.sh" "${D}/.githooks/commit-msg"
    (cd "${D}" && git init -q && git config core.hooksPath .githooks)
    printf 'contenu\n' > "${D}/fichier.txt"
    (cd "${D}" && git add -A)
}
commit_avec() {
    (cd "${D}" && git -c user.name=t -c user.email=t@t commit -q -m "$1" >/dev/null 2>&1)
}

# La politique de mention de l'IA est un choix d'instanciation (ADR-0011) :
# les assertions SUIVENT le hook installé, elles ne supposent jamais le
# défaut. Un test qui affirme le contraire de la règle n'échoue pas une fois,
# il échoue toujours — et finit désactivé.
if grep -q 'co-authored-by' tools/hooks/commit-msg.sh; then
    POLITIQUE=interdite
elif grep -q 'politique-attribution:debut' tools/hooks/commit-msg.sh; then
    POLITIQUE=obligatoire
else
    POLITIQUE=autorisee
fi
echo "socle-test — hooks : politique de mention de l'IA constatée = ${POLITIQUE}"

echo "socle-test — hooks : sujet non conventionnel, le commit doit être refusé"
prepare_hooks
if commit_avec "ajout de trucs"; then
    echo "ÉCHEC : sujet de commit non conventionnel accepté" >&2
    fail=1
fi

case "${POLITIQUE}" in
    interdite)
        echo "socle-test — hooks : trailer IA présent, le commit doit être refusé"
        prepare_hooks
        if commit_avec "chore: un sujet conventionnel

IA: aucune"; then
            echo "ÉCHEC : trailer IA accepté sous une politique d'interdiction" >&2
            fail=1
        fi

        echo "socle-test — hooks : co-auteur généré, le commit doit être refusé"
        prepare_hooks
        if commit_avec "chore: un sujet conventionnel

Co-authored-by: Un Outil <outil@example.org>"; then
            echo "ÉCHEC : co-auteur généré accepté sous une politique d'interdiction" >&2
            fail=1
        fi

        echo "socle-test — hooks : commit conforme, le commit doit passer"
        prepare_hooks
        if ! commit_avec "chore: un sujet conventionnel

Responsable: Porteur Test"; then
            echo "ÉCHEC : un commit conforme est refusé" >&2
            fail=1
        fi
        ;;
    obligatoire)
        echo "socle-test — hooks : déclaration d'IA manquante, le commit doit être refusé"
        prepare_hooks
        if commit_avec "chore: un sujet conventionnel"; then
            echo "ÉCHEC : commit sans déclaration d'usage de l'IA accepté" >&2
            fail=1
        fi

        echo "socle-test — hooks : IA déclarée sans responsable, le commit doit être refusé"
        prepare_hooks
        if commit_avec "chore: un sujet conventionnel

IA: un outil"; then
            echo "ÉCHEC : usage d'IA sans responsable humain accepté" >&2
            fail=1
        fi

        echo "socle-test — hooks : commit conforme, le commit doit passer"
        prepare_hooks
        if ! commit_avec "chore: un sujet conventionnel

IA: aucune"; then
            echo "ÉCHEC : un commit conforme est refusé" >&2
            fail=1
        fi
        ;;
    autorisee)
        echo "socle-test — hooks : commit sans mention, le commit doit passer"
        prepare_hooks
        if ! commit_avec "chore: un sujet conventionnel"; then
            echo "ÉCHEC : un commit sans mention est refusé alors qu'elle est facultative" >&2
            fail=1
        fi
        ;;
esac

# --- Exemple multi-langage ---------------------------------------------------
echo "socle-test — exemple : l'implémentation shell produit le format attendu"
EX="${ROOT}/examples/demo-multi-langages/src/notify.sh"
if [ ! -f "${EX}" ]; then
    echo "ÉCHEC : exemple shell absent : ${EX}" >&2
    fail=1
elif ! command -v bash >/dev/null 2>&1; then
    echo "  (bash absent — implémentation shell de l'exemple non exécutée)"
else
    # L'exemple déclare bash (`set -o pipefail`, `local`) : c'est son droit —
    # le gabarit est agnostique du langage, et cet exemple démontre justement
    # des langages réels. L'invoquer avec « sh » le casse là où /bin/sh n'est
    # pas bash : « Illegal option -o pipefail ». Défaut attrapé par la CI
    # (ubuntu, /bin/sh → dash) après être passé en local — la preuve, s'il en
    # fallait une, qu'un test doit invoquer l'interpréteur que son sujet
    # déclare, pas celui du script qui le teste.
    sortie="$(bash -c ". '${EX}'; notifier 'tâche' 3 1")"
    case "${sortie}" in
        "[OK] tâche (3 s)") ;;
        *) echo "ÉCHEC : sortie inattendue de l'exemple : « ${sortie} »" >&2 ; fail=1 ;;
    esac
    sortie_ko="$(bash -c ". '${EX}'; notifier 'tâche' 3 0")"
    case "${sortie_ko}" in
        "[ÉCHEC] tâche (3 s)") ;;
        *) echo "ÉCHEC : l'échec n'est pas signalé distinctement : « ${sortie_ko} »" >&2 ; fail=1 ;;
    esac
fi

if [ "${fail}" -ne 0 ]; then
    echo "socle-test : ÉCHEC." >&2
    exit 1
fi
echo "socle-test : OK."
