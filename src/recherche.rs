// SPDX-License-Identifier: EUPL-1.2
//! Recherche ancrée sur les deux couches d'un dépôt de savoir.
//!
//! La recherche est lexicale (BM25, accents et mots vides ignorés) et porte
//! sur les textes authentiques (`raw/textes`, `raw/decisions`) et sur les
//! pages du wiki. Avant d'être rendu, tout élément passe la porte de
//! l'ancrage : il est écarté, avec son motif, s'il ne porte aucun
//! identifiant officiel, s'il en cite un que la couche des textes ne porte
//! pas, ou si aucun texte qu'il cite n'est en vigueur à la date demandée.
//! La même porte juge un texte venu d'ailleurs — d'un modèle de langue par
//! exemple — par [`Ancres::verdict_texte`].
//!
//! Une version d'article n'est rendue qu'à une date que couvre sa période
//! de vigueur ; une décision n'est pas filtrée par date, car la
//! jurisprudence interprète le droit applicable aux faits, même rendue
//! après eux. La recherche n'écrit rien dans le savoir.

// [impl->req~citation-ancree~1]
// [impl->req~textes-authentiques-versionnes~1]

use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::fs;
use std::path::{Path, PathBuf};

use time::Date;

use crate::couche::{lire_entete, valeur};
use crate::erreur::{Erreur, Resultat};
use crate::periode::{Periode, ecrire_date};
use crate::verifier::{identifiants_cites, parcourir};

/// Saturation de la fréquence d'un terme (BM25).
const K1: f64 = 1.2;
/// Poids de la normalisation par la longueur (BM25).
const B: f64 = 0.75;
/// Longueur maximale d'un extrait, en caractères.
const LONGUEUR_EXTRAIT: usize = 240;
/// Dossiers lus par la recherche, relatifs au dépôt de savoir.
const DOSSIERS: [&str; 3] = ["raw/textes", "raw/decisions", "wiki"];
/// Fichiers réservés du wiki, qui ne sont pas des pages.
const RESERVES: [&str; 2] = ["wiki/index.md", "wiki/log.md"];

/// Mots vides, sans accents : ils ne discriminent aucune page.
const MOTS_VIDES: [&str; 78] = [
    "le", "la", "les", "un", "une", "des", "de", "du", "et", "ou", "au", "aux", "en", "dans",
    "par", "pour", "sur", "avec", "sans", "ce", "ces", "cet", "cette", "mon", "ma", "mes", "ton",
    "ta", "tes", "son", "sa", "ses", "notre", "nos", "votre", "vos", "leur", "leurs", "je", "tu",
    "il", "elle", "on", "nous", "vous", "ils", "elles", "me", "te", "se", "moi", "toi", "lui",
    "est", "sont", "suis", "es", "etre", "ai", "as", "ont", "avoir", "qui", "que", "quoi", "qu",
    "ne", "pas", "plus", "si", "ca", "cela", "comme", "mais", "donc", "car", "peux", "peut",
];

/// Nature d'un élément de réponse.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Nature {
    /// Version d'un article (couche des textes).
    Texte,
    /// Décision de justice (couche des textes).
    Decision,
    /// Page du wiki.
    Page,
}

impl fmt::Display for Nature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Texte => "texte",
            Self::Decision => "decision",
            Self::Page => "page",
        })
    }
}

/// Pourquoi un élément est écarté.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Motif {
    /// L'élément ne porte aucun identifiant officiel.
    SansIdentifiant,
    /// L'élément cite un identifiant que la couche des textes ne porte pas.
    IdentifiantAbsent(String),
    /// Aucun texte cité n'est en vigueur à la date demandée.
    HorsVigueur(Date),
    /// La source brute a un en-tête ou une période illisible.
    SourceMalFormee,
}

impl fmt::Display for Motif {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::SansIdentifiant => f.write_str("aucun identifiant officiel"),
            Self::IdentifiantAbsent(identifiant) => {
                write!(
                    f,
                    "identifiant absent de la couche des textes : {identifiant}"
                )
            }
            Self::HorsVigueur(date) => {
                write!(f, "aucun texte cité en vigueur le {}", ecrire_date(*date))
            }
            Self::SourceMalFormee => f.write_str("source brute mal formée (en-tête ou période)"),
        }
    }
}

