# Audit — ingénierie des exigences

Miroir de [`spec/02-exigences/ingenierie-exigences.md`](../../spec/02-exigences/ingenierie-exigences.md).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~expression-du-besoin~1` | conforme | `spec/01-besoins/besoins.md` (6 besoins, chacun avec rationale et `Needs: req`) ; modèles `need.md` fr/en ; procédure `mtest~besoin-capture-intention~1` |
| `req~format-exigence-ears~1` | conforme | méthode ch. 2 ; niveau normatif vérifié mécaniquement par `tools/classification.sh` ; la clarté relève de `mtest~redaction-ears~1` |
| `req~cycle-de-vie-exigence~2` | conforme | statut déclaré sur chacune des 39 exigences, avancement CALCULÉ depuis les tags et les items de couverture (`tools/statuts.sh`) ; les trois refus — statut absent, statut d'avancement déclaré, approbation dans un domaine non actif — sont éprouvés par `tools/gouvernance-test.sh` ; ADR-0018 |
| `req~questions-ouvertes~1` | conforme | `spec/open-questions.md`, méthode ch. 6, modèles `open-question.md` fr/en ; procédure `mtest~questions-ouvertes-vivantes~1` |

## Écarts ouverts

- Aucun.

## Écarts refermés

- `req~cycle-de-vie-exigence~1` → **révision 2**, écart tranché le 2026-08-20
  (D-2026-08-17, ADR-0018). L'arbitrage a retenu de **tenir l'exigence et de
  l'outiller** plutôt que de l'abaisser au niveau du domaine : le domaine est
  une granularité trop grossière pour la question posée, puisqu'il mêle des
  exigences approuvées mais non réalisées et d'autres livrées et prouvées.
  La révision 2 apporte ce que l'énoncé initial ne disait pas — le vocabulaire,
  le partage déclaré/calculé, et l'articulation avec le statut de domaine.
