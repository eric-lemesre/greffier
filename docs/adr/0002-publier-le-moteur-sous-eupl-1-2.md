# ADR-0002 — Publier le moteur sous la licence publique de l'Union européenne (EUPL 1.2)

**Statut** : Accepté
**Date** : 2026-11-01
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-03 au registre
**Portée** : durable

## Contexte

La promesse de Greffier — rien n'est affirmé sans source, et le modèle n'est
jamais dans la boucle de citation — ne vaut que si on peut la vérifier. Le
public visé (conciliateurs bénévoles, associations, services publics
locaux) n'achète pas de logiciel et préfère le libre ; les acheteurs publics
français y ont une préférence réglementaire. La valeur économique n'est pas
dans le moteur mais dans le savoir validé et dans le service (hébergement,
curation, intégration). Le choix de licence est irréversible pour ce qui est
déjà publié.

## Décision

Le moteur est publié sous **EUPL 1.2** (European Union Public Licence), dans
un dépôt public. Le texte de la licence est le fichier `LICENSE` (version
anglaise, qui fait foi dans toutes les langues de l'Union). Le dépôt de
savoir est un objet distinct, dont la licence de contenu se décide à part.

## Alternatives écartées

### Apache 2.0 ou MIT (permissives)

Adoption maximale, y compris par des acteurs qui exploitent le moteur en
service sans rien redonner. Pour un outil dont la valeur se concentre dans
le service, une licence à partage à l'identique protège mieux le travail.

### AGPL 3.0

Même protection que l'EUPL sur l'usage en service, mais licence d'origine
américaine, moins bien reçue par les acheteurs publics européens, et sans la
clause de compatibilité qui permet à l'EUPL de se combiner avec Apache, GPL
et d'autres.

### Propriétaire

Incompatible avec la vérifiabilité qui fait le produit, et avec l'adoption
par la cible.

## Conséquences

- Ce que cela apporte : l'auditabilité de la chaîne d'ancrage ; l'entrée
  dans les structures publiques ; les contributions reviennent au tronc
  commun ; cohérence avec des sources elles-mêmes sous licence ouverte.
- Ce que cela coûte : maintenir en public (versions, compatibilité, issues) ;
  répondre aux questions de compatibilité de licence des intégrateurs.
- Ce que cela ferme : le retour à une licence fermée pour le code déjà
  publié.

## Vérification

- `LICENSE` contient le texte officiel de l'EUPL 1.2 ; la porte des badges
  (`tools/badges.sh`) lit la licence depuis le README et doit afficher
  « EUPL ».
- Tout fichier de code portera l'en-tête SPDX `EUPL-1.2` ; une porte le
  vérifiera dès le premier fichier de code (à câbler avec lui, R7).

## Références

- <https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12>
- ADR-0001 (séparation moteur / savoir).
