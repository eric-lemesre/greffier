# Journal des changements

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) —
versionnement : [SemVer](https://semver.org/lang/fr/).

## [Non publié]

### Ajouté

- **Tests d'outillage joués en parallèle** (exigence `req~porte-ci~2`,
  constaté sur un projet instancié) : `tools/paralleles.sh` les joue au plus
  `CI_PARALLELE` à la fois (défaut : le nombre de processeurs), chacun
  jusqu'au bout quel que soit le verdict des autres, et rend leurs sorties
  dans l'ordre de la liste ; le bilan de `tools/ci.sh` donne la durée de
  chaque porte. `tools/paralleles-test.sh` joue les cas d'échec, dont un
  rendez-vous qu'un lanceur séquentiel ne tient pas. L'instanciation
  retire la ligne de son test de cette liste. Fermé en cas de panne : une
  étape non jouée jusqu'au bout (travailleur tué, xargs absent) est un
  échec nommé, `CI_PARALLELE` invalide est refusé, et `tools/ci.sh` exige
  une ligne de bilan par étape ; un `date` sans `%s` ne prive que la durée
  de sa valeur. Décrit au chapitre 4 de la méthode. Revue
  `docs/revues/2026-10-30-ci-parallele.md`.

- **Tout fichier de code se rattache à une exigence** (exigence
  `req~rattachement-code-exigence~1`, domaine traçabilité, D-2026-10-01).
  Porte `tools/rattachement.sh`, câblée dans `tools/ci.sh` (voie
  documentaire) : chaque fichier de code suivi par git porte une étiquette de
  couverture vers un item existant, ou la mention « Exigence servie :
  req~…~n » d'une exigence existante quand il la sert sans la couvrir ; une
  étiquette vers une révision périmée échoue, y compris dans `templates/`,
  qu'OpenFastTrace ne balaie pas. L'instanciation dresse la liste du code
  hérité du gabarit (`tools/rattachement-herites.txt`) et retire ses
  mentions avec ses étiquettes. Sept fichiers sans trace rattachés ; le kit
  de lint Markdown, sans exigence jusque-là, reçoit la sienne
  (`req~kit-lint-markdown~1`, PEUT, proposée). `tools/rattachement-test.sh`
  joue les cas d'échec ; `tools/init-test.sh` éprouve le projet produit.

- **Hygiène des artefacts de compilation** (exigences
  `req~hygiene-artefacts-compilation~1` et
  `req~confinement-artefacts-worktree~1`, domaine gouvernance). Porte
  `tools/hygiene-compilation.sh`, câblée dans `tools/ci.sh` : dans un projet
  qui compile du Rust, la chaîne
  est épinglée (`rust-toolchain.toml` suivi par git, canal exact ou daté —
  pas « stable ») et tout fichier qui lance des tests ou une couverture Cargo
  coupe l'incrémental (`CARGO_INCREMENTAL` à zéro sur la ligne ou avant le
  premier appel, formes `env:`, `variables:`, `:=` de just et
  `.cargo/config.toml` reconnues) ; sans manifeste, la porte le dit et passe.
  Kit Rust prêt à copier dans `templates/bootstrap.d/` : module `50-rust.sh`
  (cargo, nextest, sweep, chaîne) et `rust/rust.sh` (garde des worktrees
  liés : artefacts dans le worktree ou dans `cargo-target-<nom>` seulement ;
  tests et couverture sans incrémental ; nettoyage par l'âge, jamais par un
  plafond, refusé sur un cache partagé sans `--partage`). Deux anti-patrons
  au chapitre 4. Constats à l'origine : 70 à 80 Go de cache par branche de
  travail et un disque plein trois fois en un mois ; un balayage par plafond
  de taille qui casse une compilation en cours.
  `tools/hygiene-compilation-test.sh` et `tools/rust-kit-test.sh` (talons
  cargo et cargo-sweep) jouent les cas d'échec.

