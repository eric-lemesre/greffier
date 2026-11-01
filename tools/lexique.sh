#!/bin/sh
# Lexique du vocabulaire OUTILLÉ — le seul endroit où vivent les mots que les
# portes reconnaissent (statuts, niveaux normatifs, verdicts, étiquettes de
# forge, commandes de consultation).
#
# Pourquoi ce fichier existe (ADR-0015). Une porte qui cherche « ACTIVE » ou
# « à-tester » en dur impose la langue du gabarit à tous les projets
# instanciés. L'ADR-0009 rend la langue arbitrable, mais ne portait jusqu'ici
# que sur les artefacts GÉNÉRÉS ; le vocabulaire que les contrôles LISENT
# restait français. Le lexique referme cet écart : chaque terme existe dans
# les deux langues, l'instanciation fige le jeu, et aucune porte ne réécrit
# un mot en dur.
#
# Usage — sourcer, puis lire :
#     . "$(dirname "$0")/lexique.sh"
#     lex SPEC_ACTIVE                 # forme(s) active(s), ex. « ACTIVE »
#     lex_fr SPEC_ACTIVE              # forme française, quelle que soit la langue
#     grep -Eq "$(lex SPEC_ACTIVE)" fichier
#
# En langue « fr-en », `lex` renvoie une alternance ERE des deux formes
# (« à-tester|to-test ») : un dépôt bilingue accepte les deux vocabulaires.
# En « fr » ou « en », il ne renvoie que la forme choisie — un terme de
# l'autre langue n'est alors plus reconnu, ce qui est le but.
#
# POSIX sh strict. Ce fichier ne s'exécute pas : il se source.

# --- lexique-langue:debut ---
# Figé à l'instanciation selon --langue (ADR-0009) ; ne pas déplacer les
# marqueurs. Valeurs : fr | en | fr-en.
LEXIQUE_LANGUE="${LEXIQUE_LANGUE:-fr-en}"
# --- lexique-langue:fin ---

LEX_CLES=""

# Déclare un terme : lex_def CLÉ "forme française" "forme anglaise".
# Les deux formes peuvent être identiques (« bug: », « ✅ ») — un terme qui ne
# se traduit pas se déclare quand même, pour que le contrôle de complétude le
# voie et que la porte passe malgré tout par le lexique.
lex_def() {
    _lex_cle="$1"
    _lex_fr="$2"
    _lex_en="$3"
    # Les clés servent à composer des noms de variables via eval : la garde
    # rend l'invariant explicite au lieu de le supposer, et refuse net une clé
    # qui pourrait injecter du code au moment du sourcing.
    case "${_lex_cle}" in
        ""|*[!A-Z0-9_]*)
            echo "ERREUR : clé de lexique invalide : « ${_lex_cle} »" >&2
            echo "        Attendu : majuscules, chiffres et « _ » uniquement." >&2
            return 1
            ;;
    esac
    eval "LEX_${_lex_cle}_FR=\$_lex_fr"
    eval "LEX_${_lex_cle}_EN=\$_lex_en"
    case "${LEXIQUE_LANGUE}" in
        fr) eval "LEX_${_lex_cle}=\$_lex_fr" ;;
        en) eval "LEX_${_lex_cle}=\$_lex_en" ;;
        *)
            if [ "${_lex_fr}" = "${_lex_en}" ]; then
                eval "LEX_${_lex_cle}=\$_lex_fr"
            else
                eval "LEX_${_lex_cle}=\"\${_lex_fr}|\${_lex_en}\""
            fi
            ;;
    esac
    LEX_CLES="${LEX_CLES} ${_lex_cle}"
}

# Forme(s) active(s) d'un terme, prêtes pour grep -E / case.
lex() {
    eval "_lex_val=\${LEX_${1}:-}"
    if [ -z "${_lex_val}" ]; then
        echo "ERREUR : terme absent du lexique : $1 (tools/lexique.sh)" >&2
        return 1
    fi
    printf '%s' "${_lex_val}"
}

# Motif d'alternance PARENTHÉSÉ, prêt à être inséré dans une expression
# régulière plus large. À préférer systématiquement à `lex` dans ce cas :
# insérer « Statut|Status » au milieu d'une regex produit
# « ^\*\*Statut|Status[ \t]*: », c'est-à-dire « commence par **Statut » OU
# « contient Status suivi de : » — la seconde branche est une passoire, la
# première ignore l'anglais. Défaut réel, trouvé en revue (2026-08-20).
lex_motif() {
    _lex_m="$(lex "$1")" || return 1
    printf '(%s)' "${_lex_m}"
}

