// SPDX-License-Identifier: EUPL-1.2
//! Couche des textes authentiques : le dossier `raw/` d'un dépôt de savoir.
//!
//! Un fichier par version d'article (`raw/textes/<identifiant>@<début>.md`)
//! et un par décision (`raw/decisions/<ECLI ou POURVOI:<numéro>, « : » remplacés par « _ »>.md`),
//! chacun ouvert par un en-tête qui porte l'identifiant officiel, la source,
//! la version et la date de capture. La couche est IMMUABLE : un fichier
//! présent n'est jamais réécrit ; une capture identique est sans effet, une
//! capture différente est refusée. Une nouvelle version d'un article porte
//! un autre identifiant, donc un autre fichier : elle se range à côté des
//! précédentes.

// [impl->req~textes-authentiques-versionnes~1]

use std::fs;
use std::io::{ErrorKind, Write};
use std::path::{Path, PathBuf};

use time::Date;

use crate::erreur::{Erreur, Resultat};
use crate::judilibre::Decision;
use crate::legifrance::{self, Article};
use crate::periode::{Periode, ecrire_date};

/// Issue d'une conservation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Conservation {
    /// Le fichier n'existait pas ; il est créé.
    Cree(PathBuf),
    /// Le même texte était déjà conservé ; rien n'est écrit.
    DejaConserve(PathBuf),
}

/// Une version d'article conservée dans la couche.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VersionConservee {
    /// Fichier de la couche.
    pub chemin: PathBuf,
    /// Identifiant de la version.
    pub identifiant: String,
    /// Période de vigueur.
    pub en_vigueur: Periode,
}

/// La couche des textes d'un dépôt de savoir.
#[derive(Debug, Clone)]
pub struct Couche {
    racine: PathBuf,
}

impl Couche {
    /// Couche du dépôt de savoir situé à `savoir` (son dossier `raw/`).
    pub fn du_savoir(savoir: &Path) -> Self {
        Self {
            racine: savoir.join("raw"),
        }
    }

    /// Conserve une version d'article.
    pub fn conserver_article(&self, article: &Article, capture_le: Date) -> Resultat<Conservation> {
        legifrance::verifier_identifiant(&article.identifiant)?;
        legifrance::verifier_identifiant(&article.cid)?;
        let nom = format!(
            "{}@{}.md",
            article.identifiant,
            ecrire_date(article.en_vigueur.debut)
        );
        let entete = [
            ("identifiant", article.identifiant.clone()),
            ("cid", article.cid.clone()),
            ("intitule", guillemets(&article.intitule())),
            ("source", article.source()),
            ("etat", article.etat.clone()),
            ("en_vigueur", article.en_vigueur.to_string()),
            ("capture_le", ecrire_date(capture_le)),
        ];
        self.ecrire(
            &self.racine.join("textes").join(nom),
            &document(&entete, &article.texte),
        )
    }

    /// Conserve une décision.
    pub fn conserver_decision(
        &self,
        decision: &Decision,
        capture_le: Date,
    ) -> Resultat<Conservation> {
        let identifiant = &decision.identifiant;
        let forme_admise = (identifiant.starts_with("ECLI:")
            && identifiant
                .bytes()
                .all(|octet| octet.is_ascii_alphanumeric() || b":.".contains(&octet)))
            || identifiant
                .strip_prefix(crate::judilibre::PREFIXE_POURVOI)
                .is_some_and(crate::judilibre::est_numero_de_pourvoi);
        if !forme_admise {
            return Err(Erreur::IdentifiantInvalide(
                identifiant.clone(),
                "ECLI:… (lettres, chiffres, « : », « . ») ou POURVOI:<numéro de pourvoi>",
            ));
        }
        let nom = format!("{}.md", identifiant.replace(':', "_"));
        let entete = [
            ("identifiant", identifiant.clone()),
            ("judilibre", decision.identifiant_judilibre.clone()),
            ("intitule", guillemets(&decision.intitule())),
            ("source", decision.source()),
            ("date_decision", ecrire_date(decision.date)),
            ("capture_le", ecrire_date(capture_le)),
        ];
        self.ecrire(
            &self.racine.join("decisions").join(nom),
            &document(&entete, &decision.texte),
        )
    }

