# Besoin — Une recherche juridique dont on peut vérifier chaque élément

Porteur : Eric Lemesre. Sources : l'expérience d'un outil de conciliation de
justice (2026) dont la recherche juridique reste adossée à un catalogue
faute de source documentaire ; le motif « LLM wiki » (Karpathy, 2026-04) et
le retour d'expérience « Construire votre second cerveau » (2026-04).

## Trouver la règle applicable à une situation, avec sa source

`feat~recherche-ancree~1`

En tant que praticien de l'amiable (conciliateur, médiateur, agent d'un
service d'accès au droit), je veux poser une question dans les mots de la
vie courante et obtenir les textes et décisions applicables, chacun avec
son identifiant officiel, sa version en vigueur et un lien vers la source,
afin de préparer un entretien ou une séance sans risquer de m'appuyer sur
une référence inventée.

Rationale:
Un modèle de langue qui cite invente, et le lecteur ne peut pas le voir ;
seul un élément rattaché à un texte authentique est vérifiable d'un clic.
Le vocabulaire du justiciable n'est pas celui du droit : la recherche doit
faire le pont.

Needs: req

## Tenir un savoir de situations à plusieurs, sans le laisser dériver

`feat~savoir-de-situations~1`

En tant que référent d'une communauté de praticiens, je veux que le savoir
de pratique (ce qui marche en séance, les pièces utiles, les issues
amiables typiques d'une situation) soit compilé page par page à partir de
sources que nous proposons, que je valide chaque ingestion, et que les
pages se périment d'elles-mêmes quand un texte cité change, afin que ce
savoir reste vrai sans que son entretien repose sur une seule personne.

Rationale:
Les wikis d'équipe meurent de leur coût d'entretien ; un agent peut porter
la compilation et la cohérence, à condition qu'un humain garde le jugement
et que les contradictions entre sources restent visibles.

Needs: req

## Servir de source documentaire à un agent logiciel

`feat~source-pour-agents~1`

En tant qu'intégrateur d'un outil métier ou d'un assistant, je veux
brancher mon agent sur une source juridique qu'il interroge comme un outil
(serveur MCP, API HTTP, ligne de commande), afin qu'il cesse de citer de
mémoire et rende des éléments sourcés que mon utilisateur peut vérifier.

Rationale:
L'ancrage ne vaut que s'il est disponible là où l'agent répond ; un moteur
séparé du savoir, avec des interfaces standard, sert plusieurs outils et
plusieurs communautés.

Needs: req
