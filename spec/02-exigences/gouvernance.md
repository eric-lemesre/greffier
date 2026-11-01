# Exigences — domaine gouvernance

**Statut : ACTIVE** — domaine acté le 2026-08-20 (D-2026-08-16). Le statut commande
le dénominateur des taux d'audit et de classification (méthode, ch. 13).

## Contrat d'agents unique et agnostique

`req~gouvernance-agents~1`

**Statut : approuvée**

Le dépôt DOIT porter un contrat de gouvernance unique (AGENTS.md) faisant
autorité sur toute consigne de session, applicable à tout agent humain ou IA,
listant des règles non négociables chacune adossée à un moyen de vérification.
Les agents spécifiques s'y raccordent par des fichiers adaptateurs qui ne
contiennent aucune règle propre.

Critères d'acceptation :

- Étant donné une consigne de session contredisant le contrat, quand l'agent
  travaille dans le dépôt, alors le contrat prévaut et le conflit est signalé.
- Étant donné un nouvel agent outillé (lecteur de CLAUDE.md, de .cursorrules ou
  autre), quand on l'intègre, alors on ajoute un adaptateur-pointeur sans
  dupliquer les règles.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, mtest

## Templates bilingues

`req~bilinguisme-templates~1`

**Statut : approuvée**

Les modèles d'artefacts (ADR, besoin, exigence, question ouverte, relevé de
décision, revue de code) DOIVENT être fournis en français et en anglais, avec
les mêmes noms de fichiers dans les deux arborescences ; la parité DOIT être
vérifiée mécaniquement.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, utest

## Instanciation outillée

`req~instanciation-outillee~2`

**Statut : approuvée**

Quand un projet est instancié depuis le gabarit, le dépôt DOIT fournir un
script d'initialisation qui personnalise l'identité du projet (nom, porteur),
retire la spécification et les ADR propres au gabarit (y compris leurs tags de
couverture dans les documents conservés), réinitialise le journal des
changements, la version, la licence et les registres, et laisse la traçabilité
et les contrôles de cohérence verts.

Ce script DOIT se retirer lui-même, ainsi que son test et toutes les
références que les façades et le contrat de dépôt lui font, en dernier geste
de l'instanciation.

Rationale:
GitHub n'effectue aucune substitution de variables à la création depuis un
template : sans script, la personnalisation est une checklist manuelle,
incomplète par construction (licence, registres et tags oubliés).

Le retrait de l'outillage était jusqu'ici proposé en fin de message, comme une
option, après cinq autres étapes — c'est-à-dire jamais fait. Deux conséquences
ont été constatées sur un projet instancié. Le test d'instanciation rejoue le
script sur des copies du dépôt DEVENU projet, qui porte sa propre
spécification et son propre code : les tags de couverture de ce code
deviennent orphelins dans le dépôt produit, et la porte échoue pour une raison
qui ne dit rien de la qualité du travail. Et le script laissé en place reste
destructeur — il efface la spécification, les ADR et le registre des décisions
— tout en étant documenté au contrat et exposé par une commande de la façade.
Une option qui doit être prise à chaque fois n'est pas une option.

Critères d'acceptation :

- Étant donné une copie du gabarit, quand le script est exécuté avec un nom de
  projet et un porteur, alors la spécification du gabarit et ses ADR sont
  retirés, la licence porte le porteur, et la traçabilité passe.
- Étant donné un dépôt déjà initialisé, quand le script est relancé sans
  forçage, alors il refuse d'agir.
- Étant donné une copie du gabarit, quand le script a terminé, alors ni lui ni
  son test ne subsistent, et aucune façade ni le contrat de dépôt ne les cite
  plus.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, utest

## Accueil informatif, jamais sanctionnant

`req~accueil-informatif~1`

**Statut : approuvée**

Quand le script d'accueil rejoue les portes, il DOIT en rapporter l'état — en
nommant celles qui échouent — et NE DOIT PAS faire de leur verdict un échec de
l'accueil. Le verdict des portes reste porté par la porte elle-même.

Rationale:
Un dépôt dont la spécification précède la réalisation a des portes
légitimement rouges : la traçabilité signale des maillons manquants tant que
les exigences écrites attendent leur code. Faire échouer l'accueil sur ce
verdict fait porter à un arrivant un défaut qui n'est pas le sien et qu'il ne
peut pas corriger — son premier geste sur le dépôt échoue, et rien ne lui dit
que c'est normal.

