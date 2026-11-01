#!/bin/sh
# Avancement des domaines d'exigences — CALCULÉ, jamais saisi.
#
# Pourquoi cette porte existe. Même défaut que l'index de feuille de route
# (ch. 12, tools/todo.sh) et les statuts calculés de l'exigence (ADR-0018,
# tools/statuts.sh) : « un index tenu à la main finit toujours par mentir ».
# Rien, jusqu'ici, ne répondait à la question d'un point d'avancement de
# projet — « où en est ce DOMAINE ? » — à l'échelle du domaine plutôt que de
# l'exigence unique. Cette porte la déduit de deux faits déjà écrits, sans
# qu'aucun humain n'ait à la tenir à jour :
#
#   (a) dans le fichier du domaine — DUES : ses exigences approuvées de
#       niveau DOIT ou DEVRAIT (méthode, ch. 2) ; TENUES, parmi elles : celles
#       qui déclarent un `Needs:` non vide.
#   (b) dans la feuille de route (docs/todo/todo-*.md) — CITÉE : au moins une
#       fiche NON SOLDÉE (pastille autre que ✅) mentionne un identifiant
#       `req~…~n` du domaine.
#
# CHOIX DÉLIBÉRÉ (a) — pourquoi « Needs: déclaré » et non un balayage des
# traces réelles comme le fait `tools/matrice.sh`. La véracité d'un `Needs:`
# déclaré est déjà GARANTIE ailleurs : OpenFastTrace (`tools/oft.sh trace`)
# refuse qu'un `Needs:` ne soit pas réellement satisfait par un item aval, et
# `just ci`/`task ci` doit être vert avant toute PR (contrat du dépôt). Une
# fois cette porte-là passée, « Needs: déclaré » atteste donc une couverture
# réelle sans qu'il faille la reconstater ici — la même vérité, lue à moindre
# coût, plutôt qu'une deuxième analyse du dépôt qui répéterait celle
# d'OpenFastTrace en pire. `tools/statuts.sh`, lui, VEUT reconstater les tags
# réels : sa maille est l'exigence individuelle, où le chiffre affiché
# (implémentée/vérifiée) est la promesse elle-même. Ici, la maille est le
# domaine : un état de synthèse peut légitimement s'appuyer sur une garantie
# déjà posée par une autre porte, plutôt que la reproduire.
#
# CHOIX DÉLIBÉRÉ (b) — le motif de citation. Le modèle de fiche
# (templates/fr/roadmap-card.md) prévoit une ligne « - Exigences : {{ req~… }} »
# sous « ## Renvois », mais la seule fiche réelle du dépôt à ce jour
# (docs/todo/todo-0001-…, antérieure à cette convention) n'a pas de section
# « Renvois » du tout. S'astreindre à cette seule ligne serait donc aveugle
# à tout dépôt qui n'aurait pas encore adopté la convention à la lettre.
# Le balayage porte donc sur le CORPS ENTIER de la fiche — même généralité
# que le motif `[<type>->req~…~n]` de `tools/matrice.sh`, qui ne se limite pas
# non plus à un emplacement précis du fichier.
#
# ORDRE DES TESTS — « implémentée » prime sur « planifiée » : un domaine dont
# TOUTES les dues sont tenues est « implémentée » même s'il reste cité par une
# fiche encore ouverte (par exemple un chantier qui referme un domaine tout en
# en ouvrant un autre). Le test de citation n'est atteint que si aucune due
# n'est tenue — jamais avant.
#
#   sh tools/avancement.sh             # contrôle la colonne Avancement
#   sh tools/avancement.sh --ecrire    # la régénère dans spec/02-exigences/README.md
#
# LIMITE ASSUMÉE — « implémentée » inclut le vérifié MANUELLEMENT. « Tenue »
# signifie ici « déclare un Needs: non vide », mtest compris : un domaine dont
# toutes les dues ne sont couvertes que par mtest s'affiche « implémentée »
# alors que la complétude (tools/classification.sh) le signale « à élever ».
# C'est voulu : R10 autorise la vérification manuelle assumée — « implémentée »
# répond à « la promesse est-elle tenue ? », « à élever » répond à « la preuve
# est-elle la plus forte possible ? ». Les deux vues coexistent, chacune dit
# ce qu'elle mesure.
#
# LIMITE CONNUE : le tableau de spec/02-exigences/README.md est supposé porter
# EXACTEMENT les colonnes Domaine (1re, lien vers <domaine>.md) puis Statut,
# puis (une fois régénéré) Avancement, puis Objet — comme aujourd'hui. Une
# cellule « Objet » qui contiendrait elle-même un « | » non échappé décalerait
# la lecture (même limite documentée que tools/revues.sh pour ses tableaux).
#
# POSIX sh + awk.
set -eu

