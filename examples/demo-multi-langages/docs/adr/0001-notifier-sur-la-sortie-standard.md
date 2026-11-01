# ADR-0001 — Notifier sur la sortie standard

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : exemple
**Portée** : durable

## Item de conception

`dsn~format-message-notification~1`

La notification est une ligne texte sur la sortie standard, au format
« [état] nom (durée s) » — portable sur les trois langages de l'exemple sans
dépendance système.

Covers:
- req~notification-terminale~1

## Contexte

L'exemple doit rester exécutable partout ; une notification de bureau
(libnotify, etc.) introduirait une dépendance d'environnement.

## Décision

Sortie standard, format unique, testable par simple capture.

## Alternatives écartées

### Notification de bureau

Dépendante de l'environnement graphique : intestable en CI minimale.

## Conséquences

- Ce que cela apporte : exécution et test identiques en local et en CI.
- Ce que cela coûte : pas de vraie notification système dans l'exemple.

## Vérification

Les tests unitaires capturent la sortie et vérifient le format ; la
traçabilité impose leur existence.

## Références

- Exigences de l'exemple : `../../spec/specification.md`.
