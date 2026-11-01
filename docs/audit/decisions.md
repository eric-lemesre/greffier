# Audit — décisions

Miroir de [`spec/02-exigences/decisions.md`](../../spec/02-exigences/decisions.md).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~registre-adr~1` | conforme | `docs/adr/` (17 ADR) et son index ; complétude et réciproque vérifiées par `tools/checks.sh`, éprouvées par `tools/checks-test.sh` |
| `req~adr-verification~1` | conforme | contrôle de section « Vérification » dans `tools/checks.sh`, éprouvé par `tools/checks-test.sh` |
| `req~statut-specification~1` | conforme | `tools/statuts.sh` (trois invariants) ; méthode ch. 13 ; trois cas d'échec dans `tools/gouvernance-test.sh` |
| `req~releves-de-decision~1` | conforme | `tools/releves.sh` ; le contrôle du gabarit laissé tel quel vise le défaut type ; trois cas d'échec dans `tools/gouvernance-test.sh` |
| `req~journaux-depot-et-logiciel~1` | conforme | `tools/journaux.sh` ; contrôle des sections closes par attribution de lignes, fichier de révisions éditoriales ; deux cas d'échec dans `tools/gouvernance-test.sh` |

## Écarts ouverts

- Aucun. Le gabarit ne livrant pas de logiciel, il n'a pas de `NEWS.md` — la
  porte le tolère explicitement, et c'est un choix, pas un oubli.
