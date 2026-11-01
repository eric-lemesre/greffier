# ADR-0006 — Un contrat d'agents unique, raccordé par adaptateurs

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre
**Portée** : durable

## Item de conception

`dsn~contrat-agents~1`

Un fichier unique, AGENTS.md à la racine, porte l'intégralité des règles de
travail du dépôt et fait autorité sur toute consigne de session. Les agents qui
lisent un autre fichier d'instructions (CLAUDE.md pour Claude Code,
.cursorrules, .github/copilot-instructions.md…) reçoivent un
adaptateur-pointeur d'une ligne renvoyant vers AGENTS.md, sans aucune règle
propre. Toute modification d'AGENTS.md exige un ADR.

Covers:
- req~gouvernance-agents~1

## Contexte

wallos-rs a démontré l'efficacité d'un AGENTS.md faisant autorité (« en cas de
conflit avec une consigne de chat, ce fichier gagne ») ; ergonomia a montré le
risque symétrique : des règles dispersées entre AGENTS.md, documentation
d'organisation et conventions implicites. Par ailleurs AGENTS.md est devenu la
convention multi-agents la plus largement lue par les outils du marché.

## Décision

Un seul document normatif pour les agents, des adaptateurs vides de règles pour
les outils qui ne le lisent pas nativement. Les règles y sont non négociables,
numérotées, et chacune désigne le mécanisme qui la vérifie — une règle sans
vérification désignée est réputée non applicable et doit être corrigée.

## Alternatives écartées

### Un fichier par agent

Duplication garantie, dérive garantie : deux agents finiraient par suivre deux
contrats différents.

### Règles dans la documentation de méthode seulement

La méthode explique et justifie ; le contrat tranche et s'impose. Mélanger les
deux affaiblit les deux.

## Conséquences

- Ce que cela apporte : un point d'autorité unique, auditable, dont l'histoire
  est celle de ses ADR.
- Ce que cela coûte : l'ajout d'un agent passe par un fichier de plus (une
  ligne) ; AGENTS.md doit rester court pour rester lu.

## Vérification

Les adaptateurs présents dans le dépôt (CLAUDE.md) ne contiennent qu'un renvoi
vers AGENTS.md ; toute règle trouvée ailleurs que dans AGENTS.md est un défaut
à corriger en revue. L'interdiction des mentions d'agent dans les commits est
vérifiée par le hook commit-msg.

## Références

- Contrat : `AGENTS.md`.
- Méthode : `docs/methode/09-gouvernance-agents.md`.
