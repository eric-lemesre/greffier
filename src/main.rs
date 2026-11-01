// SPDX-License-Identifier: EUPL-1.2
// Exigence servie : req~capture-des-sources-officielles~1
//! Ligne de commande de Greffier.
//!
//! Codes de sortie : 0 réussite ; 1 erreur (pour `verifier` : rapport en
//! échec ; pour `banc` : un élément rendu sans ancrage) ; 2 usage ; 3
//! (`versions`) l'article a changé depuis la date donnée.

use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

use clap::{Args, Parser, Subcommand};
use greffier::couche::{Conservation, Couche};
use greffier::erreur::Resultat;
use greffier::periode::{aujourdhui, ecrire_date, lire_date};
use greffier::piste::{ClientPiste, Environnement, Identifiants};
use greffier::recherche::Index;
use greffier::{banc, judilibre, legifrance, verifier, versions};

/// Variables d'environnement qui remplacent les adresses PISTE (mandataire,
/// banc d'essai).
const VAR_URL_JETON: &str = "GREFFIER_PISTE_URL_JETON";
const VAR_URL_API: &str = "GREFFIER_PISTE_URL_API";

/// Code de sortie de `versions` quand l'article a changé.
const SORTIE_CHANGE: u8 = 3;

/// Nombre d'éléments rendus par défaut.
const MAX_PAR_DEFAUT: usize = 10;

#[derive(Parser)]
#[command(
    name = "greffier",
    version,
    about = "Moteur de recherche juridique ancré"
)]
struct Cli {
    #[command(subcommand)]
    commande: Commande,
}

#[derive(Subcommand)]
enum Commande {
    /// Capture un texte authentique dans la couche des textes d'un savoir.
    #[command(subcommand)]
    Capturer(Capture),
    /// Constate les changements de version d'un article depuis une date
    /// (sortie 3 si l'article a changé).
    Versions {
        /// Identifiant de l'article (LEGIARTI…).
        identifiant: String,
        /// Date de référence, AAAA-MM-JJ (exclue).
        #[arg(long)]
        depuis: String,
        #[command(flatten)]
        piste: OptionsPiste,
    },
    /// Vérifie un dépôt de savoir, en lecture seule (sortie 1 si une erreur
    /// est constatée).
    Verifier {
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
    },
    /// Cherche dans les deux couches d'un dépôt de savoir ; rend seulement
    /// des éléments ancrés et journalise les écarts sur la sortie d'erreur.
    Chercher {
        /// La question, dans les mots de la vie courante.
        question: String,
        /// Date du droit applicable, AAAA-MM-JJ (par défaut : aujourd'hui).
        #[arg(long)]
        le: Option<String>,
        /// Nombre maximal d'éléments rendus.
        #[arg(long, default_value_t = MAX_PAR_DEFAUT)]
        max: usize,
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
    },
    /// Joue le banc de questions d'un dépôt de savoir : rappel, précision,
    /// délai (sortie 1 si un élément rendu n'est pas ancré).
    Banc {
        /// Nombre maximal d'éléments rendus par question.
        #[arg(long, default_value_t = MAX_PAR_DEFAUT)]
        max: usize,
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
    },
    /// Rend la version conservée d'un article en vigueur à une date (hors
    /// ligne).
    EnVigueur {
        /// Identifiant chronologique de l'article (cid, LEGIARTI…).
        cid: String,
        /// Date, AAAA-MM-JJ.
        #[arg(long)]
        le: String,
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
    },
}

#[derive(Subcommand)]
enum Capture {
    /// Capture un article Légifrance par son identifiant de version.
    Article {
        /// Identifiant de l'article (LEGIARTI…).
        identifiant: String,
        /// Capture aussi toutes les autres versions de l'article.
        #[arg(long)]
        toutes_versions: bool,
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
        #[command(flatten)]
        piste: OptionsPiste,
    },
    /// Capture une décision Judilibre par son identifiant.
    Decision {
        /// Identifiant Judilibre (24 caractères hexadécimaux).
        identifiant: String,
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
        #[command(flatten)]
        piste: OptionsPiste,
    },
}

