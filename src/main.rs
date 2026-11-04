// SPDX-License-Identifier: EUPL-1.2
// Exigence servie : req~capture-des-sources-officielles~2
//! Ligne de commande de Greffier.
//!
//! Codes de sortie : 0 réussite ; 1 erreur (pour `verifier` : rapport en
//! échec ; pour `banc` : un élément rendu sans ancrage) ; 2 usage ; 3
//! (`versions`) l'article a changé depuis la date donnée.
//!
//! Le journal (ADR-0007) est installé ici, et seulement ici : la
//! bibliothèque émet, le binaire choisit où et comment écrire.

// [impl->dsn~journal-du-service~1]
// [impl->req~journal-du-service~1]
// [impl->req~configuration-environnement-et-fichier~1]

use std::collections::BTreeMap;
use std::io::IsTerminal;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::Arc;
use std::time::Duration;

use clap::{Args, Parser, Subcommand};
use greffier::configuration::{self, Clients, Fichier};
use greffier::couche::{Conservation, Couche};
use greffier::erreur::Erreur;
use greffier::erreur::Resultat;
use greffier::http::{ECOUTE_PAR_DEFAUT, Instance, Reglages};
use greffier::periode::{aujourdhui, ecrire_date, lire_date};
use greffier::piste::{ClientPiste, Environnement, Identifiants};
use greffier::recherche::Index;
use greffier::service::Service;
use greffier::{banc, http, judilibre, legifrance, mcp, verifier, versions};
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::{EnvFilter, Layer, Registry};

