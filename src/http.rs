// SPDX-License-Identifier: EUPL-1.2
//! API HTTP : les opérations de la façade en JSON, et le serveur MCP sous
//! `/mcp`, derrière un même contrôle d'accès.
//!
//! | Route                           | Opération           |
//! | ------------------------------- | ------------------- |
//! | `GET /sante`                    | santé (toujours ouverte) |
//! | `GET /recherche?question=&le=&max=` | `chercher`      |
//! | `GET /textes/{identifiant}?le=` | `lire_texte`        |
//! | `POST /citations/verification`  | `verifier_citation` |
//! | `GET /savoir/verification`      | `verifier_savoir`   |
//! | `/mcp`                          | MCP en HTTP « streamable » |
//!
//! Accès : sur la boucle locale, sans jeton ; ailleurs, le serveur refuse
//! de démarrer sans jeton porteur. Un jeton configuré est exigé sur toute
//! route hors `/sante`, comparé à temps constant, et ne paraît dans aucune
//! sortie.

// [impl->dsn~exposition-mcp-http~1]
// [impl->req~api-http~1]
// [impl->req~acces-http-protege~1]

use std::net::SocketAddr;
use std::sync::Arc;

use axum::extract::rejection::{JsonRejection, QueryRejection};
use axum::extract::{Path, Query, Request, State};
use axum::http::{StatusCode, header};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use rmcp::transport::streamable_http_server::session::local::LocalSessionManager;
use rmcp::transport::streamable_http_server::{StreamableHttpServerConfig, StreamableHttpService};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::erreur::{Erreur, Resultat};
use crate::mcp::Greffier;
use crate::service::{
    ErreurPublique, GenreErreur, ParametresChercher, ParametresLireTexte,
    ParametresVerifierCitation, Service,
};

/// Adresse d'écoute par défaut : la boucle locale.
pub const ECOUTE_PAR_DEFAUT: &str = "127.0.0.1:8370";
/// Noms d'hôte toujours admis par le transport MCP (protection contre le
/// rattachement DNS d'un serveur local).
const HOTES_LOCAUX: [&str; 3] = ["localhost", "127.0.0.1", "::1"];

/// Réglages du serveur.
#[derive(Debug, Clone)]
pub struct Reglages {
    /// Adresse d'écoute.
    pub ecoute: SocketAddr,
    /// Jeton porteur exigé, s'il y en a un.
    pub jeton: Option<String>,
    /// Noms d'hôte sous lesquels le serveur est joint, en plus de la
    /// boucle locale.
    pub hotes: Vec<String>,
}

/// Refuse une écoute hors de la boucle locale sans jeton.
pub fn controler_ecoute(ecoute: SocketAddr, jeton: Option<&str>) -> Resultat<()> {
    if ecoute.ip().is_loopback() || jeton.is_some_and(|jeton| !jeton.is_empty()) {
        Ok(())
    } else {
        Err(Erreur::EcouteSansJeton(ecoute.to_string()))
    }
}

/// Le routeur complet : API, MCP sous `/mcp`, contrôle d'accès.
pub fn routeur(service: Arc<Service>, reglages: &Reglages) -> Router {
    let mut hotes: Vec<String> = HOTES_LOCAUX.iter().map(|h| (*h).to_owned()).collect();
    if !reglages.ecoute.ip().is_unspecified() {
        hotes.push(reglages.ecoute.ip().to_string());
    }
    hotes.extend(reglages.hotes.iter().cloned());
    let pour_mcp = Arc::clone(&service);
    let mcp: StreamableHttpService<Greffier, LocalSessionManager> = StreamableHttpService::new(
        move || Ok(Greffier::new(Arc::clone(&pour_mcp))),
        Arc::default(),
        StreamableHttpServerConfig::default().with_allowed_hosts(hotes),
    );
    let jeton = Arc::new(reglages.jeton.clone().filter(|jeton| !jeton.is_empty()));
    Router::new()
        .route("/sante", get(sante))
        .route("/recherche", get(chercher))
        .route("/textes/{identifiant}", get(lire_texte))
        .route("/citations/verification", post(verifier_citation))
        .route("/savoir/verification", get(verifier_savoir))
        .nest_service("/mcp", mcp)
        .fallback(introuvable)
        .with_state(service)
        .layer(middleware::from_fn_with_state(jeton, controler_jeton))
}

/// Sert l'API et MCP jusqu'à l'arrêt du processus (Ctrl-C ou SIGTERM).
pub async fn servir(service: Arc<Service>, reglages: Reglages) -> Resultat<()> {
    controler_ecoute(reglages.ecoute, reglages.jeton.as_deref())?;
    let ecouteur = tokio::net::TcpListener::bind(reglages.ecoute)
        .await
        .map_err(|erreur| Erreur::Serveur(format!("écoute sur {} : {erreur}", reglages.ecoute)))?;
    let adresse = ecouteur
        .local_addr()
        .map_err(|erreur| Erreur::Serveur(erreur.to_string()))?;
    let protection = if reglages.jeton.as_deref().is_some_and(|j| !j.is_empty()) {
        "jeton porteur exigé"
    } else {
        "boucle locale, sans jeton"
    };
    eprintln!(
        "greffier : API sur http://{adresse}/ et MCP sur http://{adresse}/mcp ({protection})"
    );
    axum::serve(ecouteur, routeur(service, &reglages))
        .with_graceful_shutdown(arret())
        .await
        .map_err(|erreur| Erreur::Serveur(erreur.to_string()))
}

async fn arret() {
    let interruption = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    #[cfg(unix)]
    let terminaison = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut signal) => {
                signal.recv().await;
            }
            Err(_) => std::future::pending::<()>().await,
        }
    };
    #[cfg(not(unix))]
    let terminaison = std::future::pending::<()>();
    tokio::select! {
        () = interruption => {}
        () = terminaison => {}
    }
}

