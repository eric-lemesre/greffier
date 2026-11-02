#!/bin/sh
# Exigence servie : req~journal-du-service~1 — test de la porte reprise du gabarit alm-forge.
# Test de la porte de journalisation, sur ses cas d'échec (R3) et de
# passage, règle par règle : dépôt sans Cargo ; abonné installé dans une
# bibliothèque (chaîne d'appels sur plusieurs lignes, set_global_default,
# env_logger) mais admis dans main.rs, src/bin/ et un paquet sans lib.rs ;
# #[instrument] nu, sans skip_all, sur plusieurs lignes, avec skip_all ;
# secret en String dans un type Debug (champ, Option, nouveau type) ou dans
# un type sans Debug ; println!/dbg! dans une bibliothèque, dans main.rs ;
# commentaire et module de tests ignorés ; dérogation avec et sans raison ;
# mots de secret réglables ; message qui nomme le fichier et la ligne.
# POSIX sh strict.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT INT TERM
fail=0

D="${TMP}/depot"
prepare() {  # dépôt jetable : un paquet bibliothèque + binaire, sain
    rm -rf "${D}"
    mkdir -p "${D}/tools" "${D}/src"
    cp "${ROOT}/tools/journalisation.sh" "${D}/tools/"
    printf '[package]\nname = "x"\nversion = "0.1.0"\n' > "${D}/Cargo.toml"
    printf '//! x\npub fn f() {}\n' > "${D}/src/lib.rs"
    printf 'fn main() {}\n' > "${D}/src/main.rs"
}
porte() { (cd "${D}" && sh tools/journalisation.sh >/dev/null 2>&1); }
sortie() { (cd "${D}" && sh tools/journalisation.sh 2>&1 || true); }
attend_echec() {  # $1 libellé, $2 motif attendu dans la sortie
    if porte; then echo "ÉCHEC [$1] : la porte passe" >&2 ; fail=1
    elif ! sortie | grep -qE "$2"; then echo "ÉCHEC [$1] : le message ne dit pas « $2 »" >&2 ; fail=1 ; fi
}
attend_passage() { if ! porte; then echo "ÉCHEC [$1] : la porte échoue — $(sortie | grep ÉCHEC | head -1)" >&2 ; fail=1 ; fi ; }

echo "journalisation-test — [0] sans manifeste Cargo : rien à juger, la porte passe et le dit"
prepare ; rm "${D}/Cargo.toml"
attend_passage 0
if ! sortie | grep -q "rien à vérifier"; then echo "ÉCHEC [0] : la porte ne dit pas qu'elle n'a rien à juger" >&2 ; fail=1 ; fi

echo "journalisation-test — [0b] paquet sain : passe"
prepare
attend_passage 0b

echo "journalisation-test — [A] abonné installé dans une bibliothèque : échoue en nommant fichier et ligne"
prepare ; printf 'pub fn journal() {\n    tracing_subscriber::registry()\n        .with(fmt::layer())\n        .init();\n}\n' > "${D}/src/journal.rs"
attend_echec A 'src/journal.rs:4 — bibliothèque qui installe'
prepare ; printf 'pub fn j() { tracing::subscriber::set_global_default(s).ok(); }\n' > "${D}/src/journal.rs"
attend_echec A2 'src/journal.rs:1'
prepare ; printf 'pub fn j() { env_logger::init(); }\n' >> "${D}/src/lib.rs"
attend_echec A3 'src/lib.rs:3'

echo "journalisation-test — [A4] .init() sans abonné tracing (autre usage) : passe"
prepare ; printf 'pub fn j() { cache.init(); }\n' >> "${D}/src/lib.rs"
attend_passage A4

echo "journalisation-test — [A5] abonné dans main.rs, src/bin/, ou un paquet sans lib.rs : passe"
prepare ; printf 'fn main() {\n    tracing_subscriber::fmt().init();\n}\n' > "${D}/src/main.rs"
attend_passage A5
prepare ; mkdir -p "${D}/src/bin" ; printf 'fn main() { tracing_subscriber::fmt().init(); }\n' > "${D}/src/bin/outil.rs"
attend_passage A5b
prepare ; rm "${D}/src/lib.rs" ; printf 'pub fn j() { tracing_subscriber::fmt().init(); println!("ok"); }\n' > "${D}/src/journal.rs"
attend_passage A5c

echo "journalisation-test — [A6] paquet de l'espace de travail (crates/…) : examiné"
prepare ; mkdir -p "${D}/crates/y/src"
printf '[package]\nname = "y"\nversion = "0.1.0"\n' > "${D}/crates/y/Cargo.toml"
printf 'pub fn j() { tracing_subscriber::fmt().init(); }\n' > "${D}/crates/y/src/lib.rs"
attend_echec A6 'crates/y/src/lib.rs:1'

echo "journalisation-test — [B] #[instrument] sans skip_all : échoue"
for attr in '#[instrument]' '#[tracing::instrument]' '#[instrument(skip(self))]' '#[instrument(fields(depot = %d))]'; do
    prepare ; printf '%s\npub fn g(jeton: &str) {}\n' "${attr}" >> "${D}/src/lib.rs"
    attend_echec "B ${attr}" 'src/lib.rs:3 — #\[instrument\] sans skip_all'
done
prepare ; printf '#[instrument(\n    level = "debug",\n    fields(depot = %%d)\n)]\npub fn g() {}\n' >> "${D}/src/lib.rs"
attend_echec B2 'src/lib.rs:3'

