// SPDX-License-Identifier: EUPL-1.2
//! Accès authentifié à PISTE, la plateforme des API publiques de l'État
//! (Légifrance, Judilibre).
//!
//! Le client obtient un jeton OAuth 2.0 par `client_credentials` et le
//! réutilise jusqu'à son expiration. Ni la clé d'application ni le jeton
//! n'apparaissent dans un message, une trace ou une erreur.

// [impl->dsn~connecteur-piste-synchrone~1]

use std::cell::RefCell;
use std::fmt;
use std::time::{Duration, Instant};

use serde::Deserialize;
use serde_json::Value;

use crate::erreur::{Erreur, Resultat};

/// Variable d'environnement portant l'identifiant de l'application PISTE.
pub const VAR_CLIENT_ID: &str = "GREFFIER_PISTE_CLIENT_ID";
/// Variable d'environnement portant la clé secrète de l'application PISTE.
pub const VAR_CLIENT_SECRET: &str = "GREFFIER_PISTE_CLIENT_SECRET";

/// Délai maximal d'un appel à la source.
const DELAI: Duration = Duration::from_secs(30);
/// Marge avant l'expiration annoncée du jeton.
const MARGE_JETON: Duration = Duration::from_secs(60);

/// Ce dont Légifrance et Judilibre ont besoin : un appel JSON authentifié.
/// Le port permet d'éprouver la lecture des réponses sans réseau.
pub trait SourcePiste {
    /// `POST` d'un corps JSON sur un chemin de l'API ; rend le JSON reçu.
    fn post_json(&self, chemin: &str, corps: &Value) -> Resultat<Value>;
    /// `GET` d'un chemin de l'API avec ses paramètres ; rend le JSON reçu.
    fn get_json(&self, chemin: &str, parametres: &[(&str, &str)]) -> Resultat<Value>;
}

/// Une valeur secrète, jamais affichée.
#[derive(Clone)]
pub struct Secret(String);

impl Secret {
    /// Enveloppe une valeur secrète.
    pub fn new(valeur: String) -> Self {
        Self(valeur)
    }
}

impl fmt::Debug for Secret {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("Secret(***)")
    }
}

/// Identifiants d'une application PISTE.
#[derive(Debug, Clone)]
pub struct Identifiants {
    client_id: String,
    client_secret: Secret,
}

impl Identifiants {
    /// Construit les identifiants.
    pub fn new(client_id: String, client_secret: Secret) -> Self {
        Self {
            client_id,
            client_secret,
        }
    }

    /// Lit les identifiants dans l'environnement.
    pub fn depuis_environnement() -> Resultat<Self> {
        let lire = |nom: &'static str| {
            std::env::var(nom)
                .ok()
                .filter(|valeur| !valeur.trim().is_empty())
                .ok_or(Erreur::IdentifiantsAbsents(nom))
        };
        Ok(Self::new(
            lire(VAR_CLIENT_ID)?,
            Secret::new(lire(VAR_CLIENT_SECRET)?),
        ))
    }
}

/// Adresses d'un environnement PISTE.
#[derive(Debug, Clone)]
pub struct Environnement {
    jeton: String,
    api: String,
}

impl Environnement {
    /// Production.
    pub fn production() -> Self {
        Self::sur(
            "https://oauth.piste.gouv.fr/api/oauth/token",
            "https://api.piste.gouv.fr",
        )
    }

    /// Bac à sable (identifiants distincts de la production).
    pub fn bac_a_sable() -> Self {
        Self::sur(
            "https://sandbox-oauth.piste.gouv.fr/api/oauth/token",
            "https://sandbox-api.piste.gouv.fr",
        )
    }

    /// Adresses explicites : URL du jeton, racine des API.
    pub fn sur(jeton: &str, api: &str) -> Self {
        Self {
            jeton: jeton.to_owned(),
            api: api.trim_end_matches('/').to_owned(),
        }
    }
}

struct Jeton {
    valeur: Secret,
    expire: Instant,
}

#[derive(Deserialize)]
struct ReponseJeton {
    access_token: String,
    #[serde(default)]
    expires_in: Option<u64>,
}

