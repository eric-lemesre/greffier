// SPDX-License-Identifier: EUPL-1.2
//! Vérification d'un dépôt de savoir, en lecture seule.
//!
//! Le savoir ne contient que du texte : sources brutes (`raw/`), pages
//! compilées (`wiki/`), schéma du curateur, banc de questions. La
//! vérification rend un rapport et n'écrit rien. Elle signale :
//!
//! - **erreurs** (rapport en échec) : page sans en-tête ou incomplète, source
//!   absente de `raw/` ou encore en proposition, identifiant officiel cité
//!   qu'aucune source brute ne porte, lien `[[…]]` cassé ou ambigu, page
//!   absente de l'index ou index qui nomme une page absente, entrée de
//!   journal mal formée ou ingestion sans référent, source brute sans
//!   identifiant, programme versionné dans le savoir ;
//! - **avertissements** : page orpheline (aucun lien entrant), page
//!   sur-connectée (plus de 20 liens entrants).

// [impl->req~moteur-separe-du-savoir~1]

use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::couche::{lire_entete, valeur};
use crate::erreur::{Erreur, Resultat};
use crate::periode::lire_date;

/// Au-delà, une page est sur-connectée (schéma du curateur).
const SEUIL_SUR_CONNEXION: usize = 20;

/// Types de page admis par le schéma du curateur.
const TYPES_DE_PAGE: [&str; 7] = [
    "texte",
    "decision",
    "situation",
    "pratique",
    "procedure",
    "reference",
    "stress-test",
];

/// Extensions d'un programme : aucune n'a sa place dans le savoir.
const EXTENSIONS_DE_CODE: [&str; 18] = [
    "rs", "py", "js", "mjs", "cjs", "ts", "sh", "bash", "ps1", "rb", "pl", "php", "java", "go",
    "c", "h", "cpp", "exe",
];

/// Dossiers de dérivés ou d'outillage qui ne se versionnent pas dans le savoir.
const DOSSIERS_DERIVES: [&str; 5] = [
    "target",
    "node_modules",
    ".venv",
    "__pycache__",
    ".greffier",
];

/// Opérations admises au journal du wiki.
const OPERATIONS_DU_JOURNAL: [&str; 4] = ["ingest", "query", "lint", "schema"];

/// Gravité d'un constat.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Gravite {
    /// Le rapport est en échec.
    Erreur,
    /// Signalé au référent, sans faire échouer le rapport.
    Avertissement,
}

/// Un constat de la vérification.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Constat {
    /// Gravité.
    pub gravite: Gravite,
    /// Fichier concerné, relatif au dépôt de savoir.
    pub chemin: PathBuf,
    /// Ce qui ne va pas.
    pub message: String,
}

impl fmt::Display for Constat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let gravite = match self.gravite {
            Gravite::Erreur => "ERREUR",
            Gravite::Avertissement => "AVERTISSEMENT",
        };
        write!(f, "{gravite}\t{}\t{}", self.chemin.display(), self.message)
    }
}

/// Rapport de vérification.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Rapport {
    /// Constats, triés par gravité puis par fichier.
    pub constats: Vec<Constat>,
    /// Nombre de pages du wiki examinées.
    pub pages: usize,
    /// Nombre de sources brutes examinées.
    pub sources: usize,
}

impl Rapport {
    /// Nombre d'erreurs.
    pub fn erreurs(&self) -> usize {
        self.constats
            .iter()
            .filter(|c| c.gravite == Gravite::Erreur)
            .count()
    }

    /// Le rapport est-il en échec ?
    pub fn en_echec(&self) -> bool {
        self.erreurs() > 0
    }

    fn signaler(&mut self, gravite: Gravite, chemin: &Path, message: String) {
        self.constats.push(Constat {
            gravite,
            chemin: chemin.to_owned(),
            message,
        });
    }
}

/// Une page du wiki, telle que lue.
struct Page {
    chemin: PathBuf,
    nom: String,
    contenu: String,
}

