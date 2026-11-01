# Exigences — domaine décisions

**Statut : ACTIVE** — domaine acté le 2026-08-20 (D-2026-08-16). Le statut commande
le dénominateur des taux d'audit et de classification (méthode, ch. 13).

Rédigées selon la syntaxe EARS (voir [méthode, ch. 2](../../docs/methode/02-exigences.md)).
Niveaux normatifs : DOIT / DEVRAIT / PEUT.

## Registre des décisions d'architecture

`req~registre-adr~1`

**Statut : approuvée**

Le dépôt DOIT fournir un registre d'ADR : un répertoire dédié, une charte
(cycle de vie, numérotation continue, immuabilité des ADR acceptés) et un
modèle prêt à remplir.

Critères d'acceptation :

- Étant donné le gabarit instancié, quand un contributeur doit acter une
  décision, alors il trouve un modèle d'ADR et la procédure dans le registre.
- Étant donné un ADR accepté, quand la décision évolue, alors un nouvel ADR le
  remplace et l'ancien reçoit le statut « Remplacé », sans réécriture.

Covers:
- feat~cadre-de-decision~1

Needs: dsn, impl, utest

## Section Vérification obligatoire

`req~adr-verification~1`

**Statut : approuvée**

Lorsqu'un ADR passe au statut « Accepté », le dépôt DOIT vérifier mécaniquement
qu'il comporte une section « Vérification » décrivant comment on sait que la
décision est tenue.

Rationale:
Reprise du principe d'ergonomia : une décision qu'aucun mécanisme ne protège
dérivera. Le contrôle est outillé pour ne pas dépendre de la vigilance du
relecteur.

Critères d'acceptation :

- Étant donné un ADR au statut « Accepté » sans section « Vérification », quand
  les portes qualité s'exécutent, alors elles échouent en désignant le fichier.

Covers:
- feat~cadre-de-decision~1

Needs: impl, utest

## Statut des domaines de spécification

`req~statut-specification~1`

**Statut : approuvée**

Chaque domaine de spécification DOIT porter un statut au vocabulaire du
lexique ; un domaine actif DOIT être adossé à une décision du registre, et
l'index des domaines DOIT concorder avec l'en-tête de chacun.

Rationale:
Le statut est un commutateur : il commande le dénominateur des taux. Un statut
qui ment fausse donc un chiffre sans qu'aucune porte ne proteste — domaine
déclaré actif d'un trait de plume, index et en-tête divergents, exigences
comptées d'un domaine jamais validé.

Critères d'acceptation :

- Étant donné un domaine sans statut, quand la porte s'exécute, alors elle
  échoue.
- Étant donné un domaine actif sans entrée au registre, quand la porte
  s'exécute, alors elle échoue.
- Étant donné un index qui contredit un en-tête, quand la porte s'exécute,
  alors elle échoue.

Covers:
- feat~cadre-de-decision~1

Needs: impl, utest

## Relevés de séance et registre

`req~releves-de-decision~1`

**Statut : approuvée**

Tout relevé de séance DOIT porter une section de décisions non vide et non
laissée à l'état de gabarit ; toute décision citée dans un relevé DOIT figurer
au registre, et toute entrée du registre DOIT renvoyer vers un artefact
existant.

Rationale:
Précédent fondateur sur ergonomia (juillet 2026) : le document d'une séance
portait une section « Relevé de décisions (à compléter en séance) » qui n'a
jamais été remplie. Les décisions avaient pourtant été prises — on les
retrouve citées dans les spécifications — et les issues correspondantes
fermées. La trace opposable, elle, n'existait pas. Le contrôle du gabarit
laissé tel quel vise le défaut type : une section techniquement non vide, mais
qui ne consigne rien.

Critères d'acceptation :

- Étant donné un relevé dont la section de décisions est vide, quand la porte
  s'exécute, alors elle échoue.
- Étant donné un relevé dont la section est restée à l'état de gabarit, quand
  la porte s'exécute, alors elle échoue.
- Étant donné une décision citée hors registre, quand la porte s'exécute,
  alors elle échoue.

Covers:
- feat~cadre-de-decision~1

Needs: impl, utest

## Journal du dépôt et journal du logiciel

`req~journaux-depot-et-logiciel~1`

**Statut : approuvée**

Le journal du dépôt et le journal du logiciel DOIVENT être distincts dès lors
que le projet livre un logiciel, et toute section de version publiée DOIT être
intangible : ses lignes proviennent de commits antérieurs au tag de la
version, sauf révision éditoriale explicitement déclarée.

Rationale:
Confondre les deux journaux produit soit un journal illisible pour
l'utilisateur, noyé dans l'outillage, soit un journal muet pour le
contributeur. L'intangibilité répond à un piège constaté trois fois sur
ergonomia les 16 et 17 août 2026 : des entrées ajoutées après coup dans la
section d'une version déjà taguée, donc absentes du paquet réellement livré
sous ce numéro. Le contrôle par attribution de lignes est la seule preuve
mécanique disponible.

Critères d'acceptation :

- Étant donné une version qui n'a ni section propre ni section « non
  publié », quand la porte s'exécute, alors elle échoue.
- Étant donné une section publiée modifiée après son tag, quand la porte
  s'exécute, alors elle échoue en nommant le commit fautif.
- Étant donné une révision éditoriale déclarée, quand la porte s'exécute,
  alors elle passe.

Covers:
- feat~cadre-de-decision~1

Needs: impl, utest
