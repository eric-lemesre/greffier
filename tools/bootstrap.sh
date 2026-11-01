#!/bin/sh
# [impl->req~onboarding-outille~2]
# « Scripts to Rule Them All » — bootstrap : amener les dépendances du projet.
# Flux consenti (ADR-0014) : ANNONCE ce qui sera vérifié, DEMANDE L'ACCORD,
# puis vérifie et n'installe que les manquants (un outil présent n'est jamais
# touché). Sans accord — refus ou entrée non interactive — vérification seule,
# et échec en NOMMANT les outils absents. Idempotent. POSIX sh strict.
#
#   sh tools/bootstrap.sh            # annonce → accord → vérifie → installe
#   sh tools/bootstrap.sh --oui      # sans question (accord donné d'avance)
#   sh tools/bootstrap.sh --verifie  # vérification seule, jamais d'installation
#
# ARCHITECTURE MODULAIRE : ce script est l'orchestrateur ; chaque outil vit
# dans son module `tools/bootstrap.d/NN-outil.sh`, sourcé deux fois —
# PHASE=annonce (sa ligne du plan) puis PHASE=verifie (contrôle, puis
# installation si accordée). Un module dispose des variables PLATEFORME,
# GESTIONNAIRE, INSTALLE, RACINE, des aides verifier()/installer() et des
# compteurs MANQUANTS/AVERTISSEMENTS.
#
# POINT D'EXTENSION du projet instancié : AJOUTER UN MODULE (jamais éditer ce
# script) — le préfixe NN fixe l'ordre, chaque module technologique est la
# section Vérification concrète d'un ADR du projet. Exemple :
#   tools/bootstrap.d/50-rust.sh  → vérifie cargo, installe rustup (ADR-00NN)
# Modules prêts à copier : templates/bootstrap.d/ (Rust : 50-rust.sh + kit
# rust/rust.sh ; Node.js 22+ ; lint Markdown).
# Si le poste utilise des caches partagés (CARGO_TARGET_DIR, store pnpm…),
# le documenter dans le module et bannir les chemins d'artefacts en dur —
# voir méthode, ch. 4, anti-pattern « outillage aveugle à son environnement ».
#
# PRÉREQUIS : git (sous Windows, le shell sh exécutant ce script arrive avec
# Git for Windows) — installable via tools/install-git.sh / install-git.ps1.
set -eu

OUTILS="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
RACINE="$(CDPATH= cd -- "${OUTILS}/.." && pwd)"
MODULES="${OUTILS}/bootstrap.d"

# --- Arguments ----------------------------------------------------------------
DEMANDE="accord"                 # accord | oui | verifie
case "${1:-}" in
    "")         DEMANDE="accord" ;;
    --oui|-y)   DEMANDE="oui" ;;
    --verifie)  DEMANDE="verifie" ;;
    *) echo "Usage : tools/bootstrap.sh [--oui|--verifie]" >&2 ; exit 2 ;;
esac

MANQUANTS=0
AVERTISSEMENTS=0

# --- Détection de la plateforme et du gestionnaire de paquets ------------------
case "$(uname -s)" in
    Linux)   PLATEFORME="linux" ;;
    Darwin)  PLATEFORME="macos" ;;
    MINGW*|MSYS*|CYGWIN*) PLATEFORME="windows" ;;
    *)       PLATEFORME="inconnue" ;;
esac

GESTIONNAIRE=""
if [ "${PLATEFORME}" = "linux" ]; then
    if command -v apt-get >/dev/null 2>&1; then GESTIONNAIRE="apt"
    elif command -v dnf >/dev/null 2>&1; then GESTIONNAIRE="dnf"
    fi
elif [ "${PLATEFORME}" = "macos" ]; then
    if command -v brew >/dev/null 2>&1; then GESTIONNAIRE="brew"; fi
elif [ "${PLATEFORME}" = "windows" ]; then
    if command -v winget.exe >/dev/null 2>&1; then GESTIONNAIRE="winget"; fi
fi

# --- Prérequis : git ------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
    echo "ÉCHEC : prérequis manquant — git. L'installer d'abord :" >&2
    echo "  Linux/macOS : sh tools/install-git.sh" >&2
    echo "  Windows     : powershell -ExecutionPolicy Bypass -File tools/install-git.ps1" >&2
    echo "  (dépôt récupérable sans git : archive d'export de la forge)" >&2
    exit 1
fi

