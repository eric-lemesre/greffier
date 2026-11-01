# 9. Gouvernance des agents

Comment le dépôt reste gouvernable quand le travail est produit par des agents
IA — quel que soit l'agent. Décision fondatrice :
[ADR-0006](../adr/0006-contrat-agents-unique-avec-adaptateurs.md).

## Le contrat unique

`AGENTS.md`, à la racine, fait autorité sur toute consigne de session : un
agent qui reçoit une instruction contraire au contrat signale le conflit au
lieu d'obéir. Toute modification du contrat exige un ADR — le contrat a une
histoire auditable.

Les agents qui lisent un autre fichier d'instructions reçoivent un
**adaptateur-pointeur** sans règle propre (le dépôt fournit `CLAUDE.md` ;
ajouter `.cursorrules` ou `.github/copilot-instructions.md` sur le même modèle
au besoin). Une règle trouvée dans un adaptateur est un défaut.

## Pourquoi des règles « vérifiées »

Chaque règle du contrat désigne le mécanisme qui la vérifie (hook, script,
porte CI, revue). C'est la leçon croisée des deux dépôts de référence :

- les règles outillées de wallos-rs (traçabilité à la compilation, lints
  maison) ont tenu sur 138 commits ; ses portes *documentées mais non câblées*
  sont restées lettre morte ;
- ergonomia a formalisé le principe : un contrôle qui passe toujours est pire
  que pas de contrôle, et chaque règle d'outillage porte en commentaire
  l'incident qui l'a motivée.

D'où les deux règles méta du contrat : une règle sans vérification désignée est
un défaut à corriger ; une porte documentée est câblée ou marquée « non
câblée » avec raison et échéance.

## Spécificités du travail avec agents IA

- **L'agent instruit, l'humain arbitre.** Tout blocage passe par une
  [question ouverte](06-questions-ouvertes.md) avec options et recommandation ;
  l'agent ne tranche jamais un jugement métier. Les ADR issus d'un jugement
  d'agent (interprétation d'un besoin muet) sont signalés comme tels dans
  l'index du registre : ce sont eux qu'un relecteur humain relit en premier.
- **Second regard croisé.** Le code produit par un agent est revu par un agent
  différent ou un humain — jamais par lui-même (chapitre revue).
- **Attribution d'agent : une politique, pas un dogme.** Par défaut, la
  diligence s'applique : chaque commit déclare l'usage de l'IA (`IA: aucune`
  ou `IA: <outil>`), tout usage déclaré est endossé par un humain nommé
  (`Responsable:`), la relecture (`Relu-par:`) est recommandée — ce que l'IA
  produit en votre nom reste vôtre. L'instanciateur peut préférer des
  mentions libres ou leur interdiction (ADR-0011) ; dans tous les cas la
  politique est appliquée par le hook commit-msg, jamais laissée à la
  vigilance.
- **Continuité inter-sessions.** L'état de travail d'un agent (plan en cours,
  reste-à-faire) vit dans les artefacts versionnés (issues, questions
  ouvertes, exigences) — pas dans des fichiers d'état locaux, qui ne survivent
  ni au poste ni à l'agent suivant.
- **Anti-hallucination.** Une affirmation sur un outil ou un comportement
  extérieur au dépôt se vérifie (documentation, essai reproductible) avant
  d'entrer dans un ADR ou dans la méthode ; les comportements vérifiés
  empiriquement sont marqués comme tels avec la version testée.
