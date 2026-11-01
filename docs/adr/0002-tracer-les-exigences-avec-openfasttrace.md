# ADR-0002 — Tracer les exigences avec OpenFastTrace

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-02, registre des décisions)
**Portée** : durable — condition de réouverture : abandon du projet OpenFastTrace ou besoin d'attributs d'exigence que son format ne porte pas

## Item de conception

`dsn~moteur-tracabilite~1`

La traçabilité besoin→exigence→conception→implémentation→test est vérifiée par
OpenFastTrace (jar autonome, épinglé en version et en empreinte SHA-256 dans
`tools/oft.sh`) : items de spécification dans les fichiers Markdown, tags de
couverture dans les commentaires du code, échec du build si un maillon manque.

Covers:
- req~tracabilite-outillee~1

## Contexte

L'exigence de traçabilité outillée impose un moteur indépendant du langage.
Quatre options ont été comparées : OpenFastTrace, un script maison portable
(l'approche d'ergonomia avec tracabilite.mjs, ou de wallos-rs avec ses
proc-macros Rust), StrictDoc, ou une simple convention avec adaptateurs par
projet.

## Décision

Adopter **OpenFastTrace** comme moteur unique. Comportements vérifiés
empiriquement sur la version 4.9.0 avant décision :

- items définis en Markdown, tags de couverture reconnus dans les commentaires
  de fichiers .py, .rs, .js, .sh, .yml et .md (commentaires HTML) ;
- les blocs de code Markdown sont ignorés (la documentation peut montrer la
  syntaxe sans créer d'items fantômes) ;
- les fichiers sans extension (justfile, hooks git) ne sont **pas** scannés :
  les tags de couverture doivent vivre dans des scripts à extension reconnue ;
- code retour 1 et liste des identifiants orphelins en cas de couverture
  incomplète ; un tag vers un identifiant inexistant est une erreur.

## Alternatives écartées

### Script maison portable

Contrôle total mais code à maintenir, à tester et à porter ; recrée ce
qu'OpenFastTrace fournit déjà, sans sa robustesse (révisions d'items, types
d'artefacts, rapports).

### StrictDoc

Riche (interface web, exports) mais impose son format .sdoc comme source de
vérité et une dépendance Python lourde ; le besoin est une porte de build, pas
une plateforme de gestion documentaire.

### Convention + adaptateurs au choix du projet

Reporte le choix sur chaque projet instancié : c'est l'absence de décision, et
la garantie d'implémentations inégales.

## Conséquences

- Ce que cela apporte : zéro code de traçabilité à maintenir ; même moteur en
  local (hooks) et en CI ; formats textuels revus en pull request.
- Ce que cela coûte : dépendance à un environnement Java 17+ sur les postes et
  les runners ; syntaxe d'items à apprendre (couverte par la méthode, ch. 4).
- Ce que cela ferme : pas d'attributs d'exigence arbitraires dans l'outil
  (criticité, couches) — ils vivent dans le texte de l'exigence, pas dans le
  moteur.

## Vérification

`tools/oft.sh` épingle version et SHA-256 du jar et échoue si l'empreinte ne
correspond pas ; `just trace` et la CI exécutent la même commande sur le même
périmètre de fichiers. Une exigence orpheline fait échouer commit (hook) et CI.

## Références

- Registre des décisions : D-2026-08-02.
- Documentation OpenFastTrace : <https://github.com/itsallcode/openfasttrace/blob/main/doc/user_guide.md>
- Méthode : `docs/methode/04-tracabilite.md`.