- **Le lanceur joue toutes les portes et rend un bilan** (ADR-0019,
  `req~porte-ci~2`). `tools/ci.sh` ne s'arrête plus à la première porte en
  échec : il les joue toutes, les nomme toutes avec leur verdict, et sort en
  erreur en annonçant combien ont échoué. Une porte LÉGITIMEMENT rouge — une
  traçabilité qui attend la réalisation d'exigences déjà écrites — masquait
  jusqu'ici l'état de toutes celles qui la suivaient, et rien dans la sortie
  ne distinguait une porte non jouée d'une porte absente. Constaté sur un
  projet instancié : deux tests d'outillage cassés depuis l'origine, dont l'un
  depuis la fondation du gabarit, découverts en jouant les portes une à une à
  la main. `tools/ci-test.sh` éprouve l'invariant — la liste des portes jouées
  ne dépend pas de leurs verdicts — sans supposer un dépôt sain.

- **Aucune référence pendante depuis une façade ou le contrat**
  (`tools/checks.sh`). Une façade — `ci.sh`, `Taskfile.yml`, les deux façades
  CI, le justfile — ou `AGENTS.md` qui appelle un script absent ne se voit
  qu'à l'exécution, donc en CI et jamais en revue ; le contrat, lui, documente
  alors une commande qui échoue. Le contrôle porte sur la RÉFÉRENCE et non sur
  un nom de fichier, de sorte qu'il attrape aussi le script renommé. Cas
  d'échec dans `tools/checks-test.sh` — dont le dépôt de synthèse a dû recevoir
  un talon de `tools/ci.sh`, que ses deux façades CI appelaient déjà sans qu'il
  existe.

- **L'accueil renseigne, il ne sanctionne pas** (`req~accueil-informatif~1`).
  `tools/setup.sh` joue désormais la voie documentaire complète et en rapporte
  le bilan, sans faire du verdict des portes un échec de l'accueil. Un dépôt
  dont la spécification précède la réalisation a des portes légitimement
  rouges ; en faire échouer le premier geste d'un arrivant lui fait porter un
  défaut qui n'est pas le sien et qu'il ne peut pas corriger. Le silence
  serait pire : l'état est annoncé, et le bilan nomme les portes fautives.
  `task ci` sanctionne, `task setup` renseigne. Exigence NOUVELLE plutôt que
  révision de `req~onboarding-outille~2`, qui est tenue.

- **Porte des données** (`req~donnees-hors-depot~1`). Le dépôt porte le modèle
  des données, jamais les données. `tools/donnees.sh` refuse un export
  versionné, un SQL porteur de données — seuls les schémas sont admis — et un
  chemin de partage réseau qualifié par un nom de serveur et un domaine. Les
  trois refus se lisent sur le CONTENU : un `.gitignore` ne protège que du
  geste distrait, il n'empêche ni un ajout forcé ni le suivi d'un fichier déjà
  versionné. Le cas le plus insidieux est celui qu'aucun nom ne trahit — un
  SQL au bon endroit, sous une extension légitime, dont seules les lignes
  d'insertion révèlent l'extrait de production. Un bloc `fixtures` permet à un
  projet de déclarer ses jeux d'essai ; le test vérifie que la déclaration ne
  couvre pas plus que son chemin. Constaté sur un projet instancié, où le
  chemin d'un partage interne avait suivi la documentation d'un code existant.

### Corrigé

- **Artefacts générés indépendants de la locale** (exigence
  `req~anti-derive-generes~1`, constaté sur un projet instancié dont la CI
  tourne en `C.UTF-8` et le poste en `fr_FR`) : le suivi de revue et la
  matrice trient en ordre des octets (`LC_COLLATE=C`), et la largeur des
  badges se compte en caractères sous toute locale, `C` comprise. Un
  artefact généré sur le poste ne se dit plus périmé en CI.
  `tools/locale-test.sh` les génère sous une locale de langue et sous `C`,
  sur des données dont les deux ordres diffèrent, et exige des sorties
  identiques.