# Le terme reconnaît-il cette valeur ? Applique la langue figée : en « fr » ou
# « en », seule la forme correspondante est acceptée ; en « fr-en », les deux.
# C'est LE point d'entrée des portes qui comparent une valeur à un terme —
# comparer soi-même à `lex_fr` revient à imposer le français à un dépôt
# bilingue, ce qui contredit le critère d'acceptation de req~lexique-outille~1.
lex_est() {
    _lex_c="$1"
    _lex_v="$2"
    case "${LEXIQUE_LANGUE}" in
        fr) [ "${_lex_v}" = "$(lex_fr "${_lex_c}")" ] ;;
        en) [ "${_lex_v}" = "$(lex_en "${_lex_c}")" ] ;;
        *)  [ "${_lex_v}" = "$(lex_fr "${_lex_c}")" ] || \
            [ "${_lex_v}" = "$(lex_en "${_lex_c}")" ] ;;
    esac
}

# Forme française / anglaise, indépendamment de la langue figée. Utile aux
# messages d'aide qui citent les deux vocabulaires, et au contrôle de parité.
lex_fr() { eval "printf '%s' \"\${LEX_${1}_FR:-}\""; }
lex_en() { eval "printf '%s' \"\${LEX_${1}_EN:-}\""; }

# Liste des clés déclarées (contrôle de complétude, tests).
lex_cles() { printf '%s\n' ${LEX_CLES}; }

# ---------------------------------------------------------------------------
# Statuts de spécification — le commutateur de couverture (méthode, ch. 13).
# Un statut fait entrer ou sortir les exigences du dénominateur : c'est le
# terme le plus structurant du lexique.
# ---------------------------------------------------------------------------
lex_def SPEC_PROPOSITION "PROPOSITION" "PROPOSED"
lex_def SPEC_ACTIVE      "ACTIVE"      "ACTIVE"
lex_def SPEC_OBSOLETE    "OBSOLÈTE"    "OBSOLETE"

# ---------------------------------------------------------------------------
# Cycle de vie d'une EXIGENCE (méthode, ch. 13) — à ne pas confondre avec le
# statut d'un DOMAINE ci-dessus : celui-ci dit si le document est arbitré,
# celui-là où en est la réalisation d'une exigence donnée.
#
# Les cinq premiers se DÉCLARENT : ils relèvent du jugement. Les deux derniers
# se CALCULENT depuis la couverture réelle et ne s'écrivent jamais à la main —
# un avancement saisi est un chiffre faux en puissance (ch. 4).
# ---------------------------------------------------------------------------
lex_def EXIGENCE_BROUILLON   "brouillon" "draft"
lex_def EXIGENCE_PROPOSEE    "proposée"  "proposed"
lex_def EXIGENCE_APPROUVEE   "approuvée" "approved"
lex_def EXIGENCE_REJETEE     "rejetée"   "rejected"
lex_def EXIGENCE_DEPRECIEE   "dépréciée" "deprecated"
lex_def EXIGENCE_IMPLEMENTEE "implémentée" "implemented"
lex_def EXIGENCE_VERIFIEE    "vérifiée"    "verified"

# ---------------------------------------------------------------------------
# Niveaux normatifs — EARS (méthode, ch. 2). Le pluriel compte : une exigence
# rédigée « les portes DOIVENT » doit être classée comme « DOIT ».
# ---------------------------------------------------------------------------
lex_def NORM_DOIT    "DOIT|DOIVENT"         "SHALL|MUST"
lex_def NORM_DEVRAIT "DEVRAIT|DEVRAIENT"    "SHOULD"
lex_def NORM_PEUT    "PEUT|PEUVENT"         "MAY"

# ---------------------------------------------------------------------------
# Audit de réalisation (méthode, ch. 14) — verdicts portés par l'humain, jamais
# calculés : le générateur compte, l'humain juge.
# ---------------------------------------------------------------------------
lex_def AUDIT_CONFORME     "conforme"     "compliant"
lex_def AUDIT_ECART        "écart"        "gap"
lex_def AUDIT_NON_EXAMINE  "non examiné"  "not examined"

# ---------------------------------------------------------------------------
# Gravité constatée (méthode, ch. 11 §triage) — se constate, ne se négocie
# pas. Vocabulaire des formulaires d'anomalie des deux forges.
# ---------------------------------------------------------------------------
lex_def GRAVITE_CRITIQUE "Critique" "Critical"
lex_def GRAVITE_GENANT   "Gênant"   "Major"
lex_def GRAVITE_MINEUR   "Mineur"   "Minor"

# ---------------------------------------------------------------------------
# Suivi des constats de revue (méthode, ch. 7) — vocabulaire du modèle
# code-review.md, que la porte de consolidation relit.
# ---------------------------------------------------------------------------
lex_def SEVERITE_HAUTE   "haute"   "high"
lex_def SEVERITE_MOYENNE "moyenne" "medium"
lex_def SEVERITE_BASSE   "basse"   "low"
lex_def REVUE_OUVERT     "Ouvert"  "Open"
lex_def REVUE_CORRIGE    "Corrigé" "Fixed"
lex_def REVUE_REJETE     "Rejeté"  "Rejected"

