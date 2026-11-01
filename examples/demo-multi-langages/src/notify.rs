//! Notification de fin de tâche — implémentation Rust.

// [impl->req~notification-terminale~1]
// [impl->req~echec-signale-distinctement~1]
pub fn notifier(nom: &str, duree_s: u64, succes: bool) -> String {
    let etat = if succes { "OK" } else { "ÉCHEC" };
    let message = format!("[{etat}] {nom} ({duree_s} s)");
    println!("{message}");
    message
}