# Chemins portant espaces ou métacaractères (constat de revue n° 2, repris de
# tools/todo.sh) : le découpage par défaut d'un « $(git ls-files) » non quoté
# coupe « mon document.md » en deux et laisse un glob s'expanser. On découpe
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
    *) echo "Usage : sh tools/avancement.sh [--ecrire]" >&2 ; exit 2 ;;
esac

INDEX="spec/02-exigences/README.md"
[ -f "${INDEX}" ] || { echo "Avancement : ${INDEX} absent — rien à faire."; exit 0; }

FICHIERS="$(git ls-files 'spec/02-exigences/*.md' 2>/dev/null | grep -v "^${INDEX}\$" || true)"
FICHES_TODO="$(git ls-files 'docs/todo/todo-*.md' 2>/dev/null || true)"

# Formes d'AFFICHAGE : celle de la langue principale (même règle que
# tools/revues.sh pour REVUE_OUVERT — `lex` renverrait l'alternance
# bilingue, illisible une fois affichée).
if [ "${LEXIQUE_LANGUE}" = "en" ]; then
    LIB_AVANCEMENT="$(lex_en AVANCEMENT_LIBELLE)"
    ETAT_IMPLEMENTEE="$(lex_en AVANCEMENT_IMPLEMENTEE)"
    ETAT_EN_COURS="$(lex_en AVANCEMENT_EN_COURS)"
    ETAT_PLANIFIEE="$(lex_en AVANCEMENT_PLANIFIEE)"
    ETAT_A_PLANIFIER="$(lex_en AVANCEMENT_A_PLANIFIER)"
    ETAT_HORS_MESURE="$(lex_en AVANCEMENT_HORS_MESURE)"
else
    LIB_AVANCEMENT="$(lex_fr AVANCEMENT_LIBELLE)"
    ETAT_IMPLEMENTEE="$(lex_fr AVANCEMENT_IMPLEMENTEE)"
    ETAT_EN_COURS="$(lex_fr AVANCEMENT_EN_COURS)"
    ETAT_PLANIFIEE="$(lex_fr AVANCEMENT_PLANIFIEE)"
    ETAT_A_PLANIFIER="$(lex_fr AVANCEMENT_A_PLANIFIER)"
    ETAT_HORS_MESURE="$(lex_fr AVANCEMENT_HORS_MESURE)"
fi
ETAT_SANS_OBJET="$(lex_fr AVANCEMENT_SANS_OBJET)"

# --- Fait (b) : identifiants req~…~n cités par une fiche NON SOLDÉE --------
LIBELLE_TODO="$(lex_motif TODO_LIBELLE)"
PASTILLE_FAIT="$(lex TODO_FAIT)"
REQS_OUVERTES=""
for f in ${FICHES_TODO}; do
    ligne_statut="$(awk -v l="${LIBELLE_TODO}" '$0 ~ ("^\\*\\*" l "[ \t]*:") { print; exit }' "${f}")"
    case "${ligne_statut}" in
        *"${PASTILLE_FAIT}"*) continue ;;
    esac
    REQS_OUVERTES="${REQS_OUVERTES}
$(grep -oE 'req~[a-z0-9-]+~[0-9]+' "${f}" 2>/dev/null || true)"
done
REQS_OUVERTES="$(printf '%s\n' "${REQS_OUVERTES}" | sed '/^$/d' | sort -u)"

