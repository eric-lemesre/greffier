// SPDX-License-Identifier: EUPL-1.2
//! Plusieurs dépôts de savoir, clients à portée, configuration par fichier
//! et journal du service, de bout en bout : `greffier servir` lancé sur des
//! dépôts jetables au contenu fictif, interrogé en HTTP, son journal lu sur
//! sa sortie d'erreur.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    missing_docs
)]

use std::fs;
use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStderr, Command, Stdio};

use serde_json::Value;

const JETON: &str = "jeton-fictif-du-lecteur-0123456789";
const AUTRE_JETON: &str = "jeton-fictif-de-l-environnement-9876";

/// Un dossier jetable : deux dépôts de savoir et un fichier de
/// configuration.
struct Banc(PathBuf);

impl Banc {
    fn new(nom: &str) -> Self {
        let racine = std::env::temp_dir().join(format!(
            "greffier-savoirs-itest-{nom}-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&racine);
        let banc = Self(racine);
        banc.ecrire(
            "a/raw/textes/LEGIARTI000000000002@2016-10-01.md",
            "---\nidentifiant: LEGIARTI000000000002\ncid: LEGIARTI000000000001\nintitule: \"Code civil, article 673\"\nsource: https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000002\netat: VIGUEUR\nen_vigueur: 2016-10-01 / —\ncapture_le: 2026-11-01\n---\n\nLes branches des arbres du voisin peuvent être coupées.\n",
        );
        banc.ecrire(
            "b/raw/textes/LEGIARTI000000000004@2019-01-01.md",
            "---\nidentifiant: LEGIARTI000000000004\ncid: LEGIARTI000000000003\nintitule: \"Code de procédure civile, article 820\"\nsource: https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000004\netat: VIGUEUR\nen_vigueur: 2019-01-01 / —\ncapture_le: 2026-11-01\n---\n\nLa conciliation peut être tentée hors de toute instance.\n",
        );
        banc
    }

    fn ecrire(&self, relatif: &str, contenu: &str) {
        let chemin = self.0.join(relatif);
        fs::create_dir_all(chemin.parent().unwrap()).unwrap();
        fs::write(chemin, contenu).unwrap();
    }

    /// Écrit la configuration avec le mode donné ; rend son chemin.
    fn configuration(&self, contenu: &str, mode: u32) -> PathBuf {
        let chemin = self.0.join("greffier.toml");
        let contenu = contenu
            .replace("{A}", &self.0.join("a").to_string_lossy())
            .replace("{B}", &self.0.join("b").to_string_lossy());
        fs::write(&chemin, contenu).unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&chemin, fs::Permissions::from_mode(mode)).unwrap();
        }
        #[cfg(not(unix))]
        let _ = mode;
        chemin
    }
}

impl Drop for Banc {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

/// `greffier` sans aucun réglage hérité du poste.
fn greffier() -> Command {
    let mut commande = Command::new(env!("CARGO_BIN_EXE_greffier"));
    for (variable, _) in std::env::vars() {
        if variable.starts_with("GREFFIER_") || variable == "JOURNAL_STREAM" {
            commande.env_remove(variable);
        }
    }
    commande
}

/// `greffier --config <fichier>`, à l'écoute d'un port libre de la boucle
/// locale par l'environnement.
fn avec_configuration(config: &Path) -> Command {
    let mut commande = greffier();
    commande
        .arg("--config")
        .arg(config)
        .env("GREFFIER_ECOUTE", "127.0.0.1:0");
    commande
}

/// Un `greffier servir` en cours : son adresse, et sa sortie d'erreur
/// pour lire le journal.
struct Serveur {
    processus: Child,
    base: String,
    journal: BufReader<ChildStderr>,
    lu: String,
}

impl Serveur {
    /// Lance `servir` (avec ses options propres) sur la commande préparée.
    fn lancer(mut commande: Command, options: &[&str]) -> Self {
        commande
            .arg("servir")
            .args(options)
            .stdout(Stdio::null())
            .stderr(Stdio::piped());
        let mut processus = commande.spawn().unwrap();
        let mut journal = BufReader::new(processus.stderr.take().unwrap());
        let mut lu = String::new();
        let base = loop {
            let mut ligne = String::new();
            assert!(
                journal.read_line(&mut ligne).unwrap() > 0,
                "le serveur s'est arrêté : {lu}"
            );
            lu.push_str(&ligne);
            if let Some(adresse) = ligne
                .split("http://")
                .nth(1)
                .and_then(|reste| reste.split('/').next())
            {
                break format!("http://{adresse}");
            }
        };
        Self {
            processus,
            base,
            journal,
            lu,
        }
    }

