// SPDX-License-Identifier: EUPL-1.2
//! Lecture d'un article sur l'API Légifrance (`consult/getArticle`).
//!
//! Forme des réponses : spécification OpenAPI « Légifrance » 2.4.2 de la
//! DILA (définitions `GetArticleResponse`, `Article`, `ArticleVersion`).
//! Seuls les champs nécessaires à l'ancrage sont lus ; un champ requis
//! absent est une erreur, jamais une valeur inventée.

use serde::Deserialize;
use serde_json::{Value, json};
use time::Date;

use crate::erreur::{Erreur, Resultat};
use crate::periode::{Periode, date_depuis_millis, lire_date};
use crate::piste::SourcePiste;

/// Racine de l'API Légifrance sur PISTE.
const RACINE: &str = "/dila/legifrance/lf-engine-app";

/// Un article tel que la source le rend, réduit à ce qui ancre une citation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Article {
    /// Identifiant de cette version (`LEGIARTI…`).
    pub identifiant: String,
    /// Identifiant chronologique, commun à toutes les versions (`LEGIARTI…`).
    pub cid: String,
    /// Numéro de l'article (« 673 »).
    pub numero: String,
    /// État juridique (`VIGUEUR`, `ABROGE`, `MODIFIE`…).
    pub etat: String,
    /// Période de vigueur de cette version.
    pub en_vigueur: Periode,
    /// Texte de l'article, tel que rendu par la source.
    pub texte: String,
    /// Titre du texte qui contient l'article (« Code civil »), s'il est rendu.
    pub titre_texte: Option<String>,
    /// Nature du texte qui contient l'article (`CODE`, `LOI`…).
    pub nature_texte: Option<String>,
    /// Toutes les versions connues de l'article.
    pub versions: Vec<VersionArticle>,
}

/// Une version d'article, telle que listée par la source.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VersionArticle {
    /// Identifiant de la version (`LEGIARTI…`).
    pub identifiant: String,
    /// État juridique de la version.
    pub etat: String,
    /// Période de vigueur de la version.
    pub en_vigueur: Periode,
}

impl Article {
    /// Intitulé lisible : « Code civil, article 673 ».
    pub fn intitule(&self) -> String {
        match &self.titre_texte {
            Some(titre) => format!("{titre}, article {}", self.numero),
            None => format!("Article {}", self.numero),
        }
    }

    /// Adresse publique de l'article sur Légifrance.
    pub fn source(&self) -> String {
        let fonds = match self.nature_texte.as_deref() {
            Some("CODE") => "codes",
            _ => "loda",
        };
        format!(
            "https://www.legifrance.gouv.fr/{fonds}/article_lc/{}",
            self.identifiant
        )
    }
}

/// Vérifie la forme d'un identifiant d'article : `LEGIARTI` puis douze
/// chiffres.
pub fn verifier_identifiant(identifiant: &str) -> Resultat<()> {
    let chiffres = identifiant.strip_prefix("LEGIARTI").unwrap_or_default();
    if chiffres.len() == 12 && chiffres.bytes().all(|octet| octet.is_ascii_digit()) {
        Ok(())
    } else {
        Err(Erreur::IdentifiantInvalide(
            identifiant.to_owned(),
            "LEGIARTI suivi de 12 chiffres",
        ))
    }
}

// [impl->req~capture-des-sources-officielles~2]
/// Lit un article par son identifiant de version.
pub fn lire_article(source: &impl SourcePiste, identifiant: &str) -> Resultat<Article> {
    verifier_identifiant(identifiant)?;
    let reponse = source.post_json(
        &format!("{RACINE}/consult/getArticle"),
        &json!({ "id": identifiant }),
    )?;
    article_depuis_reponse(reponse, identifiant)
}

