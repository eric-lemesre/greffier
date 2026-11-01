// SPDX-License-Identifier: EUPL-1.2
//! Constat des changements de version d'un article depuis une date.
//!
//! Matériau de la péremption : une page vérifiée le `depuis` est à revoir
//! si l'article qu'elle cite a, depuis, une nouvelle version en vigueur ou
//! a cessé de l'être.

// [impl->req~detection-des-versions~1]

use time::Date;

use crate::legifrance::{Article, VersionArticle};

/// Ce que la source dit d'un article par rapport à une date.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Constat {
    /// Versions entrées en vigueur après la date.
    pub nouvelles_versions: Vec<VersionArticle>,
    /// Fin de vigueur de la version citée, si elle est postérieure à la
    /// date.
    pub fin_de_vigueur: Option<Date>,
}

impl Constat {
    /// L'article a-t-il changé depuis la date ?
    pub fn a_change(&self) -> bool {
        !self.nouvelles_versions.is_empty() || self.fin_de_vigueur.is_some()
    }
}

/// Constate les changements d'un article depuis `depuis` (exclu).
pub fn constater(article: &Article, depuis: Date) -> Constat {
    Constat {
        nouvelles_versions: article
            .versions
            .iter()
            .filter(|version| version.en_vigueur.debut > depuis)
            .cloned()
            .collect(),
        fin_de_vigueur: article.en_vigueur.fin.filter(|fin| *fin > depuis),
    }
}

#[cfg(test)]
mod tests {
    use time::macros::date;

    use super::*;
    use crate::legifrance::{
        lire_article,
        tests::{SourceFactice, reponse_fictive},
    };

    fn article(identifiant: &str) -> Article {
        lire_article(
            &SourceFactice::new(reponse_fictive()),
            "LEGIARTI000000000002",
        )
        .map(|mut article| {
            article.identifiant = identifiant.to_owned();
            article
        })
        .unwrap()
    }

    // [utest->req~detection-des-versions~1]
    #[test]
    fn une_version_entree_en_vigueur_apres_la_date_est_signalee() {
        let constat = constater(&article("LEGIARTI000000000002"), date!(2015 - 01 - 01));
        assert!(constat.a_change());
        assert_eq!(constat.nouvelles_versions.len(), 1);
        assert_eq!(
            constat.nouvelles_versions[0].identifiant,
            "LEGIARTI000000000002"
        );
    }

    // [utest->req~detection-des-versions~1]
    #[test]
    fn rien_n_est_signale_quand_rien_n_a_change_depuis_la_date() {
        let constat = constater(&article("LEGIARTI000000000002"), date!(2026 - 11 - 01));
        assert!(!constat.a_change());
    }

    // [utest->req~detection-des-versions~1]
    #[test]
    fn la_fin_de_vigueur_de_la_version_citee_est_signalee() {
        let mut ancienne = article("LEGIARTI000000000001");
        ancienne.en_vigueur.fin = Some(date!(2016 - 10 - 01));
        ancienne.versions.clear();
        let constat = constater(&ancienne, date!(2015 - 01 - 01));
        assert_eq!(constat.fin_de_vigueur, Some(date!(2016 - 10 - 01)));
        assert!(constat.a_change());
    }
}