/// Vérifie le dépôt de savoir situé à `savoir`, sans rien y écrire.
pub fn verifier(savoir: &Path) -> Resultat<Rapport> {
    let mut rapport = Rapport::default();
    let fichiers = fichiers_du_depot(savoir)?;

    verifier_absence_de_code(&fichiers, &mut rapport);
    let identifiants = verifier_sources(savoir, &fichiers, &mut rapport)?;
    let pages = lire_pages(savoir, &fichiers)?;
    rapport.pages = pages.len();
    let noms = noms_de_pages(&pages, &mut rapport);
    for page in &pages {
        verifier_page(savoir, page, &identifiants, &noms, &mut rapport);
    }
    verifier_liens_entrants(&pages, &noms, &mut rapport);
    verifier_index(savoir, &pages, &noms, &mut rapport)?;
    verifier_journal(savoir, &mut rapport)?;

    rapport.constats.sort();
    Ok(rapport)
}

/// Fichiers du dépôt, relatifs à sa racine : ceux que suit git quand le
/// dépôt en est un (c'est ce qui est versionné), tous sinon (hors `.git`).
fn fichiers_du_depot(savoir: &Path) -> Resultat<Vec<PathBuf>> {
    if savoir.join(".git").exists()
        && let Ok(sortie) = Command::new("git")
            .arg("-C")
            .arg(savoir)
            .args(["ls-files", "-z"])
            .output()
        && sortie.status.success()
    {
        return Ok(sortie
            .stdout
            .split(|octet| *octet == 0)
            .filter(|nom| !nom.is_empty())
            .map(|nom| PathBuf::from(String::from_utf8_lossy(nom).into_owned()))
            .collect());
    }
    let mut fichiers = Vec::new();
    parcourir(savoir, Path::new(""), &mut fichiers)?;
    fichiers.sort();
    Ok(fichiers)
}

pub(crate) fn parcourir(
    racine: &Path,
    relatif: &Path,
    fichiers: &mut Vec<PathBuf>,
) -> Resultat<()> {
    let dossier = racine.join(relatif);
    let entrees = fs::read_dir(&dossier).map_err(|cause| Erreur::Fichier {
        chemin: dossier.clone(),
        cause,
    })?;
    for entree in entrees {
        let entree = entree.map_err(|cause| Erreur::Fichier {
            chemin: dossier.clone(),
            cause,
        })?;
        let nom = entree.file_name();
        if nom == ".git" {
            continue;
        }
        let chemin = relatif.join(&nom);
        let genre = entree.file_type().map_err(|cause| Erreur::Fichier {
            chemin: racine.join(&chemin),
            cause,
        })?;
        if genre.is_dir() {
            parcourir(racine, &chemin, fichiers)?;
        } else {
            fichiers.push(chemin);
        }
    }
    Ok(())
}

fn verifier_absence_de_code(fichiers: &[PathBuf], rapport: &mut Rapport) {
    for fichier in fichiers {
        let derive = fichier.components().any(|composant| {
            DOSSIERS_DERIVES
                .iter()
                .any(|derive| composant.as_os_str() == *derive)
        });
        let code = fichier
            .extension()
            .and_then(|extension| extension.to_str())
            .is_some_and(|extension| {
                EXTENSIONS_DE_CODE.contains(&extension.to_ascii_lowercase().as_str())
            });
        if derive {
            rapport.signaler(
                Gravite::Erreur,
                fichier,
                "dérivé ou outillage versionné dans le savoir".to_owned(),
            );
        } else if code {
            rapport.signaler(
                Gravite::Erreur,
                fichier,
                "programme versionné dans le savoir".to_owned(),
            );
        }
    }
}

/// Lit les sources brutes (`raw/textes`, `raw/decisions`) et rend les
/// identifiants qu'elles portent (identifiant et identifiant chronologique).
fn verifier_sources(
    savoir: &Path,
    fichiers: &[PathBuf],
    rapport: &mut Rapport,
) -> Resultat<BTreeSet<String>> {
    let mut identifiants = BTreeSet::new();
    for fichier in fichiers.iter().filter(|f| est_markdown(f)) {
        if !(fichier.starts_with("raw/textes") || fichier.starts_with("raw/decisions")) {
            continue;
        }
        rapport.sources += 1;
        let contenu = lire(savoir, fichier)?;
        let Some(entete) = lire_entete(&contenu) else {
            rapport.signaler(
                Gravite::Erreur,
                fichier,
                "source brute sans en-tête".to_owned(),
            );
            continue;
        };
        let Some(identifiant) = valeur(&entete, "identifiant").filter(|v| !v.trim().is_empty())
        else {
            rapport.signaler(
                Gravite::Erreur,
                fichier,
                "source brute sans identifiant".to_owned(),
            );
            continue;
        };
        for manquant in ["source", "capture_le"]
            .into_iter()
            .filter(|cle| valeur(&entete, cle).is_none())
        {
            rapport.signaler(
                Gravite::Erreur,
                fichier,
                format!("source brute sans « {manquant} »"),
            );
        }
        identifiants.insert(identifiant.trim().to_owned());
        if let Some(cid) = valeur(&entete, "cid") {
            identifiants.insert(cid.trim().to_owned());
        }
    }
    Ok(identifiants)
}