- **L'instanciation garde les droits d'exécution et une matrice à jour**
  (`req~instanciation-outillee~2`). `tools/init.sh` réécrivait ses fichiers
  par un temporaire puis `mv` : 43 scripts perdaient leur droit
  d'exécution, et le hook pre-commit du projet produit refusait de
  s'exécuter (« Permission non accordée »). Il remplace désormais le
  contenu sur place (`remplacer`), et ne se réécrit plus lui-même pendant
  son exécution. Il retire aussi `tools/init.sh` et `tools/init-test.sh` de
  l'index avant de dresser la matrice, qui les listait encore : la porte
  anti-dérive refusait le premier commit. Constaté le 2026-10-31 sur deux
  projets instanciés ; `tools/init-test.sh` éprouve les deux cas, qui
  échouaient avant le correctif.

- **Quatre chemins de corruption silencieuse fermés dans les portes de
  traçabilité** (`tools/classification.sh`, `tools/matrice.sh`,
  `tools/avancement.sh`), constatés par revue adversariale sur un projet
  instancié. Une deuxième ligne `Needs:` écrasait la première — deux
  couvertures déclarées, une seule comptée : les lignes se cumulent désormais.
  Un `Needs :` à la française (espace avant le deux-points) échappait aux
  motifs `/^Needs:/` — la porte se désarmait en silence : l'espace est toléré.
  Les types de vérification se lisaient par sous-chaîne — un mot qui contient
  `itest` aurait compté : frontières de mot. Enfin le balayage des couvertures
  réelles de la matrice incluait `docs/revues` et `docs/todo` — un constat de
  revue qui CITE un tag aurait compté comme preuve : ces répertoires parlent
  des exigences, ils ne les couvrent pas, ils sont exclus. Aucune valeur
  produite ne change aujourd'hui (les générés sont identiques) : ces défauts
  étaient latents, pas actifs. S'y ajoute une limite désormais écrite dans
  `tools/avancement.sh` : « implémentée » inclut le vérifié manuellement
  (R10), là où la complétude signale « à élever » — deux vues qui coexistent,
  chacune disant ce qu'elle mesure.

- **L'outillage d'instanciation se retire lui-même**
  (`req~instanciation-outillee~2`). `tools/init.sh` supprime, en dernier geste,
  son test, ses références dans les façades et le contrat, puis lui-même. Le
  retrait était jusqu'ici PROPOSÉ en fin de message, comme une option, après
  cinq autres étapes : une option qui doit être prise à chaque fois n'en est
  pas une. Deux conséquences constatées sur un projet instancié — le test
  rejouait le script sur un dépôt portant sa propre spécification et son propre
  code, dont les tags de couverture devenaient orphelins dans le dépôt produit ;
  et le script laissé en place restait destructeur tout en étant documenté au
  contrat.

- **`tools/derive-test.sh` ne laissait que le bloc « socle » neutralisé.** Le
  fichier prévoit explicitement des cibles PROPRES AU PROJET après ce bloc ;
  les laisser dans le dépôt de synthèse y faisait chercher des artefacts
  inexistants, et le cas « artefact à jour, la porte doit passer » échouait dès
  la première cible propre au projet. Invisible dans le gabarit, qui n'en a
  aucune.

- **`tools/gouvernance-test.sh` supposait la langue par défaut du gabarit.** Le
  cas bilingue était écrit en dur et exigeait qu'un verdict d'audit anglais
  soit accepté : vrai en « fr-en », faux dans tout dépôt instancié en « fr », où
  la porte le refuse à bon droit. Même défaut que celui corrigé sur
  `tools/socle-test.sh` par ADR-0002. L'assertion suit désormais la langue
  constatée, avec un cas pour chacune des trois valeurs.

- **`tools/oft.sh` n'avait aucun emplacement pour le code de réalisation.** Le
  périmètre scanné ne connaissait que `examples/` et `tools/` ; `src/` s'y
  ajoute. Le gabarit ne réalise rien, mais tout projet instancié le fait, et
  ses exigences seraient restées orphelines sans qu'on sache pourquoi.