Le silence serait pire que l'échec : un accueil qui ne dirait rien de l'état
du dépôt laisserait croire qu'il est sain. D'où l'obligation de rapporter,
symétrique de l'interdiction de sanctionner. Deux gestes, deux rôles :
« task ci » sanctionne, « task setup » renseigne.

Critères d'acceptation :

- Étant donné un dépôt dont une porte échoue, quand le script d'accueil est
  exécuté, alors il sort en succès.
- Étant donné ce même dépôt, quand le script d'accueil est exécuté, alors sa
  sortie annonce que des portes sont en échec.
- Étant donné un dépôt dont toutes les portes passent, quand le script
  d'accueil est exécuté, alors sa sortie l'annonce.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, utest

## Onboarding outillé des contributeurs

`req~onboarding-outille~2`

**Statut : approuvée**

Quand un contributeur clone un projet issu du gabarit, le dépôt DOIT fournir
un script d'accueil idempotent qui vérifie les prérequis du socle, exécute le
bootstrap, installe les garde-fous locaux, rejoue les portes et oriente vers
le contrat et la méthode. Le bootstrap DOIT annoncer ce qu'il va vérifier,
n'installer les outils manquants qu'avec l'accord explicite de l'utilisateur
(interactif, ou donné d'avance en ligne de commande) et échouer en nommant
les outils restés absents ; un outil déjà présent n'est jamais touché. Chaque
outil vérifié DOIT vivre dans son propre module (`tools/bootstrap.d/`) — le
point d'extension des projets instanciés est l'ajout d'un module (en
vérification de leurs ADR), jamais l'édition de l'orchestrateur. git,
prérequis du bootstrap, DOIT disposer de scripts d'installation consentis
couvrant aussi les plateformes sans shell POSIX préinstallé.

Rationale:
Pattern « Scripts to Rule Them All » : des points d'entrée normalisés rendent
un contributeur productif sans connaissance préalable du projet. L'installation
consentie étend le pattern aux postes neufs sans jamais agir à l'insu de
l'utilisateur ; la modularité évite le script monolithique que chaque projet
instancié devrait éditer — source de conflits à la resynchronisation avec le
gabarit. Le gabarit reste agnostique du langage : il ne fournit que les
modules du socle, les technologies s'ajoutent en modules du projet.

Critères d'acceptation :

- Étant donné un clone frais dont le socle est complet, quand le script
  d'accueil est exécuté, alors les hooks git sont installés, les portes
  passent et le script sort en succès.
- Étant donné un prérequis du socle manquant, quand le bootstrap s'exécute
  sans accord d'installation, alors il échoue en nommant l'outil absent.
- Étant donné l'accord d'installation (`--oui` ou réponse interactive), quand
  un outil du socle manque, alors le bootstrap l'installe via le gestionnaire
  de paquets de la plateforme, sans toucher aux outils déjà présents.
- Étant donné une entrée non interactive sans `--oui`, quand le bootstrap
  s'exécute, alors aucune installation n'a lieu (vérification seule).
- Étant donné un poste déjà configuré, quand le script est relancé, alors le
  résultat est identique (idempotence).
- Étant donné un argument inconnu, quand le bootstrap s'exécute, alors il
  échoue en rappelant l'usage.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, utest

## Politique d'attribution des agents arbitrée à l'instanciation

`req~politique-attribution-agents~2`

**Statut : approuvée**

Quand un projet est instancié depuis le gabarit, la politique de mention de
l'IA dans les commits (obligatoire, autorisée ou interdite) DOIT être arbitrée
par l'instanciateur et appliquée mécaniquement par le hook commit-msg. Si
aucun choix explicite n'est exprimé, alors la déclaration DOIT être
obligatoire : chaque commit porte un trailer `IA: aucune` ou `IA: <outil>`,
tout usage déclaré exige un endossement humain (`Responsable: Prénom Nom`),
et la relecture (`Relu-par: …`) DEVRAIT être renseignée.