fn lire_pages(savoir: &Path, fichiers: &[PathBuf]) -> Resultat<Vec<Page>> {
    let mut pages = Vec::new();
    for fichier in fichiers
        .iter()
        .filter(|f| est_markdown(f) && f.starts_with("wiki"))
    {
        if fichier == Path::new("wiki/index.md") || fichier == Path::new("wiki/log.md") {
            continue;
        }
        let nom = fichier
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or_default()
            .to_owned();
        pages.push(Page {
            chemin: fichier.clone(),
            nom,
            contenu: lire(savoir, fichier)?,
        });
    }
    Ok(pages)
}

/// Nom d'une page → son chemin ; un nom porté par deux pages est ambigu.
fn noms_de_pages(pages: &[Page], rapport: &mut Rapport) -> BTreeMap<String, PathBuf> {
    let mut noms: BTreeMap<String, PathBuf> = BTreeMap::new();
    for page in pages {
        if let Some(autre) = noms.get(&page.nom) {
            rapport.signaler(
                Gravite::Erreur,
                &page.chemin,
                format!("nom de page ambigu, déjà porté par {}", autre.display()),
            );
        } else {
            noms.insert(page.nom.clone(), page.chemin.clone());
        }
    }
    noms
}

fn verifier_page(
    savoir: &Path,
    page: &Page,
    identifiants: &BTreeSet<String>,
    noms: &BTreeMap<String, PathBuf>,
    rapport: &mut Rapport,
) {
    let chemin = &page.chemin;
    let Some(entete) = lire_entete(&page.contenu) else {
        rapport.signaler(Gravite::Erreur, chemin, "page sans en-tête".to_owned());
        return;
    };
    match valeur(&entete, "type").map(str::trim) {
        Some(genre) if TYPES_DE_PAGE.contains(&genre) => {}
        Some(genre) => rapport.signaler(
            Gravite::Erreur,
            chemin,
            format!("type de page inconnu « {genre} »"),
        ),
        None => rapport.signaler(Gravite::Erreur, chemin, "page sans « type »".to_owned()),
    }
    match valeur(&entete, "verifie_le").map(str::trim) {
        Some(date) if lire_date(date).is_ok() => {}
        Some(date) => rapport.signaler(
            Gravite::Erreur,
            chemin,
            format!("« verifie_le » mal formé : {date}"),
        ),
        None => rapport.signaler(
            Gravite::Erreur,
            chemin,
            "page sans « verifie_le »".to_owned(),
        ),
    }
    if valeur(&entete, "valide_par").is_none_or(|referent| referent.trim().is_empty()) {
        rapport.signaler(
            Gravite::Erreur,
            chemin,
            "page sans référent (« valide_par »)".to_owned(),
        );
    }

    let sources = valeur(&entete, "sources").map(liste).unwrap_or_default();
    if sources.is_empty() {
        rapport.signaler(
            Gravite::Erreur,
            chemin,
            "page sans source (« sources »)".to_owned(),
        );
    }
    for source in sources {
        if source.starts_with("raw/_propositions") {
            rapport.signaler(
                Gravite::Erreur,
                chemin,
                format!("source encore en proposition : {source}"),
            );
        } else if !source.starts_with("raw/") || !savoir.join(source).is_file() {
            rapport.signaler(
                Gravite::Erreur,
                chemin,
                format!("source absente de raw/ : {source}"),
            );
        }
    }

    for identifiant in identifiants_cites(&page.contenu) {
        if !identifiants.contains(&identifiant) {
            rapport.signaler(
                Gravite::Erreur,
                chemin,
                format!("identifiant cité qu'aucune source brute ne porte : {identifiant}"),
            );
        }
    }

    for lien in liens(&page.contenu) {
        if resoudre(&lien, noms).is_none() {
            rapport.signaler(Gravite::Erreur, chemin, format!("lien cassé : [[{lien}]]"));
        }
    }
}

