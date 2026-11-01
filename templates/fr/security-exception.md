# Exception de sécurité — {{ identifiant CVE / constat }} — AAAA-MM-JJ

<!-- Une acceptation de risque est explicite, versionnée, portée et datée —
     jamais tacite (méthode, ch. 10). Utiliser le format natif de l'outil
     quand il existe (ignore-list d'audit, .gitleaks.toml) avec renvoi vers
     cette fiche pour la justification complète. -->

- **Objet** : {{ CVE-AAAA-NNNN, constat de scan, ou faux positif }}
- **Composant concerné** : {{ dépendance et version, fichier }}
- **Sévérité annoncée** : {{ critique / haute / moyenne / basse }}

## Justification

{{ Pourquoi le risque est acceptable ICI : fonction vulnérable non utilisée,
composant non exposé, contrôle compensatoire en place… Une phrase « on verra
plus tard » n'est pas une justification. }}

## Portage

- **Responsable** : {{ nom — la personne qui répond de ce risque }}
- **Échéance de réexamen** : {{ AAAA-MM-JJ — obligatoire ; une exception sans
  échéance est une dette invisible }}
- **Condition de levée** : {{ correctif publié, montée de version, retrait du
  composant… }}
