# ADR-0014 — Rendre le bootstrap consenti, modulaire et auto-installant

**Statut** : Accepté
**Date** : 2026-08-11
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-12, registre
des décisions)
**Portée** : durable

## Item de conception

`dsn~bootstrap-consenti-modulaire~1`

Le bootstrap annonce ce qu'il va vérifier, demande l'accord de l'utilisateur,
puis n'installe que les outils manquants (un outil présent n'est jamais
touché) ; chaque outil vit dans son module `tools/bootstrap.d/NN-outil.sh`
— le point d'extension des projets instanciés est l'ajout d'un module —,
et git, prérequis du bootstrap, dispose de scripts d'installation consentis
(`tools/install-git.sh`, `tools/install-git.ps1`).

Covers:

- req~onboarding-outille~2

## Contexte

Le bootstrap initial (req~onboarding-outille~1) vérifiait le socle et
**échouait** en nommant l'outil absent : le contributeur restait seul face aux
installations, plateforme par plateforme. Le point d'extension des projets
instanciés était une section à éditer **dans** le script — chaque ajout local
créait un conflit à la resynchronisation avec le gabarit, et le script grossissait
sans limite. Enfin git, prérequis absolu (sous Windows, le shell `sh` qui exécute
les scripts arrive **avec** Git for Windows), n'avait aucun chemin d'installation
outillé.

La mécanique cible a été éprouvée sur un projet instancié : annonce du plan,
accord explicite, vérifications puis installations des seuls manquants,
modules par outil, scripts dédiés au prérequis git. Le porteur demande son
intégration au gabarit.

## Décision

Le bootstrap du gabarit adopte le flux **annonce → accord → vérifie →
installe** :

- `tools/bootstrap.sh` est l'**orchestrateur** : arguments (`--oui`,
  `--verifie`), détection plateforme/gestionnaire (apt, dnf, brew, winget),
  prérequis git, accord de l'utilisateur, aides `verifier()`/`installer()`,
  bilan. Sans accord (refus, entrée non interactive), il reste en
  vérification seule et **échoue en nommant les outils absents** — le
  critère historique est conservé.
- Chaque outil du socle vit dans son **module** `tools/bootstrap.d/NN-outil.sh`,
  sourcé deux fois (`PHASE=annonce` puis `PHASE=verifie`). Les projets
  instanciés ajoutent leurs modules (langage, base de données…), chacun en
  vérification d'un de leurs ADR — l'orchestrateur ne s'édite plus.
- Le prérequis git devient auto-installable par des scripts **consentis** :
  `tools/install-git.sh` (Linux apt/dnf, macOS brew/xcode-select) et
  `tools/install-git.ps1` (Windows, winget) — le dépôt étant récupérable sans
  git via l'archive d'export de la forge.

## Alternatives écartées

### Statu quo : échec sec et instructions manuelles

C'est la garantie minimale (rien n'est installé à l'insu de l'utilisateur),
mais elle laisse le poste neuf sans chemin outillé et contredit l'esprit
« Scripts to Rule Them All » : l'outillage doit rendre productif, pas
seulement constater l'absence. Le critère d'échec nommé est conservé dans la
décision retenue ; seul s'y ajoute un chemin d'installation consenti.

### Installation automatique sans accord

Un bootstrap qui installe d'office (voire via `sudo`) agit à l'insu de
l'utilisateur sur un poste qui ne lui appartient pas toujours. Écarté :
l'accord explicite (interactif ou `--oui`) est la condition de toute
installation, et l'entrée non interactive reste en vérification seule.

### Gestionnaire d'outillage unique (nix, asdf, mise…)

Déléguer les versions à un gestionnaire dédié est séduisant mais ajoute un
prérequis de plus — qu'il faudrait lui-même installer —, impose une courbe
d'apprentissage à tout contributeur et n'est pas neutre vis-à-vis des
plateformes visées (Git Bash sous Windows notamment). Le gabarit reste sur
les gestionnaires natifs de chaque plateforme.

## Conséquences

- Ce que cela apporte : un poste neuf devient opérationnel par un seul script
  consenti ; les projets instanciés étendent le bootstrap sans toucher au
  gabarit (resynchronisation sans conflit) ; le prérequis git cesse d'être un
  angle mort.
- Ce que cela coûte : un contrat de module à connaître (deux phases, variables
  et aides documentées en tête d'orchestrateur) ; des installations
  dépendantes des gestionnaires natifs (apt/dnf/brew/winget), avec repli
  documenté quand ils manquent.
- Ce que cela ferme : le point d'extension « éditer bootstrap.sh » disparaît ;
  toute extension passe par un module.

## Vérification

`tools/bootstrap-test.sh` (tag `utest`, câblé dans les CI GitHub et GitLab)
rejoue les critères d'acceptation de req~onboarding-outille~2 sur leurs cas
d'échec : prérequis manquant → échec nommant l'outil, argument inconnu →
usage rappelé, entrée non interactive → aucune installation, poste complet →
succès idempotent. `tools/setup-test.sh` conserve le parcours d'accueil de
bout en bout. La traçabilité (`tools/oft.sh trace`) garantit que l'exigence
`~2` est couverte en dsn, impl et utest.

## Références

- req~onboarding-outille~2 (`spec/02-exigences/gouvernance.md`)
- ADR-0007 (orchestrateur en façade interchangeable — les portes restent des
  scripts POSIX autonomes)
- Mécanique éprouvée sur un projet instancié avant intégration au gabarit
- [Scripts to Rule Them All](https://github.blog/engineering/scripts-to-rule-them-all/)