fn verifier_liens_entrants(
    pages: &[Page],
    noms: &BTreeMap<String, PathBuf>,
    rapport: &mut Rapport,
) {
    let mut entrants: BTreeMap<&Path, BTreeSet<&Path>> = BTreeMap::new();
    for page in pages {
        for lien in liens(&page.contenu) {
            if let Some(cible) = resoudre(&lien, noms)
                && cible != page.chemin.as_path()
            {
                entrants.entry(cible).or_default().insert(&page.chemin);
            }
        }
    }
    for page in pages {
        let nombre = entrants.get(page.chemin.as_path()).map_or(0, BTreeSet::len);
        if nombre == 0 {
            rapport.signaler(
                Gravite::Avertissement,
                &page.chemin,
                "page orpheline : aucun lien entrant".to_owned(),
            );
        } else if nombre > SEUIL_SUR_CONNEXION {
            rapport.signaler(
                Gravite::Avertissement,
                &page.chemin,
                format!("page sur-connectée : {nombre} liens entrants (> {SEUIL_SUR_CONNEXION})"),
            );
        }
    }
}

fn verifier_index(
    savoir: &Path,
    pages: &[Page],
    noms: &BTreeMap<String, PathBuf>,
    rapport: &mut Rapport,
) -> Resultat<()> {
    let index = Path::new("wiki/index.md");
    if !savoir.join(index).is_file() {
        rapport.signaler(Gravite::Erreur, index, "index du wiki absent".to_owned());
        return Ok(());
    }
    let contenu = lire(savoir, index)?;
    let mut indexees = BTreeSet::new();
    for lien in liens(&contenu) {
        match resoudre(&lien, noms) {
            Some(cible) => {
                indexees.insert(cible.to_owned());
            }
            None => rapport.signaler(
                Gravite::Erreur,
                index,
                format!("l'index nomme une page absente : [[{lien}]]"),
            ),
        }
    }
    for page in pages.iter().filter(|page| !indexees.contains(&page.chemin)) {
        rapport.signaler(
            Gravite::Erreur,
            &page.chemin,
            "page absente de l'index".to_owned(),
        );
    }
    Ok(())
}

fn verifier_journal(savoir: &Path, rapport: &mut Rapport) -> Resultat<()> {
    let journal = Path::new("wiki/log.md");
    if !savoir.join(journal).is_file() {
        rapport.signaler(
            Gravite::Erreur,
            journal,
            "journal du wiki absent".to_owned(),
        );
        return Ok(());
    }
    let contenu = lire(savoir, journal)?;
    for (numero, ligne) in contenu.lines().enumerate() {
        let Some(entree) = ligne.strip_prefix("## ") else {
            continue;
        };
        let numero = numero + 1;
        let Some((date, reste)) = entree.strip_prefix('[').and_then(|r| r.split_once("] ")) else {
            rapport.signaler(
                Gravite::Erreur,
                journal,
                format!("ligne {numero} : entrée sans « [AAAA-MM-JJ] »"),
            );
            continue;
        };
        if lire_date(date).is_err() {
            rapport.signaler(
                Gravite::Erreur,
                journal,
                format!("ligne {numero} : date mal formée « {date} »"),
            );
        }
        let mut champs = reste.split(" | ");
        let operation = champs.next().unwrap_or_default().trim();
        if !OPERATIONS_DU_JOURNAL.contains(&operation) {
            rapport.signaler(
                Gravite::Erreur,
                journal,
                format!("ligne {numero} : opération inconnue « {operation} »"),
            );
        } else if operation == "ingest"
            && !champs.any(|champ| champ.trim_start().starts_with("validé par "))
        {
            rapport.signaler(
                Gravite::Erreur,
                journal,
                format!("ligne {numero} : ingestion sans référent (« validé par … »)"),
            );
        }
    }
    Ok(())
}

fn lire(savoir: &Path, fichier: &Path) -> Resultat<String> {
    let chemin = savoir.join(fichier);
    fs::read_to_string(&chemin).map_err(|cause| Erreur::Fichier { chemin, cause })
}

fn est_markdown(fichier: &Path) -> bool {
    fichier
        .extension()
        .is_some_and(|extension| extension == "md")
}

