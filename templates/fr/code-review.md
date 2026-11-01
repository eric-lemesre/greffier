# Revue de code — {{ branche ou exigence }} — AAAA-MM-JJ

<!-- À archiver dans docs/revues/. Le relecteur est un pair humain ou un
     modèle IA différent de celui qui a produit le code. -->

- **Périmètre** : {{ diff revu, exigences concernées }}
- **Relecteur** : {{ humain, ou modèle utilisé }}
- **Verdict global** : {{ approuvé / approuvé avec réserves / refusé }}

## Constats

| # | Sévérité | Constat | Verdict | Résolution |
| --- | --- | --- | --- | --- |
| 1 | haute / moyenne / basse | {{ description, fichier:ligne }} | Corrigé / Rejeté | {{ commit, ou motif du rejet }} |

<!-- Règles : aucun constat sans réponse ; sévérité haute corrigée dans la
     même branche avant fusion ; les leçons générales sont promues en règle
     (porte mécanique ou contrat d'agents) avec référence à cette revue. -->

## Points vérifiés hors constats

- Conformité EARS des exigences nouvelles ou modifiées : {{ ok / n-a }}
- Absence de tag de complaisance (le code tagué réalise l'exigence) : {{ ok }}
- Niveau de test conforme au Needs déclaré : {{ ok }}