#[derive(Args)]
struct OptionsPiste {
    /// Utilise le bac à sable PISTE plutôt que la production.
    #[arg(long)]
    bac_a_sable: bool,
}

impl OptionsPiste {
    fn client(&self) -> Resultat<ClientPiste> {
        let mut environnement = if self.bac_a_sable {
            Environnement::bac_a_sable()
        } else {
            Environnement::production()
        };
        if let (Ok(jeton), Ok(api)) = (std::env::var(VAR_URL_JETON), std::env::var(VAR_URL_API)) {
            environnement = Environnement::sur(&jeton, &api);
        }
        Ok(ClientPiste::new(
            environnement,
            Identifiants::depuis_environnement()?,
        ))
    }
}

fn main() -> ExitCode {
    match executer(Cli::parse().commande) {
        Ok(code) => ExitCode::from(code),
        Err(erreur) => {
            eprintln!("greffier : {erreur}");
            ExitCode::FAILURE
        }
    }
}

fn executer(commande: Commande) -> Resultat<u8> {
    match commande {
        Commande::Capturer(Capture::Article {
            identifiant,
            toutes_versions,
            savoir,
            piste,
        }) => {
            let client = piste.client()?;
            let couche = Couche::du_savoir(&savoir);
            let article = legifrance::lire_article(&client, &identifiant)?;
            annoncer(&couche.conserver_article(&article, aujourdhui())?);
            if toutes_versions {
                for version in article
                    .versions
                    .iter()
                    .filter(|v| v.identifiant != identifiant)
                {
                    let autre = legifrance::lire_article(&client, &version.identifiant)?;
                    annoncer(&couche.conserver_article(&autre, aujourdhui())?);
                }
            }
            Ok(0)
        }
        Commande::Capturer(Capture::Decision {
            identifiant,
            savoir,
            piste,
        }) => {
            let client = piste.client()?;
            let decision = judilibre::lire_decision(&client, &identifiant)?;
            annoncer(&Couche::du_savoir(&savoir).conserver_decision(&decision, aujourdhui())?);
            Ok(0)
        }
        Commande::Versions {
            identifiant,
            depuis,
            piste,
        } => {
            let depuis = lire_date(&depuis)?;
            let article = legifrance::lire_article(&piste.client()?, &identifiant)?;
            let constat = versions::constater(&article, depuis);
            for version in &constat.nouvelles_versions {
                println!(
                    "nouvelle version\t{}\t{}\t{}",
                    version.identifiant, version.etat, version.en_vigueur
                );
            }
            if let Some(fin) = constat.fin_de_vigueur {
                println!("fin de vigueur\t{identifiant}\t{}", ecrire_date(fin));
            }
            if constat.a_change() {
                Ok(SORTIE_CHANGE)
            } else {
                println!("inchangé depuis le {}\t{identifiant}", ecrire_date(depuis));
                Ok(0)
            }
        }
        Commande::Verifier { savoir } => {
            let rapport = verifier::verifier(&savoir)?;
            for constat in &rapport.constats {
                println!("{constat}");
            }
            let avertissements = rapport.constats.len() - rapport.erreurs();
            println!(
                "vérification : {} erreur(s), {avertissements} avertissement(s) — {} page(s), {} source(s) brute(s)",
                rapport.erreurs(),
                rapport.pages,
                rapport.sources
            );
            Ok(u8::from(rapport.en_echec()))
        }
        Commande::Chercher {
            question,
            le,
            max,
            savoir,
        } => {
            let date = match le {
                Some(le) => lire_date(&le)?,
                None => aujourdhui(),
            };
            let reponse = Index::construire(&savoir)?.chercher(&question, date, max);
            for ecart in &reponse.ecartes {
                eprintln!("écarté\t{}\t{}", ecart.chemin.display(), ecart.motif);
            }
            for (rang, trouve) in reponse.retenus.iter().enumerate() {
                println!(
                    "{}\t{:.2}\t{}\t{}\t{}\t{}\t{}",
                    rang + 1,
                    trouve.score,
                    trouve.nature,
                    trouve.identifiants.join(","),
                    trouve.intitule,
                    trouve.chemin.display(),
                    trouve.extrait
                );
            }
            if reponse.retenus.is_empty() {
                eprintln!("greffier : aucun élément ancré pour cette question");
            }
            println!(
                "# aide documentaire, sans valeur d'avis — droit en vigueur le {} ; {} retenu(s), {} écarté(s)",
                ecrire_date(date),
                reponse.retenus.len(),
                reponse.ecartes.len()
            );
            Ok(0)
        }
        Commande::Banc { max, savoir } => {
            let chemin = savoir.join(banc::FICHIER_DU_BANC);
            let contenu = std::fs::read_to_string(&chemin)
                .map_err(|cause| greffier::erreur::Erreur::Fichier { chemin, cause })?;
            let questions = banc::lire_banc(&contenu)?;
            let mesure = banc::mesurer(&Index::construire(&savoir)?, &questions, max);
            for question in &mesure.questions {
                let delai = millisecondes(question.delai);
                if !question.mesurable() {
                    println!(
                        "{}\tnon mesurable (aucun identifiant attendu)\t{delai} ms",
                        question.id
                    );
                    continue;
                }
                let situation = match question.situation {
                    Some(true) => "oui",
                    Some(false) => "non",
                    None => "—",
                };
                println!(
                    "{}\trappel {}/{}\tprécision {}/{}\tsituation {situation}\t{delai} ms\tnon ancré(s) {}",
                    question.id,
                    question.retrouves,
                    question.attendus,
                    question.pertinents,
                    question.rendus,
                    question.non_ancres
                );
            }
            let (retrouves, attendus) = mesure.rappel();
            let (pertinents, rendus) = mesure.precision();
            let mesurables = mesure.questions.iter().filter(|q| q.mesurable()).count();
            println!(
                "banc : {} question(s), {mesurables} mesurable(s) — rappel {retrouves}/{attendus} ({}), précision {pertinents}/{rendus} ({}), délai médian {} ms, max {} ms, {} élément(s) non ancré(s)",
                mesure.questions.len(),
                pourcentage(retrouves, attendus),
                pourcentage(pertinents, rendus),
                millisecondes(mesure.delai_median()),
                millisecondes(mesure.delai_max()),
                mesure.non_ancres()
            );
            Ok(u8::from(mesure.en_echec()))
        }
        Commande::EnVigueur { cid, le, savoir } => {
            let date = lire_date(&le)?;
            let trouvees = Couche::du_savoir(&savoir).en_vigueur_le(&cid, date)?;
            if trouvees.is_empty() {
                eprintln!("greffier : aucune version conservée de {cid} en vigueur le {le}");
                return Ok(1);
            }
            for version in &trouvees {
                println!(
                    "{}\t{}\t{}",
                    version.identifiant,
                    version.en_vigueur,
                    version.chemin.display()
                );
            }
            if trouvees.len() > 1 {
                eprintln!("greffier : versions qui se recouvrent pour {cid} le {le}");
                return Ok(1);
            }
            Ok(0)
        }
    }
}

fn millisecondes(delai: Duration) -> String {
    format!("{:.1}", delai.as_secs_f64() * 1000.0)
}

fn pourcentage(partie: usize, tout: usize) -> String {
    if tout == 0 {
        "—".to_owned()
    } else {
        format!("{:.0} %", partie as f64 * 100.0 / tout as f64)
    }
}

fn annoncer(conservation: &Conservation) {
    match conservation {
        Conservation::Cree(chemin) => println!("conservé\t{}", chemin.display()),
        Conservation::DejaConserve(chemin) => println!("déjà conservé\t{}", chemin.display()),
    }
}
