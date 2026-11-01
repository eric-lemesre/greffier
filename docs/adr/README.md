# Registre des décisions d'architecture (ADR)

<!-- [impl->req~registre-adr~1] -->

Une décision d'architecture est un choix justifié qui répond à une exigence
fonctionnelle ou non fonctionnelle de portée structurante. Chaque décision est
consignée dans un ADR : un fichier, une décision, sa motivation, ses
alternatives écartées et son moyen de vérification.

## Quand écrire un ADR

- Le choix engage la structure, la sécurité, les données, l'outillage ou la
  méthode, et coûterait cher à défaire.
- Le choix tranche entre plusieurs options défendables : les alternatives
  écartées doivent survivre à la discussion.
- Le choix interprète un besoin ambigu : l'ADR matérialise le jugement rendu et
  renvoie à la question ouverte qui l'a soulevé.

Ce qui n'est **pas** un ADR : le contenu d'une spécification (il vit dans
`spec/`), la coordination d'un chantier (elle vit dans les issues), le
compte-rendu d'une séance (il vit dans `docs/decisions/`).

## Conventions

- Fichier `NNNN-titre-en-kebab-case.md`, numérotation continue, jamais
  réutilisée : un ADR rejeté consomme son numéro.
- Titre : la décision formulée à l'infinitif.
- Modèle : [`templates/fr/adr.md`](../../templates/fr/adr.md) (dérivé de MADR
  4.0, enrichi de la section Vérification).
- **Un ADR accepté ne se modifie pas.** On écrit un nouvel ADR qui le
  remplace ; l'ancien passe au statut « Remplacé par ADR-XXXX ».
- La section **Vérification** est obligatoire pour tout ADR accepté : une
  décision qu'aucun mécanisme ne protège dérivera. Ce point est contrôlé par
  les portes qualité (`task check`).
- Quand la décision répond à une exigence tracée, l'ADR porte un item de
  conception OpenFastTrace (type dsn) qui couvre l'exigence : la décision entre
  ainsi dans la matrice de traçabilité.

## Cycle de vie

```text
Proposé ──▶ Accepté ──▶ Déprécié
   │                       ▲
   └──▶ Rejeté             └── Remplacé par ADR-XXXX
```

## Niveaux d'enjeu et cérémonie

| Niveau | Nature | Circuit |
| --- | --- | --- |
| S — structurant | irréversible, sécurité, réglementaire, données | séance + relevé de décision, puis ADR |
| F — fonctionnel | arbitrage de conception courant | consultation asynchrone, décision du responsable de domaine |
| É — éditorial | reformulation, outillage mineur | simple pull request |

## Index

| ADR | Titre | Statut |
| --- | --- | --- |
| [0001](0001-structurer-alm-forge-en-depot-gabarit.md) | Structurer alm-forge en dépôt-gabarit instanciable | Accepté |
| [0002](0002-tracer-les-exigences-avec-openfasttrace.md) | Tracer les exigences avec OpenFastTrace | Accepté |
| [0003](0003-structurer-les-adr-sur-madr-avec-verification.md) | Structurer les ADR sur MADR avec section Vérification | Accepté |
| [0004](0004-rediger-les-exigences-selon-ears.md) | Rédiger les exigences selon la syntaxe EARS | Accepté |
| [0005](0005-documentation-normative-francaise-templates-bilingues.md) | Documentation normative en français, templates bilingues | Accepté |
| [0006](0006-contrat-agents-unique-avec-adaptateurs.md) | Un contrat d'agents unique, raccordé par adaptateurs | Accepté |
| [0007](0007-orchestrateur-en-facade-interchangeable.md) | Séparer les portes de l'orchestrateur, façade interchangeable | Accepté |
| [0008](0008-attribution-agents-arbitree-a-l-instanciation.md) | Rendre la politique d'attribution des agents arbitrable à l'instanciation | Remplacé par 0011 |
| [0009](0009-langue-du-depot-arbitree-a-l-instanciation.md) | Rendre la langue du dépôt arbitrable à l'instanciation | Accepté |
| [0010](0010-ci-en-facades-par-forge.md) | Porter la CI en façades de délégation par forge | Accepté |
| [0011](0011-declaration-ia-obligatoire-par-defaut.md) | Exiger par défaut la déclaration d'usage de l'IA dans chaque commit | Accepté |
| [0012](0012-detecter-les-secrets-avec-gitleaks.md) | Détecter les secrets avec gitleaks, bloquant en CI, signalant en local | Accepté |
| [0013](0013-cycle-de-vie-issues-arbitre-a-l-instanciation.md) | Rendre le cycle de vie des issues arbitrable à l'instanciation | Accepté |
| [0014](0014-bootstrap-consenti-et-modulaire.md) | Rendre le bootstrap consenti, modulaire et auto-installant | Accepté |
| [0015](0015-lexique-du-vocabulaire-outille.md) | Rassembler le vocabulaire outillé dans un lexique bilingue | Accepté |
| [0016](0016-audit-de-realisation-distinct-de-la-tracabilite.md) | Séparer l'audit de réalisation de la traçabilité | Accepté |
| [0017](0017-perimetre-de-la-porte-constate.md) | Constater le périmètre de la porte plutôt que le déclarer | Accepté |
| [0018](0018-statut-de-cycle-de-vie-porte-par-l-exigence.md) | Porter le statut de cycle de vie au niveau de l'exigence | Accepté |
| [0019](0019-jouer-toutes-les-portes-et-rendre-un-bilan.md) | Jouer toutes les portes et rendre un bilan | Accepté |