echo "journalisation-test — [B3] #[instrument(skip_all…)] sur une ou plusieurs lignes, et dans main.rs : passe"
prepare ; printf '#[instrument(skip_all, fields(depot = %%d))]\npub fn g(jeton: &str) {}\n' >> "${D}/src/lib.rs"
attend_passage B3
prepare ; printf '#[instrument(\n    skip_all,\n    fields(depot = %%d)\n)]\npub fn g() {}\n' >> "${D}/src/lib.rs"
attend_passage B3b
prepare ; printf '#[instrument]\nfn main() {}\n' > "${D}/src/main.rs"
attend_echec B3c 'src/main.rs:1'

echo "journalisation-test — [C] secret en String dans un type qui dérive Debug : échoue"
prepare ; printf '#[derive(Debug, Clone)]\npub struct Reglages {\n    pub ecoute: String,\n    pub jeton: Option<String>,\n}\n' >> "${D}/src/lib.rs"
attend_echec C 'src/lib.rs:6 — secret en String'
prepare ; printf '#[derive(Debug)]\n#[serde(rename_all = "snake_case")]\npub struct Acces {\n    api_key: String,\n}\n' >> "${D}/src/lib.rs"
attend_echec C2 'src/lib.rs:6'
prepare ; printf '#[derive(Debug)]\npub struct JetonPorteur(pub String);\n' >> "${D}/src/lib.rs"
attend_echec C3 'src/lib.rs:4'
prepare ; printf '#[derive(Debug)]\npub struct Client {\n    password: std::string::String,\n}\n' > "${D}/src/main.rs"
attend_echec C4 'src/main.rs:3'

echo "journalisation-test — [C5] secret masqué par son type, type sans Debug, champ anodin : passe"
prepare ; printf '#[derive(Debug)]\npub struct Reglages {\n    pub jeton: Option<SecretString>,\n    pub nom: String,\n}\n#[derive(Clone)]\npub struct Brut {\n    pub token: String,\n}\n' >> "${D}/src/lib.rs"
attend_passage C5

echo "journalisation-test — [C6] mots de secret réglables (JOURNAL_MOTS_SECRETS)"
prepare ; printf '#[derive(Debug)]\npub struct R {\n    pub sesame: String,\n}\n' >> "${D}/src/lib.rs"
attend_passage C6
if (cd "${D}" && JOURNAL_MOTS_SECRETS='sesame' sh tools/journalisation.sh >/dev/null 2>&1); then
    echo "ÉCHEC [C6] : le mot réglé n'est pas reconnu" >&2 ; fail=1
fi

echo "journalisation-test — [D] diagnostic hors journal dans une bibliothèque : échoue"
for m in 'println!("x")' 'eprintln!("x")' 'dbg!(x)' 'print!("x")'; do
    prepare ; printf 'pub fn h() { %s; }\n' "${m}" >> "${D}/src/lib.rs"
    attend_echec "D ${m}" 'src/lib.rs:3 — diagnostic hors journal'
done

echo "journalisation-test — [D2] println! dans main.rs (sortie de commande) : passe"
prepare ; printf 'fn main() { println!("résultat"); }\n' > "${D}/src/main.rs"
attend_passage D2

echo "journalisation-test — [E] commentaires et module de tests ignorés"
prepare ; printf '// println!("x") et #[instrument] en commentaire\n/// ex. : tracing_subscriber::fmt().init();\n#[cfg(test)]\nmod tests {\n    #[test]\n    fn t() { tracing_subscriber::fmt().init(); println!("x"); dbg!(1); }\n}\n' >> "${D}/src/lib.rs"
attend_passage E

echo "journalisation-test — [F] dérogation : admise avec raison, refusée sans"
prepare ; printf '// journal: admis — sortie de la commande, consommée par un script\npub fn h() { println!("x"); }\n' >> "${D}/src/lib.rs"
attend_passage F
prepare ; printf 'pub fn h() { println!("x"); } // journal: admis — sortie de la commande\n' >> "${D}/src/lib.rs"
attend_passage F2
prepare ; printf '// journal: admis\npub fn h() { println!("x"); }\n' >> "${D}/src/lib.rs"
attend_echec F3 'src/lib.rs:4'

echo "journalisation-test — [G] hors git : un dossier caché (worktree d'agent) n'est pas examiné"
prepare ; mkdir -p "${D}/.claude/worktrees/w/src"
printf '[package]\nname = "w"\nversion = "0.1.0"\n' > "${D}/.claude/worktrees/w/Cargo.toml"
printf 'pub fn j() { println!("x"); }\n' > "${D}/.claude/worktrees/w/src/lib.rs"
attend_passage G

echo "journalisation-test — [G2] dans git : seuls les fichiers suivis comptent, chemins sans « ./ »"
prepare ; printf 'pub fn h() { println!("x"); }\n' > "${D}/src/brouillon.rs"
( cd "${D}" && git init -q && git add Cargo.toml src/lib.rs src/main.rs tools \
    && git -c user.name=t -c user.email=t@t commit -q -m init )
attend_passage G2
( cd "${D}" && git add src/brouillon.rs )
attend_echec G2b '^ÉCHEC : src/brouillon.rs:1'

if [ "${fail}" -ne 0 ]; then
    echo "journalisation-test : ÉCHEC." >&2
    exit 1
fi
echo "journalisation-test : OK."
