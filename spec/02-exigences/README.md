# Exigences — index des domaines

Un fichier par domaine. Le **statut** de chaque domaine est un commutateur :
`ACTIVE` fait entrer ses exigences dans le dénominateur des taux d'audit et de
classification, `PROPOSITION` les en tient dehors le temps de l'arbitrage
(méthode, [ch. 13](../../docs/methode/13-statuts-de-specification.md)). L'index
et l'en-tête de chaque domaine doivent dire la même chose : `tools/statuts.sh`
refuse la divergence.

| Domaine | Statut | Avancement | Objet |
| --- | --- | --- | --- |
| [gouvernance](gouvernance.md) | ACTIVE | implémentée | contrat d'agents, instanciation, langue, forges, nettoyage, versionnement |
| [ingenierie-exigences](ingenierie-exigences.md) | ACTIVE | implémentée | besoin, EARS, cycle de vie d'une exigence, questions ouvertes |
| [tracabilite](tracabilite.md) | ACTIVE | implémentée | traçabilité outillée, portes, périmètre, dérive, classification, audit |
| [decisions](decisions.md) | ACTIVE | implémentée | registre ADR, vérification, relevés de séance, journaux |
| [documentation](documentation.md) | ACTIVE | implémentée | intégrité des liens, feuille de route, constats de revue, badges |
| [coordination-issues](coordination-issues.md) | ACTIVE | implémentée | état/attente/acte, flux, triage, conformité, automatismes de forge |
| [securite](securite.md) | ACTIVE | implémentée | sécurité continue, détection des secrets |
