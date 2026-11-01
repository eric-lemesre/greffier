#!/bin/sh
# [impl->req~classification-exigences~2]
# [impl->req~format-exigence-ears~1]
# Classification des exigences : niveau normatif × niveau de vérification.
#
# Ce que cette porte ajoute à la traçabilité. OpenFastTrace vérifie qu'un
# `Needs: utest` déclaré est SATISFAIT. Il ne vérifie jamais que le `Needs`
# lui-même est à la hauteur de l'exigence : une exigence qui dit DOIT et ne
# déclare aucun niveau de test passe la traçabilité en silence. C'est une
# dette invisible — l'exigence la plus contraignante du dépôt peut n'être
# prouvée par rien, sans qu'aucun voyant ne s'allume.
#
# Trois contrôles :
#   1. toute exigence porte UN niveau normatif explicite (EARS, ch. 2) ;
#   2. toute exigence de niveau DOIT déclare une vérification — mécanisée
#      (utest/itest/stest) ou manuelle assumée (mtest) ;
#   3. COMPLÉTUDE (durcie — révision ~2 de l'exigence) : une vérification
#      manuelle (mtest) sur une exigence DOIT ou DEVRAIT n'est pas un défaut
#      en soi — R10 l'autorise explicitement — mais reste une promesse plus
#      faible qu'un niveau mécanisé, et la méthode (ch. 5) dit qu'« une
#      exigence bascule de mtest vers un niveau automatisé dès que c'est
#      techniquement possible ». Un signal qu'on peut ignorer sans trace
#      finit ignoré : le contrôle FAIT donc ÉCHOUER la porte, sauf report
#      explicite — l'identifiant suivi du marqueur « (à élever…) » dans une
#      fiche de la feuille de route (docs/todo/) — auquel cas l'exigence est
#      NOMMÉE comme dette à chaque passage. Chaque cas appelle un arbitrage
#      (écrire le test mécanisé, ou assumer le mtest durablement avec son
#      motif dans la fiche) — jamais un tag de complaisance.
#
# PIÈGE VÉRIFIÉ, à l'origine du découpage du corps (constaté sur ergonomia) :
# le niveau normatif se lit dans l'ÉNONCÉ seul. Un « DOIT » cité dans un
# Rationale (« la porte DOIT rester hors ligne ») ou dans un critère
# d'acceptation est un niveau EMPRUNTÉ : le classement le prendrait pour
# l'énoncé et rangerait en DOIT une exigence rédigée en DEVRAIT.
#
# ADAPTATION DÉLIBÉRÉE (constatée sur un projet instancié, qui distingue par
# un `Tags: niveau-…` le niveau de vérification CIBLE — unitaire/intégration/
# système/manuel/… — de la couverture réellement déclarée, et nomme « à
# élever » toute exigence couverte sous sa cible). Le gabarit ne porte PAS ce
# `Tags:` : son format d'item (`docs/methode/02-exigences.md`) n'a que
# Rationale/Critères/Covers/Needs, et son seul axe de rigueur exigible est le
# niveau normatif EARS lui-même (R10 : seul le DOIT engage une vérification).
# La complétude porte donc ici sur le seul écart qui existe réellement dans ce
# format — mtest déclaré seul là où un niveau mécanisé reste possible — plutôt
# que sur un axe « niveau cible » qui n'existe pas dans ce gabarit. Un projet
# instancié qui adopte un `Tags: niveau-…` retrouve le contrôle complet en
# reprenant la table niveau → type de la source (méthode, ch. 5).
#
#   sh tools/classification.sh            # contrôle + bilan chiffré
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

[ "${1:-}" = "" ] || { echo "Usage : sh tools/classification.sh" >&2 ; exit 2 ; }

FICHIERS="$(git ls-files 'spec/02-exigences/*.md' 2>/dev/null | \
            grep -v 'spec/02-exigences/README.md' || true)"
[ -n "${FICHIERS}" ] || { echo "Classification : aucune exigence."; exit 0; }