/// Quand un identifiant de la couche des textes s'applique.
#[derive(Debug, Clone, PartialEq, Eq)]
enum Applicabilite {
    /// Décision : toujours.
    Toujours,
    /// Article : pendant l'une de ces périodes (une par version conservée).
    Periodes(Vec<Periode>),
}

impl Applicabilite {
    fn couvre(&self, date: Date) -> bool {
        match self {
            Self::Toujours => true,
            Self::Periodes(periodes) => periodes.iter().any(|periode| periode.couvre(date)),
        }
    }
}

/// Registre des identifiants que porte la couche des textes : la porte de
/// l'ancrage.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Ancres {
    table: BTreeMap<String, Applicabilite>,
}

impl Ancres {
    fn ajouter_periode(&mut self, identifiant: &str, periode: Periode) {
        let entree = self
            .table
            .entry(identifiant.to_owned())
            .or_insert_with(|| Applicabilite::Periodes(Vec::new()));
        if let Applicabilite::Periodes(periodes) = entree {
            periodes.push(periode);
        }
    }

    fn ajouter_decision(&mut self, identifiant: &str) {
        self.table
            .insert(identifiant.to_owned(), Applicabilite::Toujours);
    }

    /// La couche des textes porte-t-elle cet identifiant ?
    pub fn contient(&self, identifiant: &str) -> bool {
        self.table.contains_key(identifiant)
    }

    /// Juge un élément par les identifiants qu'il cite : rend ceux qui
    /// s'appliquent à la date, ou le motif de son écart.
    pub fn verdict(
        &self,
        identifiants: &BTreeSet<String>,
        date: Date,
    ) -> Result<Vec<String>, Motif> {
        if identifiants.is_empty() {
            return Err(Motif::SansIdentifiant);
        }
        if let Some(absent) = identifiants.iter().find(|i| !self.contient(i)) {
            return Err(Motif::IdentifiantAbsent(absent.clone()));
        }
        let applicables: Vec<String> = identifiants
            .iter()
            .filter(|i| self.table.get(*i).is_some_and(|a| a.couvre(date)))
            .cloned()
            .collect();
        if applicables.is_empty() {
            Err(Motif::HorsVigueur(date))
        } else {
            Ok(applicables)
        }
    }

    /// Juge un texte venu d'ailleurs (un modèle de langue, un agent) par les
    /// identifiants officiels qu'il cite.
    pub fn verdict_texte(&self, texte: &str, date: Date) -> Result<Vec<String>, Motif> {
        self.verdict(&identifiants_cites(texte), date)
    }
}

/// Un élément indexé.
#[derive(Debug, Clone)]
struct Element {
    nature: Nature,
    chemin: PathBuf,
    intitule: String,
    identifiants: BTreeSet<String>,
    cid: Option<String>,
    /// Période propre d'une version d'article.
    periode: Option<Periode>,
    mal_forme: bool,
    corps: String,
    termes: BTreeMap<String, u32>,
    longueur: usize,
}

/// Un élément rendu par la recherche.
#[derive(Debug, Clone, PartialEq)]
pub struct Trouve {
    /// Nature de l'élément.
    pub nature: Nature,
    /// Fichier, relatif au dépôt de savoir.
    pub chemin: PathBuf,
    /// Intitulé.
    pub intitule: String,
    /// Identifiants officiels applicables à la date.
    pub identifiants: Vec<String>,
    /// Identifiant chronologique d'une version d'article.
    pub cid: Option<String>,
    /// Score BM25.
    pub score: f64,
    /// Le paragraphe le plus proche de la question.
    pub extrait: String,
}

/// Un élément qui répondait à la question et que la porte de l'ancrage a
/// écarté.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Ecart {
    /// Fichier, relatif au dépôt de savoir.
    pub chemin: PathBuf,
    /// Motif de l'écart.
    pub motif: Motif,
}

/// Réponse à une question.
#[derive(Debug, Clone, PartialEq)]
pub struct Reponse {
    /// Date du droit applicable.
    pub date: Date,
    /// Éléments rendus, du plus pertinent au moins pertinent.
    pub retenus: Vec<Trouve>,
    /// Éléments écartés par la porte de l'ancrage.
    pub ecartes: Vec<Ecart>,
}

/// Index de recherche d'un dépôt de savoir, construit en mémoire à chaque
/// lancement : aucun dérivé n'est écrit dans le savoir.
#[derive(Debug, Clone)]
pub struct Index {
    elements: Vec<Element>,
    ancres: Ancres,
    /// Nombre d'éléments qui contiennent chaque terme.
    documents: BTreeMap<String, usize>,
    longueur_moyenne: f64,
}