Rationale:
Principe de diligence : transparence sur le rôle de l'IA et responsabilité
humaine assumée du résultat (ADR-0011, qui remplace l'ADR-0008 et son défaut
d'interdiction).

Critères d'acceptation :

- Étant donné le défaut, quand un commit ne porte aucun trailer IA, alors le
  hook le refuse.
- Étant donné le défaut, quand un commit déclare un outil sans responsable
  humain, alors le hook le refuse ; avec responsable, il l'accepte.
- Étant donné le défaut, quand un commit déclare « IA: aucune », alors le
  hook l'accepte.
- Étant donné le choix « interdite », quand un commit porte une mention
  d'agent, alors le hook le refuse.
- Étant donné le choix « autorisee », quand un commit porte ou non des
  mentions, alors le hook n'impose rien.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, utest

## Langue du dépôt arbitrée à l'instanciation

`req~politique-langue~1`

**Statut : approuvée**

Quand un projet est instancié depuis le gabarit, la langue du dépôt (fr, en ou
fr-en) DOIT être arbitrée par l'instanciateur : les artefacts générés et le
jeu de modèles conservé suivent ce choix, et la porte de parité des templates
ne s'applique qu'au choix bilingue. Si aucun choix explicite n'est exprimé,
alors le bilinguisme fr-en DOIT s'appliquer.

Rationale:
Corollaire de l'ADR-0005 au niveau projet : le bilinguisme des modèles est la
politique du gabarit, pas une obligation des projets. Limitation assumée : la
documentation normative du gabarit reste en français (ADR-0009).

Critères d'acceptation :

- Étant donné une instanciation en « fr », quand elle s'achève, alors le jeu
  anglais de modèles et le README anglais sont retirés et les portes passent
  sans contrôle de parité.
- Étant donné une instanciation en « en », quand elle s'achève, alors le
  README principal est en anglais, le jeu français de modèles est retiré et
  les portes passent.
- Étant donné une instanciation sans choix, quand elle s'achève, alors les
  deux jeux de modèles et le contrôle de parité sont conservés.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, utest

## Portabilité entre forges git

`req~portabilite-forges~1`

**Statut : approuvée**

Les portes qualité DOIVENT être exécutables sans aucune forge (scripts locaux
et hooks git), et le dépôt DOIT fournir des configurations d'intégration
continue de délégation pure pour GitHub et GitLab, exécutant les mêmes étapes
via les mêmes scripts. L'ajout d'une autre forge DOIT se limiter à l'écriture
d'une nouvelle façade CI.

Rationale:
Le gabarit ne doit pas coupler la méthode à un hébergeur. Corollaire de
l'ADR-0007 : la logique vit dans les scripts, les forges comme les
orchestrateurs ne reçoivent que des façades (ADR-0010).

Critères d'acceptation :

- Étant donné un clone sans aucune forge, quand les portes sont exécutées
  localement, alors elles produisent le même verdict que la CI.
- Étant donné les façades CI GitHub et GitLab, quand on les compare, alors
  elles exécutent la même liste d'étapes via les mêmes scripts, sans logique
  propre.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, utest

## Nettoyage outillé du dépôt local

`req~nettoyage-outille~1`

**Statut : approuvée**

Le dépôt DOIT fournir un mécanisme de nettoyage local idempotent qui supprime
les artefacts générés du socle (rapports ; cache d'outillage sur demande
explicite seulement) et expose un point d'extension où le projet instancié
déclare les artefacts de son propre outillage (répertoires de build des
langages, dépendances téléchargées). Le nettoyage ne DOIT supprimer que des
chemins ou commandes explicitement déclarés — jamais l'état versionné, jamais
de balayage aveugle du type git clean -x.

Rationale:
Sans mécanisme dédié, les artefacts de build s'accumulent sans limite —
incident fondateur observé sur ergonomia : 500 Go de target/ faute de
nettoyage Cargo. La déclaration explicite (plutôt qu'un balayage) protège les
états locaux non versionnés utiles.

Critères d'acceptation :

- Étant donné des artefacts générés présents, quand le nettoyage s'exécute,
  alors ils sont supprimés et le volume libéré est affiché.
- Étant donné un dépôt déjà propre, quand le nettoyage est relancé, alors il
  réussit sans effet (idempotence).
- Étant donné les fichiers versionnés, quand le nettoyage s'exécute, alors
  ils sont intacts.
- Étant donné le cache d'outillage, quand le nettoyage s'exécute sans demande
  explicite, alors le cache est conservé.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, utest

## Hygiène des artefacts de compilation

`req~hygiene-artefacts-compilation~1`

**Statut : approuvée**

Là où le projet instancié compile du Rust (manifeste Cargo à la racine), le
dépôt DOIT épingler sa chaîne de compilation dans un fichier suivi par git
dont le canal est une version exacte ou datée, et tout fichier — façade,
script ou configuration de CI — qui lance une commande de test ou de
couverture Cargo DOIT désactiver la compilation incrémentale, sur la ligne
d'appel ou avant le premier appel. Une porte DOIT constater ces deux
réglages ; sans manifeste, elle le dit et passe.

Rationale:
Les caches de compilation sont régénérables mais énormes, et deux mécanismes
les font grossir à l'insu de tous — constats du poste de référence :
l'incrémental écrit dans `target/*/incremental` que rien ne purge (la moitié
des 503 Go de l'incident fondateur), alors qu'il n'accélère qu'une boucle
d'édition et jamais une exécution complète ; une chaîne non épinglée conserve
une copie complète des artefacts à chaque publication de rustc (62 Go de
binaires de test en 2 à 7 variantes), et un canal « stable » avance à chaque
publication — il n'épingle rien. Le nettoyage déclaré (exigence « nettoyage
outillé du dépôt local ») retire ce qui est connu ; cette exigence empêche
l'accumulation à la source et la rend visible.

Critères d'acceptation :

- Étant donné un dépôt sans manifeste Cargo, quand la porte s'exécute, alors
  elle passe en disant qu'elle n'a rien à juger.
- Étant donné un manifeste Cargo sans fichier de chaîne, ou avec un fichier
  non suivi par git, ou dont le canal est « stable », « beta » ou « nightly »
  sans version ni date, quand la porte s'exécute, alors elle échoue en
  nommant le manque.
- Étant donné un fichier qui lance `cargo test`, `cargo nextest`,
  `cargo llvm-cov` ou `cargo tarpaulin` (options, chaîne `+…`, `$(CARGO)` et
  formes `cargo-…` comprises) sans réglage `CARGO_INCREMENTAL` à zéro sur la
  ligne ni avant le premier appel, quand la porte s'exécute, alors elle
  échoue en nommant le fichier et la ligne ; un appel ou un réglage en
  commentaire, ou cité par `echo`/`printf`, n'est pas compté.
- Étant donné le réglage sous l'une de ses formes idiomatiques (préfixe de
  ligne, `export`, `env:` ou `variables:` de CI, `export … := "0"` de just,
  `incremental = false` dans `.cargo/config.toml`) et une chaîne exacte
  suivie par git, quand la porte s'exécute, alors elle passe.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, utest

