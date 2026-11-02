// SPDX-License-Identifier: EUPL-1.2
//! Configuration du moteur : dépôts de savoir servis, clients et leurs
//! jetons, journal, identifiants PISTE — par l'environnement ou par un
//! fichier TOML (ADR-0006).
//!
//! Priorité : option de commande, puis environnement, puis fichier, puis
//! défaut. Un fichier qui porte un secret (jeton en clair, secret PISTE) et
//! reste lisible par le groupe ou par tous empêche le démarrage. Aucun
//! secret ne paraît dans le `Debug` d'un type de ce module.
//!
//! ```toml
//! [serveur]
//! ecoute = "127.0.0.1:8370"
//! hotes = ["greffier.exemple"]
//!
//! [savoirs]
//! conciliateurs = "/var/lib/greffier/savoir-conciliateurs"
//!
//! [[client]]
//! nom = "pacilia"
//! empreinte = "sha256:…"      # ou : jeton = "…"
//! savoirs = ["conciliateurs"] # ou : ["*"]
//!
//! [journal]
//! filtre = "info"
//! format = "texte"            # ou : "json"
//!
//! [piste]
//! client_id = "…"
//! client_secret = "…"
//! ```

// [impl->dsn~savoirs-multiples~1]
// [impl->req~configuration-environnement-et-fichier~1]
// [impl->req~jetons-a-portee~1]
// [impl->req~savoirs-multiples~1]

use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::net::SocketAddr;
use std::path::{Path, PathBuf};

use serde::Deserialize;
use sha2::{Digest, Sha256};

use crate::erreur::{Erreur, Resultat};
use crate::piste::Secret;

/// Variable d'environnement qui désigne le fichier de configuration.
pub const VAR_CONFIG: &str = "GREFFIER_CONFIG";
/// Variable d'environnement du jeton du client `defaut` (portée : tous les
/// dépôts), seule forme connue de la version 0.2.0.
pub const VAR_JETON: &str = "GREFFIER_JETON";
/// Préfixe des jetons de client nommé : `GREFFIER_JETON_<CLIENT>`.
const PREFIXE_JETON: &str = "GREFFIER_JETON_";
/// Préfixe de la portée d'un client nommé : `GREFFIER_SAVOIRS_<CLIENT>`.
const PREFIXE_SAVOIRS: &str = "GREFFIER_SAVOIRS_";
/// Fichier de configuration du service système.
pub const FICHIER_DU_SERVICE: &str = "/etc/greffier/greffier.toml";
/// Nom du dépôt déclaré par `--savoir`, servi aussi sous les routes de la
/// version 0.2.0.
pub const DEPOT_PAR_DEFAUT: &str = "defaut";
/// Nom du client déclaré par `GREFFIER_JETON`.
pub const CLIENT_PAR_DEFAUT: &str = "defaut";
/// Longueur maximale d'un nom de dépôt ou de client.
const NOM_MAX: usize = 40;

/// Le contenu d'un fichier de configuration.
#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Fichier {
    /// Écoute et hôtes du serveur.
    #[serde(default)]
    pub serveur: SectionServeur,
    /// Dépôts servis : nom → chemin.
    #[serde(default)]
    pub savoirs: BTreeMap<String, PathBuf>,
    /// Clients admis.
    #[serde(default, rename = "client")]
    pub clients: Vec<ClientDeclare>,
    /// Réglage du journal.
    #[serde(default)]
    pub journal: SectionJournal,
    /// Identifiants PISTE de l'opérateur qui capture.
    #[serde(default)]
    pub piste: SectionPiste,
}

/// Section `[serveur]`.
#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SectionServeur {
    /// Adresse d'écoute.
    pub ecoute: Option<SocketAddr>,
    /// Noms d'hôte admis, en plus de la boucle locale.
    #[serde(default)]
    pub hotes: Vec<String>,
}

/// Un client déclaré dans le fichier.
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClientDeclare {
    /// Nom du client.
    pub nom: String,
    /// Jeton en clair (le fichier doit alors être protégé).
    pub jeton: Option<Secret>,
    /// Empreinte du jeton, `sha256:<hexadécimal>`.
    pub empreinte: Option<String>,
    /// Dépôts lisibles, ou `["*"]` pour tous.
    #[serde(default)]
    pub savoirs: Vec<String>,
}

