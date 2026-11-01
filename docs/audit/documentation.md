# Audit — documentation vérifiée

Miroir de [`spec/02-exigences/documentation.md`](../../spec/02-exigences/documentation.md).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~integrite-liens~1` | conforme | `tools/liens.sh` (85 liens vérifiés) ; `tools/liens-test.sh` couvre quatre cas, dont le fichier présent mais non versionné |
| `req~feuille-de-route-outillee~1` | conforme | `tools/todo.sh`, index dérivé et protégé par `tools/derive.sh` ; méthode ch. 12 ; deux cas d'échec dans `tools/gouvernance-test.sh` |
| `req~suivi-constats-revue~1` | conforme | `tools/revues.sh` ; le refus des sévérités hautes non soldées mécanise la règle du ch. 7 ; le rejet motivé solde, cas éprouvé |
| `req~badges-autonomes~1` | conforme | `tools/badges.sh`, aucun appel réseau, sortie déterministe ; badges versionnés et protégés par l'anti-dérive ; cas d'échec dans `tools/gouvernance-test.sh` |
| `req~avancement-calcule~1` | conforme | `tools/avancement.sh`, colonne dérivée de `Needs:` déclaré et des citations de `docs/todo/`, protégée par `tools/derive.sh` ; six états rejoués et contre-vérifiés sur un dépôt de synthèse (`tools/gouvernance-test.sh`) |

## Écarts ouverts

- Aucun.
