// SPDX-License-Identifier: EUPL-1.2
//! Sortie du journal (ADR-0008) : où vont les lignes que le binaire
//! formate, et le fichier qui se rouvre après une rotation.
//!
//! La bibliothèque n'installe aucun abonné (ADR-0007) : elle fournit le
//! choix de la sortie et un rédacteur, que `main.rs` branche sur l'abonné
//! qu'il installe. La rotation appartient à logrotate : le service ne fait
//! que rouvrir son fichier quand `SIGHUP` arrive.

// [impl->dsn~journal-en-fichier~1]
// [impl->req~journal-en-fichier~1]

use std::fs::{File, OpenOptions};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, MutexGuard};

/// Fichier du journal par défaut d'une construction de production.
pub const FICHIER_DE_PRODUCTION: &str = "/var/log/greffier/greffier.log";
/// Fichier du journal par défaut d'une construction de mise au point, là
/// où `cargo run` a le droit d'écrire.
pub const FICHIER_DE_DEVELOPPEMENT: &str = "target/journal/greffier.log";

/// Le fichier du journal par défaut : sous `/var/log` en production, sous
/// `target/` en développement.
#[must_use]
pub fn fichier_par_defaut() -> PathBuf {
    if cfg!(debug_assertions) {
        PathBuf::from(FICHIER_DE_DEVELOPPEMENT)
    } else {
        PathBuf::from(FICHIER_DE_PRODUCTION)
    }
}

/// Où va le journal.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Sortie {
    /// Un fichier, ouvert en ajout et rouvert sur `SIGHUP`.
    Fichier(PathBuf),
    /// La sortie d'erreur — transmise à journald, priorité comprise, quand
    /// systemd l'y a reliée.
    Erreur,
    /// journald directement.
    Journald,
}

impl Sortie {
    /// La sortie retenue : la sortie nommée (`fichier`, `erreur` ou
    /// `journald`) ; à défaut, un fichier si un chemin est donné ; à
    /// défaut, `defaut`. Un fichier sans chemin prend
    /// [`fichier_par_defaut`].
    ///
    /// # Errors
    ///
    /// Une sortie nommée autre que `fichier`, `erreur` ou `journald`.
    pub fn choisir(
        nommee: Option<&str>,
        chemin: Option<&Path>,
        defaut: SortieParDefaut,
    ) -> Result<Self, String> {
        let chemin = chemin.filter(|c| !c.as_os_str().is_empty());
        let fichier = || Self::Fichier(chemin.map_or_else(fichier_par_defaut, Path::to_path_buf));
        match nommee.map(str::trim).filter(|n| !n.is_empty()) {
            Some("fichier") => Ok(fichier()),
            Some("erreur") => Ok(Self::Erreur),
            Some("journald") => Ok(Self::Journald),
            Some(autre) => Err(format!(
                "sortie du journal « {autre} » : attendu fichier, erreur ou journald"
            )),
            None if chemin.is_some() => Ok(fichier()),
            None => Ok(match defaut {
                SortieParDefaut::Fichier => fichier(),
                SortieParDefaut::Erreur => Self::Erreur,
            }),
        }
    }
}

/// La sortie d'une commande quand rien ne la règle.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SortieParDefaut {
    /// Le service (`greffier servir`) sur un système Unix.
    Fichier,
    /// Les commandes, le serveur MCP sur l'entrée standard, et tout hors
    /// Unix, où logrotate ne fait pas tourner le fichier.
    Erreur,
}

/// Le fichier du journal, partagé par toutes les écritures, et rouvert au
/// même chemin après une rotation : logrotate renomme le fichier puis
/// envoie `SIGHUP` ; les lignes suivantes vont au nouveau fichier.
#[derive(Clone, Debug)]
pub struct FichierDuJournal {
    chemin: Arc<PathBuf>,
    fichier: Arc<Mutex<File>>,
}

impl FichierDuJournal {
    /// Ouvre en ajout le fichier, en le créant au besoin avec son dossier.
    ///
    /// # Errors
    ///
    /// Le dossier ou le fichier ne peut être créé ou ouvert.
    pub fn ouvrir(chemin: &Path) -> io::Result<Self> {
        Ok(Self {
            chemin: Arc::new(chemin.to_path_buf()),
            fichier: Arc::new(Mutex::new(ouvrir_en_ajout(chemin)?)),
        })
    }

    /// Le chemin du fichier.
    #[must_use]
    pub fn chemin(&self) -> &Path {
        &self.chemin
    }

    /// Rouvre le fichier à son chemin ; en échec, l'ancien descripteur
    /// reste en usage et aucune ligne n'est perdue.
    ///
    /// # Errors
    ///
    /// Le fichier ne peut être rouvert.
    pub fn rouvrir(&self) -> io::Result<()> {
        let neuf = ouvrir_en_ajout(&self.chemin)?;
        *self.verrou()? = neuf;
        Ok(())
    }

    fn verrou(&self) -> io::Result<MutexGuard<'_, File>> {
        self.fichier
            .lock()
            .map_err(|_| io::Error::other("verrou du journal empoisonné"))
    }
}

/// Ouvre en ajout, crée le dossier au besoin ; le fichier n'est lisible que
/// du compte et de son groupe (`0640`), comme logrotate le recrée.
fn ouvrir_en_ajout(chemin: &Path) -> io::Result<File> {
    if let Some(dossier) = chemin.parent().filter(|d| !d.as_os_str().is_empty()) {
        std::fs::create_dir_all(dossier)?;
    }
    let mut options = OpenOptions::new();
    options.create(true).append(true);
    #[cfg(unix)]
    std::os::unix::fs::OpenOptionsExt::mode(&mut options, 0o640);
    options.open(chemin)
}

