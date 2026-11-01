#!/bin/sh
# Test de la porte d'hygiène des artefacts de compilation, sur ses cas
# d'échec (R3) et de passage, critère par critère : dépôt sans Cargo ;
# chaîne absente, non suivie par git, flottante (« stable ») ou exacte ;
# tests Cargo sans réglage (cargo test, nextest, llvm-cov, tarpaulin,
# cargo +nightly test, $(CARGO) test), réglage en commentaire seulement,
# réglage dans une autre recette après l'appel ; réglage sur la ligne, export
# en amont, formes idiomatiques (YAML env:, GitLab variables:, just :=),
# réglage natif .cargo/config.toml ; appel en commentaire ou dans un echo
# ignoré ; message qui nomme le fichier et la ligne. POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"
prepare() {  # dépôt git jetable avec un Cargo.toml et une chaîne exacte suivie
    rm -rf "${D}"
    mkdir -p "${D}/tools"
    cp "${ROOT}/tools/hygiene-compilation.sh" "${D}/tools/"
    printf '[package]\nname = "x"\nversion = "0.1.0"\n' > "${D}/Cargo.toml"
    printf '[toolchain]\nchannel = "1.95.0"\n' > "${D}/rust-toolchain.toml"
    ( cd "${D}" && git init -q && git add Cargo.toml rust-toolchain.toml \
        && git -c user.name=t -c user.email=t@t commit -q -m init )
}
porte() { (cd "${D}" && sh tools/hygiene-compilation.sh >/dev/null 2>&1); }
sortie() { (cd "${D}" && sh tools/hygiene-compilation.sh 2>&1 || true); }
attend_echec() {  # $1 libellé, $2 motif attendu dans la sortie
    if porte; then echo "ÉCHEC [$1] : la porte passe" >&2 ; fail=1
    elif ! sortie | grep -qE "$2"; then echo "ÉCHEC [$1] : le message ne dit pas « $2 »" >&2 ; fail=1 ; fi
}
attend_passage() { if ! porte; then echo "ÉCHEC [$1] : la porte échoue — $(sortie | grep ÉCHEC | head -1)" >&2 ; fail=1 ; fi ; }

echo "hygiene-test — [A] sans manifeste Cargo : rien à juger, la porte passe et le dit"
prepare ; rm "${D}/Cargo.toml"
attend_passage A
if ! sortie | grep -q "rien à vérifier"; then echo "ÉCHEC [A] : la porte ne dit pas qu'elle n'a rien à juger" >&2 ; fail=1 ; fi

echo "hygiene-test — [B] chaîne absente : échoue en nommant le manque"
prepare ; rm "${D}/rust-toolchain.toml"
attend_echec B "rust-toolchain.toml absent"

echo "hygiene-test — [B2] chaîne présente mais non suivie par git : échoue"
prepare ; ( cd "${D}" && git rm -q --cached rust-toolchain.toml )
attend_echec B2 "pas suivi par git"

echo "hygiene-test — [B3] canal flottant « stable » : échoue (constat de revue n° 2)"
prepare ; printf '[toolchain]\nchannel = "stable"\n' > "${D}/rust-toolchain.toml"
attend_echec B3 "flottant"

echo "hygiene-test — [B4] canal daté nightly-AAAA-MM-JJ et fichier hérité rust-toolchain : passent"
prepare ; printf '[toolchain]\nchannel = "nightly-2026-10-01"\n' > "${D}/rust-toolchain.toml"
attend_passage B4
prepare ; rm "${D}/rust-toolchain.toml" ; printf '1.95.0\n' > "${D}/rust-toolchain"
( cd "${D}" && git add rust-toolchain && git -c user.name=t -c user.email=t@t commit -q -m t )
attend_passage B4

echo "hygiene-test — [C] appels sans réglage : échouent en nommant fichier et ligne"
for appel in 'cargo test --workspace' 'cargo nextest run --workspace' 'cargo llvm-cov --workspace' \
             'cargo tarpaulin' 'cargo +nightly test' 'cargo --locked test' '$(CARGO) test' 'cargo-nextest nextest run'; do
    prepare ; printf 'test:\n    %s\n' "${appel}" > "${D}/justfile"
    attend_echec "C ${appel}" '^    2:'
    if ! sortie | grep -q "ÉCHEC : justfile"; then echo "ÉCHEC [C ${appel}] : le fichier fautif n'est pas nommé" >&2 ; fail=1 ; fi
done

