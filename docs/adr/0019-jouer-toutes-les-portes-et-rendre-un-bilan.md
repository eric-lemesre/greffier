# ADR-0019 — Jouer toutes les portes et rendre un bilan

**Statut** : Accepté
**Date** : 2026-08-29
**Décideur** : Eric Lemesre — seul, sur constat remonté d'un projet instancié
**Portée** : durable

## Contexte

`tools/ci.sh` est le point d'entrée unique des portes : les deux façades CI et
les façades d'orchestration y délèguent, et ce que la CI exécute est
exactement ce que le poste exécute. Il jouait les portes en séquence sous
`set -e` : la première en échec arrêtait tout.

Ce comportement paraît sain — échouer vite — et il l'est tant que les portes
échouent pour un défaut qu'on vient d'introduire. Il cesse de l'être dès
qu'une porte est **légitimement** rouge pendant une longue période.

Le cas est apparu sur un projet instancié dont la spécification précède la
réalisation. La traçabilité y est rouge par construction : les exigences sont
écrites, le code ne l'est pas encore, et OpenFastTrace signale les maillons
manquants — ce qu'il doit faire. Or la traçabilité est la **première** étape de
la liste. Pendant tout ce temps, aucune des treize portes suivantes n'a été
jouée une seule fois. Quand on les a jouées une à une à la main, deux tests
d'outillage étaient cassés depuis l'instanciation du dépôt, et l'un d'eux
depuis la fondation du gabarit.

Le défaut n'est pas que la CI soit rouge : elle devait l'être. Le défaut est
qu'elle ne disait rien du reste, et que rien dans sa sortie ne distinguait une
porte non jouée d'une porte absente du lanceur. Une porte rouge en cachait
douze dont personne ne savait rien.

## Décision

Le lanceur joue **toutes** les portes de la voie retenue, quel qu'ait été le
verdict des précédentes, et rend un **bilan** qui les nomme toutes avec leur
verdict.

Le code de retour reste non nul dès qu'une porte échoue, et le nombre de
portes en échec est annoncé. Le bilan informe ; il n'absout pas.

L'aiguillage des voies — documentaire ou complète, constatée par
`tools/perimetre.sh` (ADR-0017) — est inchangé : le bilan porte sur les portes
de la voie retenue, pas sur toutes celles qui existent.

## Alternatives écartées

### Réordonner la liste pour mettre la traçabilité en dernier

Le remède le plus court, et le pire. Il déplace le problème sur la porte qui se
retrouve en tête, sans rien changer au fait qu'une porte en masque d'autres. Il
suppose en outre de savoir d'avance laquelle sera rouge longtemps, ce qui varie
d'un projet à l'autre et d'un mois à l'autre.

### Rendre la traçabilité tolérante aux exigences non encore réalisées

Ce serait toucher à la porte plutôt qu'au lanceur, et lui retirer précisément
ce qu'elle apporte : signaler qu'un maillon manque. Une traçabilité qui
distinguerait « pas encore réalisée » de « réalisation perdue » demanderait un
statut d'exigence qu'OpenFastTrace ne lit pas, et qui serait saisi à la main —
donc un chiffre d'avancement déclaré, ce que la méthode refuse (méthode, ch. 4,
« agrégat recalculé ailleurs »).

### Laisser le contributeur relancer porte par porte

C'est ce qu'il a fallu faire pour découvrir le défaut, et c'est précisément la
preuve que cela ne se fait pas spontanément : personne ne joue treize scripts à
la main pour vérifier qu'une CI déjà rouge n'est pas rouge ailleurs.

## Conséquences

- **Ce que cela apporte.** L'état complet du dépôt est connu à chaque
  exécution. Un projet dont une porte reste rouge longtemps — spécification
  écrite avant réalisation, dette assumée et datée — continue de voir toutes
  les autres. Et le bilan rend visible d'un coup ce qu'une lecture séquentielle
  de la sortie ne donne pas : combien de portes sont en échec, et lesquelles.
- **Ce que cela coûte.** Une exécution où tout est cassé prend le temps de tout
  jouer au lieu de s'arrêter à la première seconde. Sur la voie complète, dont
  les tests créent des dépôts git jetables, cela se compte en minutes. Le prix
  est accepté : l'information vaut plus que l'économie, et la voie documentaire
  — celle du hook pre-commit — reste de quelques secondes.
- **Ce que cela ferme.** L'échec rapide comme comportement du lanceur. Une
  porte qui doit interrompre la suite devrait le faire pour une raison propre —
  aucune ne l'exige aujourd'hui, les portes étant indépendantes.

## Vérification

`tools/ci-test.sh` joue le lanceur sur une copie jetable du dépôt et vérifie
l'invariant : **la liste des portes jouées ne dépend pas de leurs verdicts.**

Le test ne suppose pas un dépôt sain — un test qui l'exigerait échouerait dans
tout projet dont la spécification précède la réalisation, c'est-à-dire au
moment précis où ce lanceur sert le plus. Il compare la liste des portes
nommées au bilan avant et après avoir cassé délibérément deux portes non
consécutives, et exige qu'elle soit identique, que les deux portes cassées y
soient marquées en échec, et que le code de retour soit non nul.

Cas d'échec joué à la mise en place (R3) : un lanceur rendant son bilan dès la
première porte en échec produit une liste tronquée, et le test le refuse.

## Références

- ADR-0017 — périmètre de la porte constaté, qui décide de la voie.
- ADR-0010 — CI en façades par forge : les deux délèguent à ce lanceur.
- `req~porte-ci~2`, dont la seconde phrase porte la présente décision.
- Constat d'origine : projet instancié `suivi-production`, descente verticale
  du 2026-08-29 — deux tests d'outillage cassés découverts derrière une
  traçabilité légitimement rouge.