impl Index {
    /// Lit les deux couches du dépôt de savoir situé à `savoir`.
    pub fn construire(savoir: &Path) -> Resultat<Self> {
        let mut fichiers = Vec::new();
        for dossier in DOSSIERS {
            if savoir.join(dossier).is_dir() {
                parcourir(savoir, Path::new(dossier), &mut fichiers)?;
            }
        }
        fichiers.retain(|f| {
            f.extension().is_some_and(|e| e == "md") && !RESERVES.iter().any(|r| f == Path::new(r))
        });
        fichiers.sort();

        let mut ancres = Ancres::default();
        let mut elements = Vec::with_capacity(fichiers.len());
        for fichier in fichiers {
            let chemin = savoir.join(&fichier);
            let contenu =
                fs::read_to_string(&chemin).map_err(|cause| Erreur::Fichier { chemin, cause })?;
            let element = if fichier.starts_with("raw/textes") {
                lire_texte(fichier, &contenu, &mut ancres)
            } else if fichier.starts_with("raw/decisions") {
                lire_decision(fichier, &contenu, &mut ancres)
            } else {
                lire_page(fichier, &contenu)
            };
            elements.push(element);
        }

        let mut documents: BTreeMap<String, usize> = BTreeMap::new();
        for element in &elements {
            for terme in element.termes.keys() {
                *documents.entry(terme.clone()).or_default() += 1;
            }
        }
        let total: usize = elements.iter().map(|e| e.longueur).sum();
        let longueur_moyenne = if elements.is_empty() || total == 0 {
            1.0
        } else {
            total as f64 / elements.len() as f64
        };
        Ok(Self {
            elements,
            ancres,
            documents,
            longueur_moyenne,
        })
    }

    /// La porte de l'ancrage de ce savoir.
    pub fn ancres(&self) -> &Ancres {
        &self.ancres
    }

    /// Nombre d'éléments indexés.
    pub fn taille(&self) -> usize {
        self.elements.len()
    }

    /// Cherche les éléments qui répondent à `question` dans le droit en
    /// vigueur à `date` ; au plus `max` sont rendus, tous ancrés.
    pub fn chercher(&self, question: &str, date: Date, max: usize) -> Reponse {
        let requete: BTreeSet<String> = jetons(question).into_iter().collect();
        let mut notes: Vec<(&Element, f64)> = self
            .elements
            .iter()
            .map(|element| (element, self.note(element, &requete)))
            .filter(|(_, note)| *note > 0.0)
            .collect();
        notes.sort_by(|(a, na), (b, nb)| nb.total_cmp(na).then_with(|| a.chemin.cmp(&b.chemin)));

        let mut reponse = Reponse {
            date,
            retenus: Vec::new(),
            ecartes: Vec::new(),
        };
        for (element, score) in notes {
            if reponse.retenus.len() >= max {
                break;
            }
            match self.juger(element, date) {
                Ok(identifiants) => reponse.retenus.push(Trouve {
                    nature: element.nature,
                    chemin: element.chemin.clone(),
                    intitule: element.intitule.clone(),
                    identifiants,
                    cid: element.cid.clone(),
                    score,
                    extrait: extrait(&element.corps, &requete),
                }),
                Err(motif) => reponse.ecartes.push(Ecart {
                    chemin: element.chemin.clone(),
                    motif,
                }),
            }
        }
        reponse
    }

    fn juger(&self, element: &Element, date: Date) -> Result<Vec<String>, Motif> {
        if element.mal_forme {
            return Err(Motif::SourceMalFormee);
        }
        let identifiants = self.ancres.verdict(&element.identifiants, date)?;
        // Une version d'article se juge sur sa propre période : son
        // identifiant peut aussi être le cid commun à toutes les versions.
        if element.periode.is_some_and(|periode| !periode.couvre(date)) {
            return Err(Motif::HorsVigueur(date));
        }
        Ok(identifiants)
    }

    fn note(&self, element: &Element, requete: &BTreeSet<String>) -> f64 {
        let total = self.elements.len() as f64;
        let longueur = element.longueur as f64 / self.longueur_moyenne;
        requete
            .iter()
            .filter_map(|terme| {
                let frequence = f64::from(*element.termes.get(terme)?);
                let documents = self.documents.get(terme).copied().unwrap_or(0) as f64;
                let idf = ((total - documents + 0.5) / (documents + 0.5) + 1.0).ln();
                Some(idf * frequence * (K1 + 1.0) / (frequence + K1 * (1.0 - B + B * longueur)))
            })
            .sum()
    }
}