echo "hygiene-test — [C2] réglage en commentaire seulement : échoue (constat de revue n° 3a)"
prepare ; printf '#!/bin/sh\n# CARGO_INCREMENTAL=0 à faire\ncargo test --workspace\n' > "${D}/tools/ci.sh"
attend_echec C2 "tools/ci.sh"

echo "hygiene-test — [C3] réglage sur une autre recette, après l'appel nu : échoue (constat n° 3b)"
prepare ; printf 'test:\n    cargo test --workspace\nbuild:\n    CARGO_INCREMENTAL=0 cargo build\n' > "${D}/justfile"
attend_echec C3 "justfile"

echo "hygiene-test — [D] réglage sur la ligne : passe"
prepare ; printf 'test:\n    CARGO_INCREMENTAL=0 cargo nextest run --workspace\n' > "${D}/justfile"
attend_passage D

echo "hygiene-test — [E] export en amont dans le même script : passe"
prepare ; printf '#!/bin/sh\nexport CARGO_INCREMENTAL=0\ncargo test --workspace\ncargo llvm-cov --workspace\n' > "${D}/tools/ci.sh"
attend_passage E

echo "hygiene-test — [E2] formes idiomatiques : GitHub env:, GitLab variables:, just :=, guillemets (constat n° 4)"
prepare ; mkdir -p "${D}/.github/workflows"
printf 'env:\n  CARGO_INCREMENTAL: 0\njobs:\n  t:\n    steps:\n      - run: cargo test --workspace\n' > "${D}/.github/workflows/ci.yml"
attend_passage "E2 github"
prepare ; printf 'variables:\n  CARGO_INCREMENTAL: "0"\ntest:\n  script:\n    - cargo nextest run\n' > "${D}/.gitlab-ci.yml"
attend_passage "E2 gitlab"
prepare ; printf 'export CARGO_INCREMENTAL := "0"\n\ntest:\n    cargo test --workspace\n' > "${D}/justfile"
attend_passage "E2 just"
prepare ; printf '#!/bin/sh\nexport CARGO_INCREMENTAL="0"\ncargo tarpaulin\n' > "${D}/tools/cov.sh"
attend_passage "E2 guillemets"

echo "hygiene-test — [E3] réglage natif .cargo/config.toml : passe pour tout le dépôt"
prepare ; mkdir -p "${D}/.cargo" ; printf '[build]\nincremental = false\n' > "${D}/.cargo/config.toml"
printf 'test:\n    cargo test --workspace\n' > "${D}/justfile"
attend_passage E3

echo "hygiene-test — [F] appel en commentaire ou cité par echo/printf : ignoré, la porte passe"
prepare ; printf '#!/bin/sh\n# exemple : cargo test --workspace\necho "lancer cargo test"\nprintf "%%s" "cargo nextest run"\n' > "${D}/tools/ci.sh"
attend_passage F
if ! sortie | grep -q "aucune commande de test"; then echo "ÉCHEC [F] : des appels inertes ont été comptés" >&2 ; fail=1 ; fi

echo "hygiene-test — [G] couverture sans réglage dans la CI GitHub et Gitea : échoue"
prepare ; mkdir -p "${D}/.github/workflows" "${D}/.gitea/workflows"
printf 'jobs:\n  tests:\n    steps:\n      - run: cargo llvm-cov --workspace\n' > "${D}/.github/workflows/ci.yml"
attend_echec "G github" ".github/workflows/ci.yml"
prepare ; mkdir -p "${D}/.gitea/workflows"
printf 'jobs:\n  tests:\n    steps:\n      - run: cargo test\n' > "${D}/.gitea/workflows/ci.yml"
attend_echec "G gitea" ".gitea/workflows/ci.yml"

echo "hygiene-test — [H] 'cargo tree' et 'cargo build' ne sont pas des appels de test"
prepare ; printf 'arbre:\n    cargo tree\nbuild:\n    cargo build --release\n' > "${D}/justfile"
attend_passage H


echo "hygiene-test — [I] matériel du gabarit copié dans le projet (kit Rust, module bootstrap, ce test) : passe sans réglage natif"
prepare ; mkdir -p "${D}/tools/bootstrap.d"
cp "${ROOT}/tools/hygiene-compilation-test.sh" "${D}/tools/"
cp "${ROOT}/templates/bootstrap.d/50-rust.sh" "${D}/tools/bootstrap.d/"
cp "${ROOT}/templates/bootstrap.d/rust/rust.sh" "${D}/tools/rust.sh"
attend_passage I
if [ "${fail}" -ne 0 ]; then
    echo "hygiene-test : ÉCHEC." >&2
    exit 1
fi
echo "hygiene-test : OK."
