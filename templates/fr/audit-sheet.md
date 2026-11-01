# Audit — {{ domaine }}

<!-- Miroir de spec/02-exigences/{{ domaine }}.md. Les verdicts sont écrits À
     LA MAIN : c'est le jugement que la porte ne sait pas rendre. Le tableau
     de bord docs/audit/README.md, lui, est généré — ne pas l'éditer.
     Squelette des lignes manquantes :
       sh tools/audit.sh --squelette {{ domaine }} -->

Verdicts admis : `conforme` · `écart` · `non examiné`.

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~identifiant~1` | conforme | {{ fichier, porte ou test qui le montre }} |
| `req~autre~1` | écart | {{ en quoi le livré s'écarte de l'énoncé }} |
| `req~encore-une~1` | non examiné | |

<!-- Un « conforme » sans preuve est une affirmation, pas un audit.
     Un « écart » sans description est un constat inexploitable. -->

## Écarts ouverts

- {{ req~… — ce qui manque, et ce qui est décidé : correction, exigence à
     réviser, ou écart assumé avec son motif }}
