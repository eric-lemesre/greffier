# Audit — 01-ancrage

<!-- Miroir de spec/02-exigences/01-ancrage.md. Les verdicts sont écrits À
     LA MAIN : c'est le jugement que la porte ne sait pas rendre. Le tableau
     de bord docs/audit/README.md, lui, est généré — ne pas l'éditer.
     Squelette des lignes manquantes :
       sh tools/audit.sh --squelette 01-ancrage -->

Verdicts admis : `conforme` · `écart` · `non examiné`.

Domaine actif depuis D-2026-11-04 : les quatre exigences approuvées et
réalisées au lot 1 entrent au périmètre ; les exigences encore proposées
(citation ancrée, séparation moteur / savoir, péremption, cloisonnement)
n'y entreront qu'à leur approbation.

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~textes-authentiques-versionnes~1` | conforme | `src/couche.rs` : un fichier par version, écriture `create_new`, capture identique sans effet, contenu différent refusé (`TexteDifferent`) ; version en vigueur à une date rendue seule ; tests unitaires de `couche.rs` et test d'intégration `capturer_un_article_et_ses_versions_les_conserve_cote_a_cote` |
| `req~capture-des-sources-officielles~1` | écart | réalisé et éprouvé contre un faux serveur PISTE (identifiant validé avant appel, réponse sans identifiant, texte, date ou ECLI refusée, secret absent des sorties : `tests/piste_itest.rs`) ; la recette sur l'API officielle reste due — elle attend une application PISTE du porteur |
| `req~detection-des-versions~1` | conforme | `src/versions.rs` : nouvelles versions et fin de vigueur postérieures à la date, « inchangé » sinon ; sortie 3 éprouvée par `versions_sort_en_3_quand_l_article_a_change` |
| `req~chaine-de-verification-du-moteur~1` | conforme | chaîne épinglée (`rust-toolchain.toml`, porte d'hygiène) ; en-têtes SPDX vérifiés par `tools/spdx.sh`, cas d'échec par `tools/spdx-test.sh` ; format, lints et tests dans la voie complète de `tools/ci.sh` et en CI GitHub |

## Écarts ouverts

- `req~capture-des-sources-officielles~1` : recette sur l'API PISTE réelle
  (production, Légifrance et Judilibre souscrites) — forme des dates et
  adresse publique des textes hors code à confirmer (ToDo-0001, lot 1).