/// Section `[journal]`.
#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SectionJournal {
    /// Filtre au format `EnvFilter` (`info`, `info,greffier::acces=warn`…).
    pub filtre: Option<String>,
    /// `texte` ou `json`.
    pub format: Option<String>,
}

/// Section `[piste]`.
#[derive(Debug, Default, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SectionPiste {
    /// Identifiant de l'application PISTE.
    pub client_id: Option<String>,
    /// Clé secrète de l'application PISTE.
    pub client_secret: Option<Secret>,
    /// Bac à sable plutôt que production.
    #[serde(default)]
    pub bac_a_sable: bool,
    /// Adresse du jeton OAuth, en remplacement (mandataire, banc d'essai).
    // journal: admis — adresse du point d'émission des jetons, pas un jeton
    pub url_jeton: Option<String>,
    /// Adresse de l'API, en remplacement.
    pub url_api: Option<String>,
}

impl Fichier {
    /// Lit le fichier désigné, ou à défaut celui du chemin d'usage s'il
    /// existe ; sans l'un ni l'autre, une configuration vide.
    pub fn charger(designe: Option<&Path>, usage: Option<&Path>) -> Resultat<Self> {
        let chemin = match (designe, usage) {
            (Some(chemin), _) => chemin.to_owned(),
            (None, Some(chemin)) if chemin.is_file() => chemin.to_owned(),
            _ => return Ok(Self::default()),
        };
        let contenu = std::fs::read_to_string(&chemin).map_err(|cause| Erreur::Fichier {
            chemin: chemin.clone(),
            cause,
        })?;
        let fichier: Self = toml::from_str(&contenu).map_err(|cause| Erreur::Configuration {
            chemin: chemin.clone(),
            cause: cause.message().to_owned(),
        })?;
        if fichier.porte_un_secret() {
            controler_droits(&chemin)?;
        }
        Ok(fichier)
    }

    /// Le fichier porte-t-il un secret en clair ?
    fn porte_un_secret(&self) -> bool {
        self.clients.iter().any(|client| client.jeton.is_some())
            || self.piste.client_secret.is_some()
    }
}

/// Refuse un fichier à secret lisible par le groupe ou par tous.
#[cfg(unix)]
fn controler_droits(chemin: &Path) -> Resultat<()> {
    use std::os::unix::fs::PermissionsExt;
    let mode = std::fs::metadata(chemin)
        .map_err(|cause| Erreur::Fichier {
            chemin: chemin.to_owned(),
            cause,
        })?
        .permissions()
        .mode();
    if mode & 0o077 == 0 {
        Ok(())
    } else {
        Err(Erreur::ConfigurationExposee {
            chemin: chemin.to_owned(),
            mode: mode & 0o777,
        })
    }
}

/// Hors Unix, les droits se règlent par les listes d'accès du système.
#[cfg(not(unix))]
fn controler_droits(_chemin: &Path) -> Resultat<()> {
    Ok(())
}

/// Vérifie un nom de dépôt ou de client : `[a-z0-9-]`, 1 à 40 caractères.
pub fn controler_nom(nom: &str) -> Resultat<()> {
    let valide = !nom.is_empty()
        && nom.len() <= NOM_MAX
        && nom
            .bytes()
            .all(|octet| octet.is_ascii_lowercase() || octet.is_ascii_digit() || octet == b'-');
    if valide {
        Ok(())
    } else {
        Err(Erreur::NomInvalide(nom.to_owned()))
    }
}

/// Les dépôts servis : celui de `--savoir` (nommé `defaut`), puis ceux du
/// fichier.
pub fn depots(
    savoir: Option<PathBuf>,
    fichier: &BTreeMap<String, PathBuf>,
) -> Resultat<BTreeMap<String, PathBuf>> {
    let mut depots = BTreeMap::new();
    for (nom, chemin) in fichier {
        controler_nom(nom)?;
        depots.insert(nom.clone(), chemin.clone());
    }
    if let Some(chemin) = savoir {
        depots.insert(DEPOT_PAR_DEFAUT.to_owned(), chemin);
    }
    if depots.is_empty() {
        return Err(Erreur::AucunSavoir);
    }
    Ok(depots)
}

/// Les dépôts qu'un client peut lire.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Portee {
    /// Tous les dépôts.
    Tous,
    /// Les seuls dépôts nommés.
    Depots(BTreeSet<String>),
}