    /// Versions conservées d'un article (par son identifiant chronologique),
    /// en vigueur à la date donnée. Une couche cohérente en rend au plus
    /// une ; plusieurs signalent un recouvrement à corriger à la source.
    pub fn en_vigueur_le(&self, cid: &str, date: Date) -> Resultat<Vec<VersionConservee>> {
        Ok(self
            .versions(cid)?
            .into_iter()
            .filter(|version| version.en_vigueur.couvre(date))
            .collect())
    }

    /// Toutes les versions conservées d'un article, par date d'entrée en
    /// vigueur.
    pub fn versions(&self, cid: &str) -> Resultat<Vec<VersionConservee>> {
        let dossier = self.racine.join("textes");
        let entrees = match fs::read_dir(&dossier) {
            Ok(entrees) => entrees,
            Err(cause) if cause.kind() == ErrorKind::NotFound => return Ok(Vec::new()),
            Err(cause) => {
                return Err(Erreur::Fichier {
                    chemin: dossier,
                    cause,
                });
            }
        };
        let mut versions = Vec::new();
        for entree in entrees {
            let chemin = entree
                .map_err(|cause| Erreur::Fichier {
                    chemin: dossier.clone(),
                    cause,
                })?
                .path();
            if chemin.extension().is_none_or(|extension| extension != "md") {
                continue;
            }
            let contenu = fs::read_to_string(&chemin).map_err(|cause| Erreur::Fichier {
                chemin: chemin.clone(),
                cause,
            })?;
            let Some(entete) = lire_entete(&contenu) else {
                return Err(Erreur::FichierMalForme(chemin));
            };
            if valeur(&entete, "cid") != Some(cid) {
                continue;
            }
            let (Some(identifiant), Some(periode)) = (
                valeur(&entete, "identifiant"),
                valeur(&entete, "en_vigueur"),
            ) else {
                return Err(Erreur::FichierMalForme(chemin));
            };
            let en_vigueur =
                Periode::lire(periode).map_err(|_| Erreur::FichierMalForme(chemin.clone()))?;
            versions.push(VersionConservee {
                identifiant: identifiant.to_owned(),
                en_vigueur,
                chemin,
            });
        }
        versions.sort_by_key(|version| version.en_vigueur.debut);
        Ok(versions)
    }

    fn ecrire(&self, chemin: &Path, contenu: &str) -> Resultat<Conservation> {
        let erreur = |cause| Erreur::Fichier {
            chemin: chemin.to_owned(),
            cause,
        };
        if let Some(parent) = chemin.parent() {
            fs::create_dir_all(parent).map_err(erreur)?;
        }
        // create_new : jamais d'écrasement, même entre deux captures
        // concurrentes.
        match fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(chemin)
        {
            Ok(mut fichier) => {
                fichier.write_all(contenu.as_bytes()).map_err(erreur)?;
                Ok(Conservation::Cree(chemin.to_owned()))
            }
            Err(cause) if cause.kind() == ErrorKind::AlreadyExists => {
                let present = fs::read_to_string(chemin).map_err(erreur)?;
                if sans_capture(&present) == sans_capture(contenu) {
                    Ok(Conservation::DejaConserve(chemin.to_owned()))
                } else {
                    Err(Erreur::TexteDifferent(chemin.to_owned()))
                }
            }
            Err(cause) => Err(erreur(cause)),
        }
    }
}

/// Une chaîne entre guillemets doubles, échappée (forme admise par YAML).
fn guillemets(texte: &str) -> String {
    serde_json::Value::from(texte).to_string()
}

fn document(entete: &[(&str, String)], texte: &str) -> String {
    let mut document = String::from("---\n");
    for (cle, valeur) in entete {
        document.push_str(cle);
        document.push_str(": ");
        document.push_str(valeur);
        document.push('\n');
    }
    document.push_str("---\n\n");
    document.push_str(texte.trim_end());
    document.push('\n');
    document
}

/// Le document sans sa ligne de date de capture : deux captures du même
/// texte à deux dates différentes sont le même texte.
fn sans_capture(document: &str) -> Vec<&str> {
    document
        .lines()
        .filter(|ligne| !ligne.starts_with("capture_le:"))
        .collect()
}

