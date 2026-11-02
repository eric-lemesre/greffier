# Exigences — domaine distribution

**Statut : ACTIVE** — domaine acté le 2026-11-01 (D-2026-11-07).

Ce domaine dit comment le moteur arrive chez qui s'en sert : des paquets
natifs pour Linux, macOS et Windows, un binaire Linux sans dépendance, et
un service système prêt à régler sur un serveur. Il n'ajoute aucune règle
d'ancrage ni d'accès : celles des domaines « ancrage » et « interfaces »
s'appliquent telles quelles au moteur installé.

## Chaque version est livrée en paquets natifs, éprouvés avant publication

`req~paquets-natifs~1`
**Statut : approuvée**

Quand une version est publiée, le système DOIT livrer, construits depuis
la chaîne épinglée par la chaîne déclenchée au tag : un paquet deb et un
paquet rpm pour Linux x86-64 et ARM64, une image disque macOS au binaire
universel (Apple Silicon et Intel) et un installateur MSI pour Windows
x64, chacun accompagné de son empreinte SHA-256 ; chaque paquet DOIT
avoir été installé sur un système de sa famille, et le binaire installé
DOIT y avoir répondu, avant la publication.

Rationale:
Le public du moteur (conciliateurs, associations, services publics
locaux) installe un logiciel par le moyen ordinaire de son système, pas
par une chaîne de compilation ; un paquet qui n'a jamais été installé
n'est pas prouvé.

Critères d'acceptation :

- Étant donné un tag de version, quand la chaîne de publication
  s'exécute, alors la release porte les paquets deb et rpm des deux
  architectures, le dmg, le MSI et une empreinte pour chacun.
- Étant donné un paquet construit, quand on l'installe sur un système de
  sa famille, alors `greffier --version` répond, puis le paquet se retire
  sans laisser le binaire.
- Étant donné le dmg, quand on installe le paquet qu'il contient, alors
  le binaire installé porte les architectures arm64 et x86_64.

Covers:

- feat~recherche-ancree~1
- feat~source-pour-agents~1

Needs: dsn, impl, itest

## Le binaire Linux ne dépend d'aucune bibliothèque partagée

`req~installation-sans-dependance~1`
**Statut : approuvée**

Le système DOIT livrer pour Linux un binaire lié statiquement, qui ne
dépend d'aucune bibliothèque partagée du système hôte, de sorte qu'un
même paquet s'installe sur toute distribution de son architecture,
quelle que soit la version de sa bibliothèque C.

Rationale:
Un binaire lié à la bibliothèque C du système qui l'a construit refuse
de démarrer sur une distribution plus ancienne ; l'ADR-0003 promet une
installation sans environnement d'exécution à gérer.

Critères d'acceptation :

- Étant donné le binaire Linux construit pour une version, quand on
  l'examine, alors il est lié statiquement.
- Étant donné le paquet deb, quand on l'installe sur une distribution
  dont la bibliothèque C est plus ancienne que celle du système de
  construction, alors `greffier --version` répond.

Covers:

- feat~recherche-ancree~1

Needs: dsn, impl, itest

## Les paquets Linux posent un service système désactivé, réglé par un fichier protégé

`req~service-systeme-desactive~1`
**Statut : approuvée**

Le système DOIT installer, avec les paquets deb et rpm, une unité systemd
qui sert l'API HTTP sous un utilisateur système dédié, sans privilège, et
qui reste désactivée et arrêtée tant que l'exploitant ne l'active pas ;
ses réglages (dossier du savoir, adresse d'écoute, jeton, noms d'hôte)
DOIVENT venir d'un fichier d'environnement lisible du seul
administrateur et du groupe du service, et une mise à jour du paquet NE
DOIT PAS écraser ce fichier.

Rationale:
Un service qui démarre seul à l'installation, avant qu'un savoir et un
jeton soient en place, sert un savoir absent ou expose un savoir sans
contrôle ; le jeton protège un contenu sous licence fermée (ADR-0004), il
ne doit être lisible de personne d'autre ni perdu à la mise à jour.

Critères d'acceptation :

- Étant donné le paquet installé, quand on interroge systemd, alors le
  service est désactivé et inactif.
- Étant donné le fichier d'environnement installé, quand on lit ses
  droits, alors il est en 0640, propriété de root et du groupe greffier.
- Étant donné un fichier d'environnement modifié par l'exploitant, quand
  le paquet est réinstallé ou mis à jour, alors la modification demeure.
- Étant donné les réglages fournis par l'environnement, quand
  `greffier servir` démarre sans option, alors il écoute à l'adresse, sur
  le savoir et sous les noms d'hôte réglés.

Covers:

- feat~source-pour-agents~1

Needs: dsn, impl, itest
