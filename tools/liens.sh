#!/bin/sh
# [impl->req~integrite-liens~1]
# Intégrité des liens internes de la documentation : chaque lien Markdown
# relatif DOIT atteindre un fichier suivi par git, et son ancre — quand il en
# porte une — un titre qui existe réellement dans le fichier visé.
#
# Pourquoi cette porte existe. Un lien mort ne casse aucun test : il envoie un
# lecteur dans le vide et lui laisse croire qu'un document existe. Cas fondateur
# (ergonomia, 2026-08-19) : trois documents de la branche principale ont renvoyé
# NEUF JOURS durant vers une spécification jamais versée — la pull request qui
# la portait avait été fermée, celle qui la citait fusionnée. Aucune porte n'a
# protesté. Sur un dépôt dont la documentation EST le produit, c'est un défaut
# de premier ordre.
#
# DEUX ANGLES MORTS, comblés d'emblée d'après le retour d'ergonomia du
# 2026-08-20 (FIX-#846) — ils se cumulaient exactement sur le même cas :
#
#   1. les fichiers de la forge (`.github/`, `.gitlab/`) n'étaient pas
#      parcourus, alors que gabarits d'issue et workflows citent la
#      documentation aussi sûrement qu'un document le fait ;
#   2. les URL absolues `https://<forge>/<org>/<dépôt>/blob/<ref>/<chemin>`
#      étaient rangées avec les liens externes, alors qu'elles désignent un
#      chemin de CE dépôt — et c'est la SEULE forme de lien dont disposent les
#      gabarits d'issue, qui ne savent pas faire de lien relatif.
#
# Ce que ça a coûté là-bas : un renommage de répertoire a tué seize renvois,
# dont la regex d'un workflow qui excluait les documents de procédure du
# déclencheur de retombée des lectures. Elle est restée verte tout en ne
# filtrant plus rien — et aurait vidé les positions de toutes les
# consultations ouvertes. Un contrôle qui ne regarde pas où vivent les liens
# ne protège personne.
#
#   sh tools/liens.sh            # verdict, code retour non nul si défaut
#
# POSIX sh + awk. Aucune dépendance hors du socle.
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

# L'index de référence est `git ls-files` : un lien ne vaut que s'il vise un
# fichier RÉELLEMENT versionné. Un fichier présent sur le poste mais jamais
# ajouté satisferait un test d'existence tout en étant invisible pour les
# autres — c'est le même angle mort que celui de la porte anti-dérive.
INDEX="$(mktemp)"
trap 'rm -f "${INDEX}"' EXIT INT TERM
git ls-files > "${INDEX}"

# Les modèles sont scannés comme le reste : ils contiennent de vrais renvois
# vers la méthode, et un modèle qui pointe dans le vide accueille chaque
# nouveau projet par un lien mort. Les fichiers de forge entrent par la même
# porte : un gabarit d'issue affiche ses liens à qui ouvre une demande, un
# workflow poste les siens en commentaire sur une issue.
SCAN="$(git ls-files '*.md' '.github/**' '.gitlab/**' | \
        grep -E '\.(md|yml|yaml)$' | sort -u)"
[ -n "${SCAN}" ] || { echo "Liens de documentation : aucun fichier à contrôler."; exit 0; }

# Couples org/dépôt des remotes : une URL « blob » qui les cite désigne un
# chemin de CE dépôt, pas une ressource externe. Sans remote, ces URL restent
# traitées comme externes — mieux vaut ne pas contrôler que produire des faux
# positifs sur les liens vers un autre dépôt.
# Le suffixe « .git » de l'URL de clone n'existe pas dans une URL « blob » :
# le retirer est ce qui fait correspondre les deux formes.
DEPOTS="$(git remote -v 2>/dev/null | \
          sed -n 's#^[^[:space:]]*[[:space:]]*[^[:space:]]*[/:]\([^/:]*\)/\([^/[:space:]]*\).*#\1/\2#p' | \
          sed 's/\.git$//' | sort -u | tr '\n' ' ')"

