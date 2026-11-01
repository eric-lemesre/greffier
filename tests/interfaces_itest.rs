// SPDX-License-Identifier: EUPL-1.2
//! Les interfaces de bout en bout, sur un dépôt de savoir jetable au
//! contenu fictif : `greffier servir` interrogé en HTTP (routes, erreurs,
//! jeton) et `greffier mcp` piloté en JSON-RPC sur l'entrée et la sortie
//! standard.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    missing_docs
)]

use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};

use serde_json::{Value, json};

const JETON: &str = "jeton-fictif-de-test-0123456789";

struct Savoir(PathBuf);

impl Savoir {
    fn new(nom: &str) -> Self {
        let racine = std::env::temp_dir().join(format!(
            "greffier-interfaces-itest-{nom}-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&racine);
        let savoir = Self(racine);
        savoir.ecrire(
            "raw/textes/LEGIARTI000000000002@2016-10-01.md",
            "---\nidentifiant: LEGIARTI000000000002\ncid: LEGIARTI000000000001\nintitule: \"Code civil, article 673\"\nsource: https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000002\netat: VIGUEUR\nen_vigueur: 2016-10-01 / —\ncapture_le: 2026-11-01\n---\n\nLes branches des arbres du voisin peuvent être coupées.\n",
        );
        savoir.ecrire(
            "wiki/pratiques/sans-source.md",
            "---\ntype: pratique\n---\n\n# Branches\n\nCouper les branches soi-même.\n",
        );
        savoir
    }

    fn ecrire(&self, relatif: &str, contenu: &str) {
        let chemin = self.0.join(relatif);
        fs::create_dir_all(chemin.parent().unwrap()).unwrap();
        fs::write(chemin, contenu).unwrap();
    }
}

impl Drop for Savoir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

/// Un processus `greffier` arrêté à la fin du test.
struct Processus(Child);

impl Drop for Processus {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

/// Lance `greffier servir` sur un port libre ; rend le processus, l'adresse
/// de base et la première ligne de sa sortie d'erreur.
fn servir(savoir: &Path, jeton: Option<&str>) -> (Processus, String, String) {
    let mut commande = Command::new(env!("CARGO_BIN_EXE_greffier"));
    commande
        .args(["servir", "--ecoute", "127.0.0.1:0", "--savoir"])
        .arg(savoir)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .env_remove("GREFFIER_JETON")
        .env_remove("GREFFIER_ECOUTE")
        .env_remove("GREFFIER_HOTES")
        .env_remove("GREFFIER_SAVOIR");
    if let Some(jeton) = jeton {
        commande.env("GREFFIER_JETON", jeton);
    }
    let mut enfant = commande.spawn().unwrap();
    let mut ligne = String::new();
    BufReader::new(enfant.stderr.take().unwrap())
        .read_line(&mut ligne)
        .unwrap();
    let base = ligne
        .split("http://")
        .nth(1)
        .and_then(|reste| reste.split('/').next())
        .map(|adresse| format!("http://{adresse}"))
        .unwrap_or_else(|| panic!("adresse introuvable : {ligne}"));
    (Processus(enfant), base, ligne)
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

// [itest->req~api-http~1]
// [itest->req~outils-mcp~1]
#[test]
fn l_api_rend_des_elements_ancres_et_sources_et_des_erreurs_en_json() {
    let savoir = Savoir::new("api");
    let (_serveur, base, _) = servir(&savoir.0, None);

    let (statut, corps) = get(
        &format!("{base}/recherche?question=couper%20branches&le=2020-05-05"),
        None,
    );
    assert_eq!(statut, 200, "{corps}");
    let reponse: Value = serde_json::from_str(&corps).unwrap();
    assert_eq!(reponse["date"], "2020-05-05");
    assert_eq!(reponse["mention"], "aide documentaire, sans valeur d'avis");
    assert_eq!(
        reponse["elements"][0]["identifiants"][0],
        "LEGIARTI000000000002"
    );
    assert_eq!(
        reponse["elements"][0]["sources"][0]["url"],
        "https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000002"
    );
    assert!(!corps.contains("\"chemin\":\"wiki/pratiques/sans-source.md\",\"identifiants\""));
    assert_eq!(
        reponse["ecartes"][0]["chemin"],
        "wiki/pratiques/sans-source.md"
    );

    let (statut, corps) = get(
        &format!("{base}/textes/LEGIARTI000000000001?le=2020-05-05"),
        None,
    );
    assert_eq!(statut, 200, "{corps}");
    assert!(corps.contains("\"identifiant\":\"LEGIARTI000000000002\""));

    let mut reponse = agent()
        .post(&format!("{base}/citations/verification"))
        .send_json(json!({ "texte": "Selon LEGIARTI000000004242." }))
        .unwrap();
    let corps = reponse.body_mut().read_to_string().unwrap();
    assert!(corps.contains("\"admise\":false") && corps.contains("LEGIARTI000000004242"));

    let (statut, corps) = get(&format!("{base}/recherche?question=x&le=hier"), None);
    assert_eq!(statut, 400);
    assert!(corps.starts_with("{\"erreur\":"));
    let (statut, corps) = get(&format!("{base}/textes/LEGIARTI000000000099"), None);
    assert_eq!(statut, 404);
    assert!(!corps.contains(savoir.0.to_str().unwrap()));
    assert_eq!(get(&format!("{base}/savoir/verification"), None).0, 200);
}

// [itest->req~acces-http-protege~1]
#[test]
fn une_requete_sous_un_hote_non_admis_est_refusee_meme_en_local() {
    let savoir = Savoir::new("hote");
    let (_serveur, base, _) = servir(&savoir.0, None);
    let adresse = base.trim_start_matches("http://");
    let mut flux = std::net::TcpStream::connect(adresse).unwrap();
    write!(
        flux,
        "GET /recherche?question=branches HTTP/1.1\r\nHost: piege.exemple:8370\r\nConnection: close\r\n\r\n"
    )
    .unwrap();
    let mut reponse = String::new();
    flux.read_to_string(&mut reponse).unwrap();
    assert!(reponse.starts_with("HTTP/1.1 403"), "{reponse}");
    assert!(!reponse.contains("LEGIARTI"));
    assert_eq!(get(&format!("{base}/sante"), None).0, 200);
}

/// Envoie une requête brute sous l'en-tête `Host` donné ; rend la réponse.
fn get_sous_l_hote(base: &str, chemin: &str, hote: &str) -> String {
    let adresse = base.trim_start_matches("http://");
    let mut flux = std::net::TcpStream::connect(adresse).unwrap();
    write!(
        flux,
        "GET {chemin} HTTP/1.1\r\nHost: {hote}\r\nConnection: close\r\n\r\n"
    )
    .unwrap();
    let mut reponse = String::new();
    flux.read_to_string(&mut reponse).unwrap();
    reponse
}

// [itest->req~service-systeme-desactive~1]
#[test]
fn servir_se_regle_par_ses_variables_d_environnement() {
    let savoir = Savoir::new("environnement");
    let mut enfant = Command::new(env!("CARGO_BIN_EXE_greffier"))
        .arg("servir")
        .env("GREFFIER_SAVOIR", &savoir.0)
        .env("GREFFIER_ECOUTE", "127.0.0.1:0")
        .env("GREFFIER_HOTES", "greffier.exemple,autre.exemple")
        .env_remove("GREFFIER_JETON")
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut ligne = String::new();
    BufReader::new(enfant.stderr.take().unwrap())
        .read_line(&mut ligne)
        .unwrap();
    let _serveur = Processus(enfant);
    let base = ligne
        .split("http://")
        .nth(1)
        .and_then(|reste| reste.split('/').next())
        .map(|adresse| format!("http://{adresse}"))
        .unwrap_or_else(|| panic!("adresse introuvable : {ligne}"));

    let admis = get_sous_l_hote(&base, "/recherche?question=branches", "autre.exemple:8370");
    assert!(admis.starts_with("HTTP/1.1 200"), "{admis}");
    assert!(admis.contains("LEGIARTI000000000002"));
    let refuse = get_sous_l_hote(&base, "/recherche?question=branches", "piege.exemple");
    assert!(refuse.starts_with("HTTP/1.1 403"), "{refuse}");
}

// [itest->req~acces-http-protege~1]
#[test]
fn hors_de_la_boucle_locale_sans_jeton_le_serveur_refuse_de_demarrer() {
    let savoir = Savoir::new("refus");
    let sortie = Command::new(env!("CARGO_BIN_EXE_greffier"))
        .args(["servir", "--ecoute", "0.0.0.0:0", "--savoir"])
        .arg(&savoir.0)
        .env_remove("GREFFIER_JETON")
        .output()
        .unwrap();
    assert_eq!(sortie.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&sortie.stderr).contains("GREFFIER_JETON"));
}

// [itest->req~acces-http-protege~1]
#[test]
fn avec_un_jeton_toute_requete_sans_lui_est_refusee_sauf_la_sante() {
    let savoir = Savoir::new("jeton");
    let (mut serveur, base, annonce) = servir(&savoir.0, Some(JETON));
    assert!(!annonce.contains(JETON));
    assert_eq!(get(&format!("{base}/sante"), None).0, 200);

    let (statut, corps) = get(&format!("{base}/recherche?question=branches"), None);
    assert_eq!(statut, 401);
    assert!(!corps.contains("LEGIARTI"));
    assert_eq!(
        get(
            &format!("{base}/recherche?question=branches"),
            Some("jeton-faux")
        )
        .0,
        401
    );
    let (statut, corps) = get(&format!("{base}/recherche?question=branches"), Some(JETON));
    assert_eq!(statut, 200);
    assert!(corps.contains("LEGIARTI000000000002"));
    assert_eq!(get(&format!("{base}/mcp"), None).0, 401);

    let _ = serveur.0.kill();
    let mut reste = String::new();
    if let Some(mut erreur) = serveur.0.stderr.take() {
        let _ = erreur.read_to_string(&mut reste);
    }
    assert!(!reste.contains(JETON));
}

/// Une session MCP sur l'entrée et la sortie standard de `greffier mcp`.
struct SessionMcp {
    _processus: Processus,
    entree: ChildStdin,
    sortie: BufReader<ChildStdout>,
}

impl SessionMcp {
    fn ouvrir(savoir: &Path) -> Self {
        let mut enfant = Command::new(env!("CARGO_BIN_EXE_greffier"))
            .args(["mcp", "--savoir"])
            .arg(savoir)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        let entree = enfant.stdin.take().unwrap();
        let sortie = BufReader::new(enfant.stdout.take().unwrap());
        let mut session = Self {
            _processus: Processus(enfant),
            entree,
            sortie,
        };
        let initialisation = session.demander(
            1,
            "initialize",
            json!({
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": { "name": "essai", "version": "0" }
            }),
        );
        assert_eq!(initialisation["result"]["serverInfo"]["name"], "greffier");
        session.envoyer(&json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }));
        session
    }

    fn envoyer(&mut self, message: &Value) {
        writeln!(self.entree, "{message}").unwrap();
        self.entree.flush().unwrap();
    }

    fn demander(&mut self, id: u64, methode: &str, parametres: Value) -> Value {
        self.envoyer(
            &json!({ "jsonrpc": "2.0", "id": id, "method": methode, "params": parametres }),
        );
        loop {
            let mut ligne = String::new();
            assert!(
                self.sortie.read_line(&mut ligne).unwrap() > 0,
                "session close"
            );
            let message: Value = serde_json::from_str(&ligne).unwrap();
            if message["id"] == id {
                return message;
            }
        }
    }

    fn appeler(&mut self, id: u64, outil: &str, arguments: Value) -> Value {
        let reponse = self.demander(
            id,
            "tools/call",
            json!({ "name": outil, "arguments": arguments }),
        );
        reponse["result"].clone()
    }
}

// [itest->req~outils-mcp~1]
#[test]
fn un_agent_mcp_liste_les_quatre_outils_et_ne_recoit_que_de_l_ancre() {
    let savoir = Savoir::new("mcp");
    let mut session = SessionMcp::ouvrir(&savoir.0);

    let liste = session.demander(2, "tools/list", json!({}));
    let mut outils: Vec<&str> = liste["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|outil| outil["name"].as_str())
        .collect();
    outils.sort_unstable();
    assert_eq!(
        outils,
        [
            "chercher",
            "lire_texte",
            "verifier_citation",
            "verifier_savoir"
        ]
    );
    let chercher = liste["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .find(|outil| outil["name"] == "chercher")
        .unwrap();
    assert!(chercher["inputSchema"]["properties"]["question"].is_object());

    let resultat = session.appeler(
        3,
        "chercher",
        json!({ "question": "couper branches", "le": "2020-05-05" }),
    );
    let reponse = &resultat["structuredContent"];
    assert_eq!(reponse["mention"], "aide documentaire, sans valeur d'avis");
    assert_eq!(reponse["date"], "2020-05-05");
    let elements = reponse["elements"].as_array().unwrap();
    assert!(!elements.is_empty());
    assert!(
        elements
            .iter()
            .all(|e| e["chemin"] != "wiki/pratiques/sans-source.md")
    );

    let refus = session.appeler(
        4,
        "verifier_citation",
        json!({ "texte": "Vous pouvez couper (LEGIARTI000000004242)." }),
    );
    assert_eq!(refus["structuredContent"]["admise"], false);
    assert!(
        refus["structuredContent"]["motif"]
            .as_str()
            .unwrap()
            .contains("LEGIARTI000000004242")
    );

    let erreur = session.appeler(
        5,
        "lire_texte",
        json!({ "identifiant": "LEGIARTI000000000099" }),
    );
    assert_eq!(erreur["isError"], true);
}
