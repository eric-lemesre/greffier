// SPDX-License-Identifier: EUPL-1.2
//! API HTTP : les opérations de la façade en JSON, et le serveur MCP, sur un
//! ou plusieurs dépôts de savoir, derrière un même contrôle d'accès.
//!
//! | Route                                         | Opération           |
//! | --------------------------------------------- | ------------------- |
//! | `GET /sante`                                  | santé (toujours ouverte) |
//! | `GET /savoirs`                                | dépôts lisibles par le client |
//! | `GET /savoirs/{nom}/recherche?question=&le=&max=` | `chercher`      |
//! | `GET /savoirs/{nom}/textes/{identifiant}?le=` | `lire_texte`        |
//! | `POST /savoirs/{nom}/citations/verification`  | `verifier_citation` |
//! | `GET /savoirs/{nom}/verification`             | `verifier_savoir`   |
//! | `/savoirs/{nom}/mcp`                          | MCP en HTTP « streamable » |
//!
//! Les routes de la version 0.2.0 (`/recherche`, `/textes/{identifiant}`,
//! `/citations/verification`, `/savoir/verification`, `/mcp`) servent le
//! dépôt `defaut`, celui de `--savoir`.
//!
//! Accès : sans client déclaré, la boucle locale seulement ; dès qu'un
//! client est déclaré, toute route hors `/sante` exige un jeton connu
//! (comparé par son empreinte, à temps constant), et un dépôt hors de la
//! portée du client répond comme un dépôt inconnu (404). Toute requête dont
//! l'en-tête `Host` ne nomme pas la boucle locale, l'adresse d'écoute ou un
//! hôte déclaré est refusée (403) : une page web ne peut pas, par
//! rattachement DNS, lire le savoir d'un serveur local sans jeton.
//!
//! Journal (ADR-0007) : un span par requête (identifiant de corrélation,
//! route générique, dépôt, client), une ligne à la réponse (statut, durée) ;
//! les refus sous la cible `greffier::acces`. Ni jeton, ni question, ni
//! texte n'y paraissent.

// [impl->dsn~exposition-mcp-http~1]
// [impl->req~api-http~1]
// [impl->req~acces-http-protege~1]
// [impl->dsn~savoirs-multiples~1]
// [impl->req~savoirs-multiples~1]
// [impl->req~jetons-a-portee~1]
// [impl->dsn~journal-du-service~1]
// [impl->req~journal-du-service~1]

use std::collections::BTreeMap;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;

use axum::extract::rejection::{JsonRejection, QueryRejection};
use axum::extract::{ConnectInfo, MatchedPath, Path, Query, Request, State};
use axum::http::{HeaderName, StatusCode, header};
use axum::middleware::{self, Next};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Extension, Json, Router};
use rmcp::transport::streamable_http_server::session::local::LocalSessionManager;
use rmcp::transport::streamable_http_server::{StreamableHttpServerConfig, StreamableHttpService};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tower_http::request_id::{MakeRequestUuid, PropagateRequestIdLayer, SetRequestIdLayer};
use tower_http::trace::TraceLayer;
use tracing::Span;
use tracing::field::Empty;

use crate::configuration::{Clients, DEPOT_PAR_DEFAUT, Portee};
use crate::erreur::{Erreur, Resultat};
use crate::mcp::Greffier;
use crate::service::{
    ErreurPublique, GenreErreur, ParametresChercher, ParametresLireTexte,
    ParametresVerifierCitation, Service,
};