impl Write for FichierDuJournal {
    fn write(&mut self, tampon: &[u8]) -> io::Result<usize> {
        self.verrou()?.write(tampon)
    }

    fn write_all(&mut self, tampon: &[u8]) -> io::Result<()> {
        // Une ligne s'écrit d'un seul tenant, sous le verrou : deux
        // événements simultanés ne s'entremêlent pas.
        self.verrou()?.write_all(tampon)
    }

    fn flush(&mut self) -> io::Result<()> {
        self.verrou()?.flush()
    }
}

impl<'a> tracing_subscriber::fmt::MakeWriter<'a> for FichierDuJournal {
    type Writer = Self;

    fn make_writer(&'a self) -> Self::Writer {
        self.clone()
    }
}

/// Rouvre le fichier à chaque `SIGHUP` (envoyé par le `postrotate` de
/// logrotate), dans une tâche de fond de l'exécuteur courant. À appeler
/// dans le contexte d'un exécuteur tokio, avant tout travail long : tant
/// que le gestionnaire n'est pas posé, `SIGHUP` arrête le processus.
#[cfg(unix)]
pub fn rouvrir_sur_sighup(fichier: FichierDuJournal) {
    use tokio::signal::unix::{SignalKind, signal};
    let mut signaux = match signal(SignalKind::hangup()) {
        Ok(signaux) => signaux,
        Err(cause) => {
            tracing::warn!(
                cause = %cause,
                "SIGHUP non écouté : la rotation ne rouvrira pas le journal"
            );
            return;
        }
    };
    tokio::spawn(async move {
        while signaux.recv().await.is_some() {
            match fichier.rouvrir() {
                Ok(()) => tracing::info!("journal rouvert après rotation"),
                Err(cause) => tracing::warn!(
                    cause = %cause,
                    "réouverture du journal impossible : l'ancien fichier reste en usage"
                ),
            }
        }
    });
}

/// Hors Unix, pas de signal : le fichier ne tourne que service arrêté.
#[cfg(not(unix))]
pub fn rouvrir_sur_sighup(_fichier: FichierDuJournal) {}

#[cfg(test)]
mod tests {
    use super::*;

    fn dossier(nom: &str) -> PathBuf {
        let dossier = std::env::temp_dir().join(format!(
            "greffier-journal-utest-{nom}-{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&dossier);
        dossier
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn le_service_ecrit_dans_un_fichier_par_defaut() {
        assert_eq!(
            Sortie::choisir(None, None, SortieParDefaut::Fichier),
            Ok(Sortie::Fichier(fichier_par_defaut()))
        );
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn une_commande_ecrit_sur_la_sortie_d_erreur_par_defaut() {
        assert_eq!(
            Sortie::choisir(None, None, SortieParDefaut::Erreur),
            Ok(Sortie::Erreur)
        );
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn un_chemin_donne_suffit_a_choisir_le_fichier() {
        let chemin = Path::new("/tmp/greffier.log");
        assert_eq!(
            Sortie::choisir(None, Some(chemin), SortieParDefaut::Erreur),
            Ok(Sortie::Fichier(chemin.to_path_buf()))
        );
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn la_sortie_nommee_l_emporte_sur_le_chemin() {
        assert_eq!(
            Sortie::choisir(
                Some("erreur"),
                Some(Path::new("/tmp/greffier.log")),
                SortieParDefaut::Fichier
            ),
            Ok(Sortie::Erreur)
        );
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn journald_se_choisit_par_son_nom() {
        assert_eq!(
            Sortie::choisir(Some(" journald "), None, SortieParDefaut::Fichier),
            Ok(Sortie::Journald)
        );
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn une_sortie_inconnue_est_refusee_en_la_nommant() {
        let refus = Sortie::choisir(Some("syslog"), None, SortieParDefaut::Fichier).unwrap_err();
        assert!(refus.contains("syslog"), "{refus}");
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn apres_rotation_les_lignes_vont_au_nouveau_fichier() {
        let dossier = dossier("rotation");
        let chemin = dossier.join("journaux/greffier.log");
        let mut journal = FichierDuJournal::ouvrir(&chemin).unwrap();
        journal.write_all(b"avant\n").unwrap();
        let tourne = dossier.join("journaux/greffier.log.1");
        std::fs::rename(&chemin, &tourne).unwrap();
        journal.rouvrir().unwrap();
        journal.write_all(b"apres\n").unwrap();
        assert_eq!(std::fs::read_to_string(&tourne).unwrap(), "avant\n");
        assert_eq!(std::fs::read_to_string(&chemin).unwrap(), "apres\n");
        let _ = std::fs::remove_dir_all(&dossier);
    }

    // [utest->req~journal-en-fichier~1]
    #[cfg(unix)]
    #[test]
    fn le_fichier_cree_n_est_lisible_que_du_compte_et_de_son_groupe() {
        use std::os::unix::fs::PermissionsExt;
        let dossier = dossier("droits");
        let chemin = dossier.join("greffier.log");
        let _journal = FichierDuJournal::ouvrir(&chemin).unwrap();
        let mode = std::fs::metadata(&chemin).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode & 0o037, 0, "mode {mode:o}");
        let _ = std::fs::remove_dir_all(&dossier);
    }

    // [utest->req~journal-en-fichier~1]
    #[test]
    fn un_fichier_impossible_a_ouvrir_est_signale() {
        let dossier = dossier("impossible");
        std::fs::create_dir_all(&dossier).unwrap();
        // Un fichier ordinaire tient la place du dossier attendu.
        let obstacle = dossier.join("obstacle");
        std::fs::write(&obstacle, "").unwrap();
        assert!(FichierDuJournal::ouvrir(&obstacle.join("greffier.log")).is_err());
        let _ = std::fs::remove_dir_all(&dossier);
    }
}
