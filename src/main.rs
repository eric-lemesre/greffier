// SPDX-License-Identifier: EUPL-1.2
// Exigence servie : req~capture-des-sources-officielles~1
//! Ligne de commande de Greffier.
//!
//! Codes de sortie : 0 réussite ; 1 erreur ; 2 usage ; 3 (`versions`)
//! l'article a changé depuis la date donnée.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Args, Parser, Subcommand};
use greffier::couche::{Conservation, Couche};
use greffier::erreur::Resultat;
use greffier::periode::{aujourdhui, ecrire_date, lire_date};
use greffier::piste::{ClientPiste, Environnement, Identifiants};
use greffier::{judilibre, legifrance, versions};

/// Variables d'environnement qui remplacent les adresses PISTE (mandataire,
/// banc d'essai).
const VAR_URL_JETON: &str = "GREFFIER_PISTE_URL_JETON";
const VAR_URL_API: &str = "GREFFIER_PISTE_URL_API";

/// Code de sortie de `versions` quand l'article a changé.
const SORTIE_CHANGE: u8 = 3;

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

fn annoncer(conservation: &Conservation) {
    match conservation {
        Conservation::Cree(chemin) => println!("conservé\t{}", chemin.display()),
        Conservation::DejaConserve(chemin) => println!("déjà conservé\t{}", chemin.display()),
    }
}
