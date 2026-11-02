// SPDX-License-Identifier: EUPL-1.2
// Exigence servie : req~capture-des-sources-officielles~1
//! Erreurs du moteur.

use std::path::PathBuf;

/// Erreur rendue par le moteur. Aucune variante ne porte un secret : le
/// jeton et la clé d'application ne sortent jamais d'un message d'erreur.
#[derive(Debug, thiserror::Error)]
pub enum Erreur {
    /// Identifiant officiel mal formé : rien n'est demandé à la source.
    #[error("identifiant mal formé : « {0} » (attendu : {1})")]
    IdentifiantInvalide(String, &'static str),

    /// Date mal formée (attendue au format AAAA-MM-JJ).
    #[error("date mal formée : « {0} » (attendu : AAAA-MM-JJ)")]
    DateInvalide(String),

    /// Identifiants PISTE absents de l'environnement.
    #[error("identifiants PISTE absents : définir {0}")]
    IdentifiantsAbsents(&'static str),

    /// La source n'a pas pu être jointe.
    #[error("source injoignable ({url}) : {cause}")]
    Reseau {
        /// Adresse demandée, sans secret.
        url: String,
        /// Cause rapportée par le client HTTP.
        cause: String,
    },

    /// La source a répondu par un statut d'erreur.
    #[error("la source a répondu {statut} à {url}")]
    Statut {
        /// Adresse demandée, sans secret.
        url: String,
        /// Statut HTTP reçu.
        statut: u16,
    },

    /// La réponse de la source n'a pas la forme attendue.
    #[error("réponse inattendue de la source : {0}")]
    ReponseInattendue(String),

    /// La source ne connaît pas l'élément demandé.
    #[error("introuvable à la source : {0}")]
    Introuvable(String),

    /// Un texte conservé diffère de la capture : la couche des textes est
    /// immuable, rien n'est écrasé.
    #[error("texte déjà conservé avec un contenu différent, rien n'est écrasé : {0}")]
    TexteDifferent(PathBuf),

    /// Un fichier de la couche des textes n'a pas la forme attendue.
    #[error("fichier de la couche des textes mal formé : {0}")]
    FichierMalForme(PathBuf),

    /// Une ligne du banc de questions n'a pas la forme attendue.
    #[error("banc de questions, ligne {ligne} : {cause}")]
    BancMalForme {
        /// Numéro de la ligne (à partir de 1).
        ligne: usize,
        /// Ce qui ne va pas.
        cause: String,
    },

    /// Le serveur écouterait hors de la boucle locale sans jeton.
    #[error(
        "écoute sur {0} hors de la boucle locale sans jeton : définir GREFFIER_JETON, ou écouter sur 127.0.0.1"
    )]
    EcouteSansJeton(String),

    /// Le fichier de configuration est mal formé.
    #[error("configuration {chemin} : {cause}")]
    Configuration {
        /// Fichier de configuration.
        chemin: PathBuf,
        /// Ce qui ne va pas (sans valeur lue).
        cause: String,
    },

    /// Le fichier de configuration porte un secret et reste lisible par le
    /// groupe ou par tous.
    #[error(
        "configuration {chemin} : elle porte un secret et reste lisible par d'autres (mode {mode:o}) ; la protéger (chmod 600, ou 640 au groupe du service)"
    )]
    ConfigurationExposee {
        /// Fichier de configuration.
        chemin: PathBuf,
        /// Mode du fichier.
        mode: u32,
    },

    /// Un nom de dépôt ou de client sort de l'alphabet admis.
    #[error("nom « {0} » refusé : attendu 1 à 40 caractères parmi a-z, 0-9 et -")]
    NomInvalide(String),

    /// Aucun dépôt de savoir n'est déclaré.
    #[error(
        "aucun dépôt de savoir : définir --savoir, GREFFIER_SAVOIR ou la section [savoirs] de la configuration"
    )]
    AucunSavoir,

    /// Un client du fichier déclare à la fois un jeton et une empreinte, ou
    /// ni l'un ni l'autre.
    #[error("client « {0} » : déclarer soit un jeton, soit une empreinte")]
    JetonDuClient(String),

    /// L'empreinte d'un client n'a pas la forme `sha256:<64 hexadécimaux>`.
    #[error("client « {0} » : empreinte attendue au format sha256:<64 chiffres hexadécimaux>")]
    EmpreinteInvalide(String),

    /// Le serveur n'a pas pu démarrer ou s'est arrêté sur une erreur.
    #[error("serveur : {0}")]
    Serveur(String),

    /// Erreur d'entrée-sortie sur la couche des textes.
    #[error("entrée-sortie sur {chemin} : {cause}")]
    Fichier {
        /// Fichier ou dossier concerné.
        chemin: PathBuf,
        /// Cause rapportée par le système.
        cause: std::io::Error,
    },
}

/// Résultat du moteur.
pub type Resultat<T> = Result<T, Erreur>;
