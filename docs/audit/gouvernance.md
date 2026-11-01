# Audit — gouvernance

Miroir de [`spec/02-exigences/gouvernance.md`](../../spec/02-exigences/gouvernance.md).
Verdicts écrits à la main ; le tableau de bord est généré (méthode, ch. 14).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~gouvernance-agents~1` | conforme | `AGENTS.md` (R0-R8, chacune avec son moyen de vérification) ; `CLAUDE.md` est un adaptateur-pointeur sans règle propre ; procédure `mtest~contrat-prevaut~1` |
| `req~bilinguisme-templates~1` | conforme | `templates/fr/` et `templates/en/`, 10 modèles de part et d'autre ; porte de parité dans `tools/checks.sh`, éprouvée par `tools/checks-test.sh` |
| `req~instanciation-outillee~2` | conforme | `tools/init.sh` (13 étapes, deux gardes) ; `tools/init-test.sh` couvre les trois branches de langue, le refus de double exécution, et le retrait de l'outillage avec ses amarres |
| `req~accueil-informatif~1` | conforme | `tools/setup.sh` joue `tools/ci.sh --rapide` et en rapporte le bilan sans propager son code de retour ; `tools/setup-test.sh` casse une porte et exige un accueil qui réussit ET qui le dit |
| `req~onboarding-outille~2` | conforme | `tools/setup.sh`, `tools/bootstrap.sh` et ses modules `tools/bootstrap.d/` ; `tools/setup-test.sh` et `tools/bootstrap-test.sh` couvrent l'idempotence et le refus sans accord |
| `req~politique-attribution-agents~2` | conforme | bloc à marqueurs de `tools/hooks/commit-msg.sh`, les trois politiques appliquées par `tools/init.sh` ; cas d'échec dans `tools/socle-test.sh` (trailer absent, responsable absent) |
| `req~coherence-choix-instanciation~1` | conforme | `tools/init.sh` propage le choix d'attribution à AGENTS.md, CONTRIBUTING.md et au registre des décisions ; `tools/socle-test.sh` et `tools/checks-test.sh` lisent la porte installée au lieu de supposer le défaut ; `tools/init-test.sh` [C] et [E] jouent les tests du dépôt produit et échouaient sur les trois défauts avant correction |
| `req~politique-langue~1` | conforme | `tools/init.sh` étape 3 ; `tools/init-test.sh` vérifie les trois branches |
| `req~portabilite-forges~1` | conforme | les deux façades délèguent à `tools/ci.sh` ; leur alignement est vérifié par `tools/checks.sh` et éprouvé par `tools/checks-test.sh` |
| `req~nettoyage-outille~1` | conforme | `tools/clean.sh` à chemins déclarés ; `tools/clean-test.sh` couvre l'idempotence et la préservation du versionné |
| `req~hygiene-artefacts-compilation~1` | conforme | `tools/hygiene-compilation.sh` (chaîne suivie par git et de canal exact ou daté ; réglage `CARGO_INCREMENTAL` à zéro sur la ligne ou avant le premier appel, formes idiomatiques et réglage natif `.cargo/config.toml` reconnus ; passage explicite sans manifeste), câblée dans `tools/ci.sh` ; `tools/hygiene-compilation-test.sh` joue chaque critère : chaîne absente, non suivie, flottante, huit formes d'appel nu, réglage en commentaire ou hors d'atteinte, formes idiomatiques, appels inertes, fichier et ligne nommés |
| `req~confinement-artefacts-worktree~1` | conforme | kit `templates/bootstrap.d/rust/rust.sh` (`garde` : worktree ou `cargo-target-<nom>` seulement, tree principal et homonymes refusés ; `clean` : `cargo sweep --time` seul, refus du partagé sans `--partage`) ; `tools/rust-kit-test.sh` éprouve les cinq critères avec des talons cargo et cargo-sweep (constats de revue n° 1 et 8 du 2026-10-25 rejoués en cas d'échec) |
| `req~versionnement-release~1` | conforme | contrôle VERSION ↔ CHANGELOG dans `tools/checks.sh`, éprouvé par `tools/checks-test.sh` ; `tools/journaux.sh` y ajoute l'intangibilité des sections publiées |
| `req~lexique-outille~1` | conforme | `tools/lexique.sh` (42 termes, deux formes chacun) ; complétude vérifiée par `tools/checks.sh` ; effet réel du réglage éprouvé par `tools/gouvernance-test.sh` (verdict français refusé en langue `en`) |

## Écarts ouverts

- Aucun.
