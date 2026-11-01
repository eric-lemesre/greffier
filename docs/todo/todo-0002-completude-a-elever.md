# ToDo-0002 — Complétude : exigences à élever

**Statut : 🚧 en cours**

La porte de classification (révision `~2` de `req~classification-exigences~2`)
fait désormais **échouer** la voie sur toute exigence DOIT/DEVRAIT couverte
par une vérification manuelle seule, sauf report explicite par une fiche de
la feuille de route — cette fiche. Un signal qu'on peut ignorer sans trace
finit ignoré : le report transforme « ne pas prendre en compte » en acte
écrit, et la porte nomme chaque dette à chaque passage.

Chaque ligne appelle un **arbitrage du mainteneur** : écrire le test
mécanisé (utest/itest/stest), ou assumer la vérification manuelle
durablement — le motif remplace alors « arbitrage à rendre » et le marqueur
reste, dette assumée à voix haute.

## Les exigences reportées

- `req~issues-etat-attente-acte~2` (à élever : arbitrage à rendre — la
  vérification observe une forge distante, la mécanisation demande un bouchon)
- `req~issues-flux-avancement~2` (à élever : arbitrage à rendre — même
  dépendance à la forge distante)
- `req~issues-triage-priorites~2` (à élever : arbitrage à rendre — même
  dépendance à la forge distante)
- `req~conformite-issues~1` (à élever : arbitrage à rendre — même dépendance
  à la forge distante)
- `req~automatismes-forge~1` (à élever : arbitrage à rendre — même
  dépendance à la forge distante)
- `req~gouvernance-agents~1` (à élever : arbitrage à rendre — la conformité
  d'un contrat de travail se lit, une part seulement se mécanise)
- `req~expression-du-besoin~1` (à élever : arbitrage à rendre — la qualité
  d'un besoin rédigé résiste à l'automatisation)
- `req~questions-ouvertes~1` (à élever : arbitrage à rendre — le registre se
  vérifie en partie, le fond reste une lecture)
- `req~securite-continue~1` (à élever : arbitrage à rendre — l'outillage de
  sécurité varie par instanciation)
- `req~tests-mecanises~1` (à élever : arbitrage à rendre — l'exigence parle
  du parc de tests lui-même, sa preuve mécanisée reste à concevoir)

## Reste à faire

- Les dix arbitrages : chaque ligne finit soit en test mécanisé écrit (le
  marqueur tombe), soit en vérification manuelle assumée avec son motif
  définitif consigné ici.