- **Cohérence du dépôt produit avec les choix d'instanciation**
  (`req~coherence-choix-instanciation~1`). Un choix qui retire ou modifie une
  porte doit désormais se propager aux textes normatifs et aux tests
  d'outillage du dépôt produit. Trois défauts constatés sur un dépôt réel :
  une instanciation « mentions interdites » livrait une boucle de travail
  réclamant le trailer `IA:` que son propre hook refuse — contrat inapplicable
  dès le premier commit — un dépôt monolingue héritait d'un test exigeant la
  porte de parité des modèles que l'instanciation venait de retirer, et le
  registre des décisions réécrit laissait subsister des relevés citant des
  décisions absentes. `tools/init.sh` propage, `tools/socle-test.sh` et
  `tools/checks-test.sh` lisent la porte installée, et `tools/init-test.sh`
  joue désormais les tests du dépôt produit — ce qui aurait attrapé les trois.

- **Écart d'audit tranché : le statut de cycle de vie est porté par
  l'EXIGENCE** (ADR-0018, D-2026-08-17, `req~cycle-de-vie-exigence~2`).
  L'arbitrage a retenu de tenir l'exigence et de l'outiller plutôt que de
  l'abaisser au niveau du domaine — celui-ci mêle des exigences approuvées mais
  non réalisées et d'autres livrées et prouvées, granularité trop grossière
  pour la question posée.

  Le statut se lit sur **deux parts** : déclarée (brouillon · proposée ·
  approuvée · rejetée · dépréciée), qui relève du jugement, et **calculée**
  (implémentée · vérifiée), dérivée des tags et des items de couverture
  réellement présents. La porte **refuse** qu'un statut d'avancement soit écrit
  à la main : un avancement saisi se périme au premier remaniement sans rien
  signaler, et un tableau affichant « vérifiée » pour une exigence que plus
  aucun test ne couvre inspire d'autant plus confiance qu'il donne un chiffre.

  Le statut de **domaine** subsiste sur un axe orthogonal — il dit si le
  document est arbitré, non où en est une réalisation. Une règle mécanisée
  empêche les deux axes de diverger : une exigence n'est approuvée que dans un
  domaine actif. Le dénominateur des taux passe à la granularité de
  l'exigence : approuvée et au-delà comptent, le reste non.

  Les 39 exigences portent leur statut ; l'avancement calculé s'établit à
  **39 implémentées, 39 vérifiées**. Chapitre 13 réécrit sur les deux axes,
  modèles d'exigence bilingues complétés, quatre cas d'échec ajoutés.

- **Transposition des mécaniques ALM d'ergonomia** (D-2026-08-13 à
  D-2026-08-16), avec leur vocabulaire rendu bilingue. Seize mécaniques
  éprouvées sur un dépôt vivant et absentes de la fondation, chacune motivée
  par un défaut réellement constaté.

- **Lexique du vocabulaire outillé** (ADR-0015, req~lexique-outille~1) :
  `tools/lexique.sh` déclare en français et en anglais les 42 termes que les
  portes reconnaissent — statuts, niveaux normatifs, verdicts, gravités,
  étiquettes de forge, commandes de consultation. `tools/init.sh --langue`
  fige le jeu ; aucune porte n'écrit plus un de ces mots en dur. Referme
  l'écart laissé par l'ADR-0009, qui ne portait que sur les artefacts
  générés : une porte cherchant « ACTIVE » ou « conforme » devenait muette —
  sans erreur — dans un dépôt instancié en anglais.

- **Audit de réalisation** (ADR-0016, req~audit-de-realisation~1) : porte
  distincte de la traçabilité, qui pose la question que celle-ci ne pose
  jamais — le livré fait-il ce que l'exigence dit ? Une fiche par domaine dans
  `docs/audit/`, verdicts écrits à la main, tableau de bord généré, plafond
  d'exigences non examinées à 0. Le générateur compte, l'humain juge.

- **Périmètre de la porte constaté** (ADR-0017, req~perimetre-constate~1) :
  `tools/perimetre.sh` déduit la voie du changement réel — commits, index,
  arbre **et fichiers non suivis** — et impose la voie complète au moindre
  doute ; `tools/ci.sh` devient le point d'entrée unique dont les quatre
  façades (Task, just, GitHub, GitLab) ne font que déléguer.

