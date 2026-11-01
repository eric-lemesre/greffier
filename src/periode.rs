// SPDX-License-Identifier: EUPL-1.2
// Exigence servie : req~textes-authentiques-versionnes~1
//! Dates et périodes de vigueur.

use std::fmt;

use time::{Date, Duration, OffsetDateTime, macros::format_description};

use crate::erreur::{Erreur, Resultat};

/// Première année tenue pour « sans fin » : Légifrance note la fin d'un
/// texte toujours en vigueur au 1er janvier 2999.
const ANNEE_SANS_FIN: i32 = 2999;

/// Lit une date au format AAAA-MM-JJ.
pub fn lire_date(texte: &str) -> Resultat<Date> {
    Date::parse(texte, format_description!("[year]-[month]-[day]"))
        .map_err(|_| Erreur::DateInvalide(texte.to_owned()))
}

/// Écrit une date au format AAAA-MM-JJ.
pub fn ecrire_date(date: Date) -> String {
    let (annee, mois, jour) = (date.year(), u8::from(date.month()), date.day());
    format!("{annee:04}-{mois:02}-{jour:02}")
}

/// Date du jour (UTC).
pub fn aujourdhui() -> Date {
    OffsetDateTime::now_utc().date()
}

/// Convertit un instant Légifrance (millisecondes depuis l'époque Unix) en
/// date civile.
///
/// Légifrance date ses versions à minuit, sans dire si c'est minuit UTC ou
/// minuit à Paris (une à deux heures plus tôt en UTC). On décale de douze
/// heures avant de prendre la date UTC : les deux lectures tombent alors
/// sur le même jour civil.
pub fn date_depuis_millis(millis: i64) -> Resultat<Date> {
    let secondes = millis.div_euclid(1000);
    OffsetDateTime::from_unix_timestamp(secondes)
        .map(|instant| (instant + Duration::hours(12)).date())
        .map_err(|_| Erreur::ReponseInattendue(format!("instant hors bornes : {millis}")))
}

/// Période de vigueur d'un texte : du `debut` (inclus) à la `fin` (exclue),
/// `None` quand le texte est toujours en vigueur.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Periode {
    /// Entrée en vigueur.
    pub debut: Date,
    /// Fin de vigueur, absente pour un texte toujours en vigueur.
    pub fin: Option<Date>,
}

impl Periode {
    /// Construit une période ; une fin en 2999 ou au-delà vaut « sans fin ».
    pub fn new(debut: Date, fin: Option<Date>) -> Self {
        let fin = fin.filter(|date| date.year() < ANNEE_SANS_FIN);
        Self { debut, fin }
    }

    /// La période couvre-t-elle cette date ?
    pub fn couvre(&self, date: Date) -> bool {
        self.debut <= date && self.fin.is_none_or(|fin| date < fin)
    }

    /// Relit une période écrite par [`fmt::Display`] (« AAAA-MM-JJ / — »).
    pub fn lire(texte: &str) -> Resultat<Self> {
        let (debut, fin) = texte
            .split_once(" / ")
            .ok_or_else(|| Erreur::DateInvalide(texte.to_owned()))?;
        let fin = match fin.trim() {
            "—" => None,
            date => Some(lire_date(date)?),
        };
        Ok(Self::new(lire_date(debut.trim())?, fin))
    }
}

impl fmt::Display for Periode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.fin {
            Some(fin) => write!(f, "{} / {}", ecrire_date(self.debut), ecrire_date(fin)),
            None => write!(f, "{} / —", ecrire_date(self.debut)),
        }
    }
}

#[cfg(test)]
mod tests {
    use time::macros::date;

    use super::*;

    #[test]
    fn instant_a_minuit_utc_donne_le_jour_meme() {
        // 2016-10-01T00:00:00Z
        assert_eq!(
            date_depuis_millis(1_475_280_000_000).unwrap(),
            date!(2016 - 10 - 01)
        );
    }

    #[test]
    fn instant_a_minuit_paris_donne_le_jour_meme() {
        // 2016-10-01T00:00:00+02:00 = 2016-09-30T22:00:00Z
        assert_eq!(
            date_depuis_millis(1_475_272_800_000).unwrap(),
            date!(2016 - 10 - 01)
        );
    }

    #[test]
    fn fin_en_2999_vaut_sans_fin() {
        let fin = date_depuis_millis(32_472_144_000_000).unwrap();
        assert_eq!(Periode::new(date!(1804 - 03 - 21), Some(fin)).fin, None);
    }

    #[test]
    fn la_fin_est_exclue_de_la_periode() {
        let periode = Periode::new(date!(2000 - 01 - 01), Some(date!(2010 - 01 - 01)));
        assert!(periode.couvre(date!(2009 - 12 - 31)));
        assert!(!periode.couvre(date!(2010 - 01 - 01)));
    }

    #[test]
    fn une_periode_se_relit_comme_elle_s_ecrit() {
        for periode in [
            Periode::new(date!(1804 - 03 - 21), None),
            Periode::new(date!(2000 - 01 - 01), Some(date!(2010 - 01 - 01))),
        ] {
            assert_eq!(Periode::lire(&periode.to_string()).unwrap(), periode);
        }
    }

    #[test]
    fn une_date_mal_formee_est_refusee() {
        assert!(matches!(
            lire_date("01/11/2026"),
            Err(Erreur::DateInvalide(_))
        ));
    }
}