/// Liste d'un en-tête : `[a, b]` ou `a, b`.
fn liste(valeur: &str) -> Vec<&str> {
    valeur
        .trim()
        .trim_start_matches('[')
        .trim_end_matches(']')
        .split(',')
        .map(str::trim)
        .filter(|element| !element.is_empty())
        .collect()
}

/// Cibles des liens `[[cible]]` ou `[[cible|libellé]]`.
fn liens(contenu: &str) -> Vec<String> {
    let mut liens = Vec::new();
    let mut reste = contenu;
    while let Some(debut) = reste.find("[[") {
        let apres = reste.get(debut + 2..).unwrap_or_default();
        let Some(fin) = apres.find("]]") else { break };
        let interieur = apres.get(..fin).unwrap_or_default();
        let cible = interieur.split('|').next().unwrap_or_default().trim();
        if !cible.is_empty() {
            liens.push(cible.to_owned());
        }
        reste = apres.get(fin + 2..).unwrap_or_default();
    }
    liens
}

/// Résout un lien : par nom de page, ou par chemin sous `wiki/` sans
/// extension (`situations/arbres`).
fn resoudre<'a>(lien: &str, noms: &'a BTreeMap<String, PathBuf>) -> Option<&'a Path> {
    let lien = lien.trim_end_matches(".md");
    if lien.contains('/') {
        let attendu = Path::new("wiki").join(format!("{lien}.md"));
        noms.values()
            .find(|chemin| **chemin == attendu)
            .map(PathBuf::as_path)
    } else {
        noms.get(lien).map(PathBuf::as_path)
    }
}