# Identifiants req~…~n DÉFINIS dans un fichier de domaine (ligne d'item
# seule sur sa ligne — jamais une mention en passant, dans un Rationale par
# exemple).
ids_domaine() {
    grep -E '^`req~[a-z0-9-]+~[0-9]+`[ \t]*$' "$1" 2>/dev/null | tr -d '`[:space:]'
}

domaine_est_cite() {
    _ids="$(ids_domaine "$1")"
    [ -n "${_ids}" ] || return 1
    for _id in ${_ids}; do
        printf '%s\n' "${REQS_OUVERTES}" | grep -qxF "${_id}" && return 0
    done
    return 1
}

# --- Fait (a) : DUES et TENUES d'un domaine --------------------------------
# Même lecture d'item que tools/classification.sh (identifiant, statut,
# énoncé jusqu'au premier champ de relation, Needs:) : le niveau normatif se
# lit dans l'ÉNONCÉ seul, jamais dans un Rationale ou un critère qui
# emprunterait le mot.
calc_dues_tenues() {
    awk -v doit="$(lex NORM_DOIT)" -v devrait="$(lex NORM_DEVRAIT)" \
        -v approuvee="$(lex_motif EXIGENCE_APPROUVEE)" '
        function solder(   due) {
            if (id == "") return
            if (statut ~ ("^" approuvee "$")) {
                due = 0
                if (enonce ~ ("(^|[^A-Za-zÀ-ÿ])(" doit ")([^A-Za-zÀ-ÿ]|$)")) due = 1
                else if (enonce ~ ("(^|[^A-Za-zÀ-ÿ])(" devrait ")([^A-Za-zÀ-ÿ]|$)")) due = 1
                if (due) {
                    dues++
                    if (needs ~ /[A-Za-zÀ-ÿ]/) tenues++
                }
            }
            id = ""; enonce = ""; needs = ""; statut = ""
        }
        /^`req~[a-z0-9-]+~[0-9]+`[ \t]*$/ {
            solder()
            id = $0
            dans_enonce = 1
            attente_statut = 1
            next
        }
        attente_statut && /^\*\*/ {
            statut = $0
            sub(/^[^:]*:[ \t]*/, "", statut); sub(/\*\*[ \t]*$/, "", statut)
            gsub(/[ \t]+$/, "", statut)
            attente_statut = 0
            next
        }
        attente_statut && NF > 0 { attente_statut = 0 }
        id == "" { next }
        # Espace toléré avant le deux-points (« Needs : » à la française) ;
        # les lignes Needs: se cumulent — la dernière n écrase pas la première.
        /^(Rationale[ ]?:|Covers[ ]?:|Needs[ ]?:|Critères d.acceptation|Acceptance criteria|## )/ {
            dans_enonce = 0
        }
        /^Needs[ ]?:/ {
            ligne = $0
            sub(/^Needs[ ]?:[ \t]*/, "", ligne)
            needs = (needs == "" ? ligne : needs " " ligne)
        }
        dans_enonce { enonce = enonce " " $0 }
        END {
            solder()
            printf "%d %d\n", dues, tenues
        }
    ' "$1"
}

# Statut DÉCLARÉ du domaine (même lecture que tools/statuts.sh).
statut_domaine() {
    awk -v lib="$(lex_motif SECTION_STATUT)" \
        -v motif="$(lex SPEC_PROPOSITION)|$(lex SPEC_ACTIVE)|$(lex SPEC_OBSOLETE)" '
        $0 ~ ("^\\*\\*" lib "[ \t]*:") {
            ligne = $0
            if (match(ligne, "(" motif ")")) { print substr(ligne, RSTART, RLENGTH); exit }
        }' "$1"
}

