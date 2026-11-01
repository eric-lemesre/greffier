// SPDX-License-Identifier: EUPL-1.2
//! Serveur MCP : les quatre opérations de la façade offertes en outils à un
//! agent, sur l'entrée et la sortie standard ou sur HTTP (SDK officiel
//! `rmcp`).
//!
//! Chaque outil appelle la façade hors de l'exécuteur asynchrone ; une
//! erreur est rendue en résultat d'outil en échec, avec un message public
//! (ni chemin du serveur, ni secret).

// [impl->dsn~exposition-mcp-http~1]
// [impl->req~outils-mcp~1]

use std::sync::Arc;

use rmcp::handler::server::router::tool::ToolRouter;
use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{Implementation, ServerCapabilities, ServerConfig};
use rmcp::{Json, ServerHandler, ServiceExt, tool, tool_handler, tool_router};

use crate::erreur::{Erreur, Resultat};
use crate::service::{
    ErreurPublique, MENTION, ParametresChercher, ParametresLireTexte, ParametresVerifierCitation,
    ReponseChercher, ReponseCitation, ReponseSavoir, ReponseTexte, Service,
};

/// Consignes données à l'agent à l'ouverture de la session.
const CONSIGNES: &str = "Greffier rend des textes de droit français et des pages de \
    savoir, chacun ancré dans un texte authentique conservé (identifiant officiel et \
    lien vers la source). N'écrivez aucune référence qui ne vienne pas de ces outils ; \
    passez votre réponse à verifier_citation avant de la rendre. Aide documentaire, \
    sans valeur d'avis.";

/// Le serveur MCP de Greffier.
#[derive(Clone)]
pub struct Greffier {
    service: Arc<Service>,
    tool_router: ToolRouter<Self>,
}

impl Greffier {
    /// Serveur MCP sur la façade donnée.
    pub fn new(service: Arc<Service>) -> Self {
        Self {
            service,
            tool_router: Self::tool_router(),
        }
    }

    /// Appelle une opération de la façade hors de l'exécuteur.
    async fn appeler<T, F>(&self, operation: F) -> Result<Json<T>, String>
    where
        T: Send + 'static,
        F: FnOnce(&Service) -> Resultat<T> + Send + 'static,
    {
        let service = Arc::clone(&self.service);
        tokio::task::spawn_blocking(move || operation(&service))
            .await
            .map_err(|_| "erreur interne du moteur".to_owned())?
            .map(Json)
            .map_err(|erreur| ErreurPublique::from(&erreur).message)
    }
}

#[tool_router]
impl Greffier {
    /// Cherche dans les textes authentiques et les pages du savoir.
    #[tool(
        description = "Cherche, dans le droit en vigueur à une date, les textes, décisions et pages de savoir qui répondent à une question posée dans les mots de la vie courante. Chaque élément porte ses identifiants officiels et le lien vers leur source ; les éléments non ancrés sont écartés et listés avec leur motif. Aide documentaire, sans valeur d'avis."
    )]
    async fn chercher(
        &self,
        Parameters(parametres): Parameters<ParametresChercher>,
    ) -> Result<Json<ReponseChercher>, String> {
        self.appeler(move |service| service.chercher(&parametres))
            .await
    }

    /// Rend un texte conservé.
    #[tool(
        description = "Rend le texte conservé d'un article (par l'identifiant d'une version ou l'identifiant chronologique de l'article : la version en vigueur à la date est rendue) ou d'une décision (par son ECLI), avec sa période de vigueur et sa source officielle."
    )]
    async fn lire_texte(
        &self,
        Parameters(parametres): Parameters<ParametresLireTexte>,
    ) -> Result<Json<ReponseTexte>, String> {
        self.appeler(move |service| service.lire_texte(&parametres))
            .await
    }

    /// Juge un texte d'agent par la porte de l'ancrage.
    #[tool(
        description = "Juge un texte produit par un agent : il est admis seulement s'il cite au moins un identifiant officiel (LEGIARTI, LEGITEXT, JORFTEXT, ECLI), que tous ceux qu'il cite sont conservés dans la couche des textes, et qu'au moins un est en vigueur à la date. Sinon, le motif du refus est rendu."
    )]
    async fn verifier_citation(
        &self,
        Parameters(parametres): Parameters<ParametresVerifierCitation>,
    ) -> Result<Json<ReponseCitation>, String> {
        self.appeler(move |service| service.verifier_citation(&parametres))
            .await
    }

    /// Rend le rapport de cohérence du savoir.
    #[tool(
        description = "Vérifie la cohérence du dépôt de savoir, en lecture seule : en-têtes des pages, sources, identifiants cités, liens, index, journal, absence de code. Rend les erreurs et les avertissements."
    )]
    async fn verifier_savoir(&self) -> Result<Json<ReponseSavoir>, String> {
        self.appeler(Service::verifier_savoir).await
    }
}

#[tool_handler(router = self.tool_router)]
impl ServerHandler for Greffier {
    fn get_info(&self) -> ServerConfig {
        ServerConfig::new(ServerCapabilities::builder().enable_tools().build())
            .with_server_info(Implementation::new("greffier", env!("CARGO_PKG_VERSION")))
            .with_instructions(format!("{CONSIGNES} ({MENTION})"))
    }
}

/// Sert le moteur en MCP sur l'entrée et la sortie standard, jusqu'à ce que
/// le client ferme la session.
pub async fn servir_stdio(service: Arc<Service>) -> Resultat<()> {
    let session = Greffier::new(service)
        .serve(rmcp::transport::stdio())
        .await
        .map_err(|erreur| Erreur::Serveur(erreur.to_string()))?;
    session
        .waiting()
        .await
        .map_err(|erreur| Erreur::Serveur(erreur.to_string()))?;
    Ok(())
}
