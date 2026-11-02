// SPDX-License-Identifier: EUPL-1.2
//! Façade du moteur pour ses interfaces (MCP, HTTP) : les quatre opérations
//! offertes aux agents, en lecture seule sur un dépôt de savoir, et la forme
//! de leurs réponses.
//!
//! Aucune règle n'est écrite ici : la recherche et la porte de l'ancrage
//! sont celles de [`crate::recherche`], la vérification celle de
//! [`crate::verifier`]. L'index est tenu en mémoire et reconstruit dès que
//! le savoir change ; rien n'est écrit dans le savoir. Les opérations sont
//! synchrones : une interface asynchrone les appelle hors de son exécuteur.

// [impl->dsn~exposition-mcp-http~1]
// [impl->req~outils-mcp~1]
// [impl->req~api-http~1]

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::SystemTime;

use rmcp::schemars::{self, JsonSchema};
use serde::{Deserialize, Serialize};
use time::Date;

use crate::erreur::{Erreur, Resultat};
use crate::periode::{aujourdhui, ecrire_date, lire_date};
use crate::recherche::{Index, Source};
use crate::verifier::{self, Gravite, parcourir};

/// Mention portée par toute réponse qui rend du droit (ADR-0001, point 6).
pub const MENTION: &str = "aide documentaire, sans valeur d'avis";
/// Nombre d'éléments rendus par défaut.
pub const MAX_PAR_DEFAUT: usize = 10;
/// Nombre d'éléments rendus au plus, quoi qu'on demande.
pub const MAX_PLAFOND: usize = 50;
/// Dossiers dont un changement reconstruit l'index.
const DOSSIERS_INDEXES: [&str; 3] = ["raw/textes", "raw/decisions", "wiki"];

/// Paramètres de `chercher`.
#[derive(Debug, Clone, Deserialize, JsonSchema)]
pub struct ParametresChercher {
    /// La question, dans les mots de la vie courante.
    pub question: String,
    /// Date du droit applicable, AAAA-MM-JJ (par défaut : aujourd'hui).
    #[serde(default)]
    pub le: Option<String>,
    /// Nombre maximal d'éléments rendus (10 par défaut, 50 au plus).
    #[serde(default)]
    pub max: Option<usize>,
}

/// Paramètres de `lire_texte`.
#[derive(Debug, Clone, Deserialize, JsonSchema)]
pub struct ParametresLireTexte {
    /// Identifiant d'une version d'article (LEGIARTI…), identifiant
    /// chronologique de l'article, ou ECLI d'une décision.
    pub identifiant: String,
    /// Date du droit applicable, AAAA-MM-JJ (par défaut : aujourd'hui).
    #[serde(default)]
    pub le: Option<String>,
}

/// Paramètres de `verifier_citation`.
#[derive(Debug, Clone, Deserialize, JsonSchema)]
pub struct ParametresVerifierCitation {
    /// Le texte à juger, tel qu'un agent l'a produit.
    pub texte: String,
    /// Date du droit applicable, AAAA-MM-JJ (par défaut : aujourd'hui).
    #[serde(default)]
    pub le: Option<String>,
}

/// Le lien vers la source officielle d'un identifiant.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct SourceRendue {
    /// Identifiant officiel.
    pub identifiant: String,
    /// Adresse de la source officielle.
    pub url: String,
}

impl From<Source> for SourceRendue {
    fn from(source: Source) -> Self {
        Self {
            identifiant: source.identifiant,
            url: source.url,
        }
    }
}

/// Un élément rendu par `chercher`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema)]
pub struct ElementRendu {
    /// Rang, à partir de 1.
    pub rang: usize,
    /// Score lexical (BM25).
    pub score: f64,
    /// `texte`, `decision` ou `page`.
    pub nature: String,
    /// Intitulé.
    pub intitule: String,
    /// Fichier, relatif au dépôt de savoir.
    pub chemin: String,
    /// Identifiants officiels applicables à la date.
    pub identifiants: Vec<String>,
    /// Lien vers la source officielle de chaque identifiant.
    pub sources: Vec<SourceRendue>,
    /// Le paragraphe le plus proche de la question.
    pub extrait: String,
}