# --- Aides (à disposition des modules) ------------------------------------------
installer() {
    # installer <libellé> <paquet apt> <paquet dnf> <formule brew> <id winget>
    _libelle="$1"; _apt="$2"; _dnf="$3"; _brew="$4"; _winget="$5"
    if [ "${INSTALLE}" -ne 1 ]; then
        echo "  → manquant (installation non demandée)"
        return 0
    fi
    case "${GESTIONNAIRE}" in
        apt)    [ -n "${_apt}" ] && { sudo apt-get install -y "${_apt}"; return 0; } ;;
        dnf)    [ -n "${_dnf}" ] && { sudo dnf install -y "${_dnf}"; return 0; } ;;
        brew)   [ -n "${_brew}" ] && { brew install "${_brew}"; return 0; } ;;
        winget) [ -n "${_winget}" ] && { winget.exe install --id "${_winget}" -e --accept-source-agreements --accept-package-agreements; return 0; } ;;
    esac
    echo "  → installation automatique indisponible pour ${_libelle} sur cette plateforme"
    AVERTISSEMENTS=$((AVERTISSEMENTS + 1))
}

verifier() {
    # verifier <libellé> <commande> <apt> <dnf> <brew> <winget> [note]
    _libelle="$1"; _cmd="$2"
    if command -v "${_cmd}" >/dev/null 2>&1; then
        echo "ok — ${_libelle}"
        return 0
    fi
    echo "MANQUANT — ${_libelle}"
    [ -n "${7:-}" ] && echo "  note : $7"
    MANQUANTS=$((MANQUANTS + 1))
    ABSENTS="${ABSENTS} ${_libelle%% *}"
    installer "${_libelle}" "$3" "$4" "$5" "$6"
}

ABSENTS=""

# --- 1. Annonce du plan (PHASE=annonce de chaque module) -------------------------
echo "Bootstrap du poste — socle du gabarit + modules du projet"
echo "Plateforme : ${PLATEFORME}$([ -n "${GESTIONNAIRE}" ] && echo " · installations via ${GESTIONNAIRE}")"
echo ""
echo "Ce script va VÉRIFIER la présence des outils suivants, et proposer"
echo "d'INSTALLER ceux qui manquent (un outil déjà présent n'est jamais touché) :"
echo ""
PHASE="annonce"
for MODULE in "${MODULES}"/*.sh; do
    . "${MODULE}"
done
echo ""
echo "  (git est déjà présent : $(git --version | cut -d' ' -f3). La façade"
echo "   « task » est optionnelle — ADR-0007 — et gitleaks se télécharge"
echo "   épinglé au premier tools/secrets.sh — ADR-0012.)"
echo ""

# --- 2. Accord de l'utilisateur ---------------------------------------------------
INSTALLE=0
case "${DEMANDE}" in
    oui)
        INSTALLE=1
        echo "Accord donné en ligne de commande (--oui) : les manquants seront installés."
        ;;
    verifie)
        echo "Mode --verifie : vérification seule, aucune installation."
        ;;
    accord)
        if [ -t 0 ]; then
            printf "Procéder aux vérifications, puis installer les outils manquants ? [o/N] "
            read -r REPONSE
            case "${REPONSE}" in
                o|O|oui|OUI|y|Y)
                    INSTALLE=1
                    echo "Accord enregistré : les manquants seront installés."
                    ;;
                *)
                    echo "Pas d'installation : vérification seule."
                    ;;
            esac
        else
            echo "Entrée non interactive : vérification seule (utilisez --oui pour installer)."
        fi
        ;;
esac
echo ""

# --- 3. Vérifications puis installations (PHASE=verifie de chaque module) ---------
PHASE="verifie"
for MODULE in "${MODULES}"/*.sh; do
    . "${MODULE}"
done

if ! command -v task >/dev/null 2>&1; then
    echo "note : la façade « task » n'est pas installée — optionnelle,"
    echo "les portes restent utilisables via sh tools/*.sh (ADR-0007)."
fi

# --- Bilan --------------------------------------------------------------------------
echo ""
if [ "${MANQUANTS}" -eq 0 ]; then
    echo "Bootstrap : socle et modules présents."
elif [ "${INSTALLE}" -ne 1 ]; then
    echo "ÉCHEC : outil(s) manquant(s) —${ABSENTS}." >&2
    echo "Relancer et accepter l'installation (ou : sh tools/bootstrap.sh --oui)." >&2
    exit 1
else
    echo "${MANQUANTS} outil(s) traité(s) ; ${AVERTISSEMENTS} nécessitant une action manuelle."
    echo "Contrôler l'état final : sh tools/bootstrap.sh --verifie"
fi
[ "${AVERTISSEMENTS}" -eq 0 ] || exit 3
