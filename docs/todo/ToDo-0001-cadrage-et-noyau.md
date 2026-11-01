# ToDo-0001 — Cadrage et noyau prouvé

**Statut : 🚧 en cours**

Poser ce qui fait Greffier avant toute ligne de code — les décisions
fondatrices, le domaine d'exigences « ancrage », la forme du dépôt de savoir
— puis livrer un noyau mesurable : une ligne de commande sur un dépôt de
savoir d'une dizaine de situations, un connecteur aux textes authentiques,
une recherche lexicale, une vérification des versions, un banc de questions.
Il existe parce que la valeur du moteur est dans une promesse (rien sans
source) qu'il faut prouver par un banc avant de l'exposer.

## Reste à faire

- Lot 0 — cadrage : ADR-0001 à ADR-0003 acceptés ; domaine « ancrage »
  actif (D-2026-11-04), six exigences approuvées (D-2026-11-05), dont
  deux à réaliser, deux proposées ; licence de contenu du savoir tranchée (fermée, utilisable
  par Pacilia) ; décisions restantes du porteur : modèle d'ingestion (local
  ou nuage, sources publiques), référents éditoriaux.
- Lot 1 — connecteur aux textes authentiques : livré, recette sur l'API de
  production faite le 2026-11-01 (article, décision, versions). Restent :
  conserver la structure en paragraphes (le champ `texte` de Légifrance
  l'aplatit, `texteHtml` la porte) ; vérifier l'adresse publique d'un
  article hors code (`loda`) sur un premier texte réel de ce type.
- Lot 2 — vérification livrée : `greffier verifier` (lecture seule) ; le
  dépôt de savoir réel passe sans constat. Reste la première dizaine de
  situations, qui attend deux préalables : la capture des textes cités
  (application PISTE du porteur) et des référents nommés pour valider les
  ingestions. Liste candidate, à arbitrer par un référent : arbres et
  plantations du voisin ; bruit et troubles anormaux de voisinage ; clôture
  et mitoyenneté ; servitude de passage ; malfaçons d'un artisan ; produit
  défectueux et garantie légale de conformité ; vente entre particuliers et
  vices cachés ; dépôt de garantie en fin de bail ; réparations et charges
  locatives ; petite créance entre particuliers. Puis vérification jouée en
  intégration continue du dépôt de savoir.
- Lot 3 — recherche lexicale sur les deux couches, filtre par date en
  vigueur, banc de questions (rappel, précision, délai, zéro élément non
  ancré).
- Lot 4 — exposition : serveur MCP, API HTTP ; vecteurs quantifiés sur la
  couche des situations seulement si le banc le justifie.

## Renvois

- Exigences : req~citation-ancree~1, req~textes-authentiques-versionnes~1,
  req~capture-des-sources-officielles~1, req~detection-des-versions~1,
  req~chaine-de-verification-du-moteur~1,
  req~moteur-separe-du-savoir~1, req~peremption-par-version~1,
  req~cloisonnement-du-savoir~1
- Décisions : ADR-0001, ADR-0002, ADR-0003, D-2026-11-02, D-2026-11-03,
  D-2026-11-04, D-2026-11-05
- Issues : —
