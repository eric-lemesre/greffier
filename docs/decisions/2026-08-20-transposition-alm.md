# Relevé — transposition des mécaniques ALM d'ergonomia — 2026-08-20

- **Décideur** : Éric Lemesre (porteur du gabarit) — consultation directe.
- **Objet** : porter dans le gabarit les mécaniques éprouvées sur ergonomia et
  absentes de la fondation, en rendant leur vocabulaire bilingue.

## Contexte

L'inventaire comparé des deux dépôts a montré seize mécaniques présentes sur
ergonomia et absentes du gabarit — sept portes locales, cinq concepts de
méthode, quatre éléments de gouvernance des issues. Deux d'entre elles
comblaient un trou déclaré du gabarit : la règle R8 (« un artefact généré ne
s'édite jamais à la main ») n'avait aucun outil, et la règle du chapitre 7
(« sévérité haute corrigée avant fusion ») aucune porte.

## Relevé de décisions

- **D-2026-08-13** — le vocabulaire outillé est bilingue et figé à
  l'instanciation, dans un lexique unique dont toutes les portes sont
  clientes. Aucun terme d'état, de verdict ou d'étiquette n'est écrit en dur
  dans une porte. Développé par l'ADR-0015.
- **D-2026-08-14** — l'audit de réalisation devient une porte à part entière,
  distincte de la traçabilité : la traçabilité mesure la présence, l'audit
  mesure la vérité. Le générateur compte, l'humain juge. Développé par
  l'ADR-0016.
- **D-2026-08-15** — le périmètre de la porte est constaté sur le changement
  réel (commits, index, arbre, fichiers non suivis), jamais déclaré ; tout
  doute impose la voie complète. Développé par l'ADR-0017.
- **D-2026-08-16** — les sept domaines de spécification du gabarit passent
  ACTIVE : gouvernance, tracabilite, decisions, ingenierie-exigences,
  securite, coordination-issues, documentation.

## Points restés ouverts

- Aucun. Les automatismes de forge sont livrés en matériel prêt à câbler et
  non câblés dans le gabarit, avec leur raison — voir la méthode, ch. 11.