fn lire_texte(chemin: PathBuf, contenu: &str, ancres: &mut Ancres) -> Element {
    let entete = lire_entete(contenu).unwrap_or_default();
    let identifiant = non_vide(valeur(&entete, "identifiant"));
    let cid = non_vide(valeur(&entete, "cid"));
    let periode = valeur(&entete, "en_vigueur").and_then(|p| Periode::lire(p.trim()).ok());
    if let (Some(identifiant), Some(periode)) = (&identifiant, periode) {
        ancres.ajouter_periode(identifiant, periode);
        if let Some(cid) = cid.as_deref().filter(|cid| cid != identifiant) {
            ancres.ajouter_periode(cid, periode);
        }
    }
    let mal_forme = identifiant.is_some() && periode.is_none();
    element(
        Nature::Texte,
        chemin,
        intitule(valeur(&entete, "intitule")),
        identifiant.into_iter().collect(),
        cid,
        periode,
        mal_forme,
        corps(contenu),
    )
}

fn lire_decision(chemin: PathBuf, contenu: &str, ancres: &mut Ancres) -> Element {
    let entete = lire_entete(contenu).unwrap_or_default();
    let identifiant = non_vide(valeur(&entete, "identifiant"));
    if let Some(identifiant) = &identifiant {
        ancres.ajouter_decision(identifiant);
    }
    element(
        Nature::Decision,
        chemin,
        intitule(valeur(&entete, "intitule")),
        identifiant.into_iter().collect(),
        None,
        None,
        false,
        corps(contenu),
    )
}

fn lire_page(chemin: PathBuf, contenu: &str) -> Element {
    let corps = corps(contenu);
    let titre = corps
        .lines()
        .find_map(|ligne| ligne.strip_prefix("# "))
        .map(|titre| titre.trim().to_owned())
        .or_else(|| {
            chemin
                .file_stem()
                .and_then(|nom| nom.to_str())
                .map(str::to_owned)
        })
        .unwrap_or_default();
    element(
        Nature::Page,
        chemin,
        titre,
        identifiants_cites(contenu),
        None,
        None,
        false,
        corps,
    )
}

#[expect(
    clippy::too_many_arguments,
    reason = "constructeur interne qui assemble les champs lus d'un fichier"
)]
fn element(
    nature: Nature,
    chemin: PathBuf,
    intitule: String,
    identifiants: BTreeSet<String>,
    cid: Option<String>,
    periode: Option<Periode>,
    mal_forme: bool,
    corps: &str,
) -> Element {
    // Les termes de l'intitulé comptent double : il nomme ce dont parle
    // l'élément.
    let mut tous = jetons(&intitule);
    tous.extend(jetons(&intitule));
    tous.extend(jetons(corps));
    let longueur = tous.len();
    let mut termes: BTreeMap<String, u32> = BTreeMap::new();
    for terme in tous {
        *termes.entry(terme).or_default() += 1;
    }
    Element {
        nature,
        chemin,
        intitule,
        identifiants,
        cid,
        periode,
        mal_forme,
        corps: corps.to_owned(),
        termes,
        longueur,
    }
}

fn non_vide(valeur: Option<&str>) -> Option<String> {
    valeur
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .map(str::to_owned)
}

/// L'intitulé d'un en-tête, écrit entre guillemets doubles échappés.
fn intitule(valeur: Option<&str>) -> String {
    let brut = valeur.unwrap_or_default().trim();
    serde_json::from_str::<String>(brut).unwrap_or_else(|_| brut.trim_matches('"').to_owned())
}

/// Le document sans son en-tête.
fn corps(document: &str) -> &str {
    document
        .strip_prefix("---\n")
        .and_then(|reste| reste.split_once("\n---\n"))
        .map_or(document, |(_, corps)| corps)
}