/// Un élément écarté par la porte de l'ancrage.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ElementEcarte {
    /// Fichier, relatif au dépôt de savoir.
    pub chemin: String,
    /// Motif de l'écart.
    pub motif: String,
}

/// Réponse de `chercher`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, JsonSchema)]
pub struct ReponseChercher {
    /// Date du droit applicable.
    pub date: String,
    /// « aide documentaire, sans valeur d'avis ».
    pub mention: String,
    /// Éléments ancrés, du plus pertinent au moins pertinent.
    pub elements: Vec<ElementRendu>,
    /// Éléments écartés, avec leur motif.
    pub ecartes: Vec<ElementEcarte>,
}

/// Réponse de `lire_texte`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ReponseTexte {
    /// Date du droit applicable.
    pub date: String,
    /// « aide documentaire, sans valeur d'avis ».
    pub mention: String,
    /// Identifiant demandé.
    pub demande: String,
    /// `texte` ou `decision`.
    pub nature: String,
    /// Identifiant de la version rendue, ou ECLI.
    pub identifiant: String,
    /// Identifiant chronologique de l'article.
    pub cid: Option<String>,
    /// Intitulé.
    pub intitule: String,
    /// Période de vigueur de la version rendue (« du / au »).
    pub en_vigueur: Option<String>,
    /// Adresse de la source officielle.
    pub source: Option<String>,
    /// Le texte conservé.
    pub texte: String,
}

/// Réponse de `verifier_citation`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ReponseCitation {
    /// Date du droit applicable.
    pub date: String,
    /// Le texte passe-t-il la porte de l'ancrage ?
    pub admise: bool,
    /// Identifiants reconnus et applicables à la date (si admise).
    pub identifiants: Vec<String>,
    /// Lien vers la source officielle de chacun.
    pub sources: Vec<SourceRendue>,
    /// Motif du refus (si refusée).
    pub motif: Option<String>,
}

/// Un constat de `verifier_savoir`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ConstatRendu {
    /// `erreur` ou `avertissement`.
    pub gravite: String,
    /// Fichier, relatif au dépôt de savoir.
    pub chemin: String,
    /// Ce qui ne va pas.
    pub message: String,
}

/// Réponse de `verifier_savoir`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, JsonSchema)]
pub struct ReponseSavoir {
    /// Le rapport est-il en échec ?
    pub en_echec: bool,
    /// Nombre d'erreurs.
    pub erreurs: usize,
    /// Nombre d'avertissements.
    pub avertissements: usize,
    /// Pages du wiki examinées.
    pub pages: usize,
    /// Sources brutes examinées.
    pub sources: usize,
    /// Constats.
    pub constats: Vec<ConstatRendu>,
}

/// Nature d'une erreur, telle qu'une interface la rend.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GenreErreur {
    /// La demande est mal formée.
    Demande,
    /// Rien ne correspond à la demande.
    Introuvable,
    /// Le moteur a échoué.
    Interne,
}

/// Une erreur rendable au-dehors : son message ne cite ni chemin du serveur
/// ni secret.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ErreurPublique {
    /// Nature de l'erreur.
    pub genre: GenreErreur,
    /// Message.
    pub message: String,
}

impl From<&Erreur> for ErreurPublique {
    fn from(erreur: &Erreur) -> Self {
        match erreur {
            Erreur::DateInvalide(_) | Erreur::IdentifiantInvalide(..) => Self {
                genre: GenreErreur::Demande,
                message: erreur.to_string(),
            },
            Erreur::Introuvable(_) => Self {
                genre: GenreErreur::Introuvable,
                message: erreur.to_string(),
            },
            _ => Self {
                genre: GenreErreur::Interne,
                message: "erreur interne du moteur".to_owned(),
            },
        }
    }
}

