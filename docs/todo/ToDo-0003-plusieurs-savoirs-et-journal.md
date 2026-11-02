# ToDo-0003 — Plusieurs savoirs, jetons à portée, configuration et journal

**Statut : 🚧 en cours**

Faire servir par une même instance les savoirs de plusieurs communautés,
chaque client limité aux dépôts de sa portée, réglée par l'environnement ou
par un fichier protégé, avec un journal qui dit qui interroge quoi sans
livrer ni secret ni question. Il existe parce qu'un Greffier ne sert
aujourd'hui qu'un dépôt, sous un jeton unique, sans journal.

## Reste à faire

- Lots 1 à 3 (configuration, plusieurs dépôts et jetons à portée,
  journal) : réalisés, en attente de fusion.
- Lot 4 — documentation : README, modèle d'environnement des paquets et
  journaux faits ; reste la version 0.3.0, sur demande du porteur, et
  l'adoption par Pacilia (`X-Request-Id` transmis par son adaptateur).

## Renvois

- Exigences : req~savoirs-multiples~1, req~jetons-a-portee~1,
  req~configuration-environnement-et-fichier~1, req~journal-du-service~1
- Décisions : ADR-0006, ADR-0007, D-2026-11-08, D-2026-11-09
- Issues : —