/// Variables d'environnement qui remplacent les adresses PISTE (mandataire,
/// banc d'essai).
const VAR_URL_JETON: &str = "GREFFIER_PISTE_URL_JETON";
const VAR_URL_API: &str = "GREFFIER_PISTE_URL_API";
/// Filtre du journal du service, et des autres commandes.
const FILTRE_DU_SERVICE: &str = "info";
const FILTRE_DES_COMMANDES: &str = "warn";

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
    /// Fichier de configuration (par défaut : /etc/greffier/greffier.toml
    /// pour `servir`, ~/.config/greffier/greffier.toml pour les autres
    /// commandes, s'il existe).
    #[arg(long, global = true, env = "GREFFIER_CONFIG")]
    config: Option<PathBuf>,
    /// Filtre du journal, au format EnvFilter (`info`,
    /// `info,greffier::acces=warn`…).
    #[arg(long, global = true, env = "GREFFIER_JOURNAL")]
    journal: Option<String>,
    /// Format du journal hors journald : `texte` ou `json`.
    #[arg(long, global = true, env = "GREFFIER_JOURNAL_FORMAT")]
    journal_format: Option<String>,
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
    /// Sert le moteur en MCP sur l'entrée et la sortie standard (pour un
    /// agent local).
    Mcp {
        /// Dossier du dépôt de savoir.
        #[arg(long)]
        savoir: PathBuf,
    },
    // [impl->req~service-systeme-desactive~1]
    /// Sert l'API HTTP et MCP, sur un ou plusieurs dépôts de savoir ; hors
    /// de la boucle locale, exige un client déclaré (GREFFIER_JETON,
    /// GREFFIER_JETON_<CLIENT>, ou la configuration). Chaque option se règle
    /// aussi par sa variable d'environnement, puis par le fichier de
    /// configuration : c'est ainsi que le service système des paquets Linux
    /// la reçoit (`/etc/greffier/greffier.env`).
    Servir {
        /// Adresse d'écoute (défaut : 127.0.0.1:8370).
        #[arg(long, env = "GREFFIER_ECOUTE")]
        ecoute: Option<SocketAddr>,
        /// Nom d'hôte sous lequel le serveur est joint (répétable, ou liste
        /// séparée par des virgules dans GREFFIER_HOTES), en plus de la
        /// boucle locale.
        #[arg(long = "hote", env = "GREFFIER_HOTES", value_delimiter = ',')]
        hotes: Vec<String>,
        /// Dossier du dépôt de savoir servi sous le nom `defaut` (les autres
        /// dépôts se déclarent dans la section [savoirs] de la
        /// configuration).
        #[arg(long, env = "GREFFIER_SAVOIR")]
        savoir: Option<PathBuf>,
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
    /// Le client PISTE : identifiants et adresses de l'environnement, à
    /// défaut ceux de la section [piste] de la configuration.
    fn client(&self, fichier: &Fichier) -> Resultat<ClientPiste> {
        let piste = &fichier.piste;
        let mut environnement = if self.bac_a_sable || piste.bac_a_sable {
            Environnement::bac_a_sable()
        } else {
            Environnement::production()
        };
        let url_jeton = std::env::var(VAR_URL_JETON)
            .ok()
            .or_else(|| piste.url_jeton.clone());
        let url_api = std::env::var(VAR_URL_API)
            .ok()
            .or_else(|| piste.url_api.clone());
        if let (Some(jeton), Some(api)) = (url_jeton, url_api) {
            environnement = Environnement::sur(&jeton, &api);
        }
        Ok(ClientPiste::new(
            environnement,
            Identifiants::resoudre(|nom| std::env::var(nom).ok(), piste)?,
        ))
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match lancer(cli) {
        Ok(code) => ExitCode::from(code),
        Err(erreur) => {
            tracing::error!(cause = %erreur, "arrêt sur erreur");
            eprintln!("greffier : {erreur}");
            ExitCode::FAILURE
        }
    }
}

/// Lit la configuration, installe le journal, exécute la commande.
fn lancer(cli: Cli) -> Resultat<u8> {
    let service = matches!(cli.commande, Commande::Servir { .. });
    let usage = if service {
        Some(PathBuf::from(configuration::FICHIER_DU_SERVICE))
    } else {
        std::env::var_os("HOME").map(|home| Path::new(&home).join(".config/greffier/greffier.toml"))
    };
    let fichier = Fichier::charger(cli.config.as_deref(), usage.as_deref())?;
    let filtre = cli
        .journal
        .or_else(|| fichier.journal.filtre.clone())
        .unwrap_or_else(|| {
            if service || matches!(cli.commande, Commande::Mcp { .. }) {
                FILTRE_DU_SERVICE
            } else {
                FILTRE_DES_COMMANDES
            }
            .to_owned()
        });
    let format = cli
        .journal_format
        .or_else(|| fichier.journal.format.clone())
        .unwrap_or_else(|| "texte".to_owned());
    installer_journal(&filtre, &format)?;
    executer(cli.commande, &fichier)
}

/// Installe l'abonné du journal : journald quand le processus tourne sous
/// systemd (`JOURNAL_STREAM`), sinon la sortie d'erreur, en texte ou en
/// JSON. Seul le binaire l'installe (méthode d'alm-forge, ch. 17).
fn installer_journal(filtre: &str, format: &str) -> Resultat<()> {
    let filtre = EnvFilter::try_new(filtre)
        .map_err(|cause| Erreur::Serveur(format!("filtre du journal « {filtre} » : {cause}")))?;
    let json = match format {
        "texte" => false,
        "json" => true,
        autre => {
            return Err(Erreur::Serveur(format!(
                "format du journal « {autre} » : attendu texte ou json"
            )));
        }
    };
    let mut repli = None;
    let couche: Box<dyn Layer<Registry> + Send + Sync> = if sortie_d_erreur_vers_journald() {
        match tracing_journald::layer() {
            Ok(journald) => journald.boxed(),
            Err(cause) => {
                repli = Some(cause.to_string());
                sortie_d_erreur(json)
            }
        }
    } else {
        sortie_d_erreur(json)
    };
    tracing_subscriber::registry()
        .with(couche.with_filter(filtre))
        .try_init()
        .map_err(|cause| Erreur::Serveur(format!("journal : {cause}")))?;
    if let Some(cause) = repli {
        tracing::warn!(cause = %cause, "journald injoignable : journal sur la sortie d'erreur");
    }
    Ok(())
}

/// La sortie d'erreur est-elle le flux que systemd a ouvert vers journald ?
/// `JOURNAL_STREAM` (« périphérique:inode ») est hérité par les processus
/// enfants : sa seule présence ne suffit pas, il doit désigner la sortie
/// d'erreur elle-même (règle de systemd.exec(5)). Constat : un serveur
/// lancé depuis une session systemd, sortie d'erreur redirigée, écrivait
/// son journal à journald et non dans la redirection.
fn sortie_d_erreur_vers_journald() -> bool {
    let Some(valeur) = std::env::var_os("JOURNAL_STREAM") else {
        return false;
    };
    let valeur = valeur.to_string_lossy();
    let Some((peripherique, inode)) = valeur.split_once(':') else {
        return false;
    };
    #[cfg(target_os = "linux")]
    {
        use std::os::unix::fs::MetadataExt;
        std::fs::metadata("/proc/self/fd/2").is_ok_and(|meta| {
            peripherique.parse() == Ok(meta.dev()) && inode.parse() == Ok(meta.ino())
        })
    }
    #[cfg(not(target_os = "linux"))]
    {
        !peripherique.is_empty() && !inode.is_empty()
    }
}

fn sortie_d_erreur(json: bool) -> Box<dyn Layer<Registry> + Send + Sync> {
    let couche = tracing_subscriber::fmt::layer().with_writer(std::io::stderr);
    if json {
        couche.json().boxed()
    } else {
        couche.with_ansi(std::io::stderr().is_terminal()).boxed()
    }
}

fn executer(commande: Commande, fichier: &Fichier) -> Resultat<u8> {
    match commande {
        Commande::Capturer(Capture::Article {
            identifiant,
            toutes_versions,
            savoir,
            piste,
        }) => {
            let client = piste.client(fichier)?;
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
            let client = piste.client(fichier)?;
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
            let article = legifrance::lire_article(&piste.client(fichier)?, &identifiant)?;
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
                    "{}\t{:.2}\t{}\t{}\t{}\t{}\t{}\t{}",
                    rang + 1,
                    trouve.score,
                    trouve.nature,
                    trouve.identifiants.join(","),
                    trouve
                        .sources
                        .iter()
                        .map(|source| source.url.as_str())
                        .collect::<Vec<_>>()
                        .join(","),
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
                .map_err(|cause| Erreur::Fichier { chemin, cause })?;
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
        Commande::Mcp { savoir } => {
            let service = Arc::new(Service::ouvrir(&savoir)?);
            executeur()?.block_on(mcp::servir_stdio(service))?;
            Ok(0)
        }
        Commande::Servir {
            ecoute,
            hotes,
            savoir,
        } => {
            let ecoute = configuration::premier(
                ecoute,
                fichier.serveur.ecoute,
                ECOUTE_PAR_DEFAUT
                    .parse()
                    .map_err(|_| Erreur::Serveur("adresse d'écoute par défaut".to_owned()))?,
            );
            let hotes = if hotes.is_empty() {
                fichier.serveur.hotes.clone()
            } else {
                hotes
            };
            let clients = Clients::rassembler(std::env::vars(), &fichier.clients)?;
            for nom in &clients.remplaces {
                tracing::warn!(
                    target: http::CIBLE_ACCES,
                    client = %nom,
                    "client déclaré dans l'environnement et dans la configuration : l'environnement l'emporte"
                );
            }
            http::controler_ecoute(ecoute, &clients)?;
            let mut depots = BTreeMap::new();
            for (nom, chemin) in configuration::depots(savoir, &fichier.savoirs)? {
                let service = Service::ouvrir_nomme(&nom, &chemin)?;
                depots.insert(nom, Arc::new(service));
            }
            let instance = Arc::new(Instance { depots, clients });
            executeur()?.block_on(http::servir(instance, Reglages { ecoute, hotes }))?;
            Ok(0)
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

/// L'exécuteur asynchrone des interfaces ; la ligne de commande n'en a pas
/// besoin.
fn executeur() -> Resultat<tokio::runtime::Runtime> {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .map_err(|erreur| Erreur::Serveur(erreur.to_string()))
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