# ---------------------------------------------------------------------------
# Feuille de route (méthode, ch. 12). Les pastilles ne se traduisent pas ; le
# libellé de la ligne de statut, si.
# ---------------------------------------------------------------------------
lex_def TODO_LIBELLE  "Statut" "Status"
lex_def TODO_FAIT     "✅"     "✅"
lex_def TODO_EN_COURS "🚧"     "🚧"
lex_def TODO_A_VENIR  "⏳"     "⏳"

# ---------------------------------------------------------------------------
# Journaux (méthode, ch. 8). CHANGELOG = journal du dépôt, NEWS = journal du
# logiciel : deux lectorats, deux fichiers.
# ---------------------------------------------------------------------------
lex_def JOURNAL_NON_PUBLIE "Non publié" "Unreleased"
lex_def JOURNAL_AJOUTE     "Ajouté"     "Added"
lex_def JOURNAL_MODIFIE    "Modifié"    "Changed"
lex_def JOURNAL_CORRIGE    "Corrigé"    "Fixed"
lex_def JOURNAL_SUPPRIME   "Supprimé"   "Removed"
lex_def JOURNAL_SECURITE   "Sécurité"   "Security"
lex_def JOURNAL_DEPRECIE   "Déprécié"   "Deprecated"

# ---------------------------------------------------------------------------
# Classification des exigences (méthode, ch. 5) — étiquette de complétude
# portée par tools/classification.sh : une exigence couverte, mais SOUS le
# niveau de vérification que sa rigueur appelle (méthode, ch. 5 : « une
# exigence bascule de mtest vers un niveau automatisé dès que c'est
# techniquement possible »). Un état, donc un terme du lexique (R9) — même si
# la phrase qui l'entoure reste, comme le reste de ce contrôle, un message de
# diagnostic non traduit.
# ---------------------------------------------------------------------------
lex_def CLASSIFICATION_A_ELEVER "à élever" "to raise"

# ---------------------------------------------------------------------------
# Avancement des DOMAINES (méthode, ch. 13) — à ne pas confondre avec les
# statuts calculés de l'EXIGENCE (implémentée/vérifiée, ci-dessus) : celui-ci
# résume un domaine entier depuis deux faits déjà écrits — ses exigences dues
# tiennent-elles leur `Needs:` ? une fiche de feuille de route encore ouverte
# le cite-t-elle ? — jamais depuis un chiffre saisi (tools/avancement.sh).
# ---------------------------------------------------------------------------
lex_def AVANCEMENT_LIBELLE     "Avancement"  "Progress"
lex_def AVANCEMENT_IMPLEMENTEE "implémentée" "implemented"
lex_def AVANCEMENT_EN_COURS    "en cours"    "in progress"
lex_def AVANCEMENT_PLANIFIEE   "planifiée"   "planned"
lex_def AVANCEMENT_A_PLANIFIER "à planifier" "to plan"
lex_def AVANCEMENT_HORS_MESURE "hors mesure" "not measurable"
lex_def AVANCEMENT_SANS_OBJET  "—"           "—"

# ---------------------------------------------------------------------------
# Sections normatives lues par les portes.
# ---------------------------------------------------------------------------
lex_def SECTION_VERIFICATION "Vérification"        "Verification"
lex_def SECTION_DECISIONS    "Relevé de décisions" "Decision record"
lex_def SECTION_STATUT       "Statut"              "Status"

# ---------------------------------------------------------------------------
# Étiquettes de forge (méthode, ch. 11). L'étiquette dit l'état, l'assignation
# dit qui est attendu, le commentaire trace l'acte.
# ---------------------------------------------------------------------------
lex_def LABEL_A_CONSULTER      "à-consulter"      "to-review"
lex_def LABEL_A_DISCUTER       "à-discuter"       "to-discuss"
lex_def LABEL_A_TESTER         "à-tester"         "to-test"
lex_def LABEL_A_CLOTURER       "à-clôturer"       "to-close"
lex_def LABEL_LIVRE            "livré"            "delivered"
lex_def LABEL_DIFFERE          "différé"          "deferred"
lex_def LABEL_DOUBLON          "doublon"          "duplicate"
lex_def LABEL_INVALIDE         "invalide"         "invalid"
lex_def LABEL_NE_SERA_PAS_FAIT "ne-sera-pas-fait" "wont-do"

# ---------------------------------------------------------------------------
# Familles d'issues (méthode, ch. 11). Préfixes empruntés aux Conventional
# Commits : ils ne se traduisent pas, et c'est une information utile.
# ---------------------------------------------------------------------------
lex_def FAMILLE_BUG  "bug:"  "bug:"
lex_def FAMILLE_FEAT "feat:" "feat:"

# ---------------------------------------------------------------------------
# Commandes de consultation, écrites en commentaire d'issue (méthode, ch. 11).
# ---------------------------------------------------------------------------
lex_def CMD_VU    "/vu"    "/seen"
lex_def CMD_ACTER "/acter" "/enact"
