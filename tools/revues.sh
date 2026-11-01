#!/bin/sh
# [impl->req~suivi-constats-revue~1]
# Consolidation des constats de revue de code : rassemble les tableaux des
# fiches `docs/revues/` en un tableau de bord unique, et REFUSE qu'un constat
# de sévérité haute reste sans réponse.
#
# Pourquoi cette porte existe. Les constats de revue vivent dispersés, une
# fiche par branche ; passée la fusion, plus personne ne les rouvre. Demande
# d'Éric sur ergonomia (2026-08-18), mot pour mot : « sans s'y pencher
# volontairement elles peuvent mourir ». La consolidation les remet sous les
# yeux ; le refus des sévérités hautes non soldées mécanise la règle du
# chapitre 7 (« sévérité haute corrigée dans la même branche avant fusion »),
# qui n'était jusqu'ici qu'une phrase.
#
#   sh tools/revues.sh             # contrôle : fraîcheur + hautes soldées
#   sh tools/revues.sh --ecrire    # régénère docs/revues/SUIVI.md
#
# Format lu — le tableau « Constats » du modèle code-review.md :
#   | # | Sévérité | Constat | Verdict | Résolution |
# Un verdict vide, ou qui n'est ni « Corrigé » ni « Rejeté », vaut OUVERT.
#
# POSIX sh + awk.
set -eu
# Tri en ordre des octets, quelle que soit la locale du poste ou de la CI :
# sinon l'artefact généré sous fr_FR diffère de celui de la CI (C.UTF-8),
# et l'anti-dérive le dit périmé. Les caractères restent ceux de la locale.
unset LC_ALL
export LC_COLLATE=C

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

ECRIRE=0
case "${1:-}" in
    --ecrire) ECRIRE=1 ;;
    "") ;;
    *) echo "Usage : sh tools/revues.sh [--ecrire]" >&2 ; exit 2 ;;
esac

REP="docs/revues"
SUIVI="${REP}/SUIVI.md"
mkdir -p "${REP}"

