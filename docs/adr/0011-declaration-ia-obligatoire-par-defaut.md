# ADR-0011 — Exiger par défaut la déclaration d'usage de l'IA dans chaque commit

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-09, registre des décisions)
**Portée** : durable
**Remplace** : [ADR-0008](0008-attribution-agents-arbitree-a-l-instanciation.md)

## Item de conception

`dsn~politique-attribution~2`

La politique par défaut du gabarit applique un principe de **diligence** :
chaque commit déclare l'usage de l'IA par un trailer
(`IA: aucune` ou `IA: <outil>`) ; tout usage déclaré exige l'endossement d'un
humain (`Responsable: Prénom Nom`) ; la relecture (`Relu-par: …`) est
recommandée, pas exigée. Le hook commit-msg applique la politique (bloc à
marqueurs) ; l'instanciateur peut lui préférer `autorisee` (libre) ou
`interdite` (aucune mention), le script d'instanciation adaptant hook et
règle R0.

Covers:
- req~politique-attribution-agents~2

## Contexte

L'ADR-0008 avait rendu la politique arbitrable avec l'interdiction pour
défaut. Le porteur relève que ce défaut contredit le principe de diligence
qu'il retient : ce que l'IA produit en votre nom reste vôtre — la
transparence sur le rôle de l'IA et la responsabilité humaine assumée du
résultat sont le comportement à encourager par défaut, l'opacité ne devant
être qu'un choix explicite.

## Décision

Inverser le défaut : **déclaration obligatoire**. Concrètement, hors commits
techniques (merge, revert, fixup), le hook refuse un commit sans trailer
`IA:`, et refuse un usage d'IA déclaré sans `Responsable:`. La déclaration
`IA: aucune` est exigée aussi pour le travail sans IA : une politique de
transparence qui ne s'applique qu'aux commits assistés est invérifiable — la
déclaration explicite est ce qui rend l'absence d'IA crédible. Les modes
`autorisee` et `interdite` restent disponibles à l'instanciation.

## Alternatives écartées

### Déclaration exigée seulement en cas d'usage d'IA

Invérifiable mécaniquement : un commit muet est indistinguable d'un oubli.
Le trailer systématique transforme le silence en refus de porte.

### Relecture obligatoire (Relu-par exigé)

Le porteur la veut optionnelle ; l'exiger mécaniquement inciterait au trailer
de complaisance. Elle reste recommandée par la règle et vérifiée en revue.

### Conserver l'interdiction par défaut (ADR-0008)

Contraire au principe de diligence retenu ; reste disponible comme choix
explicite d'instanciation.

## Conséquences

- Ce que cela apporte : un historique où le rôle de l'IA est auditable et où
  chaque livraison assistée a un responsable humain nommé.
- Ce que cela coûte : un trailer à écrire sur chaque commit du mode par
  défaut ; les révisions d'exigence et d'item de conception (rev 2) ont été
  propagées sur tous les sites tagués.
- Ce que cela ferme : rien — les deux autres politiques restent au choix de
  l'instanciateur, et un projet peut changer par ADR.

## Vérification

`tools/init-test.sh` vérifie mécaniquement les trois politiques : défaut →
commit sans trailer refusé, `IA: aucune` accepté, `IA: <outil>` sans
`Responsable:` refusé, complet accepté ; `autorisee` → tout accepté ;
`interdite` → toute mention refusée. Le gabarit lui-même applique le défaut :
ses propres commits portent les trailers.

## Références

- Registre des décisions : D-2026-08-09.
- Exigence : req~politique-attribution-agents~2 (`spec/02-exigences/gouvernance.md`).
- Conformément au cycle de vie (méthode, ch. 2 et 3), l'item de conception de
  l'ADR-0008 est repris ici en révision 2 ; les sections Vérification des ADR
  remplacés se lisent à travers la présente politique.
