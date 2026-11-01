# Exigences — domaine traçabilité et vérification

**Statut : ACTIVE** — domaine acté le 2026-08-20 (D-2026-08-16). Le statut commande
le dénominateur des taux d'audit et de classification (méthode, ch. 13).

## Traçabilité outillée de bout en bout

`req~tracabilite-outillee~1`

**Statut : approuvée**

La chaîne besoin → exigence → conception → implémentation → test DOIT être
vérifiée par un outil indépendant du langage qui échoue (code retour non nul)
dès qu'un maillon manque : exigence sans couverture, couverture pointant un
identifiant inexistant ou une révision obsolète.

Critères d'acceptation :

- Étant donné une exigence approuvée sans implémentation taguée, quand la
  traçabilité s'exécute, alors elle échoue en nommant l'exigence orpheline.
- Étant donné un tag de couverture vers un identifiant inexistant, quand la
  traçabilité s'exécute, alors elle échoue (aucun tag fantôme possible).

Covers:
- feat~tracabilite-mecanisee~1

Needs: dsn, impl, utest

## Porte d'intégration continue

`req~porte-ci~2`

**Statut : approuvée**

Lorsqu'un commit est poussé ou qu'une pull request est ouverte, la CI DOIT
rejouer la traçabilité et les contrôles de cohérence, et DOIT échouer si l'un
d'eux échoue. Toute porte documentée DOIT être câblée dans la CI, ou marquée
explicitement « non câblée » avec sa raison et son échéance.

Le lanceur DOIT jouer toutes les portes de la voie retenue, quel qu'ait été le
verdict des précédentes, et DOIT rendre un bilan les nommant toutes avec leur
verdict.

Rationale:
Contre-exemple observé sur wallos-rs : des portes déclarées dans le contrat de
gouvernance mais absentes du workflow créent une conformité illusoire.

Un lanceur qui s'arrête à la première porte rouge produit la même illusion par
un autre chemin : les portes suivantes ne sont pas absentes du workflow, elles
n'ont simplement pas été jouées, et rien dans la sortie ne distingue les deux
cas. Le défaut est d'autant plus durable que la première porte est
LÉGITIMEMENT rouge — une traçabilité qui attend la réalisation d'exigences
déjà écrites l'est pendant des semaines. Constaté sur un projet instancié :
deux tests d'outillage étaient cassés depuis l'origine derrière une
traçabilité rouge, et le sont restés jusqu'à ce qu'on joue les portes une à
une à la main.

Critères d'acceptation :

- Étant donné un dépôt dont deux portes non consécutives échouent, quand le
  lanceur est exécuté, alors les deux figurent au bilan comme en échec.
- Étant donné ce même dépôt, quand le lanceur est exécuté, alors les portes
  saines y figurent comme telles et le code de retour est non nul.

Covers:
- feat~tracabilite-mecanisee~1

Needs: impl, utest, mtest

## Garde-fous locaux

`req~garde-fous-locaux~1`

**Statut : approuvée**

Le dépôt DOIT fournir des hooks git (pre-commit, commit-msg) reproduisant les
portes de la CI en local : traçabilité, contrôles de cohérence, format des
messages de commit, interdiction des mentions d'agent. Le contournement DOIT
être possible mais explicite et bruyant.

Critères d'acceptation :

- Étant donné les hooks installés, quand un commit casse la traçabilité, alors
  le commit est refusé avant d'atteindre le dépôt.
- Étant donné un message de commit non conventionnel ou portant une mention
  d'agent, quand le commit est validé, alors il est refusé avec le motif.

Covers:
- feat~tracabilite-mecanisee~1

Needs: impl, utest

## Tests mécanisés reliés aux exigences

`req~tests-mecanises~1`

**Statut : approuvée**

Chaque exigence testable DOIT être couverte par au moins un test automatisé
tagué avec son identifiant, au niveau approprié (unitaire, intégration,
système). Les exigences non automatisables DOIVENT être couvertes par une
procédure de vérification manuelle versionnée et taguée, jamais laissées sans
vérification déclarée.

Covers:
- feat~ingenierie-des-exigences~1
- feat~tracabilite-mecanisee~1

Needs: impl, mtest

## Exemple multi-langages

`req~exemple-multilangage~1`

**Statut : approuvée**

Le dépôt DOIT contenir un exemple exécutant la chaîne complète (besoin,
exigences, décision, implémentations, tests tagués) dans au moins trois
langages différents, pour démontrer l'agnosticisme du dispositif et servir de
référence de mise en œuvre.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, utest

## Périmètre de la porte constaté

`req~perimetre-constate~1`

**Statut : approuvée**