- **Six portes documentaires** : intégrité des liens internes
  (req~integrite-liens~1), anti-dérive des artefacts générés — qui outille
  enfin la règle R8 (req~anti-derive-generes~1), statuts de domaine
  (req~statut-specification~1), relevés de séance et registre
  (req~releves-de-decision~1), journaux et intangibilité des sections
  publiées (req~journaux-depot-et-logiciel~1), classification des exigences
  (req~classification-exigences~1).

- **Feuille de route, suivi de revue et badges dérivés**
  (req~feuille-de-route-outillee~1, req~suivi-constats-revue~1,
  req~badges-autonomes~1) : trois artefacts générés au lieu d'être tenus à la
  main. Le suivi de revue mécanise au passage la règle du chapitre 7 —
  la porte refuse désormais un constat de sévérité haute sans verdict.

- **Coordination des issues outillée** : `tools/issues.sh` contrôle la
  conformité au cycle de vie, délibérément **hors porte** (réseau et session
  requis, req~conformite-issues~1) ; `templates/forge/` fournit les cinq
  automatismes prêts à câbler pour GitHub et GitLab, déclarés non câblés dans
  le gabarit avec leur raison (req~automatismes-forge~1).

- **Quatre chapitres de méthode** : 12 (feuille de route), 13 (statuts de
  spécification), 14 (audit de réalisation), 15 (cadrage des nouvelles
  fonctionnalités) ; compléments aux chapitres 4 (liste des portes,
  aiguillage, deux nouveaux anti-patterns), 7 (suivi consolidé) et 8 (NEWS ⟂
  CHANGELOG, sections closes, campagne de non-régression aux versions
  mineures).

- **Modèles bilingues** `roadmap-card.md` et `audit-sheet.md`.

### Corrigé

- **Deux angles morts de la porte des liens**, comblés d'après le retour
  d'ergonomia du même jour (FIX-#846) : les fichiers de forge
  (`.github/`, `.gitlab/`) n'étaient pas parcourus, et les URL
  `https://<forge>/<org>/<dépôt>/blob/<ref>/<chemin>` étaient rangées avec les
  liens externes alors qu'elles désignent un chemin du dépôt — seule forme de
  lien dont disposent les gabarits d'issue. Là-bas, un renommage de répertoire
  a tué seize renvois dont la regex d'un workflow, restée verte en ne filtrant
  plus rien. Cinq cas de test ajoutés, dont deux garde-fous contre les faux
  positifs (dépôt tiers, URL interpolée) et un contre la confusion
  commentaire YAML / titre Markdown.
- **Le filtre de retombée des lectures se prouve désormais**
  (`templates/forge/tools/automatismes.sh`) : écrit en chemins, il survivait
  syntaxiquement à un renommage tout en ne filtrant plus rien — et aurait vidé
  les positions de toutes les consultations ouvertes. `verifier_filtre` refuse
  de s'exécuter si un chemin exclu n'existe pas.

- **Revue de code par un relecteur tiers** (Kimi, kimi-cli 0.28.0), archivée
  dans `docs/revues/2026-08-20-transposition-alm.md` : **sept constats, tous
  corrigés, aucun rejeté**. Le plus important — le seul de sévérité haute —
  contredisait un critère d'acceptation : `tools/audit.sh` n'acceptait que le
  français en mode bilingue, qui est pourtant le défaut de l'instanciation.
  Le lexique gagne `lex_est` (reconnaissance selon la langue figée) et
  `lex_motif` (alternance parenthésée) ; la même classe de défaut touchait
  `todo.sh` et `statuts.sh`, où l'alternance insérée nue dans une regex
  produisait deux branches fausses. Le relecteur a également établi que le
  test bilingue existant ne prouvait rien sur le mode `fr-en` : le cas
  manquant est ajouté.
- Robustesse des portes, d'après la même revue : découpage des listes de
  chemins sur les seules fins de ligne (`IFS` + `set -f`, dix portes) — un
  fichier au nom espacé était ignoré **sans que rien ne le signale** ;
  extraction des liens à parenthèses équilibrées (`guide-(v2).md` n'est plus
  déclaré mort à tort) ; recherche de forge échappée ; fenêtre du contrôle
  des journaux surchargeable ; garde sur les clés du lexique.