pub(crate) fn lire_entete(document: &str) -> Option<Vec<(&str, &str)>> {
    let reste = document.strip_prefix("---\n")?;
    let (entete, _) = reste.split_once("\n---\n")?;
    Some(
        entete
            .lines()
            .filter_map(|ligne| ligne.split_once(": "))
            .collect(),
    )
}

pub(crate) fn valeur<'a>(entete: &[(&str, &'a str)], cle: &str) -> Option<&'a str> {
    entete
        .iter()
        .find(|(nom, _)| *nom == cle)
        .map(|(_, valeur)| *valeur)
}

#[cfg(test)]
mod tests {
    use time::macros::date;

    use super::*;
    use crate::judilibre::{self, tests::reponse_fictive as decision_fictive};
    use crate::legifrance::tests::{SourceFactice, reponse_fictive};

    fn dossier_jetable(nom: &str) -> PathBuf {
        let dossier =
            std::env::temp_dir().join(format!("greffier-couche-{nom}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dossier);
        dossier
    }

    fn article(identifiant: &str, debut: Date, fin: Option<Date>, texte: &str) -> Article {
        let source = SourceFactice::new(reponse_fictive());
        let mut article = legifrance::lire_article(&source, "LEGIARTI000000000002").unwrap();
        article.identifiant = identifiant.to_owned();
        article.en_vigueur = Periode::new(debut, fin);
        article.texte = texte.to_owned();
        article
    }

    // [utest->req~textes-authentiques-versionnes~1]
    #[test]
    fn un_article_est_conserve_avec_son_identifiant_sa_source_sa_version_et_sa_capture() {
        let savoir = dossier_jetable("entete");
        let couche = Couche::du_savoir(&savoir);
        let a = article(
            "LEGIARTI000000000002",
            date!(2016 - 10 - 01),
            None,
            "Texte.",
        );
        let Conservation::Cree(chemin) =
            couche.conserver_article(&a, date!(2026 - 11 - 01)).unwrap()
        else {
            panic!("le fichier devait être créé");
        };
        assert!(chemin.ends_with("raw/textes/LEGIARTI000000000002@2016-10-01.md"));
        let contenu = fs::read_to_string(&chemin).unwrap();
        for attendu in [
            "identifiant: LEGIARTI000000000002\n",
            "cid: LEGIARTI000000000001\n",
            "intitule: \"Code civil, article 673\"\n",
            "source: https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000002\n",
            "en_vigueur: 2016-10-01 / —\n",
            "capture_le: 2026-11-01\n",
            "---\n\nTexte.\n",
        ] {
            assert!(contenu.contains(attendu), "absent : {attendu}");
        }
        fs::remove_dir_all(savoir).unwrap();
    }

    // [utest->req~textes-authentiques-versionnes~1]
    #[test]
    fn un_texte_conserve_n_est_jamais_reecrit() {
        let savoir = dossier_jetable("immuable");
        let couche = Couche::du_savoir(&savoir);
        let a = article(
            "LEGIARTI000000000002",
            date!(2016 - 10 - 01),
            None,
            "Texte.",
        );
        couche.conserver_article(&a, date!(2026 - 11 - 01)).unwrap();
        assert!(matches!(
            couche.conserver_article(&a, date!(2026 - 12 - 01)).unwrap(),
            Conservation::DejaConserve(_)
        ));
        let altere = article(
            "LEGIARTI000000000002",
            date!(2016 - 10 - 01),
            None,
            "Texte altéré.",
        );
        assert!(matches!(
            couche.conserver_article(&altere, date!(2026 - 12 - 01)),
            Err(Erreur::TexteDifferent(_))
        ));
        let chemin = savoir.join("raw/textes/LEGIARTI000000000002@2016-10-01.md");
        let contenu = fs::read_to_string(chemin).unwrap();
        assert!(contenu.contains("capture_le: 2026-11-01") && contenu.contains("Texte.\n"));
        fs::remove_dir_all(savoir).unwrap();
    }

    // [utest->req~textes-authentiques-versionnes~1]
    #[test]
    fn la_version_en_vigueur_a_une_date_est_rendue_et_elle_seule() {
        let savoir = dossier_jetable("vigueur");
        let couche = Couche::du_savoir(&savoir);
        let ancienne = article(
            "LEGIARTI000000000001",
            date!(1804 - 03 - 21),
            Some(date!(2016 - 10 - 01)),
            "Ancien.",
        );
        let nouvelle = article(
            "LEGIARTI000000000002",
            date!(2016 - 10 - 01),
            None,
            "Nouveau.",
        );
        couche
            .conserver_article(&ancienne, date!(2026 - 11 - 01))
            .unwrap();
        couche
            .conserver_article(&nouvelle, date!(2026 - 11 - 01))
            .unwrap();
        assert_eq!(couche.versions("LEGIARTI000000000001").unwrap().len(), 2);
        let avant = couche
            .en_vigueur_le("LEGIARTI000000000001", date!(2010 - 05 - 05))
            .unwrap();
        assert_eq!(avant.len(), 1);
        assert_eq!(avant[0].identifiant, "LEGIARTI000000000001");
        let apres = couche
            .en_vigueur_le("LEGIARTI000000000001", date!(2016 - 10 - 01))
            .unwrap();
        assert_eq!(apres.len(), 1);
        assert_eq!(apres[0].identifiant, "LEGIARTI000000000002");
        fs::remove_dir_all(savoir).unwrap();
    }

    #[test]
    fn une_decision_est_conservee_sous_son_ecli() {
        let savoir = dossier_jetable("decision");
        let couche = Couche::du_savoir(&savoir);
        let source = SourceFactice::new(decision_fictive());
        let decision = judilibre::lire_decision(&source, "000000000000000000000abc").unwrap();
        let Conservation::Cree(chemin) = couche
            .conserver_decision(&decision, date!(2026 - 11 - 01))
            .unwrap()
        else {
            panic!("le fichier devait être créé");
        };
        assert!(chemin.ends_with("raw/decisions/ECLI_FR_CCASS_2000_C300000.md"));
        let contenu = fs::read_to_string(&chemin).unwrap();
        assert!(contenu.contains("identifiant: ECLI:FR:CCASS:2000:C300000\n"));
        assert!(contenu.contains(
            "source: https://www.courdecassation.fr/decision/000000000000000000000abc\n"
        ));
        fs::remove_dir_all(savoir).unwrap();
    }

    // [utest->req~capture-des-sources-officielles~2]
    #[test]
    fn une_decision_sans_ecli_est_conservee_sous_son_pourvoi() {
        let savoir = dossier_jetable("pourvoi");
        let couche = Couche::du_savoir(&savoir);
        let mut reponse = decision_fictive();
        reponse["ecli"] = serde_json::Value::Null;
        let source = SourceFactice::new(reponse);
        let decision = judilibre::lire_decision(&source, "000000000000000000000abc").unwrap();
        let Conservation::Cree(chemin) = couche
            .conserver_decision(&decision, date!(2026 - 11 - 01))
            .unwrap()
        else {
            panic!("le fichier devait être créé");
        };
        assert!(chemin.ends_with("raw/decisions/POURVOI_00-00.000.md"));
        let contenu = fs::read_to_string(&chemin).unwrap();
        assert!(contenu.contains("identifiant: POURVOI:00-00.000\n"));
        fs::remove_dir_all(savoir).unwrap();
    }

    #[test]
    fn un_pourvoi_porteur_d_un_chemin_est_refuse() {
        let savoir = dossier_jetable("traversee-pourvoi");
        let couche = Couche::du_savoir(&savoir);
        let source = SourceFactice::new(decision_fictive());
        let mut decision = judilibre::lire_decision(&source, "000000000000000000000abc").unwrap();
        decision.identifiant = "POURVOI:../../etc".to_owned();
        assert!(matches!(
            couche.conserver_decision(&decision, date!(2026 - 11 - 01)),
            Err(Erreur::IdentifiantInvalide(..))
        ));
        assert!(!savoir.exists());
    }

    #[test]
    fn un_ecli_porteur_d_un_chemin_est_refuse() {
        let savoir = dossier_jetable("traversee");
        let couche = Couche::du_savoir(&savoir);
        let source = SourceFactice::new(decision_fictive());
        let mut decision = judilibre::lire_decision(&source, "000000000000000000000abc").unwrap();
        decision.identifiant = "ECLI:../../etc".to_owned();
        assert!(matches!(
            couche.conserver_decision(&decision, date!(2026 - 11 - 01)),
            Err(Erreur::IdentifiantInvalide(..))
        ));
        assert!(!savoir.exists());
    }
}