Le périmètre de vérification DOIT être déduit du changement réel — commits
depuis la base de fusion, index, arbre de travail et fichiers non suivis — et
non déclaré par le contributeur. En cas de doute — base de fusion introuvable,
empreinte vide, chemin non classé — la voie complète DOIT s'appliquer.

Rationale:
Une voie rapide choisie à la main est un contrôle qui passe toujours dès que
le jugement se trompe. La prise en compte des fichiers NON SUIVIS vient d'un
angle mort payé sur ergonomia : un nouveau script d'outillage, jamais ajouté à
l'index, échappait au classement et faisait passer un changement d'outillage
pour de la documentation.

Critères d'acceptation :

- Étant donné un changement purement documentaire, quand le périmètre est
  constaté, alors la voie rapide s'applique.
- Étant donné un fichier d'outillage non suivi, quand le périmètre est
  constaté, alors la voie complète s'applique.
- Étant donné une empreinte vide ou l'absence de base de fusion, quand le
  périmètre est constaté, alors la voie complète s'applique.

Covers:
- feat~tracabilite-mecanisee~1

Needs: dsn, impl, utest

## Anti-dérive des artefacts générés

`req~anti-derive-generes~1`

**Statut : approuvée**

Tout artefact généré DOIT être régénéré puis comparé à sa version versionnée
par une porte, et cette porte DOIT vérifier au préalable que l'artefact est
suivi par le gestionnaire de versions.

Rationale:
Sans le contrôle de suivi, la porte est un no-op : un généré non versionné ne
produit aucune différence, la comparaison passe toujours, et la règle R8
n'est vérifiée par rien. C'est l'anti-pattern « contrôle no-op » du chapitre 4,
constaté sur ergonomia avant d'être refermé par ce double contrôle.

Critères d'acceptation :

- Étant donné un artefact généré modifié à la main, quand la porte s'exécute,
  alors elle échoue en indiquant la commande de régénération.
- Étant donné un artefact généré non suivi par git, quand la porte s'exécute,
  alors elle échoue.
- Étant donné un générateur en erreur, quand la porte s'exécute, alors elle
  échoue.

Covers:
- feat~tracabilite-mecanisee~1

Needs: impl, utest

## Classification des exigences

`req~classification-exigences~2`

**Statut : approuvée**

Toute exigence DOIT porter un niveau normatif explicite dans son énoncé, et
toute exigence de niveau le plus contraignant DOIT déclarer un niveau de
vérification — mécanisé ou manuel assumé. Le niveau normatif DOIT être lu dans
le seul énoncé, à l'exclusion du rationale et des critères d'acceptation. Une
exigence du niveau le plus contraignant couverte par une vérification
manuelle SEULE DOIT faire échouer la porte, sauf report explicite —
l'identifiant suivi du marqueur « (à élever…) » dans une fiche de la feuille
de route — auquel cas la porte la nomme comme dette à chaque passage.

Rationale:
La traçabilité vérifie qu'un « Needs » déclaré est satisfait ; elle ne vérifie
jamais que ce « Needs » est à la hauteur de l'exigence. Une exigence qui dit
DOIT sans déclarer aucune vérification passe donc en silence — la plus
contraignante du dépôt peut n'être prouvée par rien. L'exclusion du rationale
répond au piège du niveau EMPRUNTÉ constaté sur ergonomia : un « DOIT » cité
dans une justification faisait classer en DOIT une exigence rédigée en
DEVRAIT. La couverture manuelle seule tient la lettre de R10 mais reste la
preuve la plus faible ; tant qu'elle n'était que signalée « à élever », le
signal pouvait être ignoré sans trace — précisément ce que les portes du
dépôt existent pour empêcher (constaté sur un projet instancié : le même
contrôle, durci, a débusqué des écarts réels dès sa première exécution). Le
report par fiche transforme « ne pas prendre en compte » en acte écrit, relu
à chaque passage — jamais un oubli silencieux. *(Révision `~2` : le
signalement devient bloquant, avec report explicite.)*

Critères d'acceptation :

- Étant donné une exigence dont l'énoncé ne porte aucun niveau normatif, quand
  la porte s'exécute, alors elle échoue.
- Étant donné une exigence de niveau DOIT sans niveau de test déclaré, quand
  la porte s'exécute, alors elle échoue.
- Étant donné une exigence dont seul le rationale contient un niveau
  normatif, quand la porte s'exécute, alors elle échoue sans la classer au
  niveau emprunté.
- Étant donné une exigence de niveau DOIT couverte par mtest seul et absente
  des reports de la feuille de route, quand la porte s'exécute, alors elle
  échoue en indiquant les deux sorties (mécaniser, ou reporter par le
  marqueur).