/// Ce qui identifie l'état du savoir : chaque fichier indexé, sa taille et
/// sa date de modification.
type Empreinte = Vec<(PathBuf, u64, Option<SystemTime>)>;

struct Charge {
    index: Arc<Index>,
    empreinte: Empreinte,
}

/// Le moteur ouvert sur un dépôt de savoir.
pub struct Service {
    nom: String,
    savoir: PathBuf,
    charge: RwLock<Charge>,
}

impl Service {
    /// Ouvre le dépôt de savoir situé à `savoir` et construit son index.
    pub fn ouvrir(savoir: &Path) -> Resultat<Self> {
        Self::ouvrir_nomme(crate::configuration::DEPOT_PAR_DEFAUT, savoir)
    }

    /// Ouvre le dépôt de savoir nommé `nom`, situé à `savoir`.
    pub fn ouvrir_nomme(nom: &str, savoir: &Path) -> Resultat<Self> {
        let debut = std::time::Instant::now();
        let empreinte = empreinte(savoir)?;
        let index = Arc::new(Index::construire(savoir)?);
        tracing::info!(
            depot = nom,
            duree_ms = millisecondes(debut),
            "index construit"
        );
        Ok(Self {
            nom: nom.to_owned(),
            savoir: savoir.to_owned(),
            charge: RwLock::new(Charge { index, empreinte }),
        })
    }

    /// L'index du savoir, reconstruit s'il a changé depuis le dernier appel.
    fn index(&self) -> Resultat<Arc<Index>> {
        let empreinte = empreinte(&self.savoir)?;
        {
            let charge = self.charge.read().map_err(|_| verrou())?;
            if charge.empreinte == empreinte {
                return Ok(Arc::clone(&charge.index));
            }
        }
        let debut = std::time::Instant::now();
        let index = Arc::new(Index::construire(&self.savoir)?);
        tracing::info!(
            depot = %self.nom,
            duree_ms = millisecondes(debut),
            "index reconstruit : le savoir a changé"
        );
        let mut charge = self.charge.write().map_err(|_| verrou())?;
        *charge = Charge {
            index: Arc::clone(&index),
            empreinte,
        };
        Ok(index)
    }

    /// Cherche les éléments ancrés qui répondent à une question.
    pub fn chercher(&self, parametres: &ParametresChercher) -> Resultat<ReponseChercher> {
        let date = date(parametres.le.as_deref())?;
        let max = parametres
            .max
            .unwrap_or(MAX_PAR_DEFAUT)
            .clamp(1, MAX_PLAFOND);
        let reponse = self.index()?.chercher(&parametres.question, date, max);
        Ok(ReponseChercher {
            date: ecrire_date(date),
            mention: MENTION.to_owned(),
            elements: reponse
                .retenus
                .into_iter()
                .enumerate()
                .map(|(rang, trouve)| ElementRendu {
                    rang: rang + 1,
                    score: (trouve.score * 100.0).round() / 100.0,
                    nature: trouve.nature.to_string(),
                    intitule: trouve.intitule,
                    chemin: chemin(&trouve.chemin),
                    identifiants: trouve.identifiants,
                    sources: trouve.sources.into_iter().map(SourceRendue::from).collect(),
                    extrait: trouve.extrait,
                })
                .collect(),
            ecartes: reponse
                .ecartes
                .into_iter()
                .map(|ecart| ElementEcarte {
                    chemin: chemin(&ecart.chemin),
                    motif: ecart.motif.to_string(),
                })
                .collect(),
        })
    }