impl Portee {
    fn lire(noms: &[String]) -> Self {
        if noms.iter().any(|nom| nom.trim() == "*") {
            Self::Tous
        } else {
            Self::Depots(
                noms.iter()
                    .map(|nom| nom.trim().to_owned())
                    .filter(|nom| !nom.is_empty())
                    .collect(),
            )
        }
    }

    /// Le dépôt nommé est-il dans la portée ?
    pub fn couvre(&self, depot: &str) -> bool {
        match self {
            Self::Tous => true,
            Self::Depots(depots) => depots.contains(depot),
        }
    }
}

/// Un client admis : son nom, l'empreinte de son jeton, sa portée.
#[derive(Clone)]
pub struct Client {
    /// Nom du client, tel qu'il paraît au journal.
    pub nom: String,
    empreinte: [u8; 32],
    /// Dépôts lisibles.
    pub portee: Portee,
}

impl fmt::Debug for Client {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Client")
            .field("nom", &self.nom)
            .field("portee", &self.portee)
            .finish_non_exhaustive()
    }
}

/// Les clients admis par une instance.
#[derive(Debug, Clone, Default)]
pub struct Clients {
    clients: Vec<Client>,
    /// Noms définis à la fois dans l'environnement et dans le fichier :
    /// l'environnement l'a emporté.
    pub remplaces: Vec<String>,
}

impl Clients {
    /// Rassemble les clients de l'environnement (lu par `variable`) et du
    /// fichier ; un même nom prend la valeur de l'environnement.
    pub fn rassembler(
        variables: impl IntoIterator<Item = (String, String)>,
        fichier: &[ClientDeclare],
    ) -> Resultat<Self> {
        let variables: BTreeMap<String, String> = variables.into_iter().collect();
        let mut admis: BTreeMap<String, Client> = BTreeMap::new();
        for declare in fichier {
            controler_nom(&declare.nom)?;
            let empreinte = match (&declare.jeton, &declare.empreinte) {
                (Some(jeton), None) => empreinte_de(jeton.exposer()),
                (None, Some(empreinte)) => lire_empreinte(empreinte)
                    .ok_or_else(|| Erreur::EmpreinteInvalide(declare.nom.clone()))?,
                _ => return Err(Erreur::JetonDuClient(declare.nom.clone())),
            };
            admis.insert(
                declare.nom.clone(),
                Client {
                    nom: declare.nom.clone(),
                    empreinte,
                    portee: Portee::lire(&declare.savoirs),
                },
            );
        }
        let mut remplaces = Vec::new();
        let mut depuis_l_environnement = Vec::new();
        if let Some(jeton) = variables.get(VAR_JETON).filter(|j| !j.trim().is_empty()) {
            depuis_l_environnement.push((CLIENT_PAR_DEFAUT.to_owned(), jeton, Portee::Tous));
        }
        for (variable, jeton) in &variables {
            let Some(suffixe) = variable.strip_prefix(PREFIXE_JETON) else {
                continue;
            };
            if jeton.trim().is_empty() {
                continue;
            }
            let nom = suffixe.to_ascii_lowercase().replace('_', "-");
            controler_nom(&nom)?;
            let portee = variables
                .get(&format!("{PREFIXE_SAVOIRS}{suffixe}"))
                .map(|liste| Portee::lire(&liste.split(',').map(str::to_owned).collect::<Vec<_>>()))
                .unwrap_or_else(|| Portee::Depots(BTreeSet::new()));
            depuis_l_environnement.push((nom, jeton, portee));
        }
        for (nom, jeton, portee) in depuis_l_environnement {
            if admis.contains_key(&nom) {
                remplaces.push(nom.clone());
            }
            admis.insert(
                nom.clone(),
                Client {
                    nom,
                    empreinte: empreinte_de(jeton),
                    portee,
                },
            );
        }
        Ok(Self {
            clients: admis.into_values().collect(),
            remplaces,
        })
    }

    /// Aucun client déclaré : seule la boucle locale est servie.
    pub fn est_vide(&self) -> bool {
        self.clients.is_empty()
    }

    /// Le client dont le jeton est présenté, s'il est connu. Chaque
    /// empreinte est comparée en entier, à temps constant.
    pub fn reconnaitre(&self, presente: &str) -> Option<&Client> {
        let empreinte = empreinte_de(presente);
        let mut trouve = None;
        for client in &self.clients {
            if egal_a_temps_constant(&client.empreinte, &empreinte) && trouve.is_none() {
                trouve = Some(client);
            }
        }
        trouve
    }
}

