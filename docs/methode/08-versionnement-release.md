# 8. Versionnement et release

<!-- [impl->req~versionnement-release~1] -->

## Versionnement

- **SemVer** (MAJEUR.MINEUR.CORRECTIF), un numéro unique pour tout le dépôt
  (lockstep), porté par le fichier `VERSION` et le tag git `vX.Y.Z`.
- Le journal `CHANGELOG.md` suit **Keep a Changelog** : une section
  « Non publié » alimentée au fil des pull requests, transformée en section
  versionnée datée au moment de la release. C'est la lecture du journal qui
  décide du niveau d'incrément (correctif, mineur, majeur).
- La cohérence VERSION ↔ CHANGELOG est une porte mécanique (`task check`) : on
  ne peut pas publier une version absente du journal.
- Dans un projet instancié multi-composants, tous les manifestes (Cargo.toml,
  package.json…) suivent le même numéro ; `tools/bump.sh` est le point unique
  de mise à jour — l'étendre aux manifestes du projet fait partie de
  l'instanciation.

## Deux journaux, deux lectorats

<!-- [impl->req~journaux-depot-et-logiciel~1] -->

| Fichier | Pour qui | Ce qu'on y met |
| --- | --- | --- |
| `CHANGELOG.md` | qui **contribue** | portes, méthode, outillage, refactorisations, décisions |
| `NEWS.md` | qui **utilise ou exploite** | ce que le produit livré fait de plus, de moins, ou autrement |

Les confondre produit soit un journal illisible pour l'utilisateur, noyé dans
l'outillage, soit un journal muet pour le contributeur. Un projet sans logiciel
livrable — un gabarit, une bibliothèque de méthode — n'a **pas** de `NEWS.md` :
le fichier est absent, et c'est un choix, pas un oubli. `alm-forge` est dans ce
cas.

Dans un projet multi-paquets, les journaux par paquet (Debian, RPM…) se
**dérivent** de `NEWS.md` : ils ne s'écrivent jamais à la main, et la porte
anti-dérive le garantit.

## Une section publiée est intangible

`tools/journaux.sh` vérifie que chaque ligne d'une section de version publiée
provient d'un commit **antérieur au tag** de cette version. La preuve est
mécanique : attribution de lignes (`git blame -M`, qui suit les déplacements),
sur une fenêtre des six dernières versions — au-delà, l'attribution ne mesure
plus rien d'utile.

Le piège que cela ferme a été constaté trois fois en deux jours sur ergonomia :
des entrées ajoutées après coup dans la section d'une version déjà taguée,
donc **absentes du paquet réellement livré sous ce numéro**. Le journal
promettait ce que le binaire ne contenait pas.

Une correction purement éditoriale — reformatage, faute d'orthographe,
renumérotation d'un document cité — se déclare dans
`tools/journaux-revisions-editoriales.txt`, un SHA par ligne avec son motif.
Fichier distinct de `.git-blame-ignore-revs`, pour ne pas fausser
l'attribution globale du dépôt avec des commits qui portent par ailleurs du
vrai contenu.

**Le geste vient nécessairement après la fusion** : sur une pull request
fusionnée en un seul commit, le SHA à déclarer n'existe pas avant le squash.
La déclaration est donc un commit de suite, pas une case à cocher dans la
demande — et c'est le seul cas où l'on touche à une section publiée sans être
en faute. Le critère qui sépare la révision éditoriale du reste tient en une
question : **le sens de l'entrée change-t-il ?** Si oui, ce n'est pas une
révision éditoriale, c'est une réécriture de l'histoire.

## Campagne de non-régression : aux versions mineures

Une campagne complète — tests longs, parcours de bout en bout, vérifications
manuelles (ch. 5) — se joue à chaque incrément **MINEUR**, jamais à chaque
correctif et **jamais dans la porte** : une porte qui dure une heure n'est plus
une porte, c'est un rendez-vous.

Le raisonnement est le même que pour l'aiguillage du périmètre (ADR-0017) : le
coût d'une vérification doit rester proportionné à la fréquence de son
déclenchement, sans quoi elle finit contournée. Les procédures de
`docs/verification-manuelle/` portent d'ailleurs cette cadence dans leur
en-tête.

## Commits et branches

- **Conventional Commits en français** : `type(scope): sujet` avec les types
  feat, fix, docs, test, chore, refactor, perf, ci, build, style, revert. Le
  scope reprend le domaine d'exigences quand il existe.
- Un commit de réalisation référence son exigence dans le sujet :
  `feat(notif): req~notification-terminale~1 accusé sonore`. Un commit = une
  exigence ou une intention cohérente — pas de commits fourre-tout.
- Le format est vérifié par le hook commit-msg (garde absente d'ergonomia,
  ajoutée ici) ; la mention de l'IA suit la politique arbitrée à
  l'instanciation — par défaut, déclaration obligatoire avec responsable
  humain et relecture recommandée (R0, ADR-0011).
- Branches : `type/sujet-court` (`feat/notification-sonore`,
  `fix/echeance-fin-de-mois`).

## Release

1. Vérifier que `task ci` passe.
2. `task bump -- X.Y.Z` — met à jour VERSION ; transformer la section
   « Non publié » du journal en section `[X.Y.Z] - AAAA-MM-JJ`.
3. Commit `chore: version X.Y.Z`, tag `vX.Y.Z`, push du tag.
4. La publication d'artefacts (paquets, images, SBOM) est propre à chaque
   projet instancié ; le gabarit fournit l'emplacement
   (`.github/workflows/`) et la règle : toute chaîne de publication est
   déclenchée par le tag, jamais à la main.