/// Adresse d'écoute par défaut : la boucle locale.
pub const ECOUTE_PAR_DEFAUT: &str = "127.0.0.1:8370";
/// Cible du journal des refus d'accès.
pub const CIBLE_ACCES: &str = "greffier::acces";
/// Noms d'hôte toujours admis (protection contre le rattachement DNS d'un
/// serveur local).
const HOTES_LOCAUX: [&str; 3] = ["localhost", "127.0.0.1", "::1"];
/// En-tête de l'identifiant de corrélation.
const EN_TETE_ID: HeaderName = HeaderName::from_static("x-request-id");
/// Routes de la version 0.2.0, servies sur le dépôt `defaut`.
const ROUTES_DU_DEPOT_PAR_DEFAUT: [&str; 5] = [
    "/recherche",
    "/textes/",
    "/citations/verification",
    "/savoir/verification",
    "/mcp",
];

/// Réglages du serveur.
#[derive(Debug, Clone)]
pub struct Reglages {
    /// Adresse d'écoute.
    pub ecoute: SocketAddr,
    /// Noms d'hôte sous lesquels le serveur est joint, en plus de la
    /// boucle locale.
    pub hotes: Vec<String>,
}

/// Les dépôts servis et les clients admis.
pub struct Instance {
    /// Dépôts servis, par nom.
    pub depots: BTreeMap<String, Arc<Service>>,
    /// Clients admis ; vide, seule la boucle locale est servie.
    pub clients: Clients,
}

/// Le client d'une requête admise et sa portée.
#[derive(Clone)]
struct Admis(Portee);

/// Refuse une écoute hors de la boucle locale sans client déclaré.
pub fn controler_ecoute(ecoute: SocketAddr, clients: &Clients) -> Resultat<()> {
    if ecoute.ip().is_loopback() || !clients.est_vide() {
        Ok(())
    } else {
        Err(Erreur::EcouteSansJeton(ecoute.to_string()))
    }
}

/// Le routeur complet : API, MCP par dépôt, contrôle d'accès, journal.
pub fn routeur(instance: Arc<Instance>, reglages: &Reglages) -> Router {
    let mut hotes: Vec<String> = HOTES_LOCAUX.iter().map(|h| (*h).to_owned()).collect();
    if !reglages.ecoute.ip().is_unspecified() {
        hotes.push(reglages.ecoute.ip().to_string());
    }
    hotes.extend(reglages.hotes.iter().cloned());
    let mut routeur = Router::new()
        .route("/sante", get(sante))
        .route("/savoirs", get(lister))
        .route("/savoirs/{nom}/recherche", get(chercher))
        .route("/savoirs/{nom}/textes/{identifiant}", get(lire_texte))
        .route(
            "/savoirs/{nom}/citations/verification",
            post(verifier_citation),
        )
        .route("/savoirs/{nom}/verification", get(verifier_savoir))
        .route("/recherche", get(chercher_par_defaut))
        .route("/textes/{identifiant}", get(lire_texte_par_defaut))
        .route(
            "/citations/verification",
            post(verifier_citation_par_defaut),
        )
        .route("/savoir/verification", get(verifier_savoir_par_defaut));
    for (nom, service) in &instance.depots {
        let mcp = service_mcp(service, &hotes);
        routeur = routeur.nest_service(&format!("/savoirs/{nom}/mcp"), mcp.clone());
        if nom == DEPOT_PAR_DEFAUT {
            routeur = routeur.nest_service("/mcp", mcp);
        }
    }
    let hotes = Arc::new(
        hotes
            .into_iter()
            .map(|h| h.to_ascii_lowercase())
            .collect::<Vec<_>>(),
    );
    routeur
        .fallback(introuvable)
        .layer(middleware::from_fn_with_state(
            Arc::clone(&instance),
            controler_acces,
        ))
        .layer(middleware::from_fn_with_state(hotes, controler_hote))
        .layer(PropagateRequestIdLayer::new(EN_TETE_ID))
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(ouvrir_span)
                .on_request(())
                .on_response(clore_requete)
                .on_failure(()),
        )
        .layer(SetRequestIdLayer::new(EN_TETE_ID, MakeRequestUuid))
        .with_state(instance)
}

