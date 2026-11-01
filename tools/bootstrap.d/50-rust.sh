# Module bootstrap — Rust : cargo (rustup), cargo-nextest, cargo-sweep, et la
# [impl->req~chaine-de-verification-du-moteur~1]
# chaîne épinglée du dépôt (rust-toolchain.toml).
# MODÈLE à copier dans tools/bootstrap.d/ d'un projet instancié, puis à
# taguer vers l'ADR technologique du projet qui le justifie (R2) ; l'hygiène
# des artefacts relève des exigences `req~hygiene-artefacts-compilation~1`
# et `req~confinement-artefacts-worktree~1` du gabarit, à reprendre dans la
# spécification du projet.
# Contrat : sourcé par tools/bootstrap.sh, PHASE=annonce puis PHASE=verifie
# (voir l'en-tête de bootstrap.sh pour les variables et aides disponibles).
case "${PHASE}" in
    annonce)
        echo "    - Rust (cargo)      — compilation ; cargo-nextest (tests), cargo-sweep (hygiène du cache)"
        ;;
    verifie)
        # rustup n'est dans aucun dépôt apt/dnf utile : https://rustup.rs
        verifier "Rust (cargo)" cargo "" "" "rustup" "Rustlang.Rustup" \
            "installer rustup (https://rustup.rs), puis relancer --verifie ; la chaîne vient de rust-toolchain.toml"

        if ! command -v cargo >/dev/null 2>&1; then
            echo "  → cargo-nextest, cargo-sweep et la chaîne épinglée ne sont pas vérifiables sans cargo"
        else
            # Outils cargo : installables par cargo lui-même, quelle que soit
            # la plateforme — on n'attend pas le gestionnaire de paquets. Un
            # manquant est compté comme tel AVANT toute installation, comme
            # le fait verifier() : le bilan dit alors ce qui a été installé.
            # Les noms se composent (« cargo-${nom} ») : écrits en toutes
            # lettres sur la ligne du for, ils ressemblaient à un appel de
            # test pour la porte d'hygiène de compilation (constaté sur un
            # projet instancié).
            for nom in nextest sweep; do
                outil="cargo-${nom}"
                if command -v "${outil}" >/dev/null 2>&1; then
                    echo "ok — ${outil}"
                    continue
                fi
                echo "MANQUANT — ${outil} (cargo install --locked ${outil})"
                MANQUANTS=$((MANQUANTS + 1))
                ABSENTS="${ABSENTS} ${outil}"
                if [ "${INSTALLE}" -eq 1 ]; then
                    cargo install --locked "${outil}" \
                        || { echo "  → échec de cargo install ${outil}" ; AVERTISSEMENTS=$((AVERTISSEMENTS + 1)) ; }
                else
                    echo "  → manquant (installation non demandée)"
                fi
            done

            # Chaîne épinglée : sans elle chaque changement de rustc duplique
            # les artefacts (porte tools/hygiene-compilation.sh du gabarit,
            # qui juge aussi le canal : une version exacte, pas « stable »).
            if [ -f "${RACINE}/rust-toolchain.toml" ] || [ -f "${RACINE}/rust-toolchain" ]; then
                echo "ok — chaîne de compilation épinglée"
            else
                echo "AVERTISSEMENT — rust-toolchain.toml absent : la chaîne n'est pas épinglée"
                AVERTISSEMENTS=$((AVERTISSEMENTS + 1))
            fi

            # Cache de compilation hors du dépôt (target-dir partagé ou
            # déplacé par le poste) : le signaler, car les chemins ./target
            # en dur deviennent muets (méthode, ch. 4). La vérification
            # effective est faite par tools/rust.sh garde avant chaque build.
            # Sans accord d'installation, rustup ne doit pas installer la
            # chaîne épinglée à cette occasion (ADR-0014 : --verifie
            # n'installe jamais) : RUSTUP_AUTO_INSTALL=0.
            if [ "${INSTALLE}" -eq 1 ]; then auto=1; else auto=0; fi
            cible="$(RUSTUP_AUTO_INSTALL="${auto}" cargo metadata --format-version 1 --no-deps \
                        --manifest-path "${RACINE}/Cargo.toml" 2>/dev/null \
                | tr ',' '\n' | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p' | head -1)"
            case "${cible}" in
                "")             echo "note — emplacement des artefacts non résolu (chaîne absente ou manifeste invalide)" ;;
                "${RACINE}"/*)  echo "ok — artefacts dans le dépôt (${cible#"${RACINE}"/})" ;;
                *)              echo "note — artefacts hors du dépôt : ${cible} (cache déplacé par le poste ; voir tools/rust.sh garde)" ;;
            esac
        fi
        ;;
esac
