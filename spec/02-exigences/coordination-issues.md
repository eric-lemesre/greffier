# Exigences — domaine coordination par les issues

**Statut : ACTIVE** — domaine acté le 2026-08-20 (D-2026-08-16). Le statut commande
le dénominateur des taux d'audit et de classification (méthode, ch. 13).

Deux couches, arbitrées par l'ADR-0013 : un socle invariant (l'état,
l'attente, l'acte) et des défauts que l'instanciateur adopte, adapte ou
réduit — en consignant son arbitrage au registre des décisions du projet.

## L'état, l'attente, l'acte — socle invariant

`req~issues-etat-attente-acte~2`

**Statut : approuvée**

Sur une issue, les trois artefacts de coordination DOIVENT garder des rôles
distincts et jamais échangés : l'étiquette porte l'**état** (où en est
l'issue), l'assignation porte l'**attente** (de qui le prochain geste dépend),
le commentaire signé et daté porte l'**acte** (constat, lecture, validation,
décision) et fait seul foi. Aucune étiquette ne DOIT porter d'information
nominative, toute transition d'état DOIT être motivée par un commentaire, et
un automatisme ne DOIT que dériver l'état depuis un acte écrit — jamais
attester à la place de quelqu'un. Cette règle est le socle invariant du cycle
de vie des issues : elle s'applique à tout projet instancié, quel que soit
l'arbitrage rendu sur les défauts (ADR-0013).

Rationale:
Une étiquette ne porte ni date, ni version, ni auteur : ce qu'elle affirme ne
se prouve pas. Leçon d'ergonomia : les étiquettes nominatives « Validé par … »
ont dû être remplacées par des commentaires de validation, seuls artefacts
signés, datés et citant la version. Le socle fonde l'opposabilité des actes ;
il ne dépend ni de l'équipe, ni du rythme, ni de la forge — c'est pourquoi il
n'est pas arbitrable.

Critères d'acceptation :

- Étant donné une validation de recette, quand elle est consignée, alors
  c'est un commentaire citant la version testée — jamais une étiquette
  nominative ni une case cochée seule.
- Étant donné une issue dont l'étiquette d'étape change, quand aucun
  commentaire ne motive la transition, alors la revue le signale comme défaut.
- Étant donné un automatisme de forge, quand il agit sur une issue, alors il
  pose ou retire étiquettes et assignations à partir d'un commentaire
  existant, sans jamais produire l'acte lui-même.
- Étant donné un arbitrage d'instanciation réduisant les défauts du cycle de
  vie, quand il est rendu, alors le socle reste appliqué tel quel.

Covers:
- feat~coordination-issues~1

Needs: dsn, impl, mtest

## Trois flux, une taxonomie d'avancement — défaut arbitrable

`req~issues-flux-avancement~2`

**Statut : approuvée**

Quand un projet est instancié depuis le gabarit, les flux de coordination et
le jeu d'étiquettes DOIVENT être arbitrés par l'instanciateur — adoption,
adaptation ou réduction — et consignés au registre des décisions du projet.
Si aucun choix explicite n'est exprimé, alors le défaut du gabarit DOIT
s'appliquer : trois flux — arbitrage d'une spécification (`[Spec]`),
arbitrage d'un document d'organisation (`[Orga]`), réalisation d'une demande
ou d'une anomalie (`[Feature]`/`[Bug]`) — partageant une même taxonomie
d'avancement scindée en **étapes** (une seule à la fois), **entraves**
(cumulables) et **sorties** (une seule, terminale) ; toute fin de vie autre
que la livraison recettée fermée « non planifiée » avec son motif en
commentaire ; une demande ventilée en exigences recevant l'étape
correspondante au lieu de rester indéfiniment en discussion.

Rationale:
Les flux d'arbitrage supposent des consultés et le jeu d'étiquettes une
équipe : ces choix reviennent à l'instanciateur (ADR-0013). Le défaut, lui,
reste structuré : mélanger étapes et entraves rend la règle « un seul état à
la fois » intenable, et ne pas distinguer les fins de vie oblige à relire
chaque issue fermée pour savoir pourquoi.

Critères d'acceptation :

- Étant donné une instanciation sans choix exprimé, quand le projet démarre,
  alors le défaut du chapitre 11 s'applique tel quel.
- Étant donné un arbitrage réduisant les flux (par exemple un porteur solo
  sans consultation), quand il est rendu, alors il est consigné au registre
  des décisions du projet instancié.
- Étant donné une issue ouverte sous le défaut, quand on lit ses étiquettes,
  alors elle porte au plus une étape, autant d'entraves que la réalité en
  impose, et aucune sortie.
- Étant donné une demande ventilée en exigences dans `spec/`, quand la
  ventilation est faite, alors l'issue quitte l'étape de discussion et un
  commentaire liste les identifiants créés.