    /// Arrête le serveur et rend tout son journal.
    fn arreter(mut self) -> String {
        let _ = self.processus.kill();
        let _ = self.journal.read_to_string(&mut self.lu);
        let _ = self.processus.wait();
        self.lu
    }
}

fn agent() -> ureq::Agent {
    ureq::Agent::config_builder()
        .http_status_as_error(false)
        .build()
        .into()
}

fn get(url: &str, jeton: Option<&str>) -> (u16, String) {
    let mut requete = agent().get(url);
    if let Some(jeton) = jeton {
        requete = requete.header("Authorization", &format!("Bearer {jeton}"));
    }
    let mut reponse = requete.call().unwrap();
    let statut = reponse.status().as_u16();
    (statut, reponse.body_mut().read_to_string().unwrap())
}

const DEUX_DEPOTS_UN_LECTEUR: &str = "[savoirs]\na = \"{A}\"\nb = \"{B}\"\n\n\
    [[client]]\nnom = \"lecteur\"\njeton = \"jeton-fictif-du-lecteur-0123456789\"\nsavoirs = [\"a\"]\n";

// [itest->req~savoirs-multiples~1]
// [itest->req~jetons-a-portee~1]
#[test]
fn un_client_ne_lit_que_les_depots_de_sa_portee() {
    let banc = Banc::new("portee");
    let config = banc.configuration(DEUX_DEPOTS_UN_LECTEUR, 0o600);
    let serveur = Serveur::lancer(avec_configuration(&config), &[]);
    let base = serveur.base.clone();

    let (statut, corps) = get(&format!("{base}/savoirs"), Some(JETON));
    assert_eq!(statut, 200, "{corps}");
    let liste: Value = serde_json::from_str(&corps).unwrap();
    assert_eq!(liste["savoirs"], serde_json::json!(["a"]));

    let (statut, corps) = get(
        &format!("{base}/savoirs/a/recherche?question=couper%20branches&le=2020-05-05"),
        Some(JETON),
    );
    assert_eq!(statut, 200, "{corps}");
    assert!(corps.contains("LEGIARTI000000000002"));
    assert!(!corps.contains("LEGIARTI000000000004"));

    // Hors portée : la même réponse qu'un dépôt inconnu.
    let hors_portee = get(
        &format!("{base}/savoirs/b/recherche?question=conciliation"),
        Some(JETON),
    );
    let inconnu = get(
        &format!("{base}/savoirs/zz/recherche?question=conciliation"),
        Some(JETON),
    );
    assert_eq!(hors_portee.0, 404);
    assert_eq!(hors_portee, inconnu);
    assert!(!hors_portee.1.contains("LEGIARTI000000000004"));
    assert_eq!(get(&format!("{base}/savoirs/b/mcp"), Some(JETON)).0, 404);
    assert_eq!(
        get(
            &format!("{base}/savoirs/b/textes/LEGIARTI000000000004"),
            Some(JETON)
        )
        .0,
        404
    );

    // Sans jeton, ou avec un jeton inconnu : 401, rien du savoir.
    let (statut, corps) = get(
        &format!("{base}/savoirs/a/recherche?question=branches"),
        None,
    );
    assert_eq!(statut, 401);
    assert!(!corps.contains("LEGIARTI"));
    assert_eq!(
        get(&format!("{base}/savoirs"), Some("jeton-inconnu")).0,
        401
    );
    assert_eq!(get(&format!("{base}/sante"), None).0, 200);
    let journal = serveur.arreter();
    assert!(!journal.contains(JETON), "{journal}");
}

// [itest->req~savoirs-multiples~1]
#[test]
fn le_depot_par_defaut_reste_servi_sous_les_routes_de_la_0_2_0() {
    let banc = Banc::new("defaut");
    let config = banc.configuration("[savoirs]\nb = \"{B}\"\n", 0o644);
    let mut commande = avec_configuration(&config);
    commande.env("GREFFIER_SAVOIR", banc.0.join("a"));
    let serveur = Serveur::lancer(commande, &[]);
    let base = serveur.base.clone();
    let (statut, corps) = get(
        &format!("{base}/recherche?question=couper%20branches&le=2020-05-05"),
        None,
    );
    assert_eq!(statut, 200, "{corps}");
    assert!(corps.contains("LEGIARTI000000000002"));
    let (statut, corps) = get(
        &format!("{base}/savoirs/defaut/recherche?question=branches&le=2020-05-05"),
        None,
    );
    assert_eq!(statut, 200, "{corps}");
    let (statut, corps) = get(
        &format!("{base}/savoirs/b/recherche?question=conciliation"),
        None,
    );
    assert_eq!(statut, 200, "{corps}");
    assert!(corps.contains("LEGIARTI000000000004"));
    let (_, corps) = get(&format!("{base}/savoirs"), None);
    assert!(
        corps.contains("\"b\"") && corps.contains("\"defaut\""),
        "{corps}"
    );
    serveur.arreter();
}

// [itest->req~configuration-environnement-et-fichier~1]
#[test]
fn un_fichier_a_secret_lisible_par_tous_empeche_le_demarrage() {
    let banc = Banc::new("expose");
    let config = banc.configuration(DEUX_DEPOTS_UN_LECTEUR, 0o644);
    let sortie = greffier()
        .arg("--config")
        .arg(&config)
        .args(["servir", "--ecoute", "127.0.0.1:0"])
        .output()
        .unwrap();
    let erreur = String::from_utf8_lossy(&sortie.stderr);
    if cfg!(unix) {
        assert_eq!(sortie.status.code(), Some(1), "{erreur}");
        assert!(erreur.contains(config.to_str().unwrap()), "{erreur}");
        assert!(erreur.contains("lisible"), "{erreur}");
    }
    assert!(!erreur.contains(JETON), "{erreur}");
}

// [itest->req~configuration-environnement-et-fichier~1]
// [itest->req~jetons-a-portee~1]
#[test]
fn un_fichier_d_empreintes_lisible_par_tous_suffit() {
    let banc = Banc::new("empreinte");
    // sha256 de « jeton-fictif-du-lecteur-0123456789 »
    let empreinte = sha256_hex(JETON);
    let config = banc.configuration(
        &format!(
            "[savoirs]\na = \"{{A}}\"\n\n[[client]]\nnom = \"lecteur\"\nempreinte = \"sha256:{empreinte}\"\nsavoirs = [\"*\"]\n"
        ),
        0o644,
    );
    let serveur = Serveur::lancer(avec_configuration(&config), &[]);
    assert_eq!(
        get(
            &format!("{}/savoirs/a/recherche?question=branches", serveur.base),
            Some(JETON)
        )
        .0,
        200
    );
    serveur.arreter();
}

// [itest->req~jetons-a-portee~1]
#[test]
fn l_environnement_l_emporte_sur_le_fichier_et_le_journal_le_dit() {
    let banc = Banc::new("remplace");
    let config = banc.configuration(&DEUX_DEPOTS_UN_LECTEUR.replace("lecteur", "pacilia"), 0o600);
    let mut commande = avec_configuration(&config);
    commande
        .env("GREFFIER_JETON_PACILIA", AUTRE_JETON)
        .env("GREFFIER_SAVOIRS_PACILIA", "b");
    let serveur = Serveur::lancer(commande, &[]);
    let base = serveur.base.clone();
    assert_eq!(
        get(
            &format!("{base}/savoirs/b/recherche?question=conciliation"),
            Some(AUTRE_JETON)
        )
        .0,
        200
    );
    assert_eq!(
        get(
            &format!("{base}/savoirs/a/recherche?question=branches"),
            Some(AUTRE_JETON)
        )
        .0,
        404
    );
    assert_eq!(
        get(
            &format!("{base}/savoirs"),
            Some(JETON.replace("lecteur", "pacilia").as_str())
        )
        .0,
        401
    );
    let journal = serveur.arreter();
    assert!(journal.contains("l'environnement l'emporte"), "{journal}");
    assert!(
        !journal.contains(AUTRE_JETON) && !journal.contains("jeton-fictif-du"),
        "{journal}"
    );
}

// [itest->req~configuration-environnement-et-fichier~1]
#[test]
fn l_option_l_emporte_sur_l_environnement_qui_l_emporte_sur_le_fichier() {
    let banc = Banc::new("priorite");
    // Écouter au-dehors sans client est refusé : chaque étage se voit à ce
    // que le serveur démarre ou non.
    let config = banc.configuration(
        "[serveur]\necoute = \"0.0.0.0:0\"\n[savoirs]\na = \"{A}\"\n",
        0o644,
    );
    let par_le_fichier = greffier()
        .arg("--config")
        .arg(&config)
        .arg("servir")
        .output()
        .unwrap();
    assert_eq!(par_le_fichier.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&par_le_fichier.stderr).contains("0.0.0.0"));

