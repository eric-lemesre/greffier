# ADR-0008 — Écrire le journal du service dans un fichier, tourné par logrotate

**Statut** : Accepté
**Date** : 2026-11-18
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-12 au registre
**Portée** : durable — condition de réouverture : un déploiement où aucun
fichier n'est inscriptible (conteneur en lecture seule) devient la norme

## Item de conception

`dsn~journal-en-fichier~1`

`greffier servir` écrit par défaut son journal dans un fichier
(`/var/log/greffier/greffier.log`) qu'il rouvre sur `SIGHUP` ; les paquets
Linux livrent la configuration logrotate qui le fait tourner. Un fichier
qui ne s'ouvre pas renvoie le journal à la sortie d'erreur, et le premier
événement le dit.

Covers:

- req~journal-en-fichier~1
- req~journal-du-service~2

Needs: impl

## Contexte

L'ADR-0007 envoie le journal à journald sous systemd, ailleurs sur la
sortie d'erreur, et écarte « un fichier de journal géré par
l'application ». Le gabarit a depuis changé sa règle commune (ADR-0023
d'alm-forge, demande du porteur du 2026-11-03 pour tous ses dépôts Rust) :
le journal d'un service se trouve dans un fichier connu, lisible sans
`journalctl`, conservé et compressé selon une règle écrite, le même sur un
poste, un serveur sans systemd ou un conteneur doté d'un volume. Pacilia,
premier client de Greffier, l'applique déjà.

Greffier n'est pas qu'un service : ses commandes (`capturer`, `chercher`,
`verifier`…) sont lancées à la main, et `greffier mcp` est lancé par un
agent qui lit sa sortie d'erreur. Il est aussi livré pour Windows et macOS.

## Décision

1. **Sortie par défaut du service : un fichier.** `greffier servir` écrit
   son journal dans `GREFFIER_JOURNAL_FICHIER` (option `--journal-fichier`,
   ou `[journal] fichier`), à défaut `/var/log/greffier/greffier.log` en
   production et `target/journal/greffier.log` en construction de mise au
   point. Une ligne de la sortie d'erreur dit où lire le journal.
2. **Sortie réglable.** `GREFFIER_JOURNAL_SORTIE` (option
   `--journal-sortie`, ou `[journal] sortie`) vaut `fichier`, `erreur` ou
   `journald` ; un chemin de fichier donné sans sortie vaut `fichier`.
   `erreur` garde le comportement de l'ADR-0007 : journald natif quand
   systemd a relié la sortie d'erreur à journald (`JOURNAL_STREAM`).
3. **Les autres commandes restent sur la sortie d'erreur.** Les commandes
   et `greffier mcp` gardent la sortie d'erreur par défaut : leur journal
   accompagne une exécution suivie par celui qui la lance.
4. **Hors Unix, la sortie d'erreur reste le défaut.** Ni logrotate ni
   `SIGHUP` n'existent sous Windows : un fichier n'y est écrit que demandé,
   et ne tourne que service arrêté. macOS, Unix, suit la règle du service.
5. **Rotation par logrotate.** Le service ne fait pas tourner son fichier :
   il le **rouvre** à la réception de `SIGHUP`, gestionnaire posé avant la
   lecture des dépôts. Les paquets deb et rpm posent
   `/etc/logrotate.d/greffier` (quotidienne, quatorze générations
   compressées, `su greffier greffier`, `create 0640`, `postrotate` qui
   envoie `SIGHUP`, pas de `copytruncate`) ; l'unité systemd reçoit
   `LogsDirectory=greffier`, seul dossier inscriptible sous
   `ProtectSystem=strict`.
6. **Repli annoncé.** Un fichier qui ne s'ouvre pas (dossier absent,
   droits) renvoie le journal à la sortie d'erreur et le premier événement
   le dit (`warn`) ; un échec de réouverture garde l'ancien descripteur et
   le dit de même.
7. **Porte.** `tools/logrotate.sh` vérifie la configuration livrée, et
   `logrotate -d` quand l'outil est présent ; câblée dans `tools/ci.sh`.

Les autres décisions de l'ADR-0007 (pile, requêtes corrélées, accès,
contenu jamais journalisé, filtre et format) sont inchangées : le fichier
porte exactement ce que la sortie d'erreur portait. Cet ADR remplace son
point 6 (journald par défaut sous systemd) et lève l'alternative qu'il
écartait.

## Alternatives écartées

### Garder journald par défaut sous systemd

C'était l'ADR-0007 : le journal dépend alors de la rétention de journald et
ne se lit qu'avec ses outils ; hors systemd, il se perd si rien ne le
recueille. Il reste disponible par `GREFFIER_JOURNAL_SORTIE=erreur`.

### Un fichier pour toutes les commandes

Une capture ou une vérification lancée à la main veut voir ses
avertissements tout de suite ; un agent qui lance `greffier mcp` lit sa
sortie d'erreur. Un fichier par défaut les rendrait muettes.

### Rotation par l'application (`tracing-appender`)

Rétention, compression et droits deviendraient du code à maintenir, alors
que logrotate les tient déjà, de la même façon pour tous les services du
serveur.

### logrotate avec `copytruncate`

Aucun signal à gérer, mais les lignes écrites entre la copie et la
troncature sont perdues.

## Conséquences

- Ce que cela apporte : le journal du service à un endroit connu, conservé
  quatorze jours et compressé, identique d'un déploiement à l'autre.
- Ce que cela coûte : un rédacteur qui sait se rouvrir et un gestionnaire
  de `SIGHUP` ; une configuration logrotate livrée et sa porte ; un
  déploiement qui fournit sa propre unité doit créer `/var/log/greffier`
  (sinon le journal revient à la sortie d'erreur, en le disant).
- Ce que cela ferme : un journal perdu faute de collecteur ; une rétention
  décidée ailleurs que dans le projet.

## Vérification

- Tests unitaires (`src/journal.rs`) : choix de la sortie (défaut du
  service et des commandes, chemin seul, sortie nommée, valeur refusée),
  réouverture après renommage, droits `0640`, fichier impossible à ouvrir.
- Tests d'intégration (`tests/savoirs_itest.rs`) : `greffier servir`
  écrit dans son fichier, et après renommage puis `SIGHUP`, les lignes
  suivantes vont au nouveau fichier ; un fichier impossible renvoie à la
  sortie d'erreur avec un avertissement.
- `tools/logrotate.sh` dans `tools/ci.sh`, éprouvée sur ses cas d'échec par
  `tools/logrotate-test.sh` ; épreuves des paquets deb (`logrotate -d` sur
  la configuration installée) et rpm (fichier de configuration préservé).

## Références

- ADR-0005 (paquets natifs), ADR-0007 (journal du service).
- ADR-0023 d'alm-forge ; méthode d'alm-forge, chapitre 17, règles 6 et 7.
- `spec/02-exigences/04-exploitation.md`.
- `logrotate(8)`, `systemd.exec(5)` (`LogsDirectory=`).
