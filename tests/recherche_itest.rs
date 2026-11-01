// SPDX-License-Identifier: EUPL-1.2
//! `greffier chercher` et `greffier banc` de bout en bout sur un dépôt de
//! savoir jetable : la date choisit la version rendue, un élément sans
//! ancrage est journalisé et jamais rendu, le banc mesure. Contenu fictif.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, missing_docs)]

use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

struct Savoir(PathBuf);

impl Savoir {
    fn new(nom: &str) -> Self {
        let racine = std::env::temp_dir().join(format!(
            "greffier-recherche-itest-{nom}-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&racine);
        let savoir = Self(racine);
        for (identifiant, periode, debut) in [
            (
                "LEGIARTI000000000001",
                "1804-03-21 / 2016-10-01",
                "1804-03-21",
            ),
            ("LEGIARTI000000000002", "2016-10-01 / —", "2016-10-01"),
        ] {
            savoir.ecrire(
                &format!("raw/textes/{identifiant}@{debut}.md"),
                &format!(
                    "---\nidentifiant: {identifiant}\ncid: LEGIARTI000000000001\nintitule: \"Code civil, article 673\"\nsource: https://www.legifrance.gouv.fr/codes/article_lc/{identifiant}\netat: VIGUEUR\nen_vigueur: {periode}\ncapture_le: 2026-11-01\n---\n\nLes branches des arbres du voisin peuvent être coupées.\n"
                ),
            );
        }
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

    fn greffier(&self, arguments: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_greffier"))
            .args(arguments)
            .arg("--savoir")
            .arg(&self.0)
            .output()
            .unwrap()
    }
}

impl Drop for Savoir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn sortie(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

// [itest->req~textes-authentiques-versionnes~1]
#[test]
fn chercher_a_une_date_rend_la_version_en_vigueur_et_elle_seule() {
    let savoir = Savoir::new("date");
    let avant = savoir.greffier(&["chercher", "branches du voisin", "--le", "2010-05-05"]);
    let apres = savoir.greffier(&["chercher", "branches du voisin", "--le", "2020-05-05"]);
    assert!(avant.status.success() && apres.status.success());
    let (avant, apres) = (sortie(&avant), sortie(&apres));
    assert!(avant.contains("\tLEGIARTI000000000001\t") && !avant.contains("LEGIARTI000000000002"));
    assert!(apres.contains("\tLEGIARTI000000000002\t") && !apres.contains("@1804-03-21"));
}

#[test]
fn un_element_sans_ancrage_est_journalise_et_jamais_rendu() {
    let savoir = Savoir::new("ancrage");
    let resultat = savoir.greffier(&["chercher", "couper les branches"]);
    assert!(resultat.status.success());
    let journal = String::from_utf8_lossy(&resultat.stderr);
    assert!(
        journal.contains("écarté\twiki/pratiques/sans-source.md\taucun identifiant officiel"),
        "{journal}"
    );
    let rendu = sortie(&resultat);
    assert!(!rendu.contains("sans-source"));
    assert!(rendu.contains("# aide documentaire, sans valeur d'avis"));
}

#[test]
fn le_banc_mesure_et_sort_en_succes_quand_tout_est_ancre() {
    let savoir = Savoir::new("banc");
    savoir.ecrire(
        "banc/questions.tsv",
        "id\tquestion\tdate\tattendus\tsituation\tsource\nQ001\tLes branches du voisin dépassent\t2026-11-01\tLEGIARTI000000000001\t\tcas type\nQ002\tSans attendu\t2026-11-01\tà relever\t\tcas type\n",
    );
    let resultat = savoir.greffier(&["banc"]);
    let rendu = sortie(&resultat);
    assert!(resultat.status.success(), "{rendu}");
    assert!(rendu.contains("Q001\trappel 1/1\t"), "{rendu}");
    assert!(rendu.contains("Q002\tnon mesurable"), "{rendu}");
    assert!(rendu.contains("0 élément(s) non ancré(s)"), "{rendu}");
}

#[test]
fn la_recherche_n_ecrit_rien_dans_le_savoir() {
    let savoir = Savoir::new("lecture-seule");
    let avant = lister(&savoir.0);
    savoir.greffier(&["chercher", "branches"]);
    assert_eq!(lister(&savoir.0), avant);
}

fn lister(racine: &Path) -> Vec<(PathBuf, Vec<u8>)> {
    let mut fichiers = Vec::new();
    let mut a_voir = vec![racine.to_owned()];
    while let Some(dossier) = a_voir.pop() {
        for entree in fs::read_dir(dossier).unwrap() {
            let chemin = entree.unwrap().path();
            if chemin.is_dir() {
                a_voir.push(chemin);
            } else {
                let contenu = fs::read(&chemin).unwrap();
                fichiers.push((chemin, contenu));
            }
        }
    }
    fichiers.sort();
    fichiers
}
