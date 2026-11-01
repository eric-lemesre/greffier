// SPDX-License-Identifier: EUPL-1.2
//! Banc de questions : la mesure de la recherche sur un dépôt de savoir.
//!
//! Le banc (`banc/questions.tsv` du savoir) donne, pour chaque question
//! posée dans les mots de la vie courante, la date des faits, les
//! identifiants officiels attendus et la page de situation attendue. La
//! mesure rend le rappel, la précision et le délai ; un élément rendu sans
//! ancrage n'est pas une mesure mais un échec.

// [impl->req~citation-ancree~1]

use std::collections::BTreeSet;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use time::Date;

use crate::erreur::{Erreur, Resultat};
use crate::periode::lire_date;
use crate::recherche::Index;
use crate::verifier::identifiants_cites;

/// Fichier du banc, relatif au dépôt de savoir.
pub const FICHIER_DU_BANC: &str = "banc/questions.tsv";

/// Colonnes du banc : id, question, date, attendus, situation, source.
const COLONNES: usize = 6;

/// Une question du banc.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Question {
    /// Identifiant court, stable.
    pub id: String,
    /// La question, dans les mots du justiciable.
    pub question: String,
    /// Date des faits : le droit applicable est celui de cette date.
    pub date: Date,
    /// Identifiants officiels attendus dans la réponse.
    pub attendus: BTreeSet<String>,
    /// Page de situation attendue (`wiki/situations/<nom>`), s'il y en a une.
    pub situation: Option<String>,
}

/// Lit le banc (format TSV, ligne d'en-tête `id…` admise).
pub fn lire_banc(contenu: &str) -> Resultat<Vec<Question>> {
    let mut questions = Vec::new();
    for (rang, ligne) in contenu.lines().enumerate() {
        let numero = rang + 1;
        if ligne.trim().is_empty() || ligne.starts_with("id\t") || ligne.starts_with('#') {
            continue;
        }
        let colonnes: Vec<&str> = ligne.split('\t').collect();
        let [id, question, date, attendus, situation, _source] = colonnes.as_slice() else {
            return Err(Erreur::BancMalForme {
                ligne: numero,
                cause: format!("{COLONNES} colonnes attendues, {} trouvées", colonnes.len()),
            });
        };
        let date = lire_date(date.trim()).map_err(|erreur| Erreur::BancMalForme {
            ligne: numero,
            cause: erreur.to_string(),
        })?;
        questions.push(Question {
            id: id.trim().to_owned(),
            question: question.trim().to_owned(),
            date,
            attendus: identifiants_cites(attendus),
            situation: Some(situation.trim())
                .filter(|s| !s.is_empty())
                .map(str::to_owned),
        });
    }
    Ok(questions)
}

/// Mesure d'une question.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MesureQuestion {
    /// Identifiant de la question.
    pub id: String,
    /// Nombre d'identifiants attendus ; zéro rend la question non mesurable.
    pub attendus: usize,
    /// Identifiants attendus retrouvés (par identifiant ou par cid).
    pub retrouves: usize,
    /// Éléments rendus.
    pub rendus: usize,
    /// Éléments rendus qui portent un identifiant attendu.
    pub pertinents: usize,
    /// La page de situation attendue est-elle rendue ? (`None` : aucune
    /// n'est attendue.)
    pub situation: Option<bool>,
    /// Durée de la recherche.
    pub delai: Duration,
    /// Éléments rendus que la porte de l'ancrage refuse : doit rester nul.
    pub non_ancres: usize,
}

impl MesureQuestion {
    /// La question a-t-elle des identifiants attendus ?
    pub fn mesurable(&self) -> bool {
        self.attendus > 0
    }
}

/// Mesure d'un banc.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MesureBanc {
    /// Mesures, dans l'ordre du banc.
    pub questions: Vec<MesureQuestion>,
}

impl MesureBanc {
    /// Rappel cumulé des questions mesurables : (retrouvés, attendus).
    pub fn rappel(&self) -> (usize, usize) {
        self.mesurables()
            .fold((0, 0), |(r, a), q| (r + q.retrouves, a + q.attendus))
    }

    /// Précision cumulée des questions mesurables : (pertinents, rendus).
    pub fn precision(&self) -> (usize, usize) {
        self.mesurables()
            .fold((0, 0), |(p, r), q| (p + q.pertinents, r + q.rendus))
    }

    /// Délai médian d'une recherche.
    pub fn delai_median(&self) -> Duration {
        let mut delais: Vec<Duration> = self.questions.iter().map(|q| q.delai).collect();
        delais.sort();
        delais.get(delais.len() / 2).copied().unwrap_or_default()
    }

    /// Délai maximal d'une recherche.
    pub fn delai_max(&self) -> Duration {
        self.questions
            .iter()
            .map(|q| q.delai)
            .max()
            .unwrap_or_default()
    }

    /// Éléments rendus sans ancrage, toutes questions confondues.
    pub fn non_ancres(&self) -> usize {
        self.questions.iter().map(|q| q.non_ancres).sum()
    }