fn service_mcp(
    service: &Arc<Service>,
    hotes: &[String],
) -> StreamableHttpService<Greffier, LocalSessionManager> {
    let service = Arc::clone(service);
    StreamableHttpService::new(
        move || Ok(Greffier::new(Arc::clone(&service))),
        Arc::default(),
        StreamableHttpServerConfig::default().with_allowed_hosts(hotes.to_vec()),
    )
}

/// Le span d'une requête : identifiant de corrélation, méthode, route
/// générique ; dépôt, client et mesures s'y ajoutent ensuite. Ni chemin
/// brut, ni paramètre, ni en-tête.
fn ouvrir_span<B>(requete: &axum::http::Request<B>) -> Span {
    let route = requete
        .extensions()
        .get::<MatchedPath>()
        .map_or("(inconnue)", MatchedPath::as_str);
    let id = requete
        .headers()
        .get(&EN_TETE_ID)
        .and_then(|valeur| valeur.to_str().ok())
        .unwrap_or_default();
    tracing::info_span!(
        "requete",
        id_requete = %id,
        methode = %requete.method(),
        route = %route,
        depot = Empty,
        client = Empty,
        rendus = Empty,
        ecartes = Empty,
    )
}

fn clore_requete<B>(reponse: &axum::http::Response<B>, duree: Duration, _span: &Span) {
    let statut = reponse.status();
    let duree_ms = u64::try_from(duree.as_millis()).unwrap_or(u64::MAX);
    if statut.is_server_error() {
        tracing::error!(statut = statut.as_u16(), duree_ms, "requête en échec");
    } else {
        tracing::info!(statut = statut.as_u16(), duree_ms, "requête servie");
    }
}