# Les fiches, hors index et hors tableau de bord lui-même.
FICHES="$(git ls-files "${REP}/*.md" 2>/dev/null | grep -v -e "${REP}/README.md" -e "${REP}/SUIVI.md" || true)"

extraire() {
    [ -n "${FICHES}" ] || return 0
    # Le code de retour d awk se perdrait dans un pipe vers « sort » : c est
    # le code de sort qui remonterait, toujours nul. On passe donc par un
    # fichier intermédiaire. (« set -o pipefail » reglerait le cas mais n est
    # pas POSIX, et le socle du gabarit exclut les bashismes.)
    _brut="$(mktemp)"
    # shellcheck disable=SC2086 — découpe en mots voulue.
    awk -v haute="$(lex SEVERITE_HAUTE)" \
        -v moyenne="$(lex SEVERITE_MOYENNE)" \
        -v basse="$(lex SEVERITE_BASSE)" \
        -v corrige="$(lex REVUE_CORRIGE)" \
        -v rejete="$(lex REVUE_REJETE)" '
        BEGIN { SEPARATEUR = sprintf("%c", 1) }
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        # Ne lire que les lignes de tableau à cinq colonnes, en sautant
        # l’en-tête et le séparateur.
        /^[ \t]*\|/ {
            # Une barre ÉCHAPPÉE (« \| ») appartient au texte de la cellule :
            # Markdown la rend littérale. awk, lui, découperait dessus — on la
            # met donc de côté le temps du découpage, puis on la restaure.
            ligne_t = $0
            gsub(/\\\|/, SEPARATEUR, ligne_t)
            n = split(ligne_t, c, "|")
            if (n < 7) next                      # | a | b | c | d | e | → 7 champs
            # Plus de sept champs : une cellule contient un « | » non échappé.
            # Les colonnes sont alors décalées et le verdict lu au mauvais
            # endroit — la porte afficherait « ouvert » un constat soldé, en
            # silence. Une erreur franche vaut mieux que ce chiffre-là. chiffre faux.
            if (n > 7) {
                printf "ÉCHEC : %s:%d — « | » non échappé dans une cellule.\n", FILENAME, FNR > "/dev/stderr"
                printf "        L écrire « \\| » : sinon les colonnes se décalent.\n" > "/dev/stderr"
                malformees++
                next
            }
            ref = trim(c[2]); sev = trim(c[3]); constat = trim(c[4]); verdict = trim(c[5])
            gsub(SEPARATEUR, "|", constat)
            gsub(SEPARATEUR, "|", verdict)
            if (ref == "" || ref == "#") next
            if (ref ~ /^-+$/) next
            sevl = tolower(sev)
            if (sevl !~ ("^(" tolower(haute) "|" tolower(moyenne) "|" tolower(basse) ")$")) next
            ouvert = 1
            if (verdict ~ ("^(" corrige "|" rejete ")$")) ouvert = 0
            fiche = FILENAME
            sub(/^.*\//, "", fiche)
            rang = (sevl ~ ("^" tolower(haute) "$")) ? 1 : (sevl ~ ("^" tolower(moyenne) "$")) ? 2 : 3
            printf "%d\t%d\t%s\t%s\t%s\t%s\t%s\n", ouvert ? 0 : 1, rang, fiche, ref, sev, constat, verdict
        }
        END { if (malformees > 0) exit 1 }
    ' ${FICHES} > "${_brut}" || { rm -f "${_brut}"; return 1; }
    sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3 "${_brut}"
    rm -f "${_brut}"
}

rendre() {
    _lignes="$1"
    if [ "${LEXIQUE_LANGUE}" = "en" ]; then
        printf '# Review findings — consolidated\n\n'
        printf '<!-- GENERATED by tools/revues.sh — do not edit by hand (R8). -->\n\n'
        printf '| State | Severity | Review | # | Finding | Verdict |\n'
        printf '| --- | --- | --- | --- | --- | --- |\n'
    else
        printf '# Constats de revue — suivi consolidé\n\n'
        printf '<!-- GÉNÉRÉ par tools/revues.sh — ne pas éditer à la main (R8). -->\n\n'
        printf '| État | Sévérité | Revue | # | Constat | Verdict |\n'
        printf '| --- | --- | --- | --- | --- | --- |\n'
    fi
    [ -n "${_lignes}" ] || return 0
    # Forme d'AFFICHAGE : celle de la langue principale. « lex » renverrait
    # l'alternance « Ouvert|Open », qui n'a de sens que pour reconnaître —
    # exactement la confusion que le constat de revue n° 1 a mise au jour,
    # reproduite ici jusqu'à ce que la revue la révèle.
    if [ "${LEXIQUE_LANGUE}" = "en" ]; then _ouvert="$(lex_en REVUE_OUVERT)"
    else _ouvert="$(lex_fr REVUE_OUVERT)"; fi
    printf '%s\n' "${_lignes}" | awk -F "\t" -v ouvert="${_ouvert}" '
        { etat = ($1 == "0") ? "**" ouvert "**" : "soldé"
          printf "| %s | %s | [%s](%s) | %s | %s | %s |\n", etat, $5, $3, $3, $4, $6, ($7 == "" ? "—" : $7) }'
}

LIGNES="$(extraire)" || {
    echo "Constats de revue : tableau mal formé, rien n'a été consolidé." >&2
    exit 1
}

if [ "${ECRIRE}" -eq 1 ]; then
    rendre "${LIGNES}" > "${SUIVI}.tmp"
    mv "${SUIVI}.tmp" "${SUIVI}"
    echo "Suivi des constats régénéré : ${SUIVI}"
    exit 0
fi

FAILURES=0
rendre "${LIGNES}" > "${SUIVI}.verif"
if ! cmp -s "${SUIVI}.verif" "${SUIVI}" 2>/dev/null; then
    echo "ÉCHEC : ${SUIVI} périmé — exécuter « sh tools/revues.sh --ecrire »." >&2
    FAILURES=$((FAILURES + 1))
fi
rm -f "${SUIVI}.verif"

# Règle du chapitre 7, désormais mécanisée : aucune sévérité haute sans
# réponse. « Rejeté » est une réponse — le rejet motivé solde le constat.
if [ -n "${LIGNES}" ]; then
    hautes="$(printf '%s\n' "${LIGNES}" | awk -F "\t" '$1 == "0" && $2 == "1" { print "  " $3 " #" $4 " — " $6 }')"
    if [ -n "${hautes}" ]; then
        echo "ÉCHEC : constat(s) de sévérité haute sans verdict :" >&2
        printf '%s\n' "${hautes}" >&2
        FAILURES=$((FAILURES + 1))
    fi
fi

if [ "${FAILURES}" -gt 0 ]; then exit 1; fi
echo "Constats de revue : OK."