/// L'empreinte SHA-256 d'un jeton.
fn empreinte_de(jeton: &str) -> [u8; 32] {
    Sha256::digest(jeton.as_bytes()).into()
}

/// Lit une empreinte `sha256:<64 chiffres hexadécimaux>`.
fn lire_empreinte(texte: &str) -> Option<[u8; 32]> {
    let hex = texte.trim().strip_prefix("sha256:")?;
    if hex.len() != 64 {
        return None;
    }
    let mut empreinte = [0_u8; 32];
    for (octet, paire) in empreinte.iter_mut().zip(hex.as_bytes().chunks(2)) {
        let paire = std::str::from_utf8(paire).ok()?;
        *octet = u8::from_str_radix(paire, 16).ok()?;
    }
    Some(empreinte)
}

/// Compare deux suites d'octets sans s'arrêter à la première différence.
pub fn egal_a_temps_constant(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0_u8, |ecart, (x, y)| ecart | (x ^ y)) == 0
}

/// Le premier réglage défini : option ou environnement (déjà fusionnés par
/// la ligne de commande), puis fichier, puis défaut.
pub fn premier<T>(commande: Option<T>, fichier: Option<T>, defaut: T) -> T {
    commande.or(fichier).unwrap_or(defaut)
}

#[cfg(test)]
mod tests {
    use super::*;

    const JETON: &str = "jeton-fictif-de-test-0123456789";

    fn variables(paires: &[(&str, &str)]) -> Vec<(String, String)> {
        paires
            .iter()
            .map(|(n, v)| ((*n).to_owned(), (*v).to_owned()))
            .collect()
    }

    // [utest->req~configuration-environnement-et-fichier~1]
    #[test]
    fn l_option_l_emporte_sur_le_fichier_qui_l_emporte_sur_le_defaut() {
        assert_eq!(premier(Some(1), Some(2), 3), 1);
        assert_eq!(premier(None, Some(2), 3), 2);
        assert_eq!(premier(None, None, 3), 3);
    }

    // [utest->req~configuration-environnement-et-fichier~1]
    #[test]
    fn le_fichier_se_lit_et_son_debug_ne_montre_aucun_secret() {
        let fichier: Fichier = toml::from_str(&format!(
            "[serveur]\necoute = \"127.0.0.1:9000\"\n[savoirs]\nconciliateurs = \"/srv/a\"\n\
             [[client]]\nnom = \"pacilia\"\njeton = \"{JETON}\"\nsavoirs = [\"conciliateurs\"]\n\
             [piste]\nclient_id = \"id\"\nclient_secret = \"secret-piste-fictif\"\n"
        ))
        .unwrap();
        assert_eq!(
            fichier.serveur.ecoute,
            Some("127.0.0.1:9000".parse().unwrap())
        );
        assert!(fichier.porte_un_secret());
        let vu = format!("{fichier:?}");
        assert!(!vu.contains(JETON), "{vu}");
        assert!(!vu.contains("secret-piste-fictif"), "{vu}");
        let clients = Clients::rassembler(Vec::new(), &fichier.clients).unwrap();
        assert!(!format!("{clients:?}").contains(JETON));
    }

    // [utest->req~configuration-environnement-et-fichier~1]
    #[test]
    fn une_cle_inconnue_du_fichier_est_refusee() {
        assert!(toml::from_str::<Fichier>("[serveur]\necoutte = \"x\"\n").is_err());
    }

    // [utest->req~savoirs-multiples~1]
    #[test]
    fn un_nom_de_depot_hors_de_l_alphabet_est_refuse() {
        assert!(controler_nom("conciliateurs-2026").is_ok());
        for nom in ["", "Majuscule", "avec espace", "a/b", &"x".repeat(41)] {
            assert!(controler_nom(nom).is_err(), "{nom}");
        }
        let mut fichier = BTreeMap::new();
        fichier.insert("../evasion".to_owned(), PathBuf::from("/srv"));
        assert!(depots(None, &fichier).is_err());
    }

