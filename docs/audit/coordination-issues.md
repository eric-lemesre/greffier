# Audit — coordination par les issues

Miroir de [`spec/02-exigences/coordination-issues.md`](../../spec/02-exigences/coordination-issues.md).

Domaine dont la vérification est **majoritairement manuelle** : l'état d'une
issue vit sur la forge, hors du dépôt, et une porte qui doit rester exécutable
hors ligne ne peut pas l'interroger. Les procédures sont dans
[`docs/verification-manuelle/coordination.md`](../verification-manuelle/coordination.md).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~issues-etat-attente-acte~2` | conforme | méthode ch. 11 (socle invariant) ; formulaires GitHub et GitLab ; procédure `mtest~etat-attente-acte~1` |
| `req~issues-flux-avancement~2` | conforme | méthode ch. 11 (trois flux, entraves cumulables, fins de vie motivées) ; ADR-0013 ; procédure `mtest~flux-avancement~1` |
| `req~issues-triage-priorites~2` | conforme | méthode ch. 11 (la gravité se constate, la priorité se décide) ; gravité au formulaire d'anomalie ; procédure `mtest~triage-priorites~1` |
| `req~conformite-issues~1` | conforme | `tools/issues.sh`, délibérément hors porte ; voie GitLab conditionnée à `jq`, avec refus explicite plutôt qu'un parseur JSON maison ; procédure `mtest~conformite-issues~1` |
| `req~automatismes-forge~1` | conforme | `templates/forge/` — logique unique en POSIX sh, façades GitHub et GitLab ; non câblés dans le gabarit avec raison et échéance (ch. 11) ; procédure `mtest~automatismes-forge~1` |

## Écarts ouverts

- Aucun. Les automatismes ne sont pas câblés **par décision**, pas par
  manquement : ils écrivent sur les issues d'une forge que le gabarit n'a pas.
