# Audit — 01-ancrage

<!-- Miroir de spec/02-exigences/01-ancrage.md. Les verdicts sont écrits À
     LA MAIN : c'est le jugement que la porte ne sait pas rendre. Le tableau
     de bord docs/audit/README.md, lui, est généré — ne pas l'éditer.
     Squelette des lignes manquantes :
       sh tools/audit.sh --squelette 01-ancrage -->

Verdicts admis : `conforme` · `écart` · `non examiné`.

Domaine actif depuis D-2026-11-04 : les six exigences approuvées entrent au
périmètre — quatre réalisées au lot 1, la séparation moteur / savoir au
lot 2, la citation ancrée (conçue par l'ADR-0001, approuvée par
D-2026-11-05) au lot 3. Les exigences encore proposées (péremption,
cloisonnement) n'y entreront qu'à leur approbation.

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~textes-authentiques-versionnes~1` | conforme | `src/couche.rs` : un fichier par version, écriture `create_new`, capture identique sans effet, contenu différent refusé (`TexteDifferent`) ; version en vigueur à une date rendue seule ; tests unitaires de `couche.rs` et test d'intégration `capturer_un_article_et_ses_versions_les_conserve_cote_a_cote` |
| `req~capture-des-sources-officielles~2` | conforme | éprouvé contre un faux serveur PISTE (identifiant validé avant appel, réponse sans identifiant, texte, date ou ECLI refusée, secret absent des sorties : `tests/piste_itest.rs`) ; recette sur l'API de production le 2026-11-01 : article `LEGIARTI000006307920` capturé (dates rendues en millisecondes, minuit UTC ; code rangé sous `/codes/`), décision `ECLI:FR:CCASS:2018:C301117` capturée, constat de versions en sortie 3 — identifiants d'exemple des spécifications officielles |
| `req~detection-des-versions~1` | conforme | `src/versions.rs` : nouvelles versions et fin de vigueur postérieures à la date, « inchangé » sinon ; sortie 3 éprouvée par `versions_sort_en_3_quand_l_article_a_change` |
| `req~citation-ancree~2` | conforme | `src/recherche.rs` : tout élément passe la porte `Ancres::verdict` avant d'être rendu — écarté s'il ne porte aucun identifiant, s'il en cite un absent de `raw/`, ou si aucun texte cité n'est en vigueur à la date ; écarts journalisés sur la sortie d'erreur de `greffier chercher` ; un texte venu d'un modèle de langue se juge par `Ancres::verdict_texte` ; tests unitaires de `recherche.rs`, test d'intégration `un_element_sans_ancrage_est_journalise_et_jamais_rendu` ; `greffier banc` (`src/banc.rs`) rejoue la porte sur chaque élément rendu et sort en échec au premier non ancré |
| `req~moteur-separe-du-savoir~1` | conforme | `src/verifier.rs`, `greffier verifier` : rapport en lecture seule (test qui compare le dépôt avant et après), page citant un identifiant absent des sources brutes signalée et rapport en échec, programme ou dérivé versionné refusé, dérivé non suivi ignoré (`tests/verifier_itest.rs`) ; liens, orphelines, sur-connexion, index, journal ; dépôt de savoir réel vérifié sans constat le 2026-11-01 |
| `req~chaine-de-verification-du-moteur~1` | conforme | chaîne épinglée (`rust-toolchain.toml`, porte d'hygiène) ; en-têtes SPDX vérifiés par `tools/spdx.sh`, cas d'échec par `tools/spdx-test.sh` ; format, lints et tests dans la voie complète de `tools/ci.sh` et en CI GitHub |

## Écarts ouverts

Aucun.
