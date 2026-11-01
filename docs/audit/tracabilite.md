# Audit — traçabilité et vérification

Miroir de [`spec/02-exigences/tracabilite.md`](../../spec/02-exigences/tracabilite.md).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~tracabilite-outillee~1` | conforme | `tools/oft.sh` (jar épinglé par empreinte) ; `tools/socle-test.sh` prouve l'échec sur exigence orpheline **et** le retour au vert une fois le maillon posé |
| `req~porte-ci~2` | conforme | les deux façades délèguent à `tools/ci.sh`, qui joue toutes les portes de la voie et rend un bilan (ADR-0019) ; `tools/ci-test.sh` éprouve l'invariant sur son cas d'échec ; seuls les automatismes de forge sont non câblés, avec raison et échéance (méthode ch. 11) ; procédure `mtest~portes-cablees~1` |
| `req~garde-fous-locaux~1` | conforme | `.githooks/` et `tools/hooks/` ; le pre-commit rejoue la voie documentaire, le contournement `ALM_SKIP_HOOKS=1` est explicite et bruyant ; `tools/socle-test.sh` couvre trois refus et un passage |
| `req~tests-mecanises~1` | conforme | 100 % des exigences DOIT déclarent une vérification (`tools/classification.sh`) ; les non automatisables sont couvertes par `docs/verification-manuelle/` ; la vérité des tags relève de `mtest~pyramide-tests~1` |
| `req~exemple-multilangage~1` | conforme | `examples/demo-multi-langages/` — Python, Rust, shell, chaîne complète et tests tagués ; l'implémentation shell est exécutée par `tools/socle-test.sh` |
| `req~perimetre-constate~1` | conforme | `tools/perimetre.sh` et `tools/ci.sh` ; ADR-0017 ; `tools/perimetre-test.sh` couvre six cas dont quatre négatifs |
| `req~anti-derive-generes~1` | conforme | `tools/derive.sh`, double contrôle suivi-par-git puis régénération ; `tools/derive-test.sh` couvre le cas capital de l'artefact non versionné |
| `req~classification-exigences~2` | conforme | `tools/classification.sh` ; `tools/gouvernance-test.sh` couvre les cinq cas, dont le niveau emprunté au rationale, le mtest seul refusé sans report et le report par fiche qui nomme la dette |
| `req~audit-de-realisation~1` | conforme | ce document et ses six pairs ; `tools/audit.sh` ; ADR-0016 ; quatre cas d'échec dans `tools/gouvernance-test.sh` |
| `req~rattachement-code-exigence~1` | conforme | `tools/rattachement.sh`, câblée dans `tools/ci.sh` (voie documentaire) ; `tools/rattachement-test.sh` joue seize cas, dont neuf d'échec : fichier sans trace, matériel de `templates/` sans trace, mention inconnue, révision périmée malgré une mention valide, item défini en bloc de code ou dans un modèle, et trois fautes de la liste du code hérité ; `tools/init-test.sh` prouve la liste dressée à l'instanciation, la porte verte du projet produit puis rouge sur son premier fichier sans trace ; sept fichiers sans trace rattachés à la mise en place, une exigence manquante écrite (`req~kit-lint-markdown~1`) |

## Écarts ouverts

- Aucun.