/// Sert l'API et MCP jusqu'à l'arrêt du processus (Ctrl-C ou SIGTERM).
pub async fn servir(instance: Arc<Instance>, reglages: Reglages) -> Resultat<()> {
    controler_ecoute(reglages.ecoute, &instance.clients)?;
    let ecouteur = tokio::net::TcpListener::bind(reglages.ecoute)
        .await
        .map_err(|erreur| Erreur::Serveur(format!("écoute sur {} : {erreur}", reglages.ecoute)))?;
    let adresse = ecouteur
        .local_addr()
        .map_err(|erreur| Erreur::Serveur(erreur.to_string()))?;
    let protection = if instance.clients.est_vide() {
        "boucle locale, sans jeton"
    } else {
        "jeton porteur exigé"
    };
    let depots = instance
        .depots
        .keys()
        .map(String::as_str)
        .collect::<Vec<_>>()
        .join(",");
    tracing::info!(
        api = %format_args!("http://{adresse}/"),
        depots = %depots,
        protection,
        version = env!("CARGO_PKG_VERSION"),
        "service démarré"
    );
    axum::serve(
        ecouteur,
        routeur(instance, &reglages).into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(arret())
    .await
    .map_err(|erreur| Erreur::Serveur(erreur.to_string()))?;
    tracing::info!("service arrêté");
    Ok(())
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

/// L'adresse du pair, pour le journal des refus.
fn pair(requete: &Request) -> String {
    requete
        .extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|ConnectInfo(adresse)| adresse.ip().to_string())
        .unwrap_or_default()
}

async fn controler_hote(
    State(hotes): State<Arc<Vec<String>>>,
    requete: Request,
    suite: Next,
) -> Response {
    let admis = requete
        .headers()
        .get(header::HOST)
        .and_then(|valeur| valeur.to_str().ok())
        .map(nom_d_hote)
        .is_some_and(|nom| hotes.contains(&nom));
    if admis {
        suite.run(requete).await
    } else {
        tracing::warn!(target: CIBLE_ACCES, motif = "hôte non admis", pair = %pair(&requete), "accès refusé");
        erreur(StatusCode::FORBIDDEN, "hôte non admis")
    }
}

/// Le nom d'hôte d'un en-tête `Host`, sans le port, en minuscules
/// (`[::1]:8370` → `::1`, `localhost:8370` → `localhost`).
fn nom_d_hote(valeur: &str) -> String {
    let valeur = valeur.trim();
    let nom = if let Some(reste) = valeur.strip_prefix('[') {
        reste.split(']').next().unwrap_or_default()
    } else if valeur.matches(':').count() == 1 {
        valeur.split(':').next().unwrap_or_default()
    } else {
        valeur
    };
    nom.to_ascii_lowercase()
}

/// Le dépôt que vise un chemin : `/savoirs/{nom}/…`, ou `defaut` pour les
/// routes de la version 0.2.0 ; aucun pour `/savoirs` et les autres.
fn depot_vise(chemin: &str) -> Option<&str> {
    if let Some(reste) = chemin.strip_prefix("/savoirs/") {
        return reste.split('/').next().filter(|nom| !nom.is_empty());
    }
    ROUTES_DU_DEPOT_PAR_DEFAUT
        .iter()
        .any(|route| {
            if route.ends_with('/') {
                chemin.starts_with(route)
            } else {
                chemin == *route || chemin.starts_with(&format!("{route}/"))
            }
        })
        .then_some(DEPOT_PAR_DEFAUT)
}

async fn controler_acces(
    State(instance): State<Arc<Instance>>,
    mut requete: Request,
    suite: Next,
) -> Response {
    let chemin = requete.uri().path().to_owned();
    if chemin == "/sante" {
        return suite.run(requete).await;
    }
    let span = Span::current();
    let portee = if instance.clients.est_vide() {
        Portee::Tous
    } else {
        let presente = requete
            .headers()
            .get(header::AUTHORIZATION)
            .and_then(|valeur| valeur.to_str().ok())
            .and_then(|valeur| valeur.strip_prefix("Bearer "));
        let Some(presente) = presente else {
            return refuser(&requete, "jeton absent");
        };
        let Some(client) = instance.clients.reconnaitre(presente) else {
            return refuser(&requete, "jeton inconnu");
        };
        span.record("client", client.nom.as_str());
        client.portee.clone()
    };
    if let Some(depot) = depot_vise(&chemin) {
        span.record("depot", depot);
        if !instance.depots.contains_key(depot) || !portee.couvre(depot) {
            return erreur(StatusCode::NOT_FOUND, "dépôt de savoir inconnu");
        }
    }
    requete.extensions_mut().insert(Admis(portee));
    suite.run(requete).await
}

fn refuser(requete: &Request, motif: &'static str) -> Response {
    tracing::warn!(target: CIBLE_ACCES, motif, pair = %pair(requete), "accès refusé");
    (
        StatusCode::UNAUTHORIZED,
        [(header::WWW_AUTHENTICATE, "Bearer")],
        Json(json!({ "erreur": "jeton porteur absent ou invalide" })),
    )
        .into_response()
}

async fn sante() -> Json<serde_json::Value> {
    Json(json!({ "etat": "ok", "version": env!("CARGO_PKG_VERSION") }))
}

async fn introuvable() -> Response {
    erreur(StatusCode::NOT_FOUND, "route inconnue")
}

/// Les dépôts que le client peut lire.
async fn lister(
    State(instance): State<Arc<Instance>>,
    Extension(Admis(portee)): Extension<Admis>,
) -> Json<serde_json::Value> {
    let savoirs: Vec<&str> = instance
        .depots
        .keys()
        .map(String::as_str)
        .filter(|nom| portee.couvre(nom))
        .collect();
    Json(json!({ "savoirs": savoirs }))
}

/// Le service d'un dépôt ; l'accès l'a déjà contrôlé.
fn depot(instance: &Instance, nom: &str) -> Option<Arc<Service>> {
    instance.depots.get(nom).map(Arc::clone)
}

async fn chercher(
    State(instance): State<Arc<Instance>>,
    Path(nom): Path<String>,
    parametres: Result<Query<ParametresChercher>, QueryRejection>,
) -> Response {
    chercher_dans(&instance, &nom, parametres).await
}

async fn chercher_par_defaut(
    State(instance): State<Arc<Instance>>,
    parametres: Result<Query<ParametresChercher>, QueryRejection>,
) -> Response {
    chercher_dans(&instance, DEPOT_PAR_DEFAUT, parametres).await
}

async fn chercher_dans(
    instance: &Instance,
    nom: &str,
    parametres: Result<Query<ParametresChercher>, QueryRejection>,
) -> Response {
    let Some(service) = depot(instance, nom) else {
        return erreur(StatusCode::NOT_FOUND, "dépôt de savoir inconnu");
    };
    match parametres {
        Ok(Query(parametres)) => {
            let span = Span::current();
            executer(service, move |s| {
                let reponse = s.chercher(&parametres)?;
                // Des mesures, jamais la question.
                span.record("rendus", reponse.elements.len());
                span.record("ecartes", reponse.ecartes.len());
                Ok(reponse)
            })
            .await
        }
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
    State(instance): State<Arc<Instance>>,
    Path((nom, identifiant)): Path<(String, String)>,
    parametres: Result<Query<ParametreDate>, QueryRejection>,
) -> Response {
    lire_texte_dans(&instance, &nom, identifiant, parametres).await
}

async fn lire_texte_par_defaut(
    State(instance): State<Arc<Instance>>,
    Path(identifiant): Path<String>,
    parametres: Result<Query<ParametreDate>, QueryRejection>,
) -> Response {
    lire_texte_dans(&instance, DEPOT_PAR_DEFAUT, identifiant, parametres).await
}

async fn lire_texte_dans(
    instance: &Instance,
    nom: &str,
    identifiant: String,
    parametres: Result<Query<ParametreDate>, QueryRejection>,
) -> Response {
    let Some(service) = depot(instance, nom) else {
        return erreur(StatusCode::NOT_FOUND, "dépôt de savoir inconnu");
    };
    match parametres {
        Ok(Query(ParametreDate { le })) => {
            let parametres = ParametresLireTexte { identifiant, le };
            executer(service, move |s| s.lire_texte(&parametres)).await
        }
        Err(rejet) => erreur(StatusCode::BAD_REQUEST, &rejet.body_text()),
    }
}

async fn verifier_citation(
    State(instance): State<Arc<Instance>>,
    Path(nom): Path<String>,
    corps: Result<Json<ParametresVerifierCitation>, JsonRejection>,
) -> Response {
    verifier_citation_dans(&instance, &nom, corps).await
}

async fn verifier_citation_par_defaut(
    State(instance): State<Arc<Instance>>,
    corps: Result<Json<ParametresVerifierCitation>, JsonRejection>,
) -> Response {
    verifier_citation_dans(&instance, DEPOT_PAR_DEFAUT, corps).await
}

async fn verifier_citation_dans(
    instance: &Instance,
    nom: &str,
    corps: Result<Json<ParametresVerifierCitation>, JsonRejection>,
) -> Response {
    let Some(service) = depot(instance, nom) else {
        return erreur(StatusCode::NOT_FOUND, "dépôt de savoir inconnu");
    };
    match corps {
        Ok(Json(parametres)) => executer(service, move |s| s.verifier_citation(&parametres)).await,
        Err(rejet) => erreur(StatusCode::BAD_REQUEST, &rejet.body_text()),
    }
}

async fn verifier_savoir(
    State(instance): State<Arc<Instance>>,
    Path(nom): Path<String>,
) -> Response {
    verifier_savoir_dans(&instance, &nom).await
}

async fn verifier_savoir_par_defaut(State(instance): State<Arc<Instance>>) -> Response {
    verifier_savoir_dans(&instance, DEPOT_PAR_DEFAUT).await
}

async fn verifier_savoir_dans(instance: &Instance, nom: &str) -> Response {
    match depot(instance, nom) {
        Some(service) => executer(service, Service::verifier_savoir).await,
        None => erreur(StatusCode::NOT_FOUND, "dépôt de savoir inconnu"),
    }
}

/// Appelle une opération de la façade hors de l'exécuteur et rend sa
/// réponse en JSON, ou une erreur publique. Le travail garde le span de la
/// requête : ses événements y sont rattachés.
async fn executer<T, F>(service: Arc<Service>, operation: F) -> Response
where
    T: Serialize + Send + 'static,
    F: FnOnce(&Service) -> Resultat<T> + Send + 'static,
{
    let span = Span::current();
    match tokio::task::spawn_blocking(move || span.in_scope(|| operation(&service))).await {
        Ok(Ok(reponse)) => Json(reponse).into_response(),
        Ok(Err(cause)) => {
            let publique = ErreurPublique::from(&cause);
            let statut = match publique.genre {
                GenreErreur::Demande => StatusCode::BAD_REQUEST,
                GenreErreur::Introuvable => StatusCode::NOT_FOUND,
                GenreErreur::Interne => {
                    // Une seule fois, ici, à la frontière ; la cause peut
                    // nommer un chemin du serveur, jamais un secret.
                    tracing::error!(cause = %cause, "opération en échec");
                    StatusCode::INTERNAL_SERVER_ERROR
                }
            };
            erreur(statut, &publique.message)
        }
        Err(_) => {
            tracing::error!("opération interrompue");
            erreur(
                StatusCode::INTERNAL_SERVER_ERROR,
                "erreur interne du moteur",
            )
        }
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
    fn hors_de_la_boucle_locale_un_client_est_exige() {
        let dehors: SocketAddr = "0.0.0.0:8370".parse().unwrap();
        let local: SocketAddr = "127.0.0.1:8370".parse().unwrap();
        let aucun = Clients::default();
        let erreur = controler_ecoute(dehors, &aucun).unwrap_err();
        assert!(erreur.to_string().contains("GREFFIER_JETON"));
        let un = Clients::rassembler(
            vec![("GREFFIER_JETON".to_owned(), "jeton-fictif".to_owned())],
            &[],
        )
        .unwrap();
        assert!(controler_ecoute(dehors, &un).is_ok());
        assert!(controler_ecoute(local, &aucun).is_ok());
    }

    // [utest->req~acces-http-protege~1]
    #[test]
    fn le_nom_d_hote_est_lu_sans_son_port() {
        assert_eq!(nom_d_hote("localhost:8370"), "localhost");
        assert_eq!(nom_d_hote("127.0.0.1"), "127.0.0.1");
        assert_eq!(nom_d_hote("[::1]:8370"), "::1");
        assert_eq!(nom_d_hote("Greffier.Exemple:443"), "greffier.exemple");
    }

    // [utest->req~savoirs-multiples~1]
    #[test]
    fn le_depot_vise_se_lit_dans_le_chemin() {
        assert_eq!(depot_vise("/savoirs/a/recherche"), Some("a"));
        assert_eq!(depot_vise("/savoirs/a/mcp"), Some("a"));
        assert_eq!(depot_vise("/savoirs"), None);
        assert_eq!(depot_vise("/savoirs/"), None);
        assert_eq!(depot_vise("/recherche"), Some("defaut"));
        assert_eq!(depot_vise("/textes/LEGIARTI000000000001"), Some("defaut"));
        assert_eq!(depot_vise("/mcp"), Some("defaut"));
        assert_eq!(depot_vise("/savoir/verification"), Some("defaut"));
        assert_eq!(depot_vise("/sante"), None);
        assert_eq!(depot_vise("/rechercher"), None);
    }

    #[test]
    fn le_refus_d_ecoute_ne_cite_aucun_jeton() {
        let erreur = Erreur::EcouteSansJeton("0.0.0.0:8370".to_owned());
        assert!(!erreur.to_string().contains("jeton-fictif"));
    }
}