    // L'environnement l'emporte sur le fichier.
    Serveur::lancer(avec_configuration(&config), &[]).arreter();

    // L'option l'emporte sur l'environnement.
    let mut commande = greffier();
    commande
        .arg("--config")
        .arg(&config)
        .env("GREFFIER_ECOUTE", "0.0.0.0:0");
    Serveur::lancer(commande, &["--ecoute", "127.0.0.1:0"]).arreter();
}

// [itest->req~journal-du-service~1]
#[test]
fn le_journal_dit_qui_interroge_quoi_sans_jeton_ni_question() {
    let banc = Banc::new("journal");
    let config = banc.configuration(DEUX_DEPOTS_UN_LECTEUR, 0o600);
    let serveur = Serveur::lancer(avec_configuration(&config), &[]);
    let base = serveur.base.clone();
    let mut reponse = agent()
        .get(&format!(
            "{base}/savoirs/a/recherche?question=voisinage%20elagage%20tilleul&le=2020-05-05"
        ))
        .header("Authorization", &format!("Bearer {JETON}"))
        .header("X-Request-Id", "correlation-fictive-42")
        .call()
        .unwrap();
    assert_eq!(reponse.status().as_u16(), 200);
    assert_eq!(
        reponse.headers().get("x-request-id").unwrap(),
        "correlation-fictive-42"
    );
    let _ = reponse.body_mut().read_to_string();
    let refus = agent()
        .get(&format!("{base}/savoirs/a/recherche?question=tilleul"))
        .header("Authorization", "Bearer jeton-presente-mais-faux")
        .call()
        .unwrap();
    assert_eq!(refus.status().as_u16(), 401);
    assert!(refus.headers().get("x-request-id").is_some());

    let journal = serveur.arreter();
    let servie = journal
        .lines()
        .find(|l| l.contains("correlation-fictive-42") && l.contains("requête servie"))
        .unwrap_or_else(|| panic!("ligne de requête absente : {journal}"));
    for attendu in [
        "route=/savoirs/{nom}/recherche",
        "depot=\"a\"",
        "client=\"lecteur\"",
        "statut=200",
        "duree_ms=",
        "rendus=",
    ] {
        assert!(servie.contains(attendu), "« {attendu} » absent : {servie}");
    }
    let refuse = journal
        .lines()
        .find(|l| l.contains("greffier::acces") && l.contains("jeton inconnu"))
        .unwrap_or_else(|| panic!("refus absent : {journal}"));
    assert!(refuse.contains("WARN"), "{refuse}");
    for interdit in [
        JETON,
        "jeton-presente-mais-faux",
        "tilleul",
        "elagage",
        "voisinage",
    ] {
        assert!(
            !journal.contains(interdit),
            "« {interdit} » au journal : {journal}"
        );
    }
}

