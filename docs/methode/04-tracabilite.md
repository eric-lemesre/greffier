# 4. Traçabilité

La chaîne besoin → exigence → conception → implémentation → test est vérifiée
par [OpenFastTrace](https://github.com/itsallcode/openfasttrace) (décision :
[ADR-0002](https://github.com/eric-lemesre/alm-forge/blob/main/docs/adr/0002-tracer-les-exigences-avec-openfasttrace.md)). L'outil
échoue si un maillon manque ; il n'y a pas de matrice tenue à la main.

## Types d'artefacts et chaîne

| Type | Artefact | Vit dans |
| --- | --- | --- |
| feat | expression de besoin | `spec/01-besoins/` |
| req | exigence | `spec/02-exigences/` |
| dsn | décision de conception | `docs/adr/` |
| impl | implémentation | code, scripts, docs selon le projet |
| utest / itest / stest | test unitaire / intégration / système | arborescence de tests |
| mtest | procédure de vérification manuelle | `docs/verification-manuelle/` |

Chaque item déclare ce qu'il attend en aval (`Needs: dsn, impl, utest`) ;
chaque artefact aval déclare ce qu'il couvre (mot-clé Covers pour les items,
tags pour le code).

## Définir un item (fichiers Markdown)

L'identifiant, entouré d'accents graves, **seul sur sa ligne** :

```markdown
`req~mon-exigence~1`

Texte de l'exigence.

Covers:
- feat~besoin-parent~1

Needs: impl, utest
```

Comportements vérifiés empiriquement (OpenFastTrace 4.9.0) :

- les blocs de code (comme ci-dessus) sont **ignorés** : la documentation peut
  citer la syntaxe sans créer d'items ;
- une mention d'identifiant à l'intérieur d'une phrase, ou indentée, ne crée
  pas d'item ;
- en revanche, une ligne qui **commence en colonne 0** par un identifiant entre
  accents graves est une définition, **même suivie de texte** (« `req~x~1`, et
  la suite ») : une citation ainsi placée dans un journal ou une fiche redéfinit
  l'item. `tools/oft.sh` le contrôle avant la trace et nomme chaque
  identifiant défini plusieurs fois avec ses fichiers (`sh tools/oft.sh
  doublons`).

## Taguer une couverture (tout langage)

Le tag `[type-aval->identifiant-couvert]` se place dans un commentaire,
n'importe quel langage à extension reconnue :

```python
def ma_fonction():
    ...
```

```rust
// [utest->req~mon-exigence~1]
#[test]
fn verifie_mon_exigence() { ... }
```

Dans un document Markdown, le tag s'écrit dans un commentaire HTML en début de
ligne — `<!-- [impl->…] -->` ; voir les tags réels en tête des chapitres 2 et 5
de cette méthode.

**Pièges vérifiés** (OpenFastTrace 4.9.0) : l'importateur de tags ne respecte
pas les blocs de code pour les commentaires HTML des fichiers Markdown, et un
titre Markdown à l'intérieur d'un bloc de code réactive l'importateur d'items —
ne jamais placer un titre ni un tag HTML complet dans un exemple de code.

**Piège vérifié** : les fichiers **sans extension** (hooks git, justfile…) ne
sont pas scannés. Les tags doivent vivre dans des fichiers à extension reconnue
(.sh, .py, .rs, .js, .ts, .yml, .md…) — d'où les hooks minces qui délèguent à
des scripts `.sh` tagués dans `tools/`. C'est aussi une des raisons du choix
de `Taskfile.yml` comme façade par défaut : son extension le rend scannable
(ADR-0007).

## Rattacher tout fichier de code

OpenFastTrace part des exigences : il ne voit jamais le code qui ne revendique
rien. La porte `tools/rattachement.sh` (`req~rattachement-code-exigence~1`)
prend le chemin inverse : tout fichier de code suivi par git se rattache à une
exigence existante, par l'une de deux traces.

- **L'étiquette de couverture** — `[impl->…]`, `[utest->…]`… — quand le
  fichier réalise ou vérifie l'exigence, et que ce type figure dans son
  `Needs:` (sinon OpenFastTrace refuse une couverture non demandée).
- **La mention** — par convention `Exigence servie : req~…~n` en commentaire
  — quand le fichier sert l'exigence sans la couvrir : outil d'appoint,
  fichier de structure, matériel prêt à copier de `templates/`. OpenFastTrace
  ne la lit pas comme une couverture ; elle dit honnêtement « sert, sans
  couvrir ».

Une étiquette qui vise un item inexistant fait échouer la porte, y compris
dans `templates/`, qu'OpenFastTrace ne balaie pas. Quand aucune exigence ne
convient, on écrit celle qui manque — jamais une étiquette de complaisance.

Dans un projet instancié, le code hérité du gabarit a perdu ses exigences :
l'instanciation en dresse la liste dans `tools/rattachement-herites.txt`.
Cette liste ne se complète pas à la main : un fichier ajouté par le projet se
rattache à ses propres exigences, et une ligne se retire dès que le fichier
disparaît ou porte sa propre trace.

## Exécution

| Commande | Effet |
| --- | --- |
| `task trace` (ou `sh tools/oft.sh trace`) | vérification complète, liste les défauts, code retour non nul si échec |
| `task report` (ou `sh tools/oft.sh report`) | rapport HTML navigable dans `build/tracabilite.html` |

## La porte, et son périmètre constaté

La traçabilité n'est qu'une porte parmi d'autres. Le point d'entrée unique est
`tools/ci.sh` : ce qu'il exécute est exactement ce que la CI exécute, sur les
deux forges (ADR-0010).

| Porte | Ce qu'elle refuse |
| --- | --- |
| `oft.sh` | un maillon manquant dans la chaîne besoin → test |
| `rattachement.sh` | un fichier de code sans étiquette ni mention d'une exigence existante, une étiquette vers un item inexistant |
| `checks.sh` | parité des modèles, ADR sans vérification, version hors journal, index d'ADR incomplet, façades CI désalignées, lexique incomplet, référence pendante depuis une façade ou le contrat |
| `liens.sh` | un lien interne qui ne mène nulle part |
| `statuts.sh` | un statut de domaine absent, non acté, ou divergent de l'index |
| `classification.sh` | une exigence sans niveau normatif, ou de niveau DOIT sans vérification |
| `releves.sh` | un relevé sans décision consignée, une décision hors registre |
| `journaux.sh` | une section de version publiée réécrite après son tag |
| `todo.sh`, `revues.sh`, `audit.sh`, `badges.sh` | une fiche mal formée, un tableau de bord périmé |
| `derive.sh` | un artefact généré retouché à la main, ou non versionné |
| `secrets.sh` | un secret dans l'historique ou dans l'index |
| `donnees.sh` | un export versionné, un SQL porteur de données, un chemin de partage réseau qualifié |

**Toutes les portes de la voie sont jouées, puis un bilan est rendu**
(ADR-0019). Le lanceur ne s'arrête pas à la première en échec : il les joue
toutes, les nomme toutes avec leur verdict, et sort en erreur en annonçant
combien ont échoué. Le motif tient en une phrase : une porte légitimement
rouge — une traçabilité qui attend la réalisation d'exigences déjà écrites —
masquerait sinon l'état de toutes celles qui la suivent, et rien dans la
sortie ne distinguerait une porte non jouée d'une porte absente.

**Les tests d'outillage sont joués en parallèle** (`tools/paralleles.sh`),
au plus `CI_PARALLELE` à la fois — par défaut le nombre de processeurs, `0`
pour ne pas limiter. Chacun travaille dans son propre dossier jetable ; un
test qui écrirait dans le dépôt n'a pas sa place dans cette liste. La règle
du bilan ne change pas : chaque test est joué jusqu'au bout quel que soit le
verdict des autres, sa sortie est rendue entière dans l'ordre de la liste,
et une étape qui n'a pas pu aller au bout compte comme un échec. Le bilan
donne la durée de chaque porte : c'est lui qui dit où le temps se passe.

**Le périmètre est constaté, jamais déclaré** (ADR-0017). `tools/perimetre.sh`
lit le changement réel — commits depuis la base de fusion, index, arbre de
travail **et fichiers non suivis** — et impose la voie complète au moindre
doute. La voie `docs` n'allège que les tests d'outillage, qui créent chacun des
dépôts git jetables ; aucune porte documentaire n'est jamais sautée.

Le hook pre-commit force la voie documentaire (`tools/ci.sh --rapide`) : un
hook trop lent finit contourné, et une porte contournée ne protège personne.
La porte complète reste due avant de proposer le travail.

Le périmètre scanné est défini une seule fois dans `tools/oft.sh` (hooks et CI
exécutent le même script). `templates/` en est exclu : les modèles contiennent
des exemples d'identifiants qui ne doivent pas devenir des items.

## Anti-patterns

- **Tag de complaisance** : taguer un fichier qui ne réalise pas réellement
  l'exigence pour faire passer la porte. La revue traque ce cas ; la
  traçabilité mesure la présence, la revue mesure la vérité.
- **Porte déclarée non câblée** : documenter un contrôle sans l'exécuter en CI.
  Interdit par l'exigence de porte CI — toute exception est marquée « non
  câblée » avec raison et échéance.
- **Contrôle no-op** : un contrôle de dérive qui compare un fichier jamais
  généré passe toujours. Vérifier le cas d'échec d'une porte fait partie de sa
  mise en place. Forme la plus fréquente : l'artefact généré **non versionné**
  — la régénération l'écrit, la comparaison ne voit rien, la porte est verte.
  D'où le double contrôle de `tools/derive.sh` : suivi par git, *puis*
  comparé.
- **Test qui suppose le défaut** : le symétrique du no-op, et il se voit
  encore moins. Un test d'outillage qui affirme le comportement livré par
  défaut, alors qu'un choix d'instanciation l'a changé, n'échoue pas une fois
  sur un cas particulier — il échoue **toujours**, dès le premier jour du
  projet produit, et un contrôle qui échoue toujours finit désactivé aussi
  sûrement qu'un contrôle qui passe toujours finit ignoré. Constaté deux fois
  sur un même dépôt instancié : le test des hooks exigeait qu'un commit
  portant `IA: aucune` soit accepté quand la politique retenue l'interdit, et
  le test de cohérence exigeait une porte de parité des modèles que le choix
  d'une langue unique venait de retirer. La règle qui en découle : **un test
  lit ce qui est installé, il ne suppose jamais le défaut**, et un choix qui
  retire une porte retire ou neutralise son test dans le même geste.
- **Agrégat recalculé ailleurs** : deux outils qui comptent la même chose
  finissent par ne plus compter pareil, et rien ne dit lequel se trompe. Un
  chiffre a **une** source ; qui en a besoin la consulte, ne la recalcule pas.
  Corollaire pratique : un état d'avancement se **calcule** à partir des
  artefacts, il ne se saisit jamais à la main — un état saisi est un second
  chiffre en puissance.
- **Porte muette par changement de langue** : une porte qui cherche un terme
  écrit en dur (« ACTIVE », « conforme », « à-tester ») ne trouve plus rien
  dans un dépôt instancié dans l'autre langue — et ne signale rien, puisqu'elle
  ne trouve rien. C'est pourquoi tout terme lu par une porte vient du lexique
  (ADR-0015).
- **Outillage aveugle à son environnement** : un chemin d'artefact de build
  codé en dur (`./target`, `node_modules/.bin`…) dans une recette, un script
  ou une CI casse — ou pire, devient silencieusement sans effet — dès qu'un
  réglage de poste le déplace (répertoire Cargo partagé via
  CARGO_TARGET_DIR, store pnpm, ccache…). Résoudre les chemins via l'outil
  (`cargo metadata` donne `target_directory`), et re-tester les portes —
  nettoyage compris — après tout changement d'environnement : un nettoyage
  devenu no-op est un contrôle qui passe toujours. Attention aussi au sens
  inverse : avec un cache partagé, un `cargo clean` « local » purge le
  répertoire commun à tous les projets du poste. (Cas vécu à l'origine de
  cette règle : bascule d'un poste en target partagé, scripts de nettoyage
  devenus vides et recettes clean devenues globales le même jour.)
- **Purge par la taille pendant une compilation** : un nettoyage borné par un
  plafond (`cargo sweep --maxsize`, et ses équivalents) efface les artefacts
  les plus anciens jusqu'à repasser sous la limite — y compris ceux de
  quelques minutes, dès que le cache frôle le plafond. Lancé par un minuteur
  pendant qu'un build tourne, il retire sous ses pieds un fichier objet que
  l'étape suivante attend : échec incompréhensible, sans rapport avec le
  changement en cours. Un nettoyage périodique sélectionne **par l'âge**
  d'inutilisation ; un plafond ne s'applique qu'à froid, quand aucune
  compilation ne tourne. (Cas vécu : CI cassée sur une dépendance
  cryptographique par le balayage de 17 h 22, cache à 75 Go pour un plafond
  de 80.)
- **Cache qui grossit à l'insu de tous** : la compilation incrémentale écrit
  dans `target/*/incremental` que rien ne purge, et n'accélère qu'une boucle
  d'édition — jamais une exécution complète de tests ou de CI ; une chaîne de
  compilation non épinglée conserve une copie complète des artefacts à
  chaque changement de version de l'outil ; un cache ouvert par branche de
  travail survit à la suppression de sa branche. Chacun de ces trois
  mécanismes est invisible jusqu'au disque plein. D'où l'exigence d'hygiène
  des artefacts de compilation (domaine gouvernance) : incrémental coupé sur
  tests, couverture et CI ; chaîne épinglée dans un fichier versionné ; cache de
  worktree nommé d'après le worktree, pour qu'un balayage sache le reconnaître
  et le retirer. (Cas vécu : 70 à 80 Go par branche, disque plein trois fois
  en un mois.)