fn article_depuis_reponse(reponse: Value, demande: &str) -> Resultat<Article> {
    let lu: ReponseArticle = serde_json::from_value(reponse)
        .map_err(|cause| Erreur::ReponseInattendue(format!("getArticle : {cause}")))?;
    let brut = lu
        .article
        .ok_or_else(|| Erreur::Introuvable(demande.to_owned()))?;
    let requis = |champ: Option<String>, nom: &str| {
        champ
            .filter(|valeur| !valeur.trim().is_empty())
            .ok_or_else(|| {
                Erreur::ReponseInattendue(format!("getArticle : champ « {nom} » absent"))
            })
    };
    let identifiant = requis(brut.id, "id")?;
    if identifiant != demande {
        return Err(Erreur::ReponseInattendue(format!(
            "getArticle : demandé {demande}, reçu {identifiant}"
        )));
    }
    let en_vigueur = periode(brut.date_debut, brut.date_fin)?;
    let versions = brut
        .article_versions
        .unwrap_or_default()
        .into_iter()
        .map(|version| {
            Ok(VersionArticle {
                identifiant: requis(version.id, "articleVersions.id")?,
                etat: version.etat.unwrap_or_default(),
                en_vigueur: periode(version.date_debut, version.date_fin)?,
            })
        })
        .collect::<Resultat<Vec<_>>>()?;
    let titre = brut.text_titles.unwrap_or_default().into_iter().next();
    Ok(Article {
        cid: brut.cid.unwrap_or_else(|| identifiant.clone()),
        identifiant,
        numero: requis(brut.num, "num")?,
        etat: brut.etat.unwrap_or_default(),
        en_vigueur,
        // texteHtml porte les paragraphes ; texte les aplatit en un bloc.
        texte: requis(
            brut.texte_html
                .as_deref()
                .map(texte_depuis_html)
                .filter(|texte| !texte.is_empty())
                .or(brut.texte),
            "texte",
        )?,
        titre_texte: titre.as_ref().and_then(|titre| titre.titre.clone()),
        nature_texte: titre.and_then(|titre| titre.nature),
        versions,
    })
}

/// Texte d'un article depuis son HTML Légifrance, un paragraphe par bloc,
/// séparés par une ligne vide. Deux formes coexistent à la source : des
/// paragraphes encadrés (`<p>…</p>`), et des `<p></p>` vides posés entre des
/// paragraphes laissés hors balise. Toute balise de bloc vaut donc coupure ;
/// les autres balises (liens) sont retirées, leur texte gardé ; les entités
/// sont décodées et les blancs d'un paragraphe ramenés à un seul.
fn texte_depuis_html(html: &str) -> String {
    let mut paragraphes: Vec<String> = Vec::new();
    let mut courant = String::new();
    let mut reste = html;
    while let Some(debut) = reste.find('<') {
        courant.push_str(reste.get(..debut).unwrap_or_default());
        let apres = reste.get(debut..).unwrap_or_default();
        let Some(fin) = apres.find('>') else {
            courant.push_str(apres);
            reste = "";
            break;
        };
        let balise = apres.get(1..fin).unwrap_or_default();
        let nom: String = balise
            .trim_start_matches('/')
            .chars()
            .take_while(char::is_ascii_alphanumeric)
            .collect::<String>()
            .to_ascii_lowercase();
        if matches!(
            nom.as_str(),
            "p" | "br" | "div" | "li" | "tr" | "h1" | "h2" | "h3" | "h4"
        ) {
            paragraphes.push(std::mem::take(&mut courant));
        }
        reste = apres.get(fin + 1..).unwrap_or_default();
    }
    courant.push_str(reste);
    paragraphes.push(courant);
    paragraphes
        .iter()
        .map(|paragraphe| {
            decoder_entites(paragraphe)
                .split_whitespace()
                .collect::<Vec<_>>()
                .join(" ")
        })
        .filter(|paragraphe| !paragraphe.is_empty())
        .collect::<Vec<_>>()
        .join("\n\n")
}

/// Décode les entités HTML nommées courantes et numériques ; une entité
/// inconnue est laissée telle quelle.
fn decoder_entites(texte: &str) -> String {
    let mut sortie = String::with_capacity(texte.len());
    let mut reste = texte;
    while let Some(debut) = reste.find('&') {
        sortie.push_str(reste.get(..debut).unwrap_or_default());
        let apres = reste.get(debut..).unwrap_or_default();
        let entite = apres
            .find(';')
            .and_then(|fin| apres.get(1..fin).map(|nom| (nom, fin)));
        let decode = entite.and_then(|(nom, fin)| {
            let caractere = match nom {
                "amp" => Some('&'),
                "lt" => Some('<'),
                "gt" => Some('>'),
                "quot" => Some('"'),
                "apos" => Some('\''),
                "nbsp" => Some('\u{a0}'),
                _ => nom
                    .strip_prefix("#x")
                    .or_else(|| nom.strip_prefix("#X"))
                    .and_then(|hexa| u32::from_str_radix(hexa, 16).ok())
                    .or_else(|| nom.strip_prefix('#').and_then(|dec| dec.parse().ok()))
                    .and_then(char::from_u32),
            };
            caractere.map(|c| (c, fin))
        });
        match decode {
            Some((caractere, fin)) => {
                sortie.push(caractere);
                reste = apres.get(fin + 1..).unwrap_or_default();
            }
            None => {
                sortie.push('&');
                reste = apres.get(1..).unwrap_or_default();
            }
        }
    }
    sortie.push_str(reste);
    sortie
}