/// Termes d'un texte : en minuscules, sans accents, sans mots vides ni
/// lettres isolées, au singulier approché.
pub fn jetons(texte: &str) -> Vec<String> {
    let mut plie = String::with_capacity(texte.len());
    for c in texte.chars().flat_map(char::to_lowercase) {
        match c {
            'à' | 'â' | 'ä' | 'á' => plie.push('a'),
            'é' | 'è' | 'ê' | 'ë' => plie.push('e'),
            'î' | 'ï' | 'í' => plie.push('i'),
            'ô' | 'ö' | 'ó' => plie.push('o'),
            'ù' | 'û' | 'ü' | 'ú' => plie.push('u'),
            'ç' => plie.push('c'),
            'ÿ' => plie.push('y'),
            'œ' => plie.push_str("oe"),
            'æ' => plie.push_str("ae"),
            c => plie.push(c),
        }
    }
    plie.split(|c: char| !c.is_alphanumeric())
        .filter(|mot| mot.chars().count() >= 2 && !MOTS_VIDES.contains(mot))
        .map(raciner)
        .collect()
}

/// Retire la marque du pluriel d'un mot de plus de trois lettres.
fn raciner(mot: &str) -> String {
    if mot.chars().count() > 3
        && let Some(singulier) = mot.strip_suffix(['s', 'x'])
    {
        return singulier.to_owned();
    }
    mot.to_owned()
}

