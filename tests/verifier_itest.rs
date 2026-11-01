// SPDX-License-Identifier: EUPL-1.2
//! `greffier verifier` de bout en bout sur un dépôt de savoir git jetable :
//! ce qui est versionné est jugé, un dérivé non suivi est ignoré, et le
//! code de sortie dit l'échec. Contenu fictif.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, missing_docs)]

use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn ecrire(racine: &Path, relatif: &str, contenu: &str) {
    let chemin = racine.join(relatif);
    fs::create_dir_all(chemin.parent().unwrap()).unwrap();
    fs::write(chemin, contenu).unwrap();
}

fn git(racine: &Path, arguments: &[&str]) {
    let statut = Command::new("git")
        .arg("-C")
        .arg(racine)
        .args(["-c", "user.name=t", "-c", "user.email=t@t"])
        .args(arguments)
        .status()
        .unwrap();
    assert!(statut.success());
}

fn savoir(nom: &str) -> PathBuf {
    let racine = std::env::temp_dir().join(format!(
        "greffier-verifier-itest-{nom}-{}",
        std::process::id()
    ));
    let _ = fs::remove_dir_all(&racine);
    ecrire(&racine, "wiki/index.md", "# Index\n\nAucune page.\n");
    ecrire(
        &racine,
        "wiki/log.md",
        "# Journal\n\n## [2026-11-01] schema | amorçage\n",
    );
    git(&racine, &["init", "-q"]);
    git(&racine, &["add", "-A"]);
    git(&racine, &["commit", "-q", "-m", "amorçage"]);
    racine
}

fn verifier(racine: &Path) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_greffier"))
        .args(["verifier", "--savoir"])
        .arg(racine)
        .output()
        .unwrap()
}

// [itest->req~moteur-separe-du-savoir~1]
#[test]
fn un_derive_non_versionne_est_ignore_et_le_rapport_passe() {
    let racine = savoir("derive");
    ecrire(&racine, "target/index.bin", "dérivé reconstructible");
    let sortie = verifier(&racine);
    assert!(
        sortie.status.success(),
        "{}",
        String::from_utf8_lossy(&sortie.stdout)
    );
    assert!(String::from_utf8_lossy(&sortie.stdout).contains("0 erreur(s)"));
    fs::remove_dir_all(racine).unwrap();
}

// [itest->req~moteur-separe-du-savoir~1]
#[test]
fn un_programme_versionne_fait_sortir_en_echec() {
    let racine = savoir("code");
    ecrire(&racine, "outils/compiler.sh", "#!/bin/sh\n");
    git(&racine, &["add", "-A"]);
    git(&racine, &["commit", "-q", "-m", "code"]);
    let sortie = verifier(&racine);
    assert_eq!(sortie.status.code(), Some(1));
    assert!(
        String::from_utf8_lossy(&sortie.stdout)
            .contains("ERREUR\toutils/compiler.sh\tprogramme versionné dans le savoir")
    );
    fs::remove_dir_all(racine).unwrap();
}
