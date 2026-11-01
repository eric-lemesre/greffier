# Modélisation des menaces — {{ exigence ou flux }} — AAAA-MM-JJ

<!-- Format court (30-60 min, en équipe). Obligatoire pour les exigences de
     niveau S et toute nouvelle frontière de données (méthode, ch. 10).
     Débouché obligatoire : les menaces retenues deviennent des critères
     d'acceptation de l'exigence. -->

- **Exigence(s) concernée(s)** : {{ req~identifiant~n }}
- **Participants** : {{ noms }}

## Le flux

{{ Composants, données échangées, limites de confiance — trois phrases ou un
schéma. Qu'est-ce qui entre, qu'est-ce qui sort, qui a le droit de parler à
qui ? }}

## Menaces examinées (STRIDE)

| Catégorie | Menace identifiée | Priorité | Décision |
| --- | --- | --- | --- |
| S — usurpation | {{ … ou « rien d'identifié » }} | critique/élevée/moyenne/faible | critère d'acceptation / mitigation ADR / risque accepté |
| T — altération | {{ … }} | | |
| R — répudiation | {{ … }} | | |
| I — exposition | {{ … }} | | |
| D — indisponibilité | {{ … }} | | |
| E — escalade | {{ … }} | | |

## Débouchés

- Critères d'acceptation ajoutés à {{ req~identifiant~n }} : {{ lister }}
- Décisions structurantes à acter : {{ ADR à ouvrir, ou aucune }}
- Risques acceptés : {{ renvoi vers l'exception versionnée, ou aucun }}