/// Le paragraphe qui contient le plus de termes de la question, tronqué.
fn extrait(corps: &str, requete: &BTreeSet<String>) -> String {
    let mut meilleur: Option<(&str, usize)> = None;
    for paragraphe in corps
        .split("\n\n")
        .map(str::trim)
        .filter(|p| !p.is_empty() && !p.starts_with('#'))
    {
        let communs: BTreeSet<String> = jetons(paragraphe)
            .into_iter()
            .filter(|terme| requete.contains(terme))
            .collect();
        if meilleur.is_none_or(|(_, n)| communs.len() > n) {
            meilleur = Some((paragraphe, communs.len()));
        }
    }
    let texte = meilleur
        .map(|(p, _)| p.split_whitespace().collect::<Vec<_>>().join(" "))
        .unwrap_or_default();
    if texte.chars().count() > LONGUEUR_EXTRAIT {
        let mut court: String = texte.chars().take(LONGUEUR_EXTRAIT).collect();
        court.push('…');
        court
    } else {
        texte
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use time::macros::date;

    use super::*;

    /// Un dépôt de savoir jetable, aux identifiants fictifs : l'article
    /// fictif `LEGIARTI000000000001` en deux versions (avant et depuis le
    /// 2016-10-01), une décision fictive, une page qui les cite.
    pub(crate) struct Savoir(pub(crate) PathBuf);

    impl Savoir {
        pub(crate) fn new(nom: &str) -> Self {
            let racine = std::env::temp_dir()
                .join(format!("greffier-recherche-{nom}-{}", std::process::id()));
            let _ = fs::remove_dir_all(&racine);
            let savoir = Self(racine);
            savoir.ecrire(
                "raw/textes/LEGIARTI000000000001@1804-03-21.md",
                &texte(
                    "LEGIARTI000000000001",
                    "1804-03-21 / 2016-10-01",
                    "Ancienne rédaction : celui sur la propriété duquel avancent les branches des arbres du voisin peut contraindre celui-ci à les couper.",
                ),
            );
            savoir.ecrire(
                "raw/textes/LEGIARTI000000000002@2016-10-01.md",
                &texte(
                    "LEGIARTI000000000002",
                    "2016-10-01 / —",
                    "Celui sur la propriété duquel avancent les branches des arbres, arbustes et arbrisseaux du voisin peut contraindre celui-ci à les couper.\n\nLe droit de couper les racines est imprescriptible.",
                ),
            );
            savoir.ecrire(
                "raw/decisions/ECLI_FR_CCASS_2000_C300000.md",
                "---\nidentifiant: ECLI:FR:CCASS:2000:C300000\njudilibre: 000000000000000000000abc\nintitule: \"cc civ3, 2030-01-01, n° 00-00.000\"\nsource: https://www.courdecassation.fr/decision/000000000000000000000abc\ndate_decision: 2030-01-01\ncapture_le: 2026-11-01\n---\n\nDécision fictive sur l'élagage des branches.\n",
            );
            savoir.ecrire(
                "wiki/situations/arbres-du-voisin.md",
                "---\ntype: situation\nsources: [raw/textes/LEGIARTI000000000002@2016-10-01.md]\nverifie_le: 2026-11-01\nvalide_par: Référent Fictif\n---\n\n# Arbres et branches du voisin\n\n## Résumé\n\nLes branches qui dépassent : le voisin peut être contraint à les couper (LEGIARTI000000000002).\n",
            );
            savoir.ecrire(
                "wiki/index.md",
                "# Index\n\n- [[arbres-du-voisin]] : branches.\n",
            );
            savoir.ecrire(
                "wiki/log.md",
                "# Journal\n\n## [2026-11-01] schema | branches\n",
            );
            savoir
        }

        pub(crate) fn ecrire(&self, relatif: &str, contenu: &str) {
            let chemin = self.0.join(relatif);
            fs::create_dir_all(chemin.parent().unwrap()).unwrap();
            fs::write(chemin, contenu).unwrap();
        }

        pub(crate) fn index(&self) -> Index {
            Index::construire(&self.0).unwrap()
        }
    }

    impl Drop for Savoir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn texte(identifiant: &str, periode: &str, corps: &str) -> String {
        format!(
            "---\nidentifiant: {identifiant}\ncid: LEGIARTI000000000001\nintitule: \"Code civil, article 673\"\nsource: https://www.legifrance.gouv.fr/codes/article_lc/{identifiant}\netat: VIGUEUR\nen_vigueur: {periode}\ncapture_le: 2026-11-01\n---\n\n{corps}\n"
        )
    }

    fn chemins(reponse: &Reponse) -> Vec<&Path> {
        reponse.retenus.iter().map(|t| t.chemin.as_path()).collect()
    }

    // [utest->req~citation-ancree~1]
    #[test]
    fn une_page_sans_identifiant_est_ecartee_et_le_refus_est_motive() {
        let savoir = Savoir::new("sans-identifiant");
        savoir.ecrire(
            "wiki/pratiques/branches-sans-source.md",
            "---\ntype: pratique\n---\n\n# Couper les branches\n\nOn peut couper les branches soi-même.\n",
        );
        let reponse = savoir
            .index()
            .chercher("couper les branches", date!(2026 - 11 - 01), 10);
        let chemin = Path::new("wiki/pratiques/branches-sans-source.md");
        assert!(!chemins(&reponse).contains(&chemin));
        assert!(reponse.ecartes.contains(&Ecart {
            chemin: chemin.to_owned(),
            motif: Motif::SansIdentifiant,
        }));
    }

    // [utest->req~citation-ancree~1]
    #[test]
    fn une_page_qui_cite_un_identifiant_absent_de_la_couche_est_ecartee() {
        let savoir = Savoir::new("absent");
        savoir.ecrire(
            "wiki/pratiques/branches-inventees.md",
            "---\ntype: pratique\n---\n\n# Branches\n\nSelon LEGIARTI000000000002 et LEGIARTI000000000099, couper les branches.\n",
        );
        let reponse = savoir
            .index()
            .chercher("couper les branches", date!(2026 - 11 - 01), 10);
        let chemin = Path::new("wiki/pratiques/branches-inventees.md");
        assert!(!chemins(&reponse).contains(&chemin));
        assert!(reponse.ecartes.contains(&Ecart {
            chemin: chemin.to_owned(),
            motif: Motif::IdentifiantAbsent("LEGIARTI000000000099".to_owned()),
        }));
    }

    // [utest->req~citation-ancree~1]
    #[test]
    fn un_texte_de_modele_n_est_admis_que_s_il_cite_un_texte_conserve() {
        let index = Savoir::new("modele").index();
        let ancres = index.ancres();
        let le = date!(2026 - 11 - 01);
        assert_eq!(
            ancres.verdict_texte("Vous pouvez couper les branches.", le),
            Err(Motif::SansIdentifiant)
        );
        assert_eq!(
            ancres.verdict_texte("Voir l'article LEGIARTI000000004242.", le),
            Err(Motif::IdentifiantAbsent("LEGIARTI000000004242".to_owned()))
        );
        assert_eq!(
            ancres.verdict_texte("Voir LEGIARTI000000000002.", le),
            Ok(vec!["LEGIARTI000000000002".to_owned()])
        );
    }

    // [utest->req~citation-ancree~1]
    #[test]
    fn tout_element_rendu_porte_un_identifiant_de_la_couche() {
        let savoir = Savoir::new("tout-ancre");
        let index = savoir.index();
        let reponse = index.chercher("branches arbres voisin", date!(2026 - 11 - 01), 10);
        assert!(!reponse.retenus.is_empty());
        for trouve in &reponse.retenus {
            assert!(!trouve.identifiants.is_empty(), "{trouve:?}");
            assert!(
                trouve
                    .identifiants
                    .iter()
                    .all(|i| index.ancres().contient(i))
            );
        }
    }

    // [utest->req~textes-authentiques-versionnes~1]
    #[test]
    fn seule_la_version_en_vigueur_a_la_date_est_rendue() {
        let index = Savoir::new("versions").index();
        let avant = index.chercher("branches arbres voisin", date!(2010 - 05 - 05), 10);
        let apres = index.chercher("branches arbres voisin", date!(2020 - 05 - 05), 10);
        let ancienne = Path::new("raw/textes/LEGIARTI000000000001@1804-03-21.md");
        let nouvelle = Path::new("raw/textes/LEGIARTI000000000002@2016-10-01.md");
        assert!(chemins(&avant).contains(&ancienne) && !chemins(&avant).contains(&nouvelle));
        assert!(chemins(&apres).contains(&nouvelle) && !chemins(&apres).contains(&ancienne));
        assert!(apres.ecartes.contains(&Ecart {
            chemin: ancienne.to_owned(),
            motif: Motif::HorsVigueur(date!(2020 - 05 - 05)),
        }));
    }

    #[test]
    fn une_page_dont_aucun_texte_cite_n_est_en_vigueur_est_ecartee() {
        let index = Savoir::new("page-hors-vigueur").index();
        let reponse = index.chercher("branches qui dépassent", date!(2010 - 05 - 05), 10);
        assert!(reponse.ecartes.contains(&Ecart {
            chemin: PathBuf::from("wiki/situations/arbres-du-voisin.md"),
            motif: Motif::HorsVigueur(date!(2010 - 05 - 05)),
        }));
    }

    #[test]
    fn une_decision_n_est_pas_filtree_par_la_date_des_faits() {
        let index = Savoir::new("decision").index();
        let reponse = index.chercher("élagage", date!(2020 - 01 - 01), 10);
        assert_eq!(
            chemins(&reponse),
            vec![Path::new("raw/decisions/ECLI_FR_CCASS_2000_C300000.md")]
        );
    }

    #[test]
    fn une_source_brute_a_la_periode_illisible_est_ecartee() {
        let savoir = Savoir::new("mal-forme");
        savoir.ecrire(
            "raw/textes/LEGIARTI000000000003@2000-01-01.md",
            "---\nidentifiant: LEGIARTI000000000003\nen_vigueur: hier\n---\n\nTexte sur les clôtures.\n",
        );
        let reponse = savoir
            .index()
            .chercher("clôtures", date!(2026 - 11 - 01), 10);
        assert!(reponse.retenus.is_empty());
        assert_eq!(
            reponse.ecartes.first().map(|e| &e.motif),
            Some(&Motif::SourceMalFormee)
        );
    }

    #[test]
    fn les_jetons_ignorent_accents_elisions_mots_vides_et_pluriels() {
        assert_eq!(
            jetons("L’élagage des Branches de l'arbre — œuvre"),
            vec!["elagage", "branche", "arbre", "oeuvre"]
        );
    }

    #[test]
    fn l_intitule_et_la_frequence_ordonnent_les_elements() {
        let savoir = Savoir::new("ordre");
        savoir.ecrire(
            "wiki/pratiques/racines.md",
            "---\ntype: pratique\n---\n\n# Racines\n\nRacines, racines, racines (LEGIARTI000000000002).\n",
        );
        let reponse = savoir
            .index()
            .chercher("racines", date!(2026 - 11 - 01), 10);
        assert_eq!(
            chemins(&reponse).first(),
            Some(&Path::new("wiki/pratiques/racines.md"))
        );
    }

    #[test]
    fn l_extrait_est_le_paragraphe_le_plus_proche_de_la_question() {
        let index = Savoir::new("extrait").index();
        let reponse = index.chercher("racines imprescriptible", date!(2026 - 11 - 01), 1);
        assert_eq!(
            reponse.retenus.first().map(|t| t.extrait.as_str()),
            Some("Le droit de couper les racines est imprescriptible.")
        );
    }

    #[test]
    fn le_nombre_d_elements_rendus_est_borne() {
        let index = Savoir::new("borne").index();
        assert_eq!(
            index
                .chercher("branches arbres voisin", date!(2026 - 11 - 01), 1)
                .retenus
                .len(),
            1
        );
    }
}