async fn controler_jeton(
    State(jeton): State<Arc<Option<String>>>,
    requete: Request,
    suite: Next,
) -> Response {
    let Some(attendu) = jeton.as_deref() else {
        return suite.run(requete).await;
    };
    if requete.uri().path() == "/sante" {
        return suite.run(requete).await;
    }
    let presente = requete
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|valeur| valeur.to_str().ok())
        .and_then(|valeur| valeur.strip_prefix("Bearer "));
    if presente
        .is_some_and(|presente| egal_a_temps_constant(presente.as_bytes(), attendu.as_bytes()))
    {
        suite.run(requete).await
    } else {
        (
            StatusCode::UNAUTHORIZED,
            [(header::WWW_AUTHENTICATE, "Bearer")],
            Json(json!({ "erreur": "jeton porteur absent ou invalide" })),
        )
            .into_response()
    }
}

/// Compare deux suites d'octets sans s'arrêter à la première différence.
fn egal_a_temps_constant(a: &[u8], b: &[u8]) -> bool {
    a.len() == b.len() && a.iter().zip(b).fold(0_u8, |ecart, (x, y)| ecart | (x ^ y)) == 0
}

async fn sante() -> Json<serde_json::Value> {
    Json(json!({ "etat": "ok", "version": env!("CARGO_PKG_VERSION") }))
}

async fn introuvable() -> Response {
    erreur(StatusCode::NOT_FOUND, "route inconnue")
}

async fn chercher(
    State(service): State<Arc<Service>>,
    parametres: Result<Query<ParametresChercher>, QueryRejection>,
) -> Response {
    match parametres {
        Ok(Query(parametres)) => executer(service, move |s| s.chercher(&parametres)).await,
        Err(rejet) => erreur(StatusCode::BAD_REQUEST, &rejet.body_text()),
    }
}

/// Date du droit applicable, en paramètre de requête.
#[derive(Debug, Deserialize)]
struct ParametreDate {
    #[serde(default)]
    le: Option<String>,
}

async fn lire_texte(
    State(service): State<Arc<Service>>,
    Path(identifiant): Path<String>,
    parametres: Result<Query<ParametreDate>, QueryRejection>,
) -> Response {
    match parametres {
        Ok(Query(ParametreDate { le })) => {
            let parametres = ParametresLireTexte { identifiant, le };
            executer(service, move |s| s.lire_texte(&parametres)).await
        }
        Err(rejet) => erreur(StatusCode::BAD_REQUEST, &rejet.body_text()),
    }
}

async fn verifier_citation(
    State(service): State<Arc<Service>>,
    corps: Result<Json<ParametresVerifierCitation>, JsonRejection>,
) -> Response {
    match corps {
        Ok(Json(parametres)) => executer(service, move |s| s.verifier_citation(&parametres)).await,
        Err(rejet) => erreur(StatusCode::BAD_REQUEST, &rejet.body_text()),
    }
}

async fn verifier_savoir(State(service): State<Arc<Service>>) -> Response {
    executer(service, Service::verifier_savoir).await
}

/// Appelle une opération de la façade hors de l'exécuteur et rend sa
/// réponse en JSON, ou une erreur publique.
async fn executer<T, F>(service: Arc<Service>, operation: F) -> Response
where
    T: Serialize + Send + 'static,
    F: FnOnce(&Service) -> Resultat<T> + Send + 'static,
{
    match tokio::task::spawn_blocking(move || operation(&service)).await {
        Ok(Ok(reponse)) => Json(reponse).into_response(),
        Ok(Err(cause)) => {
            let publique = ErreurPublique::from(&cause);
            let statut = match publique.genre {
                GenreErreur::Demande => StatusCode::BAD_REQUEST,
                GenreErreur::Introuvable => StatusCode::NOT_FOUND,
                GenreErreur::Interne => StatusCode::INTERNAL_SERVER_ERROR,
            };
            erreur(statut, &publique.message)
        }
        Err(_) => erreur(
            StatusCode::INTERNAL_SERVER_ERROR,
            "erreur interne du moteur",
        ),
    }
}

fn erreur(statut: StatusCode, message: &str) -> Response {
    (statut, Json(json!({ "erreur": message }))).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    // [utest->req~acces-http-protege~1]
    #[test]
    fn hors_de_la_boucle_locale_le_jeton_est_exige() {
        let dehors: SocketAddr = "0.0.0.0:8370".parse().unwrap();
        let local: SocketAddr = "127.0.0.1:8370".parse().unwrap();
        let erreur = controler_ecoute(dehors, None).unwrap_err();
        assert!(erreur.to_string().contains("GREFFIER_JETON"));
        assert!(controler_ecoute(dehors, Some("")).is_err());
        assert!(controler_ecoute(dehors, Some("jeton-fictif")).is_ok());
        assert!(controler_ecoute(local, None).is_ok());
    }

    // [utest->req~acces-http-protege~1]
    #[test]
    fn la_comparaison_du_jeton_rejette_tout_ecart() {
        assert!(egal_a_temps_constant(b"jeton-fictif", b"jeton-fictif"));
        assert!(!egal_a_temps_constant(b"jeton-fictif", b"jeton-fictiF"));
        assert!(!egal_a_temps_constant(b"jeton", b"jeton-fictif"));
    }

    #[test]
    fn le_refus_d_ecoute_ne_cite_aucun_jeton() {
        let erreur = Erreur::EcouteSansJeton("0.0.0.0:8370".to_owned());
        assert!(!erreur.to_string().contains("jeton-fictif"));
    }
}