# --- État par domaine -------------------------------------------------------
ETATS=""
for f in ${FICHIERS}; do
    dom="${f##*/}"; dom="${dom%.md}"
    if ! lex_est SPEC_ACTIVE "$(statut_domaine "${f}")"; then
        etat="${ETAT_SANS_OBJET}"
    else
        dt="$(calc_dues_tenues "${f}")"
        dues="${dt%% *}"
        tenues="${dt##* }"
        if [ "${dues}" -eq 0 ]; then
            etat="${ETAT_HORS_MESURE}"
        elif [ "${tenues}" -eq "${dues}" ]; then
            # « implémentée » prime sur « planifiée » : testé avant toute
            # citation de la feuille de route (cf. en-tête).
            etat="${ETAT_IMPLEMENTEE}"
        elif [ "${tenues}" -gt 0 ]; then
            etat="${ETAT_EN_COURS}"
        elif domaine_est_cite "${f}"; then
            etat="${ETAT_PLANIFIEE}"
        else
            etat="${ETAT_A_PLANIFIER}"
        fi
    fi
    ETATS="${ETATS}${dom}	${etat}
"
done

# --- Régénération du tableau, en place -------------------------------------
# Domaine (1re colonne, lien vers <domaine>.md) et Statut sont reconstruits
# depuis les mêmes sources de vérité ; Objet, seule colonne sans source
# calculée, est repris tel quel depuis le fichier lu — jamais inventé.
rendre_readme() {
    awk -v etats="${ETATS}" -v lib_av="${LIB_AVANCEMENT}" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        BEGIN {
            n = split(etats, lignes, "\n")
            for (i = 1; i <= n; i++) {
                if (lignes[i] == "") continue
                split(lignes[i], c, "\t")
                etat[c[1]] = c[2]
            }
            phase = 0
        }
        phase == 0 && /^\|/ && ($0 ~ /Domaine/ || $0 ~ /Domain/) {
            printf "| Domaine | Statut | %s | Objet |\n", lib_av
            phase = 1
            next
        }
        phase == 1 {
            if ($0 !~ /^\|[ \t]*-/) {
                print "ERREUR : ligne de separation de tableau introuvable." > "/dev/stderr"
                exit 1
            }
            print "| --- | --- | --- | --- |"
            phase = 2
            next
        }
        phase == 2 && /^\|/ {
            m = split($0, cell, "|")
            dom = cell[2]
            sub(/^[^][]*\[[^]]*\]\(/, "", dom); sub(/\.md\).*$/, "", dom)
            dom = trim(dom)
            statut_c = trim(cell[3])
            objet_c = (m >= 6) ? trim(cell[m - 1]) : trim(cell[4])
            e = (dom in etat) ? etat[dom] : "ERREUR-DOMAINE-INCONNU"
            printf "| [%s](%s.md) | %s | %s | %s |\n", dom, dom, statut_c, e, objet_c
            next
        }
        phase == 2 { phase = 3 }
        { print }
    '
}

SUFFIXE="verif"
[ "${ECRIRE}" -eq 1 ] && SUFFIXE="tmp"
SORTIE="${INDEX}.${SUFFIXE}"

if ! rendre_readme < "${INDEX}" > "${SORTIE}"; then
    rm -f "${SORTIE}"
    echo "ÉCHEC : régénération du tableau — format inattendu dans ${INDEX}." >&2
    exit 1
fi

if grep -q 'ERREUR-DOMAINE-INCONNU' "${SORTIE}" 2>/dev/null; then
    rm -f "${SORTIE}"
    echo "ÉCHEC : ${INDEX} — une ligne du tableau cite un domaine sans fichier correspondant." >&2
    exit 1
fi

if [ "${ECRIRE}" -eq 1 ]; then
    mv "${SORTIE}" "${INDEX}"
    echo "Avancement des domaines régénéré : ${INDEX}"
else
    if cmp -s "${SORTIE}" "${INDEX}"; then
        rm -f "${SORTIE}"
        echo "Avancement des domaines : OK."
    else
        rm -f "${SORTIE}"
        echo "ÉCHEC : ${INDEX} — colonne Avancement périmée : exécuter « sh tools/avancement.sh --ecrire »." >&2
        exit 1
    fi
fi