- `templates/forge/` n'est plus supprimé à l'instanciation : le retirer
  privait le projet instancié de ce que `req~automatismes-forge~1` promet de
  lui fournir. Constat classé « basse » par le relecteur, en réalité une
  annulation d'exigence.
- Deux défauts trouvés **en corrigeant la revue**, dans la porte de
  consolidation elle-même : une barre verticale non échappée dans une cellule
  décalait les colonnes et faisait lire le verdict au mauvais endroit — un
  constat soldé s'affichait « ouvert », en silence ; et le code de retour
  d'`awk` se perdait dans un pipe vers `sort`. Les deux sont mécanisés, avec
  leurs cas de test.
- **Nouveau contrôle** `tools/checks.sh` : tout script du dépôt est analysable
  par `sh`. Ajouté après **trois** occurrences du même défaut — une apostrophe
  dans un commentaire de programme `awk` referme la quote qui l'entoure, et le
  shell se met à lire le programme comme du code. Le fichier paraît sain et
  casse à l'exécution, donc en CI, jamais en revue.

### Modifié

- **La complétude devient bloquante** (`req~classification-exigences~2`).
  Une exigence DOIT/DEVRAIT couverte par mtest seul n'est plus un signal
  « à élever » qu'on peut ignorer sans trace : la porte de classification
  **échoue**, sauf report explicite — l'identifiant suivi du marqueur
  « (à élever : motif) » dans une fiche de la feuille de route
  (`docs/todo/`) — la dette étant alors nommée à chaque passage. Assumer
  durablement une vérification manuelle reste légitime (R10) : c'est
  désormais un motif consigné qui le dit. Les dix exigences concernées sont
  reportées par la fiche
  [ToDo-0002](docs/todo/todo-0002-completude-a-elever.md), chacune en
  attente d'un arbitrage du mainteneur ; `tools/gouvernance-test.sh`
  éprouve les deux nouveaux cas (mtest seul refusé sans report ; report par
  fiche qui passe en nommant). Mécanique éprouvée sur un projet instancié,
  où le même durcissement a débusqué des écarts réels dès sa première
  exécution.
- **Dette révélée et résorbée.** La porte de classification a montré que 19
  exigences sur 25 étaient de niveau DOIT **sans aucune vérification
  déclarée** — dont les trois contrôles historiques de `tools/checks.sh`, qui
  n'avaient jamais été éprouvés sur leur cas d'échec (R3). Le taux passe de
  24 % à 100 % : `tools/checks-test.sh` et `tools/socle-test.sh` couvrent ce
  qui est mécanisable, `docs/verification-manuelle/` porte les douze
  procédures `mtest` de ce qui ne l'est pas.
- `tools/checks.sh` : trois contrôles ajoutés — complétude de l'index des ADR
  et sa réciproque, alignement des façades CI, complétude du lexique.
- Hook pre-commit : rejoue la voie documentaire complète (`tools/ci.sh
  --rapide`) au lieu de trois portes ; la voie complète reste due avant de
  proposer le travail.
- `tools/init.sh` : fige la langue du lexique, retire les procédures et fiches
  du gabarit, régénère et indexe les artefacts dérivés (12 étapes).
- Contrat d'agents : R8 outillée, deux règles ajoutées (R9 vocabulaire au
  lexique, R10 vérification déclarée pour tout DOIT), trois interdits
  explicites.
- Méthode, trois amendements repris d'ergonomia le même jour : une
  spécification validée **ne ferme pas** la demande — l'artefact n'est pas le
  besoin, et « quand la totalité de la pratique dément une règle écrite, c'est
  la règle qui est fausse » (ch. 11) ; un agrégat a **une** source, et un état
  d'avancement se calcule au lieu de se saisir (ch. 4, nouvel anti-pattern) ;
  la révision éditoriale d'une section publiée se déclare **après** la fusion,
  son SHA n'existant pas avant le squash (ch. 8).

### Connu

- **Aucun écart d'audit ouvert.** Le seul qui l'était —
  `req~cycle-de-vie-exigence~1`, révélé par la mise en place de l'audit et
  présent depuis la fondation — a été tranché le jour même (ADR-0018) : il est
  refermé, et son historique est conservé dans
  `docs/audit/ingenierie-exigences.md`.

