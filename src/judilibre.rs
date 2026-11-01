// SPDX-License-Identifier: EUPL-1.2
//! Lecture d'une décision sur l'API Judilibre (`GET /decision`).
//!
//! Forme des réponses : spécification publique de Judilibre (Cour de
//! cassation, `JUDILIBRE-public.json`). Une décision sans ECLI n'est pas
//! ancrable : elle est refusée.

use serde::Deserialize;
use serde_json::Value;
use time::Date;

use crate::erreur::{Erreur, Resultat};
use crate::periode::lire_date;
use crate::piste::SourcePiste;

/// Racine de l'API Judilibre sur PISTE.
const RACINE: &str = "/cassation/judilibre/v1.0";

/// Une décision, réduite à ce qui ancre une citation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Decision {
    /// Identifiant Judilibre (24 caractères hexadécimaux).
    pub identifiant_judilibre: String,
    /// Identifiant européen de la jurisprudence (`ECLI:FR:…`).
    pub ecli: String,
    /// Juridiction (`cc`, `ca`…).
    pub juridiction: String,
    /// Chambre (`civ3`, `soc`…), si rendue.
    pub chambre: Option<String>,
    /// Numéro de pourvoi ou de rôle, si rendu.
    pub numero: Option<String>,
    /// Date de la décision.
    pub date: Date,
    /// Texte intégral, tel que rendu par la source.
    pub texte: String,
}

impl Decision {
    /// Intitulé lisible : « cc civ3, 2018-12-20, n° 17-18.194 ».
    pub fn intitule(&self) -> String {
        let mut intitule = self.juridiction.clone();
        if let Some(chambre) = &self.chambre {
            intitule.push(' ');
            intitule.push_str(chambre);
        }
        intitule.push_str(", ");
        intitule.push_str(&crate::periode::ecrire_date(self.date));
        if let Some(numero) = &self.numero {
            intitule.push_str(", n° ");
            intitule.push_str(numero);
        }
        intitule
    }

    /// Adresse publique de la décision sur le site de la Cour de cassation.
    pub fn source(&self) -> String {
        format!(
            "https://www.courdecassation.fr/decision/{}",
            self.identifiant_judilibre
        )
    }
}

/// Vérifie la forme d'un identifiant Judilibre : 24 caractères
/// hexadécimaux.
pub fn verifier_identifiant(identifiant: &str) -> Resultat<()> {
    if identifiant.len() == 24 && identifiant.bytes().all(|octet| octet.is_ascii_hexdigit()) {
        Ok(())
    } else {
        Err(Erreur::IdentifiantInvalide(
            identifiant.to_owned(),
            "identifiant Judilibre de 24 caractères hexadécimaux",
        ))
    }
}

// [impl->req~capture-des-sources-officielles~1]
/// Lit une décision par son identifiant Judilibre.
pub fn lire_decision(source: &impl SourcePiste, identifiant: &str) -> Resultat<Decision> {
    verifier_identifiant(identifiant)?;
    let reponse = source.get_json(&format!("{RACINE}/decision"), &[("id", identifiant)])?;
    decision_depuis_reponse(reponse, identifiant)
}

fn decision_depuis_reponse(reponse: Value, demande: &str) -> Resultat<Decision> {
    let brut: DecisionBrute = serde_json::from_value(reponse)
        .map_err(|cause| Erreur::ReponseInattendue(format!("decision : {cause}")))?;
    let requis = |champ: Option<String>, nom: &str| {
        champ
            .filter(|valeur| !valeur.trim().is_empty())
            .ok_or_else(|| Erreur::ReponseInattendue(format!("decision : champ « {nom} » absent")))
    };
    let identifiant = requis(brut.id, "id")?;
    if identifiant != demande {
        return Err(Erreur::ReponseInattendue(format!(
            "decision : demandé {demande}, reçu {identifiant}"
        )));
    }
    let ecli = requis(brut.ecli, "ecli")?;
    if !ecli.starts_with("ECLI:") {
        return Err(Erreur::ReponseInattendue(format!(
            "decision : ECLI mal formé « {ecli} »"
        )));
    }
    let date = requis(brut.decision_date, "decision_date")?;
    Ok(Decision {
        identifiant_judilibre: identifiant,
        ecli,
        juridiction: requis(brut.jurisdiction, "jurisdiction")?,
        chambre: brut.chamber.filter(|chambre| !chambre.is_empty()),
        numero: brut.number.filter(|numero| !numero.is_empty()),
        date: lire_date(date.get(..10).unwrap_or(&date))?,
        texte: requis(brut.text, "text")?,
    })
}

#[derive(Deserialize)]
struct DecisionBrute {
    id: Option<String>,
    ecli: Option<String>,
    jurisdiction: Option<String>,
    chamber: Option<String>,
    number: Option<String>,
    decision_date: Option<String>,
    text: Option<String>,
}

#[cfg(test)]
pub(crate) mod tests {
    use serde_json::json;
    use time::macros::date;

    use super::*;
    use crate::legifrance::tests::SourceFactice;

    /// Réponse de forme réelle (champs de la spécification publique) ; le
    /// contenu est fictif.
    pub(crate) fn reponse_fictive() -> Value {
        json!({
            "id": "000000000000000000000abc",
            "jurisdiction": "cc",
            "chamber": "civ3",
            "number": "00-00.000",
            "ecli": "ECLI:FR:CCASS:2000:C300000",
            "decision_date": "2000-01-01",
            "text": "Texte fictif de la décision.",
            "update_date": "2000-01-02"
        })
    }

    // [utest->req~capture-des-sources-officielles~1]
    #[test]
    fn une_decision_est_lue_avec_son_ecli_et_sa_date() {
        let source = SourceFactice::new(reponse_fictive());
        let decision = lire_decision(&source, "000000000000000000000abc").unwrap();
        assert_eq!(decision.ecli, "ECLI:FR:CCASS:2000:C300000");
        assert_eq!(decision.date, date!(2000 - 01 - 01));
        assert_eq!(decision.intitule(), "cc civ3, 2000-01-01, n° 00-00.000");
        let appels = source.appels.borrow();
        assert_eq!(appels[0].0, "/cassation/judilibre/v1.0/decision");
        assert_eq!(appels[0].1, json!({ "id": "000000000000000000000abc" }));
    }

    #[test]
    fn une_decision_sans_ecli_est_refusee() {
        let mut reponse = reponse_fictive();
        reponse["ecli"] = Value::Null;
        let source = SourceFactice::new(reponse);
        assert!(matches!(
            lire_decision(&source, "000000000000000000000abc"),
            Err(Erreur::ReponseInattendue(_))
        ));
    }

    #[test]
    fn un_identifiant_mal_forme_n_interroge_pas_la_source() {
        let source = SourceFactice::new(reponse_fictive());
        assert!(matches!(
            lire_decision(&source, "pas-un-identifiant"),
            Err(Erreur::IdentifiantInvalide(..))
        ));
        assert!(source.appels.borrow().is_empty());
    }
}