fn periode(debut: Option<DateSource>, fin: Option<DateSource>) -> Resultat<Periode> {
    let debut = debut
        .ok_or_else(|| Erreur::ReponseInattendue("date de début de vigueur absente".to_owned()))?
        .date()?;
    let fin = fin.map(DateSource::date).transpose()?;
    Ok(Periode::new(debut, fin))
}

/// La spécification annonce des dates ISO ; l'API rend en pratique des
/// millisecondes depuis l'époque Unix. Les deux formes sont admises.
#[derive(Deserialize)]
#[serde(untagged)]
enum DateSource {
    Millis(i64),
    Texte(String),
}

impl DateSource {
    fn date(self) -> Resultat<Date> {
        match self {
            Self::Millis(millis) => date_depuis_millis(millis),
            Self::Texte(texte) => match texte.get(..10) {
                Some(jour) => lire_date(jour),
                None => Err(Erreur::DateInvalide(texte)),
            },
        }
    }
}

#[derive(Deserialize)]
struct ReponseArticle {
    article: Option<ArticleBrut>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ArticleBrut {
    id: Option<String>,
    cid: Option<String>,
    num: Option<String>,
    etat: Option<String>,
    date_debut: Option<DateSource>,
    date_fin: Option<DateSource>,
    texte: Option<String>,
    texte_html: Option<String>,
    text_titles: Option<Vec<TitreBrut>>,
    article_versions: Option<Vec<VersionBrute>>,
}

#[derive(Deserialize)]
struct TitreBrut {
    titre: Option<String>,
    nature: Option<String>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct VersionBrute {
    id: Option<String>,
    etat: Option<String>,
    date_debut: Option<DateSource>,
    date_fin: Option<DateSource>,
}

#[cfg(test)]
pub(crate) mod tests {
    use std::cell::RefCell;

    use time::macros::date;

    use super::*;

    /// Source factice : rend une réponse fixée et note les appels.
    pub(crate) struct SourceFactice {
        pub(crate) reponse: Value,
        pub(crate) appels: RefCell<Vec<(String, Value)>>,
    }

    impl SourceFactice {
        pub(crate) fn new(reponse: Value) -> Self {
            Self {
                reponse,
                appels: RefCell::new(Vec::new()),
            }
        }
    }

    impl SourcePiste for SourceFactice {
        fn post_json(&self, chemin: &str, corps: &Value) -> Resultat<Value> {
            self.appels
                .borrow_mut()
                .push((chemin.to_owned(), corps.clone()));
            Ok(self.reponse.clone())
        }

        fn get_json(&self, chemin: &str, parametres: &[(&str, &str)]) -> Resultat<Value> {
            let parametres: serde_json::Map<String, Value> = parametres
                .iter()
                .map(|(cle, valeur)| ((*cle).to_owned(), Value::from(*valeur)))
                .collect();
            self.appels
                .borrow_mut()
                .push((chemin.to_owned(), Value::Object(parametres)));
            Ok(self.reponse.clone())
        }
    }

    /// Réponse de forme réelle (champs de la spécification 2.4.2) ; le
    /// contenu est fictif et ne cite aucun identifiant réel.
    pub(crate) fn reponse_fictive() -> Value {
        json!({
            "article": {
                "id": "LEGIARTI000000000002",
                "cid": "LEGIARTI000000000001",
                "num": "673",
                "etat": "VIGUEUR",
                "dateDebut": 1_475_272_800_000_i64,
                "dateFin": 32_472_144_000_000_i64,
                "texte": "Texte fictif de l'article.",
                "textTitles": [{ "titre": "Code civil", "nature": "CODE" }],
                "articleVersions": [
                    { "id": "LEGIARTI000000000001", "etat": "MODIFIE",
                      "dateDebut": -5_330_000_000_000_i64, "dateFin": 1_475_272_800_000_i64 },
                    { "id": "LEGIARTI000000000002", "etat": "VIGUEUR",
                      "dateDebut": 1_475_272_800_000_i64, "dateFin": 32_472_144_000_000_i64 }
                ]
            },
            "executionTime": 12
        })
    }

    // [utest->req~capture-des-sources-officielles~2]
    #[test]
    fn un_article_est_lu_avec_son_identifiant_sa_version_et_ses_versions() {
        let source = SourceFactice::new(reponse_fictive());
        let article = lire_article(&source, "LEGIARTI000000000002").unwrap();
        assert_eq!(article.cid, "LEGIARTI000000000001");
        assert_eq!(
            article.en_vigueur,
            Periode::new(date!(2016 - 10 - 01), None)
        );
        assert_eq!(article.versions.len(), 2);
        assert_eq!(article.intitule(), "Code civil, article 673");
        assert_eq!(
            article.source(),
            "https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000002"
        );
    }