/// Client PISTE synchrone.
pub struct ClientPiste {
    agent: ureq::Agent,
    environnement: Environnement,
    identifiants: Identifiants,
    jeton: RefCell<Option<Jeton>>,
}

impl ClientPiste {
    /// Construit un client ; aucun appel n'est fait avant la première
    /// demande.
    pub fn new(environnement: Environnement, identifiants: Identifiants) -> Self {
        let agent = ureq::Agent::config_builder()
            .timeout_global(Some(DELAI))
            .http_status_as_error(false)
            .build()
            .into();
        Self {
            agent,
            environnement,
            identifiants,
            jeton: RefCell::new(None),
        }
    }

    fn jeton(&self) -> Resultat<String> {
        if let Some(jeton) = self.jeton.borrow().as_ref()
            && Instant::now() < jeton.expire
        {
            return Ok(jeton.valeur.0.clone());
        }
        let url = &self.environnement.jeton;
        let mut reponse = self
            .agent
            .post(url)
            .send_form([
                ("grant_type", "client_credentials"),
                ("client_id", self.identifiants.client_id.as_str()),
                ("client_secret", self.identifiants.client_secret.0.as_str()),
                ("scope", "openid"),
            ])
            .map_err(|cause| reseau(url, &cause))?;
        verifier_statut(url, reponse.status().as_u16())?;
        let lu: ReponseJeton = reponse
            .body_mut()
            .read_json()
            .map_err(|_| Erreur::ReponseInattendue("jeton OAuth illisible".to_owned()))?;
        let duree = Duration::from_secs(lu.expires_in.unwrap_or(0)).saturating_sub(MARGE_JETON);
        let valeur = lu.access_token;
        *self.jeton.borrow_mut() = Some(Jeton {
            valeur: Secret::new(valeur.clone()),
            expire: Instant::now() + duree,
        });
        Ok(valeur)
    }

    fn url(&self, chemin: &str) -> String {
        format!("{}{chemin}", self.environnement.api)
    }
}

impl SourcePiste for ClientPiste {
    fn post_json(&self, chemin: &str, corps: &Value) -> Resultat<Value> {
        let jeton = self.jeton()?;
        let url = self.url(chemin);
        let mut reponse = self
            .agent
            .post(&url)
            .header("Authorization", format!("Bearer {jeton}"))
            .header("Accept", "application/json")
            .send_json(corps)
            .map_err(|cause| reseau(&url, &cause))?;
        verifier_statut(&url, reponse.status().as_u16())?;
        reponse.body_mut().read_json().map_err(|_| illisible(&url))
    }

    fn get_json(&self, chemin: &str, parametres: &[(&str, &str)]) -> Resultat<Value> {
        let jeton = self.jeton()?;
        let url = self.url(chemin);
        let mut reponse = self
            .agent
            .get(&url)
            .query_pairs(parametres.iter().copied())
            .header("Authorization", format!("Bearer {jeton}"))
            .header("Accept", "application/json")
            .call()
            .map_err(|cause| reseau(&url, &cause))?;
        verifier_statut(&url, reponse.status().as_u16())?;
        reponse.body_mut().read_json().map_err(|_| illisible(&url))
    }
}

fn verifier_statut(url: &str, statut: u16) -> Resultat<()> {
    match statut {
        200..=299 => Ok(()),
        statut => Err(Erreur::Statut {
            url: url.to_owned(),
            statut,
        }),
    }
}

fn reseau(url: &str, cause: &ureq::Error) -> Erreur {
    Erreur::Reseau {
        url: url.to_owned(),
        cause: cause.to_string(),
    }
}

fn illisible(url: &str) -> Erreur {
    Erreur::ReponseInattendue(format!("corps JSON illisible depuis {url}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn un_secret_ne_s_affiche_jamais() {
        let identifiants = Identifiants::new(
            "appli".to_owned(),
            Secret::new("cle-tres-secrete".to_owned()),
        );
        assert!(!format!("{identifiants:?}").contains("cle-tres-secrete"));
    }

    #[test]
    fn un_statut_d_erreur_est_rendu_comme_erreur() {
        assert!(matches!(
            verifier_statut("https://x", 403),
            Err(Erreur::Statut { statut: 403, .. })
        ));
    }
}
