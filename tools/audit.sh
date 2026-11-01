#!/bin/sh
# Audit de réalisation : le produit tient-il sa spécification ?
#
# À ne pas confondre avec la traçabilité. OpenFastTrace répond à « cette
# exigence a-t-elle du code et un test ? » — une question de PRÉSENCE, qui se
# calcule. L'audit répond à « ce qui est livré fait-il ce que l'exigence
# dit ? » — une question de VÉRITÉ, qui se lit. Un tag de complaisance passe
# la traçabilité et échoue à l'audit.
#
# Ce script ne juge donc rien : le verdict et la colonne de preuve sont
# écrits à la main. Ce qui se mécanise, c'est la COMPTABILITÉ — quelles
# exigences sont examinées, lesquelles ne le sont pas, et si le tableau de
# bord dit la vérité. Même partage que la traçabilité : le générateur compte,
# l'humain juge.
#
#   sh tools/audit.sh                    # contrôle du périmètre de l'audit
#   sh tools/audit.sh --ecrire           # régénère docs/audit/README.md
#   sh tools/audit.sh --squelette <dom>  # lignes manquantes, à coller et juger
#
# Une fiche par domaine : docs/audit/<domaine>.md pour
# spec/02-exigences/<domaine>.md, portant le tableau
#   | Exigence | Verdict | Preuve / écart |
#
# POSIX sh + awk.
set -eu

# Chemins portant espaces ou métacaractères (constat de revue n° 2) : le
# découpage par défaut d'un « $(git ls-files) » non quoté coupe « mon
# document.md » en deux et laisse un glob s'expanser. Une porte qui rate un
# fichier ne signale rien — elle se contente de ne pas le voir. On découpe
# donc sur les seules fins de ligne, globbing désactivé.
IFS='
'
set -f

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
. "${ROOT}/tools/lexique.sh"

MODE="controle"
DOMAINE=""
case "${1:-}" in
    --ecrire)    MODE="ecrire" ;;
    --squelette) MODE="squelette"; DOMAINE="${2:-}" ;;
    "") ;;
    *) echo "Usage : sh tools/audit.sh [--ecrire | --squelette <domaine>]" >&2 ; exit 2 ;;
esac

REP="docs/audit"
INDEX="${REP}/README.md"
mkdir -p "${REP}"

# Formes d'AFFICHAGE (en-têtes du tableau de bord, messages d'aide) : celle de
# la langue principale. La RECONNAISSANCE, elle, passe par `lex_est` — en
# bilingue, les deux formes sont acceptées. Confondre les deux revenait à
# imposer le français à un dépôt « fr-en », contre le critère d'acceptation de
# req~lexique-outille~1 (constat de revue n° 1, 2026-08-20).
if [ "${LEXIQUE_LANGUE}" = "en" ]; then
    CONFORME="$(lex_en AUDIT_CONFORME)"
    ECART="$(lex_en AUDIT_ECART)"
    NON_EXAMINE="$(lex_en AUDIT_NON_EXAMINE)"
else
    CONFORME="$(lex_fr AUDIT_CONFORME)"
    ECART="$(lex_fr AUDIT_ECART)"
    NON_EXAMINE="$(lex_fr AUDIT_NON_EXAMINE)"
fi

# --- Plafond d'exigences non examinées --------------------------------------
# Le gabarit tient 0 : toute exigence du socle est jugée. Un projet qui
# transpose un existant volumineux peut desserrer ce plafond LE TEMPS de
# résorber sa dette, à condition de le faire décroître — un plafond qui suit
# le réel ne contrôle plus rien.
PLAFOND_NON_EXAMINEES=0

