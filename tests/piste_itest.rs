// SPDX-License-Identifier: EUPL-1.2
//! Bout à bout contre un faux serveur PISTE local : jeton OAuth, appel
//! authentifié, capture dans la couche des textes, constat des versions.
//! Aucun réseau extérieur ; contenu fictif.
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    missing_docs
)]

use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpListener;
use std::path::PathBuf;
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread;

/// Une requête reçue par le faux serveur.
#[derive(Debug, Clone)]
struct Recue {
    ligne: String,
    autorisation: Option<String>,
    corps: String,
}

const JETON: &str = "jeton-fictif-0123";
const SECRET: &str = "cle-secrete-fictive";

fn article(id: &str, debut: i64, fin: i64) -> String {
    format!(
        r#"{{"article":{{"id":"{id}","cid":"LEGIARTI000000000001","num":"673","etat":"VIGUEUR",
        "dateDebut":{debut},"dateFin":{fin},"texte":"Texte fictif {id}.",
        "textTitles":[{{"titre":"Code civil","nature":"CODE"}}],
        "articleVersions":[
          {{"id":"LEGIARTI000000000001","etat":"MODIFIE","dateDebut":-5330000000000,"dateFin":1475272800000}},
          {{"id":"LEGIARTI000000000002","etat":"VIGUEUR","dateDebut":1475272800000,"dateFin":32472144000000}}]}}}}"#
    )
}

/// Démarre le faux serveur ; rend son adresse et le journal des requêtes.
fn serveur() -> (String, Arc<Mutex<Vec<Recue>>>) {
    let ecoute = TcpListener::bind("127.0.0.1:0").unwrap();
    let adresse = format!("http://{}", ecoute.local_addr().unwrap());
    let journal = Arc::new(Mutex::new(Vec::new()));
    let partage = Arc::clone(&journal);
    thread::spawn(move || {
        for flux in ecoute.incoming() {
            let mut flux = flux.unwrap();
            let mut lecteur = BufReader::new(flux.try_clone().unwrap());
            let mut ligne = String::new();
            lecteur.read_line(&mut ligne).unwrap();
            let (mut longueur, mut autorisation) = (0usize, None);
            loop {
                let mut entete = String::new();
                lecteur.read_line(&mut entete).unwrap();
                let entete = entete.trim_end();
                if entete.is_empty() {
                    break;
                }
                let (nom, valeur) = entete.split_once(':').unwrap();
                match nom.to_ascii_lowercase().as_str() {
                    "content-length" => longueur = valeur.trim().parse().unwrap(),
                    "authorization" => autorisation = Some(valeur.trim().to_owned()),
                    _ => {}
                }
            }
            let mut corps = vec![0; longueur];
            lecteur.read_exact(&mut corps).unwrap();
            let corps = String::from_utf8(corps).unwrap();
            let ligne = ligne.trim_end().to_owned();
            let reponse = if ligne.starts_with("POST /jeton") {
                format!(r#"{{"access_token":"{JETON}","token_type":"Bearer","expires_in":3600}}"#)
            } else if ligne.starts_with("POST /dila/legifrance/lf-engine-app/consult/getArticle") {
                if corps.contains("LEGIARTI000000000001") {
                    article(
                        "LEGIARTI000000000001",
                        -5_330_000_000_000,
                        1_475_272_800_000,
                    )
                } else {
                    article(
                        "LEGIARTI000000000002",
                        1_475_272_800_000,
                        32_472_144_000_000,
                    )
                }
            } else if ligne
                .starts_with("GET /cassation/judilibre/v1.0/decision?id=000000000000000000000abc")
            {
                r#"{"id":"000000000000000000000abc","jurisdiction":"cc","chamber":"civ3","number":"00-00.000",
                   "ecli":"ECLI:FR:CCASS:2000:C300000","decision_date":"2000-01-01","text":"Texte fictif."}"#
                    .to_owned()
            } else {
                String::from("{}")
            };
            partage.lock().unwrap().push(Recue {
                ligne,
                autorisation,
                corps,
            });
            let _ = write!(
                flux,
                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{reponse}",
                reponse.len()
            );
        }
    });
    (adresse, journal)
}

fn greffier(adresse: &str, arguments: &[&str]) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_greffier"))
        .args(arguments)
        .env("GREFFIER_PISTE_CLIENT_ID", "appli-fictive")
        .env("GREFFIER_PISTE_CLIENT_SECRET", SECRET)
        .env("GREFFIER_PISTE_URL_JETON", format!("{adresse}/jeton"))
        .env("GREFFIER_PISTE_URL_API", adresse)
        .output()
        .unwrap()
}