    /// Rend le texte conservé que désigne un identifiant, applicable à une
    /// date.
    pub fn lire_texte(&self, parametres: &ParametresLireTexte) -> Resultat<ReponseTexte> {
        let date = date(parametres.le.as_deref())?;
        let demande = parametres.identifiant.trim();
        let texte = self.index()?.lire(demande, date).ok_or_else(|| {
            Erreur::Introuvable(format!(
                "aucun texte conservé « {demande} » applicable le {}",
                ecrire_date(date)
            ))
        })?;
        Ok(ReponseTexte {
            date: ecrire_date(date),
            mention: MENTION.to_owned(),
            demande: demande.to_owned(),
            nature: texte.nature.to_string(),
            identifiant: texte.identifiant,
            cid: texte.cid,
            intitule: texte.intitule,
            en_vigueur: texte.en_vigueur.map(|periode| periode.to_string()),
            source: texte.source,
            texte: texte.texte,
        })
    }

    /// Juge un texte venu d'un agent par la porte de l'ancrage.
    pub fn verifier_citation(
        &self,
        parametres: &ParametresVerifierCitation,
    ) -> Resultat<ReponseCitation> {
        let date = date(parametres.le.as_deref())?;
        let index = self.index()?;
        let ancres = index.ancres();
        Ok(match ancres.verdict_texte(&parametres.texte, date) {
            Ok(identifiants) => ReponseCitation {
                date: ecrire_date(date),
                admise: true,
                sources: ancres
                    .sources(&identifiants, date)
                    .into_iter()
                    .map(SourceRendue::from)
                    .collect(),
                identifiants,
                motif: None,
            },
            Err(motif) => ReponseCitation {
                date: ecrire_date(date),
                admise: false,
                identifiants: Vec::new(),
                sources: Vec::new(),
                motif: Some(motif.to_string()),
            },
        })
    }

    /// Rend le rapport de cohérence du savoir, sans rien y écrire.
    pub fn verifier_savoir(&self) -> Resultat<ReponseSavoir> {
        let rapport = verifier::verifier(&self.savoir)?;
        Ok(ReponseSavoir {
            en_echec: rapport.en_echec(),
            erreurs: rapport.erreurs(),
            avertissements: rapport.constats.len() - rapport.erreurs(),
            pages: rapport.pages,
            sources: rapport.sources,
            constats: rapport
                .constats
                .into_iter()
                .map(|constat| ConstatRendu {
                    gravite: match constat.gravite {
                        Gravite::Erreur => "erreur",
                        Gravite::Avertissement => "avertissement",
                    }
                    .to_owned(),
                    chemin: chemin(&constat.chemin),
                    message: constat.message,
                })
                .collect(),
        })
    }
}

fn date(le: Option<&str>) -> Resultat<Date> {
    match le.map(str::trim).filter(|le| !le.is_empty()) {
        Some(le) => lire_date(le),
        None => Ok(aujourdhui()),
    }
}

fn chemin(chemin: &Path) -> String {
    chemin.to_string_lossy().into_owned()
}

fn millisecondes(debut: std::time::Instant) -> u64 {
    u64::try_from(debut.elapsed().as_millis()).unwrap_or(u64::MAX)
}

fn verrou() -> Erreur {
    Erreur::Serveur("verrou de l'index empoisonné".to_owned())
}