- Étant donné la même exigence dont l'identifiant, suivi du marqueur
  « (à élever…) », figure dans une fiche de la feuille de route, quand la
  porte s'exécute, alors elle passe en nommant la dette.

Covers:
- feat~tracabilite-mecanisee~1

Needs: impl, utest

## Audit de réalisation

`req~audit-de-realisation~1`

**Statut : approuvée**

Le dépôt DOIT porter un audit de réalisation distinct de la traçabilité, où
chaque exigence d'un domaine actif reçoit un verdict écrit à la main —
conforme, écart, ou non examinée — assorti de sa preuve. La comptabilité de
cet audit DOIT être générée, et le nombre d'exigences non examinées DOIT
rester sous un plafond déclaré.

Rationale:
La traçabilité répond à « cette exigence a-t-elle du code et un test ? », une
question de présence qui se calcule. L'audit répond à « le livré fait-il ce
que l'exigence dit ? », une question de vérité qui se lit : un tag de
complaisance passe la première et échoue au second. Le partage du travail est
celui de la matrice — le générateur compte, l'humain juge — et le plafond
empêche la dette de s'installer sans être vue.

Critères d'acceptation :

- Étant donné une exigence sans ligne d'audit, quand la porte s'exécute,
  alors elle la compte comme non examinée et échoue si le plafond est
  dépassé.
- Étant donné un verdict hors du vocabulaire, quand la porte s'exécute, alors
  elle échoue.
- Étant donné une ligne d'audit visant une exigence supprimée, quand la porte
  s'exécute, alors elle échoue.

Covers:
- feat~tracabilite-mecanisee~1

Needs: dsn, impl, utest

## Tout fichier de code se rattache à une exigence

`req~rattachement-code-exigence~1`

**Statut : approuvée**

Tout fichier de code suivi par git DOIT se rattacher à une exigence
existante : par une étiquette de couverture (`impl`, `utest`, `itest`,
`stest`…) quand il réalise ou vérifie l'exigence, ou par la mention de son
identifiant (convention : `Exigence servie : req~…~n`) quand il la sert sans
la couvrir — outil d'appoint, fichier de structure, matériel prêt à copier.
Une étiquette qui vise un item inexistant (révision périmée, faute de
frappe) DOIT faire échouer la porte, y compris dans les répertoires
qu'OpenFastTrace ne balaie pas. Dans un projet instancié, le code hérité du
gabarit, dont les exigences ont été retirées, DOIT être déclaré dans une
liste dressée à l'instanciation ; une déclaration DOIT viser un fichier de
code suivi qui ne porte aucune trace propre.

Rationale:
OpenFastTrace part des exigences et cherche leurs couvertures : il ne voit
jamais le code qui ne revendique rien. La matrice le montre à titre
informatif, sur l'outillage seulement ; constaté dans un projet aval, plus
d'une centaine de fichiers de code s'étaient accumulés sans trace sans
qu'aucune porte ne bronche (demande du porteur, D-2026-10-01). La mention
existe pour dire honnêtement « sert, sans couvrir » : une étiquette de
complaisance ne répond pas à la règle — la revue et l'audit de réalisation
la traquent, et OpenFastTrace la refuse quand le type ne figure pas dans le
`Needs:` de l'exigence. La liste du code hérité est dressée par
l'instanciation, jamais à la main : un fichier ajouté ensuite par le projet
n'y figure pas et se rattache à ses propres exigences.

Critères d'acceptation :

- Étant donné un fichier de code suivi sans étiquette ni mention d'une
  exigence existante, quand la porte s'exécute, alors elle échoue en le
  nommant ; un fichier non suivi, ou qui n'est pas du code, est ignoré.
- Étant donné une étiquette vers un item existant, ou la mention d'une
  exigence existante, quand la porte s'exécute, alors le fichier est
  rattaché.
- Étant donné une étiquette vers une révision périmée, quand la porte
  s'exécute, alors elle échoue même si le fichier porte une autre trace
  valide.
- Étant donné un identifiant défini seulement dans un bloc de code ou dans
  `templates/`, quand un fichier le vise, alors la porte le tient pour
  inexistant.
- Étant donné un projet fraîchement instancié, quand la porte s'exécute,
  alors elle passe, et un fichier de code ajouté ensuite sans trace la fait
  échouer.
- Étant donné une déclaration de code hérité qui vise un fichier absent ou
  déjà tracé, ou cette liste présente dans le gabarit lui-même, quand la
  porte s'exécute, alors elle échoue.

Covers:
- feat~tracabilite-mecanisee~1

Needs: impl, utest