fn savoir_jetable(nom: &str) -> PathBuf {
    let dossier = std::env::temp_dir().join(format!("greffier-itest-{nom}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dossier);
    dossier
}

// [itest->req~capture-des-sources-officielles~1]
// [itest->req~textes-authentiques-versionnes~1]
#[test]
fn capturer_un_article_et_ses_versions_les_conserve_cote_a_cote() {
    let (adresse, journal) = serveur();
    let savoir = savoir_jetable("article");
    let sortie = greffier(
        &adresse,
        &[
            "capturer",
            "article",
            "LEGIARTI000000000002",
            "--toutes-versions",
            "--savoir",
            savoir.to_str().unwrap(),
        ],
    );
    assert!(
        sortie.status.success(),
        "{}",
        String::from_utf8_lossy(&sortie.stderr)
    );
    let textes = savoir.join("raw/textes");
    assert!(textes.join("LEGIARTI000000000002@2016-10-01.md").is_file());
    assert!(textes.join("LEGIARTI000000000001@1801-02-06.md").is_file());

    let recues = journal.lock().unwrap().clone();
    // Un seul jeton, réutilisé pour les deux appels.
    assert_eq!(
        recues
            .iter()
            .filter(|r| r.ligne.starts_with("POST /jeton"))
            .count(),
        1
    );
    let jeton = &recues[0];
    assert!(jeton.corps.contains("grant_type=client_credentials"));
    for appel in recues.iter().filter(|r| r.ligne.contains("getArticle")) {
        assert_eq!(
            appel.autorisation.as_deref(),
            Some(format!("Bearer {JETON}").as_str())
        );
    }

    let applicable = greffier(
        &adresse,
        &[
            "en-vigueur",
            "LEGIARTI000000000001",
            "--le",
            "2010-01-01",
            "--savoir",
            savoir.to_str().unwrap(),
        ],
    );
    assert!(applicable.status.success());
    assert!(String::from_utf8_lossy(&applicable.stdout).starts_with("LEGIARTI000000000001\t"));
    std::fs::remove_dir_all(savoir).unwrap();
}

// [itest->req~capture-des-sources-officielles~1]
#[test]
fn capturer_une_decision_la_conserve_sous_son_ecli() {
    let (adresse, _) = serveur();
    let savoir = savoir_jetable("decision");
    let sortie = greffier(
        &adresse,
        &[
            "capturer",
            "decision",
            "000000000000000000000abc",
            "--savoir",
            savoir.to_str().unwrap(),
        ],
    );
    assert!(
        sortie.status.success(),
        "{}",
        String::from_utf8_lossy(&sortie.stderr)
    );
    assert!(
        savoir
            .join("raw/decisions/ECLI_FR_CCASS_2000_C300000.md")
            .is_file()
    );
    std::fs::remove_dir_all(savoir).unwrap();
}

// [itest->req~detection-des-versions~1]
#[test]
fn versions_sort_en_3_quand_l_article_a_change() {
    let (adresse, _) = serveur();
    let change = greffier(
        &adresse,
        &["versions", "LEGIARTI000000000002", "--depuis", "2015-01-01"],
    );
    assert_eq!(change.status.code(), Some(3));
    assert!(
        String::from_utf8_lossy(&change.stdout).contains("nouvelle version\tLEGIARTI000000000002")
    );
    let stable = greffier(
        &adresse,
        &["versions", "LEGIARTI000000000002", "--depuis", "2026-11-01"],
    );
    assert_eq!(stable.status.code(), Some(0));
}

#[test]
fn le_secret_n_apparait_jamais_dans_une_sortie() {
    // Une source qui répond 403 : l'erreur cite l'adresse, jamais la clé.
    let ecoute = TcpListener::bind("127.0.0.1:0").unwrap();
    let adresse = format!("http://{}", ecoute.local_addr().unwrap());
    thread::spawn(move || {
        for flux in ecoute.incoming() {
            let mut flux = flux.unwrap();
            let mut tampon = [0u8; 4096];
            let _ = flux.read(&mut tampon);
            let _ = flux.write_all(
                b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
            );
        }
    });
    let sortie = greffier(
        &adresse,
        &["versions", "LEGIARTI000000000002", "--depuis", "2015-01-01"],
    );
    assert_eq!(sortie.status.code(), Some(1));
    let tout = format!(
        "{}{}",
        String::from_utf8_lossy(&sortie.stdout),
        String::from_utf8_lossy(&sortie.stderr)
    );
    assert!(tout.contains("403"));
    assert!(!tout.contains(SECRET));
}

#[test]
fn sans_identifiants_rien_n_est_demande() {
    let sortie = Command::new(env!("CARGO_BIN_EXE_greffier"))
        .args(["versions", "LEGIARTI000000000002", "--depuis", "2015-01-01"])
        .env_remove("GREFFIER_PISTE_CLIENT_ID")
        .env_remove("GREFFIER_PISTE_CLIENT_SECRET")
        .output()
        .unwrap();
    assert_eq!(sortie.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&sortie.stderr).contains("GREFFIER_PISTE_CLIENT_ID"));
}
