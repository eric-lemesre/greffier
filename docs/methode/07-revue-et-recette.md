# 7. Revue et recette

Deux vérifications humaines complètent les portes mécaniques : la revue (le
code est-il juste et bien fait ?) et la recette (le produit répond-il au
besoin ?). Les portes mécaniques mesurent la présence ; la revue et la recette
mesurent la vérité.

## Revue de code

- Toute pull request est revue par un second regard : un pair humain, ou à
  défaut un second modèle IA **différent de celui qui a produit le code**
  (pratique éprouvée sur ergonomia et wallos-rs). L'auteur ne s'auto-approuve
  pas.
- La revue vérifie en particulier ce que l'outil ne voit pas : conformité EARS
  des exigences nouvelles, tags de complaisance, qualité des alternatives dans
  les ADR, pertinence du niveau de test choisi.
- Les conclusions sont archivées dans `docs/revues/` (modèle
  `templates/fr/code-review.md`) : chaque constat est trié — **Corrigé** ou
  **Rejeté avec motif** — jamais laissé sans réponse. Les anomalies de sévérité
  haute se corrigent dans la même branche, avant fusion.
- Les leçons de revue qui deviennent des règles sont promues : en porte
  mécanique si outillables, sinon dans le contrat d'agents, avec référence à la
  revue d'origine en commentaire de la règle.

## Le suivi consolidé des constats

<!-- [impl->req~suivi-constats-revue~1] -->

Les constats vivent dispersés, une fiche par branche dans `docs/revues/` ;
passée la fusion, plus personne ne les rouvre. `tools/revues.sh --ecrire`
les rassemble dans `docs/revues/SUIVI.md`, généré et protégé par l'anti-dérive.

La règle « sévérité haute corrigée avant fusion » n'est plus une phrase : la
porte **échoue** tant qu'un constat de sévérité haute n'a pas de verdict. Un
rejet motivé est une réponse valable — ce qui est refusé, c'est le silence.

## Recette

- La recette confronte le livrable aux **critères d'acceptation** des exigences
  livrées, par les rôles concernés (métier, produit, technique) — chacun valide
  son regard, la validation finale exige tous les regards. Le parcours d'issue
  qui l'encadre (étiquettes, fins de vie) est décrit au
  [chapitre 11](11-cycle-de-vie-issues.md).
- Une validation est nominative et horodatée (commentaire d'issue ou relevé) ;
  une validation tacite n'existe pas.
- **Sortie négative documentée** : un refus de recette retire les validations
  acquises et laisse une trace du motif ; on ne « re-valide » pas par-dessus un
  refus sans nouvelle recette complète.
- Ce qui est constaté en recette et n'était pas dans les exigences devient :
  une exigence nouvelle (si c'est un manque), ou une question ouverte (si c'est
  un arbitrage).

## Definition of Done

Une exigence est terminée quand — dans l'ordre :

1. son texte est approuvé (EARS, critères d'acceptation, Covers vers le
   besoin — et, pour le niveau d'enjeu S, menaces STRIDE examinées et
   reportées en critères, méthode ch. 10) ;
2. les décisions qu'elle appelait sont actées en ADR ;
3. l'implémentation est taguée et la traçabilité passe ;
4. les tests du niveau déclaré sont tagués et passent ;
5. la revue est archivée et ses constats sont soldés ;
6. le journal des changements mentionne le changement visible.