    #[test]
    fn la_demande_porte_l_identifiant_sur_getarticle() {
        let source = SourceFactice::new(reponse_fictive());
        lire_article(&source, "LEGIARTI000000000002").unwrap();
        let appels = source.appels.borrow();
        assert_eq!(appels.len(), 1);
        assert_eq!(
            appels[0].0,
            "/dila/legifrance/lf-engine-app/consult/getArticle"
        );
        assert_eq!(appels[0].1, json!({ "id": "LEGIARTI000000000002" }));
    }

    #[test]
    fn un_identifiant_mal_forme_n_interroge_pas_la_source() {
        let source = SourceFactice::new(reponse_fictive());
        assert!(matches!(
            lire_article(&source, "LEGIARTI12"),
            Err(Erreur::IdentifiantInvalide(..))
        ));
        assert!(source.appels.borrow().is_empty());
    }

    #[test]
    fn un_article_sans_texte_est_refuse() {
        let mut reponse = reponse_fictive();
        reponse["article"]["texte"] = Value::Null;
        let source = SourceFactice::new(reponse);
        assert!(matches!(
            lire_article(&source, "LEGIARTI000000000002"),
            Err(Erreur::ReponseInattendue(_))
        ));
    }

    #[test]
    fn un_article_absent_est_introuvable() {
        let source = SourceFactice::new(json!({ "article": null }));
        assert!(matches!(
            lire_article(&source, "LEGIARTI000000000002"),
            Err(Erreur::Introuvable(_))
        ));
    }

    #[test]
    fn une_reponse_pour_un_autre_identifiant_est_refusee() {
        let source = SourceFactice::new(reponse_fictive());
        assert!(matches!(
            lire_article(&source, "LEGIARTI000000000009"),
            Err(Erreur::ReponseInattendue(_))
        ));
    }

    #[test]
    fn les_dates_iso_sont_admises() {
        let mut reponse = reponse_fictive();
        reponse["article"]["dateDebut"] = json!("2016-10-01T00:00:00.000+0000");
        let source = SourceFactice::new(reponse);
        let article = lire_article(&source, "LEGIARTI000000000002").unwrap();
        assert_eq!(article.en_vigueur.debut, date!(2016 - 10 - 01));
    }

    // [utest->req~capture-des-sources-officielles~2]
    #[test]
    fn les_paragraphes_du_html_encadre_sont_conserves() {
        let html = "<p>Premier alinéa, selon <a href=\"/x?id=LEGIARTI000000000003\">l'article 6</a> :</p><p>  I. Second   alinéa &amp; suite.</p>";
        assert_eq!(
            texte_depuis_html(html),
            "Premier alinéa, selon l'article 6 :\n\nI. Second alinéa & suite."
        );
    }

    #[test]
    fn les_paragraphes_separes_par_des_balises_vides_sont_conserves() {
        let html = "<p></p>   Premier alinéa :<p></p><p></p><p></p>   I. Second.<p></p>";
        assert_eq!(texte_depuis_html(html), "Premier alinéa :\n\nI. Second.");
    }

    #[test]
    fn les_entites_numeriques_sont_decodees_et_les_inconnues_gardees() {
        assert_eq!(
            decoder_entites("&#233;t&#xE9; &inconnue; a&b"),
            "été &inconnue; a&b"
        );
    }

    #[test]
    fn le_html_prime_sur_le_texte_aplati() {
        let mut reponse = reponse_fictive();
        reponse["article"]["texteHtml"] = json!("<p>Alinéa un.</p><p>Alinéa deux.</p>");
        let source = SourceFactice::new(reponse);
        let article = lire_article(&source, "LEGIARTI000000000002").unwrap();
        assert_eq!(article.texte, "Alinéa un.\n\nAlinéa deux.");
    }

    #[test]
    fn sans_html_le_texte_aplati_est_garde() {
        let source = SourceFactice::new(reponse_fictive());
        let article = lire_article(&source, "LEGIARTI000000000002").unwrap();
        assert_eq!(article.texte, "Texte fictif de l'article.");
    }

    #[test]
    fn un_texte_hors_code_pointe_vers_le_fonds_loda() {
        let mut reponse = reponse_fictive();
        reponse["article"]["textTitles"] = json!([{ "titre": "Loi fictive", "nature": "LOI" }]);
        let source = SourceFactice::new(reponse);
        let article = lire_article(&source, "LEGIARTI000000000002").unwrap();
        assert!(article.source().contains("/loda/article_lc/"));
    }
}