# Exigences AUDITABLES : définies (« `req~nom~n` » seul sur sa ligne, méthode
# ch. 4) ET approuvées. Une exigence encore en brouillon ou en proposition n'a
# pas à être jugée sur sa réalisation — l'auditer reviendrait à reprocher à un
# texte en cours d'écriture de n'être pas encore livré (ADR-0018).
exigences_du_domaine() {
    awk -v approuvee="$(lex_motif EXIGENCE_APPROUVEE)" '
        /^`req~[a-z0-9-]+~[0-9]+`[ \t]*$/ {
            id = $0; gsub(/`/, "", id); gsub(/[ \t]/, "", id); attente = 1; next
        }
        attente && /^\*\*/ {
            st = $0; sub(/^[^:]*:[ \t]*/, "", st); sub(/\*\*[ \t]*$/, "", st)
            gsub(/[ \t]+$/, "", st)
            if (st ~ ("^" approuvee "$")) print id
            attente = 0; next
        }
        attente && NF > 0 { attente = 0 }
    ' "$1"
}

# Lignes du tableau d'audit : identifiant en colonne 1, verdict en colonne 2.
lignes_de_fiche() {
    [ -f "$1" ] || return 0
    awk '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        /^[ \t]*\|/ {
            n = split($0, c, "|")
            if (n < 5) next
            id = trim(c[2]); verdict = trim(c[3])
            gsub(/`/, "", id)
            if (id !~ /^req~[a-z0-9-]+~[0-9]+$/) next
            print id "\t" verdict
        }' "$1"
}

DOMAINES="$(git ls-files 'spec/02-exigences/*.md' 2>/dev/null | \
            grep -v 'spec/02-exigences/README.md' || true)"

# --- Mode squelette ---------------------------------------------------------
if [ "${MODE}" = "squelette" ]; then
    spec="spec/02-exigences/${DOMAINE}.md"
    [ -f "${spec}" ] || { echo "ERREUR : domaine inconnu : ${spec}" >&2; exit 2; }
    fiche="${REP}/${DOMAINE}.md"
    deja="$(lignes_de_fiche "${fiche}" | cut -f1)"
    exigences_du_domaine "${spec}" | while IFS= read -r id; do
        printf '%s\n' "${deja}" | grep -qx "${id}" && continue
        printf '| `%s` | %s | |\n' "${id}" "${NON_EXAMINE}"
    done
    exit 0
fi

# --- Relevé ------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
FAILURES=0
: > "${TMP}/bilan"

for spec in ${DOMAINES}; do
    dom="${spec##*/}"; dom="${dom%.md}"
    fiche="${REP}/${dom}.md"
    exigences_du_domaine "${spec}" | sort > "${TMP}/spec.ids"
    lignes_de_fiche "${fiche}" | sort > "${TMP}/fiche.lignes"
    cut -f1 "${TMP}/fiche.lignes" | sort -u > "${TMP}/fiche.ids"

    total="$(wc -l < "${TMP}/spec.ids" | tr -d ' ')"
    conformes=0; ecarts=0; non_examinees=0

    while IFS="$(printf '\t')" read -r id verdict; do
        [ -n "${id}" ] || continue
        if ! grep -qx "${id}" "${TMP}/spec.ids"; then
            echo "ÉCHEC : ${fiche} — audite une exigence qui n'existe plus : ${id}" >&2
            FAILURES=$((FAILURES + 1))
            continue
        fi
        if lex_est AUDIT_CONFORME "${verdict}"; then
            conformes=$((conformes + 1))
        elif lex_est AUDIT_ECART "${verdict}"; then
            ecarts=$((ecarts + 1))
        elif lex_est AUDIT_NON_EXAMINE "${verdict}"; then
            non_examinees=$((non_examinees + 1))
        else
            echo "ÉCHEC : ${fiche} — verdict hors lexique pour ${id} : « ${verdict} »" >&2
            echo "        attendu : $(lex AUDIT_CONFORME) | $(lex AUDIT_ECART) | $(lex AUDIT_NON_EXAMINE)" >&2
            FAILURES=$((FAILURES + 1))
        fi
    done < "${TMP}/fiche.lignes"

    # Une exigence sans ligne du tout est non examinée : l'absence de fiche ne
    # doit jamais se lire comme une absence de dette.
    absentes="$(comm -23 "${TMP}/spec.ids" "${TMP}/fiche.ids" | wc -l | tr -d ' ')"
    non_examinees=$((non_examinees + absentes))
    if [ "${absentes}" -gt 0 ]; then
        echo "  ${dom} : ${absentes} exigence(s) sans ligne d'audit — « sh tools/audit.sh --squelette ${dom} »" >&2
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "${dom}" "${total}" "${conformes}" "${ecarts}" "${non_examinees}" \
        >> "${TMP}/bilan"