# Reports de complétude : l'identifiant suivi du marqueur « (à élever…) »
# dans une fiche de la feuille de route. Le marqueur se lit dans TOUTES les
# fiches, ouvertes ou closes : le report vit dans la fiche du chantier qui
# rendra l'arbitrage, et s'il survit à sa clôture il reste une dette nommée,
# jamais un oubli. Terme pris au lexique (R9) — la ou les langues selon la
# langue figée du dépôt.
MARQUE_ELEVER="req~[a-z0-9-]+~[0-9]+\`? *\($(lex_motif CLASSIFICATION_A_ELEVER)"
ELEVEES=""
for fiche in $(git ls-files 'docs/todo/todo-*.md' 2>/dev/null || true); do
    ELEVEES="${ELEVEES}$(grep -ohE "${MARQUE_ELEVER}" "${fiche}" 2>/dev/null \
        | grep -ohE '^req~[a-z0-9-]+~[0-9]+' || true)
"
done

# shellcheck disable=SC2086 — découpe en mots voulue.
awk -v doit="$(lex NORM_DOIT)" \
    -v devrait="$(lex NORM_DEVRAIT)" \
    -v peut="$(lex NORM_PEUT)" \
    -v approuvee="$(lex_motif EXIGENCE_APPROUVEE)" \
    -v etiq_a_elever="$(lex_fr CLASSIFICATION_A_ELEVER)" \
    -v elevees="${ELEVEES}" '
BEGIN {
    nrep = split(elevees, liste, "\n")
    for (i = 1; i <= nrep; i++) if (liste[i] != "") {
        # La comparaison ignore la version : un report survit à une révision
        # de l’exigence — c’est l’exigence qu’on reporte, pas son numéro.
        r = liste[i]; sub(/~[0-9]+$/, "~", r); reportee[r] = 1
    }
}
function racine(item,   r) { r = item; sub(/~[0-9]+$/, "~", r); return r }
function solder(   niveau, teste, mecanisee, manuelle_seule) {
    if (id == "") return
    # Dénominateur : les exigences approuvées (ADR-0018). Un brouillon n’a pas
    # à porter un niveau de vérification : ce n’est pas encore un engagement.
    if (statut !~ ("^" approuvee "$")) { id = ""; enonce = ""; needs = ""; statut = ""; return }
    niveau = ""
    # L’ordre compte : une exigence qui dit DOIT et DEVRAIT dans le même
    # énoncé est de niveau DOIT — le plus contraignant l’emporte.
    if (enonce ~ ("(^|[^A-Za-zÀ-ÿ])(" doit ")([^A-Za-zÀ-ÿ]|$)"))         niveau = "DOIT"
    else if (enonce ~ ("(^|[^A-Za-zÀ-ÿ])(" devrait ")([^A-Za-zÀ-ÿ]|$)")) niveau = "DEVRAIT"
    else if (enonce ~ ("(^|[^A-Za-zÀ-ÿ])(" peut ")([^A-Za-zÀ-ÿ]|$)"))    niveau = "PEUT"

    if (niveau == "") {
        printf "ÉCHEC : %s — %s : énoncé sans niveau normatif explicite.\n", fichier, id > "/dev/stderr"
        printf "        Attendu dans l’énoncé : %s | %s | %s\n", doit, devrait, peut > "/dev/stderr"
        defauts++
    } else {
        total[niveau]++
    }

    # Frontières de mot : « itest » ne doit se lire ni dans un mot qui le
    # contient, ni ailleurs que comme un type entier de la liste Needs.
    teste = (needs ~ /(^|[ ,:])(utest|itest|stest|mtest)([ ,]|$)/)
    if (niveau == "DOIT") {
        if (teste) verifiees++
        else {
            printf "ÉCHEC : %s — %s : niveau DOIT sans vérification déclarée.\n", fichier, id > "/dev/stderr"
            printf "        Ajouter un niveau à « Needs: » — utest/itest/stest, ou mtest si la\n" > "/dev/stderr"
            printf "        vérification est manuelle et assumée (méthode, ch. 5).\n" > "/dev/stderr"
            defauts++
        }
    }

    # Contrôle 3 — complétude (durcie) : un DOIT/DEVRAIT couvert par mtest
    # SEUL (aucun niveau mécanisé) tient la lettre de R10 mais reste la
    # preuve la plus faible. ÉCHEC, sauf report explicite par une fiche de
    # la feuille de route — l’exigence est alors nommée comme dette à
    # chaque passage, jamais un signal qu’on ignore en silence.
    mecanisee = (needs ~ /(^|[ ,:])(utest|itest|stest)([ ,]|$)/)
    manuelle_seule = (teste && !mecanisee && needs ~ /(^|[ ,:])mtest([ ,]|$)/)
    if (manuelle_seule && (niveau == "DOIT" || niveau == "DEVRAIT")) {
        if (reportee[racine(id)]) {
            printf "  %s   %s — %s (niveau %s couvert par mtest seul ; reporté par fiche)\n", \
                   etiq_a_elever, fichier, id, niveau
            a_elever++
        } else {
            printf "ÉCHEC : %s — %s : niveau %s couvert par mtest seul, sans report.\n", \
                   fichier, id, niveau > "/dev/stderr"
            printf "        Écrire le test mécanisé (utest/itest/stest), ou reporter\n" > "/dev/stderr"
            printf "        explicitement : « %s (%s : motif) » dans une fiche de la\n", id, etiq_a_elever > "/dev/stderr"
            printf "        feuille de route (docs/todo/) — la dette sera nommée à chaque passage.\n" > "/dev/stderr"
            defauts++
        }
    }
    id = ""; enonce = ""; needs = ""; statut = ""
}

