# Audit — sécurité

Miroir de [`spec/02-exigences/securite.md`](../../spec/02-exigences/securite.md).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~detection-secrets~1` | conforme | `tools/secrets.sh` (gitleaks épinglé, ADR-0012), balayage complet en CI et fichiers indexés en local ; `tools/secrets-test.sh` prouve la détection sur un secret de synthèse assemblé à l'exécution |
| `req~donnees-hors-depot~1` | conforme | `tools/donnees.sh` — trois refus lus sur le CONTENU : export versionné, SQL porteur de données, chemin de partage réseau qualifié ; bloc `fixtures` pour les jeux d'essai déclarés ; `tools/donnees-test.sh` joue les trois cas d'échec et les trois contreparties, dont « hors du chemin déclaré » |
| `req~securite-continue~1` | conforme | méthode ch. 10 ; modèles `threat-model.md` et `security-exception.md` fr/en ; durcissement CI (actions épinglées par SHA, permissions minimales, pas de jeton persisté) ; procédure `mtest~securite-continue-tenue~1` |

## Écarts ouverts

- Aucun **à ce jour**. Le SBOM n'est pas produit : le gabarit ne livre pas
  d'artefact exécutable. Tout projet instancié qui en livre un doit le
  produire — c'est le premier point que `mtest~securite-continue-tenue~1` fait
  vérifier.