### Modifié

- Bootstrap consenti, modulaire et auto-installant (ADR-0014,
  req~onboarding-outille~2) : `tools/bootstrap.sh` devient un orchestrateur —
  annonce → accord (`--oui`/`--verifie`) → vérifie → installe les seuls
  manquants via le gestionnaire natif (apt/dnf/brew/winget), échec nommant
  les outils restés absents. Chaque outil du socle vit dans son module
  `tools/bootstrap.d/NN-outil.sh` ; le point d'extension des projets
  instanciés devient l'ajout d'un module, jamais l'édition du script.
  Nouveaux scripts consentis `tools/install-git.sh` / `tools/install-git.ps1`
  pour le prérequis git (Windows compris, où `sh` n'existe qu'avec Git for
  Windows). Test mécanisé `tools/bootstrap-test.sh` câblé dans les deux CI.

- Anti-pattern « outillage aveugle à son environnement » ajouté à la méthode
  (ch. 4) et rappelé dans les points d'extension de `tools/clean.sh` et
  `tools/bootstrap.sh` : chemins d'artefacts en dur cassés ou neutralisés
  par les caches partagés du poste (CARGO_TARGET_DIR…), nettoyages d'outil
  devenus globaux — leçon d'un cas vécu le jour même.

- Orchestration découplée (ADR-0007, OQ-001) : portes réécrites en POSIX sh
  strict dans `tools/` (appelées directement par la CI et les hooks),
  orchestrateur réduit à une façade de délégation pure et interchangeable —
  `Taskfile.yml` (Task) par défaut, variante justfile dans
  `templates/orchestrators/`, ou aucun. Le justfile racine est supprimé.

### Ajouté

- Modules de bootstrap **prêts à copier** (`templates/bootstrap.d/`, matériel
  post-instanciation hors traçabilité du gabarit, comme
  `templates/orchestrators/`) : kit **lint Markdown** — modules Node.js 22+
  et dépendances npm, porte `markdown.sh` (lint/fix, auto-suffisante via
  `npm ci`), formateur `format-tables.mjs` aligné sur la règle MD060 (même
  mesure `string-width`, emoji compris) et configuration `markdownlint-cli2`
  modèle. Le projet instancié copie, adapte les globs, tague vers ses
  exigences (R2) et câble la porte dans sa CI (R7).

- Cycle de vie des issues (feat~coordination-issues~1, méthode ch. 11),
  formalisé depuis le processus éprouvé sur ergonomia : règle état/attente/acte
  (req~issues-etat-attente-acte~2 — l'étiquette dit l'état, l'assignation dit
  qui est attendu, le commentaire trace l'acte et fait seul foi), trois flux
  [Spec]/[Orga]/réalisation avec avancement scindé en étapes, entraves et
  sorties et fins de vie motivées (req~issues-flux-avancement~2), triage où la
  gravité se constate et la priorité se décide — P1/P2/P3 par le « quand »,
  limite de P1 (req~issues-triage-priorites~2). Formulaires : gravité ajoutée
  à l'anomalie (GitHub et GitLab), nouveau formulaire [Orga], le formulaire
  [Spec] passe en `à-consulter`. Automatismes de forge documentés non câblés
  (R7) : à câbler à l'instanciation, testés sur leur cas d'échec.
- Arbitrage d'instanciation du cycle de vie des issues (ADR-0013,
  D-2026-08-11) : seul le socle état/attente/acte est invariant ; flux
  [Spec]/[Orga], jeu d'étiquettes, décideurs par domaine, valeurs (délais,
  limite de P1, cadences) et outillage des automatismes sont des défauts que
  l'instanciateur adopte, adapte ou réduit en le consignant au registre des
  décisions du projet. Exigences passées en révision 2, sites re-tagués.