# shellcheck disable=SC2086 — la découpe en mots de SCAN est voulue.
awk -v index_file="${INDEX}" -v depots="${DEPOTS}" '
# --- URL « blob » : un chemin du dépôt déguisé en lien externe ---------------
# https://<forge>/<org>/<dépôt>/blob/<ref>/<chemin> désigne un fichier de CE
# dépôt dès lors que <org>/<dépôt> est un de ses remotes. Les gabarits
# d’issue n’ont pas d’autre forme de lien à leur disposition : les ignorer,
# c’est laisser leur documentation pourrir sans témoin.
function chemin_blob(url,    reste, i, n, parts, couple) {
    if (url !~ /^https?:\/\/[^\/]+\/[^\/]+\/[^\/]+\/blob\//) return ""
    # Une URL qui interpole une variable ne désigne aucun chemin fixe.
    if (url ~ /\$\{/ || url ~ /\$[A-Z_]/) return ""
    sub(/^https?:\/\/[^\/]+\//, "", url)
    n = split(url, parts, "/")
    if (n < 4) return ""
    couple = parts[1] "/" parts[2]
    if (index(" " depots " ", " " couple " ") == 0) return ""
    if (parts[3] != "blob") return ""
    reste = ""
    for (i = 5; i <= n; i++) reste = (reste == "" ? parts[i] : reste "/" parts[i])
    return reste
}

# --- Slug des ancres, règle GitHub ------------------------------------------
# Minuscules, ponctuation ASCII retirée, espaces en tirets. La ponctuation est
# retirée par ÉNUMÉRATION et non par classe négative : une classe [^a-z0-9-]
# mangerait aussi les octets UTF-8 des lettres accentuées, et « Vérification »
# ne trouverait plus son ancre.
function slug(s,    t) {
    t = s
    gsub(/`/, "", t)                       # code inline
    gsub(/\*\*|\*|__|_/, "", t)            # emphase
    gsub(/\]\([^)]*\)/, "", t)             # cible des liens dans les titres
    gsub(/\[|\]/, "", t)                   #   … et leurs crochets
    t = tolower(t)
    gsub(/[!"#$%&'"'"'()*+,.\/:;<=>?@\\^{|}~]/, "", t)
    # Ponctuation typographique française : GitHub la retire aussi. Remontée
    # depuis un projet instancié dont les titres emploient le tiret cadratin
    # (« 01 — Gestion… ») : sans cette ligne, chaque ancre vers eux est un
    # faux positif — et un contenu parenthésé non-lien (« (SIGLE) ») était
    # avalé par la règle précédente, alors que GitHub le garde.
    gsub(/—|–|«|»|…|'"'"'/, "", t)
    gsub(/^[ \t]+|[ \t]+$/, "", t)
    # Chaque espace devient UN tiret, sans fusion : GitHub transforme les
    # espaces un à un (« act — obligations » → « act--obligations »).
    gsub(/[ \t]/, "-", t)
    return t
}

function normalise(p,    parts, n, out, i, j) {
    # Résolution des « . » et « .. » sans toucher au disque.
    n = split(p, parts, "/")
    j = 0
    for (i = 1; i <= n; i++) {
        if (parts[i] == "" || parts[i] == ".") continue
        if (parts[i] == "..") { if (j > 0) j--; continue }
        out[++j] = parts[i]
    }
    p = ""
    for (i = 1; i <= j; i++) p = (p == "" ? out[i] : p "/" out[i])
    return p
}

# --- Passe 0 : index des chemins versionnés ---------------------------------
FILENAME == index_file {
    FICHIERS[$0] = 1
    # Tout préfixe de répertoire est une cible de lien légitime.
    chemin = $0
    while (match(chemin, /\/[^\/]*$/)) {
        chemin = substr(chemin, 1, RSTART - 1)
        REPS[chemin] = 1
    }
    next
}

# --- Passe 1 : titres (pour les ancres) et liens ----------------------------
# Les conventions Markdown — clôtures de bloc de code, titres — n’ont pas
# cours dans un YAML : un « # commentaire » y serait pris pour un titre et
# polluerait la table des ancres.
FNR == 1 { dans_bloc = 0; est_md = (FILENAME ~ /\.md$/) }

est_md && /^[ \t]*(```|~~~)/ { dans_bloc = !dans_bloc; next }
dans_bloc { next }

est_md && /^#{1,6}[ \t]+/ {
    titre = $0
    sub(/^#{1,6}[ \t]+/, "", titre)
    a = slug(titre)
    ANCRES[FILENAME SUBSEP a] = 1
    # Titres homonymes : GitHub suffixe -1, -2… On enregistre les variantes
    # pour ne pas signaler un renvoi légitime vers le second homonyme.
    n = ++VUS[FILENAME SUBSEP a]
    if (n > 1) ANCRES[FILENAME SUBSEP a "-" (n - 1)] = 1
}

{
    ligne = $0
    # Chaque lien Markdown de la ligne : [texte](cible) et ![alt](cible).
    # Les parenthèses ÉQUILIBRÉES appartiennent à la cible : « fichier-(v2).md »
    # est un nom de fichier légitime. Une extraction qui rend les armes à la
    # première parenthèse le tronque puis le déclare mort — faux positif, soit
    # le défaut qui fait désactiver une porte (constat de revue n° 3).
    pos = 1
    while ((idx = index(substr(ligne, pos), "](")) > 0) {
        debut = pos + idx + 1
        prof = 1
        j = debut
        while (j <= length(ligne)) {
            ch = substr(ligne, j, 1)
            if (ch == "(") prof++
            else if (ch == ")") { prof--; if (prof == 0) break }
            else if (ch == " " || ch == "\t") break   # [x](cible "titre")
            j++
        }
        cible = (prof == 0) ? substr(ligne, debut, j - debut) : ""
        pos = j + 1
        if (cible == "") continue
        if (cible ~ /^(https?|mailto|ftp|tel):/) {
            interne = chemin_blob(cible)
            # Externe véritable : hors périmètre de cette porte.
            if (interne == "") continue
            LIENS[++nl] = FILENAME "\t" FNR "\t/" interne "\t" cible
            continue
        }
        LIENS[++nl] = FILENAME "\t" FNR "\t" cible "\t" cible
    }

    # URL « blob » écrites NUES — la forme qu’emploient les gabarits d’issue,
    # qui ne savent pas produire de lien Markdown relatif.
    ligne = $0
    while (match(ligne, /https?:\/\/[^ \t)"'"'"'<>]+/)) {
        url = substr(ligne, RSTART, RLENGTH)
        ligne = substr(ligne, RSTART + RLENGTH)
        gsub(/[.,;:]+$/, "", url)
        interne = chemin_blob(url)
        if (interne == "") continue
        LIENS[++nl] = FILENAME "\t" FNR "\t/" interne "\t" url
    }
}

# --- Verdict ----------------------------------------------------------------
END {
    defauts = 0
    for (i = 1; i <= nl; i++) {
        split(LIENS[i], c, "\t")
        source = c[1]; num = c[2]; cible = c[3]; brut = c[4]

        ancre = ""
        p = index(cible, "#")
        if (p > 0) { ancre = substr(cible, p + 1); cible = substr(cible, 1, p - 1) }

        if (cible == "") {          # renvoi interne au document
            fichier = source
        } else {
            base = source
            sub(/\/[^\/]*$/, "", base)
            if (base == source) base = ""            # fichier à la racine
            fichier = normalise(cible ~ /^\// ? cible : (base == "" ? cible : base "/" cible))
            if (!(fichier in FICHIERS)) {
                if (fichier in REPS) continue        # renvoi vers un répertoire
                printf "ÉCHEC : %s:%d — cible absente : %s\n", source, num, brut > "/dev/stderr"
                defauts++
                continue
            }
        }
        if (ancre == "") continue
        # Les ancres explicites (<a name="…">) et les cibles non-Markdown ne
        # se vérifient pas par les titres : on ne signale que ce qui est sûr.
        if (fichier !~ /\.md$/) continue
        if (!((fichier SUBSEP tolower(ancre)) in ANCRES)) {
            printf "ÉCHEC : %s:%d — ancre absente de %s : #%s\n", source, num, fichier, ancre > "/dev/stderr"
            defauts++
        }
    }
    if (defauts > 0) {
        printf "%d lien(s) mort(s).\n", defauts > "/dev/stderr"
        exit 1
    }
    printf "ok — %d lien(s) interne(s) vérifié(s)\n", nl
}
' "${INDEX}" ${SCAN}

echo "Liens de documentation : OK."