fn empreinte(savoir: &Path) -> Resultat<Empreinte> {
    let mut fichiers = Vec::new();
    for dossier in DOSSIERS_INDEXES {
        if savoir.join(dossier).is_dir() {
            parcourir(savoir, Path::new(dossier), &mut fichiers)?;
        }
    }
    fichiers.sort();
    Ok(fichiers
        .into_iter()
        .map(|fichier| {
            let meta = fs::metadata(savoir.join(&fichier)).ok();
            let taille = meta.as_ref().map_or(0, fs::Metadata::len);
            let modifie = meta.and_then(|meta| meta.modified().ok());
            (fichier, taille, modifie)
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::recherche::tests::Savoir;

    fn chercher(question: &str, le: &str) -> ParametresChercher {
        ParametresChercher {
            question: question.to_owned(),
            le: Some(le.to_owned()),
            max: None,
        }
    }

    // [utest->req~outils-mcp~1]
    #[test]
    fn chercher_rend_la_date_la_mention_et_des_elements_sources() {
        let savoir = Savoir::new("service-chercher");
        let service = Service::ouvrir(&savoir.0).unwrap();
        let reponse = service
            .chercher(&chercher("branches arbres voisin", "2020-05-05"))
            .unwrap();
        assert_eq!(reponse.date, "2020-05-05");
        assert_eq!(reponse.mention, MENTION);
        assert!(!reponse.elements.is_empty());
        assert!(reponse.elements.iter().all(|e| !e.sources.is_empty()));
    }

    // [utest->req~outils-mcp~1]
    #[test]
    fn verifier_citation_refuse_un_identifiant_absent_et_le_nomme() {
        let savoir = Savoir::new("service-citation");
        let service = Service::ouvrir(&savoir.0).unwrap();
        let refus = service
            .verifier_citation(&ParametresVerifierCitation {
                texte: "Selon LEGIARTI000000004242, vous pouvez couper.".to_owned(),
                le: None,
            })
            .unwrap();
        assert!(!refus.admise);
        assert!(refus.motif.unwrap().contains("LEGIARTI000000004242"));
        let admise = service
            .verifier_citation(&ParametresVerifierCitation {
                texte: "Selon LEGIARTI000000000002.".to_owned(),
                le: Some("2020-05-05".to_owned()),
            })
            .unwrap();
        assert!(admise.admise);
        assert_eq!(admise.sources.len(), 1);
    }

    // [utest->req~outils-mcp~1]
    #[test]
    fn lire_texte_rend_la_version_en_vigueur_et_sa_source() {
        let savoir = Savoir::new("service-lire");
        let service = Service::ouvrir(&savoir.0).unwrap();
        let texte = service
            .lire_texte(&ParametresLireTexte {
                identifiant: "LEGIARTI000000000001".to_owned(),
                le: Some("2020-05-05".to_owned()),
            })
            .unwrap();
        assert_eq!(texte.identifiant, "LEGIARTI000000000002");
        assert_eq!(texte.en_vigueur.as_deref(), Some("2016-10-01 / —"));
        assert_eq!(texte.mention, MENTION);
        assert!(texte.source.unwrap().ends_with("LEGIARTI000000000002"));
    }

    #[test]
    fn un_texte_absent_est_introuvable_et_une_date_mal_formee_est_une_erreur_de_demande() {
        let savoir = Savoir::new("service-erreurs");
        let service = Service::ouvrir(&savoir.0).unwrap();
        let absent = service
            .lire_texte(&ParametresLireTexte {
                identifiant: "LEGIARTI000000000099".to_owned(),
                le: None,
            })
            .unwrap_err();
        assert_eq!(
            ErreurPublique::from(&absent).genre,
            GenreErreur::Introuvable
        );
        let date = service.chercher(&chercher("branches", "hier")).unwrap_err();
        assert_eq!(ErreurPublique::from(&date).genre, GenreErreur::Demande);
    }

    #[test]
    fn une_erreur_interne_ne_revele_aucun_chemin() {
        let erreur = Erreur::Fichier {
            chemin: PathBuf::from("/srv/savoir/secret.md"),
            cause: std::io::Error::other("refus"),
        };
        let publique = ErreurPublique::from(&erreur);
        assert_eq!(publique.genre, GenreErreur::Interne);
        assert!(!publique.message.contains("/srv"));
    }

    #[test]
    fn l_index_est_reconstruit_quand_le_savoir_change() {
        let savoir = Savoir::new("service-recharge");
        let service = Service::ouvrir(&savoir.0).unwrap();
        assert!(
            service
                .chercher(&chercher("mitoyenneté", "2026-11-01"))
                .unwrap()
                .elements
                .is_empty()
        );
        savoir.ecrire(
            "wiki/situations/cloture.md",
            "---\ntype: situation\n---\n\n# Clôture\n\nMitoyenneté (LEGIARTI000000000002).\n",
        );
        assert_eq!(
            service
                .chercher(&chercher("mitoyenneté", "2026-11-01"))
                .unwrap()
                .elements
                .len(),
            1
        );
    }
}