## Confinement des artefacts d'un worktree lié

`req~confinement-artefacts-worktree~1`

**Statut : approuvée**

Là où un worktree lié compile du Rust, ses artefacts DOIVENT être confinés au
worktree ou placés dans un répertoire nommé exactement `cargo-target-<nom du
worktree>` hors du tree principal, et l'outillage fourni DOIT refuser de
compiler vers tout autre répertoire. Un nettoyage des artefacts DOIT
sélectionner par l'âge d'inutilisation, jamais par un plafond de taille, et
DOIT refuser un répertoire partagé entre projets sauf demande explicite.

Rationale:
Un worktree lié qui compile dans le cache du tree principal sert les
artefacts de l'autre copie : symbole introuvable pourtant présent dans les
sources, fichier généré vidé (ergonomia, 2026-08-14). Un cache par branche de
travail (70 à 80 Go chacun) survit à la suppression de son worktree : seul un
nom convenu permet à un balayage du poste de le reconnaître et de le retirer.
Un plafond de taille efface des artefacts de quelques minutes dès que le
cache frôle la limite et casse la compilation en cours ; un nettoyage lancé
depuis un dépôt sur un cache partagé purge les artefacts de tous les projets
du poste (2026-10-25). Le matériel qui réalise cette exigence est le kit Rust
de `templates/bootstrap.d/`, hors du périmètre tracé ; le gabarit l'éprouve
par un test qui remplace cargo et cargo-sweep par des talons.

Critères d'acceptation :

- Étant donné le tree principal, quand la garde s'exécute, alors elle passe
  sans contrôle.
- Étant donné un worktree lié dont les artefacts vont dans le worktree, ou
  dans `cargo-target-<nom du worktree>`, quand la garde s'exécute, alors elle
  passe.
- Étant donné un worktree lié dont les artefacts iraient dans le tree
  principal, dans le cache partagé du poste, ou dans un répertoire dont seul
  un composant porte le nom du worktree, quand la garde s'exécute, alors elle
  échoue en donnant le remède.
