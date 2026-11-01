// SPDX-License-Identifier: EUPL-1.2
// Exigence servie : req~textes-authentiques-versionnes~1
//! Greffier — moteur de recherche juridique ancré : rien n'est rendu sans
//! texte authentique.
//!
//! Ce premier lot porte la couche des textes : la capture d'un article
//! (Légifrance) ou d'une décision (Judilibre) par son identifiant officiel,
//! sa conservation immuable et versionnée dans le dossier `raw/` d'un dépôt
//! de savoir, et le constat des changements de version.
#![cfg_attr(
    test,
    allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing
    )
)]

pub mod couche;
pub mod erreur;
pub mod judilibre;
pub mod legifrance;
pub mod periode;
pub mod piste;
pub mod versions;