- Arbitrage du cycle de vie outillé (amendement de l'ADR-0013, en conception
  de gabarit) : option `--cycle-issues complet|reduit` de `tools/init.sh` —
  le circuit réduit retire les formulaires de consultation [Spec]/[Orga]
  (questions ouvertes + ADR à la place), et l'arbitrage rendu, défaut
  compris, est consigné automatiquement au registre des décisions du projet
  instancié ; testé sur ses deux modes et sa valeur invalide
  (`tools/init-test.sh`). L'instanciation retire désormais aussi les tags de
  couverture des formulaires d'issues (ils pointaient vers des exigences
  supprimées et cassaient la traçabilité du projet instancié).
- Porte anti-secrets (req~detection-secrets~1, ADR-0012) : gitleaks épinglé
  par version et empreintes par plateforme, bloquant en CI, signalant en
  local sans l'outil ; test mécanisé `tools/secrets-test.sh` ; cible
  `secrets` dans les façades, intégrée à `ci` et au hook pre-commit.
- Cadre de sécurité continue (req~securite-continue~1, méthode ch. 10) :
  STRIDE léger obligatoire pour les exigences de niveau S (reporté dans la
  Definition of Done), politique de vulnérabilités avec délais par sévérité
  et exceptions justifiées-datées-portées, SBOM en point d'extension de la
  release ; modèles bilingues threat-model et security-exception.
- Durcissement des façades CI : permissions minimales (contents: read) et
  persist-credentials: false sur le checkout GitHub.
- Scripts `tools/adr-new.sh` et `tools/bump.sh` (logique sortie des façades).
- Script d'instanciation `tools/init.sh` (req~instanciation-outillee~1) avec
  test mécanisé `tools/init-test.sh` câblé en CI : personnalise l'identité du
  projet, retire la spécification et les ADR du gabarit, laisse les portes
  vertes.
- Arbitrages d'instanciation : politique de mention de l'IA dans les commits
  (req~politique-attribution-agents~2, ADR-0011 remplaçant l'ADR-0008 — par
  défaut, déclaration obligatoire « IA: » avec responsable humain et relecture
  recommandée ; « autorisee » et « interdite » au choix) et langue du dépôt
  fr/en/fr-en (req~politique-langue~1, ADR-0009, bilingue par défaut) —
  appliqués mécaniquement par init.sh (blocs à marqueurs dans les portes).
- Portabilité des forges (req~portabilite-forges~1, ADR-0010) : façade CI
  GitLab `.gitlab-ci.yml` et modèles d'issues/MR `.gitlab/`, mêmes scripts que
  la façade GitHub ; périmètre de traçabilité filtrant les chemins absents.
- Nettoyage outillé du dépôt local (req~nettoyage-outille~1) :
  `tools/clean.sh` (chemins déclarés uniquement, point d'extension projet,
  cache purgé sur `--all` seulement, volume libéré affiché — motivé par
  l'incident des 500 Go de target/ sur ergonomia) et son test
  `tools/clean-test.sh` câblé dans les deux façades CI.
- Onboarding « Scripts to Rule Them All » (req~onboarding-outille~1) :
  `tools/setup.sh` (accueil après clone : bootstrap, hooks, portes,
  orientation) et `tools/bootstrap.sh` (socle + point d'extension où chaque
  projet installe son outillage en vérification de ses ADR), testés par
  `tools/setup-test.sh` câblé en CI.

## [0.1.0] - 2026-08-08

### Ajouté

- Méthode complète (`docs/methode/`, 9 chapitres) : expression du besoin,
  exigences EARS, ADR, traçabilité, tests mécanisés, questions ouvertes, revue
  et recette, versionnement, gouvernance des agents.
- Registre ADR avec six décisions fondatrices et charte du registre.
- Spécification auto-appliquée : 4 besoins, 14 exigences tracées.
- Traçabilité OpenFastTrace 4.9.0 (jar épinglé par SHA-256), hooks git,
  contrôles de cohérence et porte CI GitHub Actions.
- Modèles d'artefacts bilingues (`templates/fr/`, `templates/en/`) : ADR,
  besoin, exigence, question ouverte, relevé de décision, revue de code.
- Exemple multi-langages (Python, Rust, shell) exécutant la chaîne complète.
- Contrat d'agents AGENTS.md et adaptateur CLAUDE.md.