// [itest->req~journal-du-service~1]
#[test]
fn le_journal_au_format_json_est_une_suite_d_objets() {
    let banc = Banc::new("json");
    let mut commande = greffier();
    commande
        .env("GREFFIER_ECOUTE", "127.0.0.1:0")
        .env("GREFFIER_SAVOIR", banc.0.join("a"))
        .env("GREFFIER_JOURNAL_FORMAT", "json");
    let serveur = Serveur::lancer(commande, &[]);
    assert_eq!(
        get(
            &format!("{}/recherche?question=branches", serveur.base),
            None
        )
        .0,
        200
    );
    let journal = serveur.arreter();
    let lignes: Vec<&str> = journal.lines().filter(|l| !l.trim().is_empty()).collect();
    assert!(lignes.len() >= 2, "{journal}");
    for ligne in lignes {
        let objet: Value =
            serde_json::from_str(ligne).unwrap_or_else(|_| panic!("ligne non JSON : {ligne}"));
        assert!(objet["level"].is_string(), "{ligne}");
    }
}

/// L'empreinte SHA-256 hexadécimale d'un texte, par l'outil du système
/// (`sha256sum`), pour ne pas réécrire le calcul du moteur dans son test.
fn sha256_hex(texte: &str) -> String {
    let mut enfant = Command::new("sha256sum")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    use std::io::Write;
    enfant
        .stdin
        .take()
        .unwrap()
        .write_all(texte.as_bytes())
        .unwrap();
    let sortie = enfant.wait_with_output().unwrap();
    String::from_utf8(sortie.stdout)
        .unwrap()
        .split_whitespace()
        .next()
        .unwrap()
        .to_owned()
}