FNR == 1 { solder(); fichier = FILENAME }

# Définition d’item : ferme la précédente, ouvre la suivante.
/^`req~[a-z0-9-]+~[0-9]+`[ \t]*$/ {
    solder()
    id = $0; gsub(/`/, "", id); gsub(/[ \t]/, "", id)
    dans_enonce = 1
    attente_statut = 1
    next
}

# Ligne de statut, juste sous l’identifiant.
attente_statut && /^\*\*/ {
    statut = $0
    sub(/^[^:]*:[ \t]*/, "", statut); sub(/\*\*[ \t]*$/, "", statut)
    gsub(/[ \t]+$/, "", statut)
    attente_statut = 0
    next
}
attente_statut && NF > 0 { attente_statut = 0 }

id == "" { next }

# Fin de l’énoncé : tout ce qui suit (rationale, critères, relations) porte
# un vocabulaire qui n’est PAS celui de l’exigence. Les noms de champ
# tolèrent l’espace avant le deux-points (« Needs : » à la française) : une
# typographie ne doit jamais désarmer une porte en silence.
/^(Rationale[ ]?:|Covers[ ]?:|Needs[ ]?:|Critères d.acceptation|Acceptance criteria|## )/ {
    dans_enonce = 0
}
# Les lignes Needs: se CUMULENT : la dernière n’écrase pas la première —
# deux déclarations valent deux couvertures, pas une perte silencieuse.
/^Needs[ ]?:/ { needs = (needs == "" ? $0 : needs " " $0) }
dans_enonce { enonce = enonce " " $0 }

END {
    solder()
    d = total["DOIT"] + 0; v = total["DEVRAIT"] + 0; p = total["PEUT"] + 0
    n = d + v + p
    printf "Classification : %d exigence(s) — %s %d, %s %d, %s %d.\n", n, "DOIT", d, "DEVRAIT", v, "PEUT", p
    # Dénominateur/taux (méthode, ch. 5) : M = exigences « testables » — dans
    # ce gabarit, celles de niveau DOIT, seul niveau que R10 engage à une
    # vérification (DEVRAIT/PEUT en sont l’équivalent du « non applicable » :
    # aucune règle ne leur impose de Needs). N = celles qui en déclarent un
    # réel (utest/itest/stest/mtest).
    if (d > 0) {
        printf "Couverture déclarée : %d/%d exigence(s) testable(s) (%.1f %%).\n", \
               verifiees + 0, d, (verifiees + 0) * 100 / d
        if (a_elever > 0)
            printf "Complétude : %d exigence(s) couverte(s) par mtest seul, reportée(s) par fiche (à élever).\n", a_elever + 0
    }
    if (defauts > 0) {
        printf "%d défaut(s) de classification.\n", defauts > "/dev/stderr"
        exit 1
    }
}
' ${FICHIERS}