- Étant donné un nettoyage sur des artefacts confinés, quand il s'exécute,
  alors il balaie par l'âge et n'applique aucun plafond de taille.
- Étant donné un nettoyage visant un répertoire partagé, quand il s'exécute
  sans demande explicite, alors il refuse sans rien balayer ; avec la demande
  explicite, il balaie par l'âge.

Covers:
- feat~gouvernance-agnostique~1

Needs: utest

## Versionnement et journal des changements

`req~versionnement-release~1`

**Statut : approuvée**

Le dépôt DOIT être versionné en SemVer avec un journal des changements au
format Keep a Changelog ; la cohérence entre le fichier VERSION et le journal
DOIT être vérifiée mécaniquement avant publication.

Covers:
- feat~cadre-de-decision~1

Needs: impl, utest

## Lexique du vocabulaire outillé

`req~lexique-outille~1`

**Statut : approuvée**

Les termes que les portes reconnaissent — statuts, niveaux normatifs,
verdicts, gravités, étiquettes de forge, commandes de consultation — DOIVENT
être déclarés en français et en anglais dans un lexique unique dont les portes
sont clientes, et le jeu retenu DOIT être figé par le choix de langue de
l'instanciation. Aucune porte NE DOIT écrire un de ces termes en dur.

Rationale:
L'arbitrage de langue de l'ADR-0009 ne portait que sur les artefacts GÉNÉRÉS ;
le vocabulaire que les contrôles LISENT restait français, ce qui imposait la
langue du gabarit à tout projet instancié dès lors qu'une porte cherchait
« ACTIVE » ou « à-tester ». Un terme identique dans les deux langues se
déclare quand même, pour que le contrôle de complétude le voie et que la
porte passe malgré tout par le lexique.

Critères d'acceptation :

- Étant donné une instanciation en français, quand une porte lit un terme
  d'état, alors seule la forme française est reconnue.
- Étant donné une instanciation en anglais, quand un artefact porte un terme
  resté français, alors la porte concernée échoue.
- Étant donné une instanciation bilingue, quand un artefact porte l'une ou
  l'autre forme, alors la porte l'accepte.

Covers:
- feat~gouvernance-agnostique~1

Needs: dsn, impl, utest

## Cohérence du dépôt produit avec les choix d'instanciation

`req~coherence-choix-instanciation~1`

**Statut : approuvée**

Quand un choix d'instanciation retire, remplace ou modifie une porte, alors
les textes normatifs du dépôt produit et les tests d'outillage qui portent sur
cette porte DOIVENT refléter ce choix. Aucun texte NE DOIT prescrire ce qu'une
porte refuse, et aucun test d'outillage NE DOIT supposer le comportement par
défaut du gabarit plutôt que celui effectivement installé.

Rationale:
L'exigence de politique d'attribution n'obligeait que le hook, et l'exigence
de politique de langue que le retrait de la porte de parité. L'une et l'autre
étaient tenues, et le dépôt produit était pourtant incohérent : un projet
instancié en « interdite » recevait une boucle de travail réclamant le trailer
`IA:` que son propre hook refuse — donc un contrat inapplicable dès le premier
commit — et un projet monolingue recevait un test exigeant une porte de parité
que l'instanciation venait de retirer, donc une voie complète rouge à la
naissance. Le défaut n'est ni dans le hook ni dans le retrait : il est dans ce
que personne n'exigeait de propager. Un test qui suppose le défaut du gabarit
n'échoue pas une fois sur un cas particulier — il échoue toujours, et un
contrôle qui échoue toujours finit désactivé aussi sûrement qu'un contrôle qui
passe toujours finit ignoré (R3).

Critères d'acceptation :

- Étant donné le choix « interdite », quand le dépôt produit est inspecté,
  alors aucun texte normatif ne prescrit le trailer `IA:`.
- Étant donné le choix « interdite », quand les tests d'outillage du dépôt
  produit sont exécutés, alors ils passent.
- Étant donné le choix d'une langue unique, quand les tests d'outillage du
  dépôt produit sont exécutés, alors ils passent malgré le retrait de la porte
  de parité.
- Étant donné une instanciation quelconque, quand le registre des décisions
  est réécrit, alors aucun relevé citant les décisions retirées ne subsiste.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, utest