    // [utest->req~savoirs-multiples~1]
    #[test]
    fn le_savoir_de_la_commande_devient_le_depot_par_defaut() {
        let mut fichier = BTreeMap::new();
        fichier.insert("a".to_owned(), PathBuf::from("/srv/a"));
        let depots = depots(Some(PathBuf::from("/srv/d")), &fichier).unwrap();
        assert_eq!(depots.get(DEPOT_PAR_DEFAUT), Some(&PathBuf::from("/srv/d")));
        assert_eq!(depots.len(), 2);
        assert!(super::depots(None, &BTreeMap::new()).is_err());
    }

    // [utest->req~jetons-a-portee~1]
    #[test]
    fn un_client_est_reconnu_par_son_jeton_ou_son_empreinte_et_porte_sa_portee() {
        let hex: String = empreinte_de(JETON)
            .iter()
            .map(|o| format!("{o:02x}"))
            .collect();
        let fichier = vec![ClientDeclare {
            nom: "lecteur".to_owned(),
            jeton: None,
            empreinte: Some(format!("sha256:{hex}")),
            savoirs: vec!["a".to_owned()],
        }];
        let clients = Clients::rassembler(
            variables(&[
                ("GREFFIER_JETON", "jeton-global-fictif"),
                ("GREFFIER_JETON_OUTIL_METIER", "jeton-outil-fictif"),
                ("GREFFIER_SAVOIRS_OUTIL_METIER", "a, b"),
            ]),
            &fichier,
        )
        .unwrap();
        let lecteur = clients.reconnaitre(JETON).unwrap();
        assert_eq!(lecteur.nom, "lecteur");
        assert!(lecteur.portee.couvre("a") && !lecteur.portee.couvre("b"));
        let outil = clients.reconnaitre("jeton-outil-fictif").unwrap();
        assert_eq!(outil.nom, "outil-metier");
        assert!(outil.portee.couvre("b"));
        assert_eq!(
            clients.reconnaitre("jeton-global-fictif").unwrap().portee,
            Portee::Tous
        );
        assert!(clients.reconnaitre("jeton-faux").is_none());
    }

    // [utest->req~jetons-a-portee~1]
    #[test]
    fn l_environnement_l_emporte_sur_le_fichier_et_le_signale() {
        let fichier = vec![ClientDeclare {
            nom: "pacilia".to_owned(),
            jeton: Some(Secret::new("jeton-du-fichier".to_owned())),
            empreinte: None,
            savoirs: vec!["*".to_owned()],
        }];
        let clients = Clients::rassembler(
            variables(&[
                ("GREFFIER_JETON_PACILIA", "jeton-de-l-environnement"),
                ("GREFFIER_SAVOIRS_PACILIA", "a"),
            ]),
            &fichier,
        )
        .unwrap();
        assert_eq!(clients.remplaces, ["pacilia"]);
        assert!(clients.reconnaitre("jeton-du-fichier").is_none());
        let pacilia = clients.reconnaitre("jeton-de-l-environnement").unwrap();
        assert!(!pacilia.portee.couvre("b"));
    }

    // [utest->req~jetons-a-portee~1]
    #[test]
    fn un_client_sans_portee_ne_lit_rien_et_un_client_ambigu_est_refuse() {
        let clients =
            Clients::rassembler(variables(&[("GREFFIER_JETON_SEUL", "jeton-seul")]), &[]).unwrap();
        assert!(
            !clients
                .reconnaitre("jeton-seul")
                .unwrap()
                .portee
                .couvre("a")
        );
        let ambigu = vec![ClientDeclare {
            nom: "ambigu".to_owned(),
            jeton: Some(Secret::new("x".to_owned())),
            empreinte: Some("sha256:00".to_owned()),
            savoirs: Vec::new(),
        }];
        assert!(Clients::rassembler(Vec::new(), &ambigu).is_err());
        let mal_forme = vec![ClientDeclare {
            nom: "mal-forme".to_owned(),
            jeton: None,
            empreinte: Some("sha256:zz".to_owned()),
            savoirs: Vec::new(),
        }];
        assert!(Clients::rassembler(Vec::new(), &mal_forme).is_err());
    }

    #[test]
    fn la_comparaison_rejette_tout_ecart() {
        assert!(egal_a_temps_constant(b"jeton-fictif", b"jeton-fictif"));
        assert!(!egal_a_temps_constant(b"jeton-fictif", b"jeton-fictiF"));
        assert!(!egal_a_temps_constant(b"jeton", b"jeton-fictif"));
    }
}
