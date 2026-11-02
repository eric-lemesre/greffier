# ToDo-0003 — Plusieurs savoirs, jetons à portée, configuration et journal

**Statut : 🚧 en cours**

Faire servir par une même instance les savoirs de plusieurs communautés,
chaque client limité aux dépôts de sa portée, réglée par l'environnement ou
par un fichier protégé, avec un journal qui dit qui interroge quoi sans
livrer ni secret ni question. Il existe parce qu'un Greffier ne sert
aujourd'hui qu'un dépôt, sous un jeton unique, sans journal.

## Reste à faire

- Lot 1 — configuration : fichier TOML (`--config`, `GREFFIER_CONFIG`),
  priorité option, environnement, fichier, défaut ; garde sur les droits
  d'un fichier à secret ; secrets typés ; section `[piste]`.
- Lot 2 — plusieurs dépôts et jetons à portée : dépôts nommés, routes
  `/savoirs/{nom}/…` et MCP par dépôt, routes de la 0.2.0 gardées, clients
  de l'environnement et du fichier, empreintes SHA-256, 404 hors portée.
- Lot 3 — journal : `tracing` installé par le binaire, `X-Request-Id`,
  ligne par requête, cible `greffier::acces`, journald, filtre et format ;
  porte `tools/journalisation.sh` du gabarit.
- Lot 4 — documentation (README, service systemd et modèle de fichier
  des paquets), version 0.3.0 sur demande du porteur.

## Renvois

- Exigences : req~savoirs-multiples~1, req~jetons-a-portee~1,
  req~configuration-environnement-et-fichier~1, req~journal-du-service~1
- Décisions : ADR-0006, ADR-0007, D-2026-11-08, D-2026-11-09
- Issues : —