/// Identifiants officiels cités dans un texte : `LEGIARTI`, `LEGITEXT`,
/// `JORFTEXT` suivis de douze chiffres, `ECLI:…`, et `POURVOI:` suivi d'un
/// numéro de pourvoi de la Cour de cassation (décision sans ECLI).
pub(crate) fn identifiants_cites(contenu: &str) -> BTreeSet<String> {
    let mut trouves = BTreeSet::new();
    for prefixe in ["LEGIARTI", "LEGITEXT", "JORFTEXT"] {
        for (position, _) in contenu.match_indices(prefixe) {
            let suite = contenu.get(position + prefixe.len()..).unwrap_or_default();
            let chiffres: String = suite.chars().take_while(char::is_ascii_digit).collect();
            if chiffres.len() == 12 {
                trouves.insert(format!("{prefixe}{chiffres}"));
            }
        }
    }
    let prefixe = crate::judilibre::PREFIXE_POURVOI;
    for (position, _) in contenu.match_indices(prefixe) {
        let suite = contenu.get(position + prefixe.len()..).unwrap_or_default();
        if let Some(numero) = suite.get(..9)
            && crate::judilibre::est_numero_de_pourvoi(numero)
        {
            trouves.insert(format!("{prefixe}{numero}"));
        }
    }
    for (position, _) in contenu.match_indices("ECLI:") {
        let suite = contenu.get(position..).unwrap_or_default();
        let ecli: String = suite
            .chars()
            .take_while(|c| c.is_ascii_alphanumeric() || *c == ':' || *c == '.')
            .collect();
        let ecli = ecli.trim_end_matches(['.', ':']);
        if ecli.matches(':').count() >= 4 {
            trouves.insert(ecli.to_owned());
        }
    }
    trouves
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Un dépôt de savoir jetable, sans git.
    struct Savoir(PathBuf);

    impl Savoir {
        fn new(nom: &str) -> Self {
            let racine = std::env::temp_dir()
                .join(format!("greffier-verifier-{nom}-{}", std::process::id()));
            let _ = fs::remove_dir_all(&racine);
            let savoir = Self(racine);
            savoir.ecrire("wiki/index.md", "# Index\n\n## Situations\n\n- [[arbres-du-voisin]] : branches.\n- [[elagage]] : texte.\n");
            savoir.ecrire("wiki/log.md", "# Journal\n\n## [2026-11-01] schema | amorçage\n\n## [2026-11-02] ingest | raw/textes/LEGIARTI000000000002@2016-10-01.md | validé par Référent Fictif\n");
            savoir.ecrire(
                "raw/textes/LEGIARTI000000000002@2016-10-01.md",
                "---\nidentifiant: LEGIARTI000000000002\ncid: LEGIARTI000000000001\nintitule: \"Code civil, article 673\"\nsource: https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000000000002\netat: VIGUEUR\nen_vigueur: 2016-10-01 / —\ncapture_le: 2026-11-01\n---\n\nTexte fictif.\n",
            );
            savoir.ecrire(
                "wiki/situations/arbres-du-voisin.md",
                "---\ntype: situation\nsources: [raw/textes/LEGIARTI000000000002@2016-10-01.md]\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\n# Arbres du voisin\n\nSelon LEGIARTI000000000002. Voir [[elagage]].\n",
            );
            savoir.ecrire(
                "wiki/textes/elagage.md",
                "---\ntype: texte\nsources: [raw/textes/LEGIARTI000000000002@2016-10-01.md]\nidentifiant: LEGIARTI000000000002\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\n# Élagage\n\nCité par [[situations/arbres-du-voisin|la situation]].\n",
            );
            savoir
        }

        fn ecrire(&self, relatif: &str, contenu: &str) {
            let chemin = self.0.join(relatif);
            fs::create_dir_all(chemin.parent().unwrap()).unwrap();
            fs::write(chemin, contenu).unwrap();
        }

        fn messages(&self) -> Vec<String> {
            verifier(&self.0)
                .unwrap()
                .constats
                .iter()
                .map(ToString::to_string)
                .collect()
        }
    }

    impl Drop for Savoir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn contient(messages: &[String], attendu: &str) -> bool {
        messages.iter().any(|message| message.contains(attendu))
    }

    // [utest->req~moteur-separe-du-savoir~1]
    #[test]
    fn un_savoir_conforme_rend_un_rapport_sans_constat() {
        let savoir = Savoir::new("conforme");
        let rapport = verifier(&savoir.0).unwrap();
        assert_eq!(rapport.constats, Vec::new(), "{:?}", rapport.constats);
        assert_eq!((rapport.pages, rapport.sources), (2, 1));
    }

    // [utest->req~moteur-separe-du-savoir~1]
    #[test]
    fn la_verification_ne_modifie_aucun_fichier() {
        let savoir = Savoir::new("lecture-seule");
        savoir.ecrire("wiki/pratiques/fautive.md", "pas d'en-tête [[absente]]\n");
        let instantane = |racine: &Path| {
            let mut tout = Vec::new();
            parcourir(racine, Path::new(""), &mut tout).unwrap();
            tout.sort();
            tout.into_iter()
                .map(|f| (fs::read(racine.join(&f)).unwrap(), f))
                .collect::<Vec<_>>()
        };
        let avant = instantane(&savoir.0);
        let rapport = verifier(&savoir.0).unwrap();
        assert!(rapport.en_echec());
        assert_eq!(instantane(&savoir.0), avant);
    }

    // [utest->req~moteur-separe-du-savoir~1]
    #[test]
    fn une_page_qui_cite_un_identifiant_absent_des_sources_brutes_fait_echouer_le_rapport() {
        let savoir = Savoir::new("identifiant");
        savoir.ecrire(
            "wiki/situations/arbres-du-voisin.md",
            "---\ntype: situation\nsources: [raw/textes/LEGIARTI000000000002@2016-10-01.md]\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\nSelon LEGIARTI000000000009 et ECLI:FR:CCASS:2000:C300000. Voir [[elagage]].\n",
        );
        let messages = savoir.messages();
        assert!(contient(
            &messages,
            "ERREUR\twiki/situations/arbres-du-voisin.md\tidentifiant cité qu'aucune source brute ne porte : LEGIARTI000000000009"
        ));
        assert!(contient(&messages, "ECLI:FR:CCASS:2000:C300000"));
        assert!(verifier(&savoir.0).unwrap().en_echec());
    }

    // [utest->req~moteur-separe-du-savoir~1]
    #[test]
    fn un_programme_versionne_dans_le_savoir_fait_echouer_le_rapport() {
        let savoir = Savoir::new("code");
        savoir.ecrire("outils/compiler.py", "print('non')\n");
        savoir.ecrire("target/index.bin", "dérivé");
        let messages = savoir.messages();
        assert!(contient(
            &messages,
            "ERREUR\toutils/compiler.py\tprogramme versionné dans le savoir"
        ));
        assert!(contient(
            &messages,
            "ERREUR\ttarget/index.bin\tdérivé ou outillage versionné dans le savoir"
        ));
    }

    #[test]
    fn un_lien_casse_et_une_page_hors_index_sont_des_erreurs() {
        let savoir = Savoir::new("liens");
        savoir.ecrire(
            "wiki/pratiques/accueil.md",
            "---\ntype: pratique\nsources: [raw/textes/LEGIARTI000000000002@2016-10-01.md]\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\nVoir [[inexistante]].\n",
        );
        let messages = savoir.messages();
        assert!(contient(
            &messages,
            "ERREUR\twiki/pratiques/accueil.md\tlien cassé : [[inexistante]]"
        ));
        assert!(contient(
            &messages,
            "ERREUR\twiki/pratiques/accueil.md\tpage absente de l'index"
        ));
        assert!(contient(
            &messages,
            "AVERTISSEMENT\twiki/pratiques/accueil.md\tpage orpheline"
        ));
    }

    #[test]
    fn une_source_absente_ou_en_proposition_est_une_erreur() {
        let savoir = Savoir::new("sources");
        savoir.ecrire(
            "wiki/textes/elagage.md",
            "---\ntype: texte\nsources: [raw/textes/absent.md, raw/_propositions/piste.md]\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\n[[arbres-du-voisin]]\n",
        );
        let messages = savoir.messages();
        assert!(contient(
            &messages,
            "source absente de raw/ : raw/textes/absent.md"
        ));
        assert!(contient(
            &messages,
            "source encore en proposition : raw/_propositions/piste.md"
        ));
    }

    #[test]
    fn un_en_tete_incomplet_est_une_erreur() {
        let savoir = Savoir::new("entete");
        savoir.ecrire(
            "wiki/textes/elagage.md",
            "---\ntype: inconnu\nverifie_le: hier\n---\n\n[[arbres-du-voisin]]\n",
        );
        let messages = savoir.messages();
        for attendu in [
            "type de page inconnu",
            "« verifie_le » mal formé",
            "page sans référent",
            "page sans source",
        ] {
            assert!(contient(&messages, attendu), "absent : {attendu}");
        }
    }

    #[test]
    fn une_ingestion_sans_referent_et_une_entree_mal_formee_sont_des_erreurs() {
        let savoir = Savoir::new("journal");
        savoir.ecrire("wiki/log.md", "# Journal\n\n## [2026-11-02] ingest | raw/textes/x.md\n\n## 2026-11-03 lint | passe\n\n## [2026-11-04] effacer | tout\n");
        let messages = savoir.messages();
        assert!(contient(&messages, "ligne 3 : ingestion sans référent"));
        assert!(contient(
            &messages,
            "ligne 5 : entrée sans « [AAAA-MM-JJ] »"
        ));
        assert!(contient(
            &messages,
            "ligne 7 : opération inconnue « effacer »"
        ));
    }

    #[test]
    fn une_page_sur_connectee_est_signalee() {
        let savoir = Savoir::new("sur-connexion");
        let mut index = String::from("# Index\n\n- [[arbres-du-voisin]]\n- [[elagage]]\n");
        for i in 0..21 {
            savoir.ecrire(
                &format!("wiki/pratiques/p{i}.md"),
                "---\ntype: pratique\nsources: [raw/textes/LEGIARTI000000000002@2016-10-01.md]\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\n[[elagage]]\n",
            );
            index.push_str(&format!("- [[p{i}]]\n"));
        }
        savoir.ecrire("wiki/index.md", &index);
        assert!(contient(
            &savoir.messages(),
            "AVERTISSEMENT\twiki/textes/elagage.md\tpage sur-connectée : 22 liens entrants"
        ));
    }

    #[test]
    fn les_identifiants_cites_sont_extraits_sans_ponctuation_finale() {
        let trouves = identifiants_cites(
            "Voir LEGIARTI000000000003, ECLI:FR:CCASS:2000:C300000. Et LEGIARTI12. \
             Puis POURVOI:81-14.743, et POURVOI:81-14 tronqué.",
        );
        assert_eq!(
            trouves.into_iter().collect::<Vec<_>>(),
            [
                "ECLI:FR:CCASS:2000:C300000",
                "LEGIARTI000000000003",
                "POURVOI:81-14.743"
            ]
        );
    }
}
