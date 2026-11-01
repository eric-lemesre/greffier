# ADR-0016 — Séparer l'audit de réalisation de la traçabilité

**Statut** : Accepté
**Date** : 2026-08-20
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-14, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~audit-de-realisation~1`

L'audit de réalisation est une porte distincte de la traçabilité, avec ses
propres artefacts : une fiche par domaine dans `docs/audit/`, portant un
tableau `| Exigence | Verdict | Preuve / écart |` dont les verdicts sont
**écrits à la main**, et un tableau de bord `docs/audit/README.md` **généré**
qui n'en fait que la comptabilité.

`tools/audit.sh` ne juge jamais. Il vérifie que chaque exigence d'un domaine
actif a une ligne, que chaque ligne vise une exigence existante, que chaque
verdict appartient au lexique, et que le nombre d'exigences non examinées reste
sous un plafond déclaré.

Covers:
- req~audit-de-realisation~1

## Contexte

OpenFastTrace répond à une question de **présence** : cette exigence a-t-elle
un item de conception, du code, un test ? La question se calcule, et la
réponse est binaire.

Elle laisse entière la question de la **vérité** : ce qui est livré fait-il ce
que l'exigence dit ? Un tag de complaisance — poser `[impl->req~…]` sur un
fichier qui ne réalise pas l'exigence — passe la traçabilité sans réserve. Le
chapitre 4 le nomme déjà comme anti-pattern et renvoie à la revue ; mais la
revue porte sur un diff, pas sur l'état du produit, et rien ne consolidait le
jugement porté exigence par exigence.

## Décision

Deux portes, deux questions, deux artefacts. Le partage du travail est celui
que la traçabilité applique déjà : **le générateur compte, l'humain juge**.

Le plafond d'exigences non examinées est ce qui empêche la dette de
s'installer sans être vue. Il est déclaré dans le script, à 0 pour le gabarit.
Un projet qui transpose un existant volumineux peut le desserrer le temps de
résorber, à condition de le faire décroître : un plafond qui suit le réel ne
contrôle plus rien — il l'enregistre.

## Alternatives écartées

### Étendre OpenFastTrace avec un statut de verdict

L'outil n'a pas ce concept, et l'ajouter supposerait de le forker ou de
détourner ses champs. L'ADR-0002 a retenu OFT pour sa traçabilité, pas comme
réceptacle de tout jugement.

### Faire porter l'audit par la revue de code seule

C'est l'état antérieur. La revue voit un diff au moment où il est proposé ;
elle ne dit rien de l'exigence rédigée il y a six mois dont l'implémentation a
dérivé depuis. L'audit est un balayage d'état, la revue un contrôle de flux :
les deux sont nécessaires.

### Générer aussi les fiches de domaine

Tentant pour supprimer la dérive, mais un verdict généré ne veut rien dire :
c'est précisément le jugement qu'on ne peut pas calculer. Seule la
comptabilité est dérivée — ce qui évite au passage l'en-tête chiffré tenu à la
main, source de dérive constatée sur ergonomia.

## Conséquences

- Ce que cela apporte : le tag de complaisance devient visible ; l'état réel du
  produit face à sa spécification se lit dans un tableau, à jour par
  construction.
- Ce que cela coûte : un verdict à écrire pour chaque exigence, et à revoir
  quand l'exigence change. C'est un coût de lecture, assumé : il n'existe pas
  de version automatique de ce travail.
- Ce que cela ferme : l'idée d'un taux de conformité calculé. Tout chiffre
  d'audit reste la somme de jugements humains.

## Vérification

`tools/audit.sh` échoue si une exigence n'a pas de ligne, si un verdict sort du
lexique, si une ligne vise une exigence supprimée, ou si le tableau de bord est
périmé. `tools/gouvernance-test.sh` éprouve ces quatre cas.

## Références

- Registre des décisions : D-2026-08-14.
- ADR-0002 (OpenFastTrace comme moteur de traçabilité) : inchangé, cet ADR en
  délimite le périmètre par le haut.
