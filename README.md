# Greffier

**Moteur de recherche juridique ancrée. Il tient le registre, il ne juge
pas.**

[English summary](README.en.md)

Greffier répond à une question de droit français par des éléments **tous
rattachés à un texte authentique** : un article de code ou une décision,
identifiés par leur identifiant officiel (`LEGIARTI…`, `ECLI…`) et par leur
version en vigueur. Il ne demande jamais à un modèle de langue de citer un
texte, parce qu'un modèle qui cite invente, et que son lecteur ne peut pas
s'en apercevoir.

Il s'adresse à celles et ceux qui ont besoin de *la règle applicable à une
situation de la vie courante* sans être juristes de métier : conciliateurs
et médiateurs, maisons de justice et du droit, associations, juristes
isolés, et aux agents logiciels qui ont besoin d'une source documentaire
plutôt que d'une mémoire.

## Trois couches

1. **Les textes authentiques** — source de vérité, jamais générés :
   articles et décisions, identifiés, versionnés dans le temps, texte
   intégral (Légifrance, Judilibre).
2. **Le wiki de situations et de pratique** — compilé par un agent-curateur
   sous un schéma juridique, relu par un référent humain : une page par
   situation type, reliée aux textes, aux pièces utiles, aux issues
   amiables ; il fait le pont entre les mots du justiciable et ceux du
   droit.
3. **La recherche** — lexicale d'abord, sémantique ensuite, sur les deux
   couches ; elle ne rend que des éléments ancrés. Le modèle de langue
   n'intervient qu'en reformulation de la question et en résumé d'extraits
   qu'il cite.

Le **moteur** (ce dépôt) et le **savoir** (un dépôt de texte : sources
brutes, pages compilées, schéma du curateur, banc de questions) sont
séparés. Le moteur lit un dépôt de savoir ; n'importe quelle communauté
peut tenir le sien.

## Quatre interfaces

| Interface          | Usage                                                                 |
| ------------------ | --------------------------------------------------------------------- |
| Serveur MCP        | la source documentaire de n'importe quel agent : il ne cite plus de mémoire |
| Ligne de commande  | `ingérer`, `chercher`, `vérifier`, `consulter` — les rituels du curateur |
| API HTTP           | l'intégration dans un outil métier                                    |
| Compétence d'agent | le mode d'emploi du curateur, pour un agent sans le moteur            |

## Ce que Greffier n'est pas

Ce n'est pas un conseil juridique : la consultation juridique est une
activité réglementée (loi n° 71-1130 du 31 décembre 1971, art. 54 et
suivants). Greffier fournit une **aide documentaire** sourcée et datée ; le
lecteur humain reste l'auteur de son appréciation. Aucune page, aucune
réponse ne conclut sur le fond d'un litige concret.

## État

Premier lot (novembre 2026) : les décisions fondatrices sont prises
([ADR-0001](docs/adr/0001-separer-le-moteur-du-savoir-et-ancrer-toute-citation.md),
[ADR-0002](docs/adr/0002-publier-le-moteur-sous-eupl-1-2.md),
[ADR-0003](docs/adr/0003-ecrire-le-moteur-en-rust-en-binaire-unique.md)),
les exigences sont en proposition (`spec/`), la feuille de route est dans
`docs/todo/`. Le binaire `greffier` (Rust) porte la couche des textes
authentiques : il capture un article Légifrance ou une décision Judilibre
par son identifiant officiel, le conserve, immuable et daté, dans le
dossier `raw/` d'un dépôt de savoir, et constate les changements de
version.

```sh
export GREFFIER_PISTE_CLIENT_ID=…  GREFFIER_PISTE_CLIENT_SECRET=…   # application PISTE
greffier capturer article LEGIARTI… --toutes-versions --savoir ../savoir
greffier capturer decision <identifiant Judilibre> --savoir ../savoir
greffier versions LEGIARTI… --depuis 2026-01-01      # sortie 3 si l'article a changé
greffier en-vigueur <cid> --le 2026-01-01 --savoir ../savoir   # hors ligne
greffier verifier --savoir ../savoir                  # lecture seule, sortie 1 si erreur
```

Les identifiants viennent d'une application enregistrée sur
[PISTE](https://piste.gouv.fr) (production et bac à sable — `--bac-a-sable`
— ont des identifiants distincts) ; ils ne sont jamais écrits ni affichés.

## Méthode

Le dépôt suit la méthode du gabarit ALM alm-forge : besoins tracés,
exigences EARS, décisions en ADR, traçabilité vérifiée par OpenFastTrace en
local et en CI (`docs/methode/`, contrat de travail : `AGENTS.md`).
Commandes : `just ci` (ou `sh tools/oft.sh trace && sh tools/checks.sh`).

Porteur : Eric Lemesre. Licence : [EUPL 1.2](LICENSE).