- Étant donné une anomalie non reproduite, quand elle est fermée, alors la
  fermeture est « non planifiée » et le commentaire dit ce qui a été essayé
  et avec quelle version.
- Étant donné une régression, quand son correctif est recetté, alors un test
  de non-régression l'accompagne.

Covers:
- feat~coordination-issues~1

Needs: dsn, impl, mtest

## La gravité se constate, la priorité se décide — défaut arbitrable

`req~issues-triage-priorites~2`

**Statut : approuvée**

Quand un projet est instancié depuis le gabarit, la grille de triage DOIT
être arbitrée par l'instanciateur et consignée au registre des décisions du
projet. Si aucun choix explicite n'est exprimé, alors le défaut du gabarit
DOIT s'appliquer : la gravité d'une anomalie constatée par le déclarant dans
le formulaire (critique, gênant, mineur) ; la priorité décidée au triage,
jamais demandée à la création, sur une échelle temporelle (P1 : avant tout le
reste ; P2 : ce jalon ou le suivant ; P3 : un jour) ; une limite de cinq
issues en P1 — la dépasser fait redescendre une autre issue, motif en
commentaire.

Rationale:
La limite de P1 et la cadence de triage dépendent de la capacité de l'équipe :
elles s'arbitrent à l'instanciation (ADR-0013). Le principe du défaut, lui,
est éprouvé : une priorité définie par le domaine (« sécurité,
réglementaire ») finit par tout qualifier et ne classe rien ; définie par le
rang et bornée en nombre, elle redevient un choix. Constat fondateur sur
ergonomia : 21 issues sur 39 sans priorité, et du confort d'affichage en P1
pendant qu'un risque réel dormait en P2.

Critères d'acceptation :

- Étant donné une instanciation sans choix exprimé, quand une anomalie est
  déclarée, alors la gravité est renseignée dans le formulaire et aucune
  priorité n'est demandée au déclarant.
- Étant donné un arbitrage modifiant la limite de P1 ou l'échelle, quand il
  est rendu, alors il est consigné au registre des décisions du projet.
- Étant donné la limite de P1 atteinte, quand une issue supplémentaire doit
  passer en P1, alors une autre redescend et le commentaire dit laquelle et
  pourquoi.
- Étant donné un changement de priorité, quand il survient, alors son motif
  est écrit en commentaire.

Covers:
- feat~coordination-issues~1

Needs: dsn, impl, mtest

## Conformité des issues au processus

`req~conformite-issues~1`

**Statut : approuvée**

Le dépôt DEVRAIT fournir un contrôle de conformité des issues ouvertes au
cycle de vie déclaré — étiquette d'état unique, assignation présente quand
une attente existe, sortie négative motivée. Ce contrôle NE DOIT PAS être
câblé dans la porte de vérification : il dépend de l'API de la forge et d'une
session authentifiée, là où la porte reste reproductible hors ligne.

Rationale:
Transposé d'ergonomia, où le contrôle sert la revue de triage hebdomadaire et
non l'intégration continue. La séparation est délibérée : la porte vérifie le
dépôt, pas la conformité organisationnelle des issues, et rien de ce qui exige
un réseau n'entre dans une porte qui doit tourner sur un poste déconnecté.

Critères d'acceptation :

- Étant donné une issue portant deux étiquettes d'état, quand le contrôle
  s'exécute, alors il la signale.
- Étant donné l'absence de session authentifiée, quand le contrôle s'exécute,
  alors il s'interrompt avec un message explicite sans faire échouer la porte.

Covers:
- feat~coordination-issues~1

Needs: impl, mtest

## Automatismes de forge

`req~automatismes-forge~1`

**Statut : approuvée**

Les automatismes de coordination — accusé de lecture d'une consultation,
retombée des lectures quand le document consulté change, pose de l'étiquette
de clôture, rappel des recettes dormantes, fermeture non planifiée sur sortie
négative — DOIVENT être fournis prêts à câbler pour les forges supportées, et
DOIVENT être marqués non câblés dans le gabarit avec leur raison. Un
automatisme DOIT signaler sans jamais décider à la place d'un humain.

Rationale:
Ces automatismes dépendent de l'API d'une forge et de droits d'écriture sur
les issues : ils ne peuvent être ni exécutés ni éprouvés dans le gabarit, ce
que la règle R7 impose alors de déclarer. Le sens unique — dériver l'état
depuis l'acte, jamais l'inverse — vient d'ergonomia : l'étiquette de clôture
n'est jamais posée à la main, elle reflète l'état d'une liste de vérification,
et c'est l'auteur qui ferme.

Critères d'acceptation :

- Étant donné un projet instancié, quand il câble un automatisme, alors le
  matériel fourni s'applique sans réécriture de sa logique.
- Étant donné le gabarit, quand on inventorie ses portes, alors les
  automatismes y figurent comme non câblés avec leur raison.

Covers:
- feat~coordination-issues~1

Needs: impl, mtest