    /// Le banc est-il en échec (un élément rendu sans ancrage) ?
    pub fn en_echec(&self) -> bool {
        self.non_ancres() > 0
    }

    fn mesurables(&self) -> impl Iterator<Item = &MesureQuestion> {
        self.questions.iter().filter(|q| q.mesurable())
    }
}

/// Joue chaque question du banc sur l'index ; au plus `max` éléments rendus
/// par question.
pub fn mesurer(index: &Index, questions: &[Question], max: usize) -> MesureBanc {
    let questions = questions
        .iter()
        .map(|question| {
            let debut = Instant::now();
            let reponse = index.chercher(&question.question, question.date, max);
            let delai = debut.elapsed();

            let porte = |trouve: &crate::recherche::Trouve| -> Vec<String> {
                trouve
                    .identifiants
                    .iter()
                    .chain(trouve.cid.iter())
                    .cloned()
                    .collect()
            };
            let rendus: BTreeSet<String> = reponse.retenus.iter().flat_map(porte).collect();
            let attendue = question
                .situation
                .as_ref()
                .map(|s| PathBuf::from(format!("{}.md", s.trim_end_matches(".md"))));
            // La porte rejouée sur chaque élément rendu : un garde-fou contre
            // une régression de la recherche elle-même.
            let non_ancres = reponse
                .retenus
                .iter()
                .filter(|trouve| {
                    let identifiants = trouve.identifiants.iter().cloned().collect();
                    index
                        .ancres()
                        .verdict(&identifiants, question.date)
                        .is_err()
                })
                .count();
            MesureQuestion {
                id: question.id.clone(),
                attendus: question.attendus.len(),
                retrouves: question
                    .attendus
                    .iter()
                    .filter(|a| rendus.contains(*a))
                    .count(),
                rendus: reponse.retenus.len(),
                pertinents: reponse
                    .retenus
                    .iter()
                    .filter(|t| porte(t).iter().any(|i| question.attendus.contains(i)))
                    .count(),
                situation: attendue
                    .map(|chemin| reponse.retenus.iter().any(|t| t.chemin == chemin)),
                delai,
                non_ancres,
            }
        })
        .collect();
    MesureBanc { questions }
}

#[cfg(test)]
mod tests {
    use time::macros::date;

    use super::*;
    use crate::recherche::tests::Savoir;

    const BANC: &str = "id\tquestion\tdate\tattendus\tsituation\tsource\n\
        Q001\tLes branches de l'arbre du voisin dépassent chez moi\t2026-11-01\tLEGIARTI000000000001\twiki/situations/arbres-du-voisin\tcas type\n\
        Q002\tLes branches du voisin, en 2010\t2010-05-05\tLEGIARTI000000000001\t\tcas type\n\
        Q003\tUne question sans attendu\t2026-11-01\tà relever\t\tcas type\n";

    #[test]
    fn le_banc_est_lu_avec_ses_attendus_et_sa_situation() {
        let questions = lire_banc(BANC).unwrap();
        assert_eq!(questions.len(), 3);
        let premiere = questions.first().unwrap();
        assert_eq!(premiere.date, date!(2026 - 11 - 01));
        assert!(premiere.attendus.contains("LEGIARTI000000000001"));
        assert_eq!(
            premiere.situation.as_deref(),
            Some("wiki/situations/arbres-du-voisin")
        );
        assert!(questions.get(2).unwrap().attendus.is_empty());
    }

    #[test]
    fn une_ligne_du_banc_mal_formee_est_une_erreur() {
        assert!(matches!(
            lire_banc("Q001\tquestion\t2026-11-01\n"),
            Err(Erreur::BancMalForme { ligne: 1, .. })
        ));
        assert!(matches!(
            lire_banc("Q001\tquestion\thier\t\t\t\n"),
            Err(Erreur::BancMalForme { ligne: 1, .. })
        ));
    }

    // [utest->req~citation-ancree~1]
    #[test]
    fn le_banc_mesure_rappel_et_precision_sans_aucun_element_non_ancre() {
        let savoir = Savoir::new("banc");
        let mesure = mesurer(&savoir.index(), &lire_banc(BANC).unwrap(), 10);
        assert_eq!(mesure.non_ancres(), 0);
        assert!(!mesure.en_echec());
        let q1 = mesure.questions.first().unwrap();
        assert_eq!((q1.retrouves, q1.attendus), (1, 1));
        assert_eq!(q1.situation, Some(true));
        // Q001 rend la version en vigueur (par son cid) et la page ; Q002,
        // en 2010, l'ancienne version seule.
        let (retrouves, attendus) = mesure.rappel();
        assert_eq!((retrouves, attendus), (2, 2));
        let (pertinents, rendus) = mesure.precision();
        assert!(pertinents >= 2 && pertinents <= rendus);
        assert!(!mesure.questions.get(2).unwrap().mesurable());
    }
}