done

rendre() {
    t_total=0; t_conf=0; t_ecart=0; t_non=0
    if [ "${LEXIQUE_LANGUE}" = "en" ]; then
        printf '# Implementation audit\n\n'
        printf '<!-- GENERATED by tools/audit.sh — do not edit by hand (R8). -->\n\n'
        printf 'Does what is delivered do what the requirement says? Verdicts are\n'
        printf 'written by hand in each domain sheet; this dashboard only counts them.\n\n'
        printf '| Domain | Requirements | %s | %s | %s |\n' "${CONFORME}" "${ECART}" "${NON_EXAMINE}"
    else
        printf '# Audit de réalisation\n\n'
        printf '<!-- GÉNÉRÉ par tools/audit.sh — ne pas éditer à la main (R8). -->\n\n'
        printf 'Le livré fait-il ce que l’exigence dit ? Les verdicts sont écrits à la main\n'
        printf 'dans la fiche de chaque domaine ; ce tableau de bord ne fait que les compter.\n\n'
        printf '| Domaine | Exigences | %s | %s | %s |\n' "${CONFORME}" "${ECART}" "${NON_EXAMINE}"
    fi
    printf '| --- | --- | --- | --- | --- |\n'
    while IFS="$(printf '\t')" read -r dom total conf ecart non; do
        [ -n "${dom}" ] || continue
        printf '| [%s](%s.md) | %s | %s | %s | %s |\n' "${dom}" "${dom}" "${total}" "${conf}" "${ecart}" "${non}"
        t_total=$((t_total + total)); t_conf=$((t_conf + conf))
        t_ecart=$((t_ecart + ecart)); t_non=$((t_non + non))
    done < "${TMP}/bilan"
    printf '| **total** | **%s** | **%s** | **%s** | **%s** |\n' "${t_total}" "${t_conf}" "${t_ecart}" "${t_non}"
}

if [ "${MODE}" = "ecrire" ]; then
    rendre > "${INDEX}.tmp"
    mv "${INDEX}.tmp" "${INDEX}"
    echo "Tableau de bord d'audit régénéré : ${INDEX}"
    exit 0
fi

rendre > "${TMP}/index.verif"
if ! cmp -s "${TMP}/index.verif" "${INDEX}" 2>/dev/null; then
    echo "ÉCHEC : ${INDEX} périmé — exécuter « sh tools/audit.sh --ecrire »." >&2
    FAILURES=$((FAILURES + 1))
fi

total_non="$(awk -F "\t" '{ s += $5 } END { print s + 0 }' "${TMP}/bilan")"
if [ "${total_non}" -gt "${PLAFOND_NON_EXAMINEES}" ]; then
    echo "ÉCHEC : ${total_non} exigence(s) non examinée(s) — plafond : ${PLAFOND_NON_EXAMINEES}." >&2
    FAILURES=$((FAILURES + 1))
fi

if [ "${FAILURES}" -gt 0 ]; then
    echo "${FAILURES} défaut(s) sur le périmètre de l'audit." >&2
    exit 1
fi
echo "Audit de réalisation : OK (${total_non} non examinée(s), plafond ${PLAFOND_NON_EXAMINEES})."
