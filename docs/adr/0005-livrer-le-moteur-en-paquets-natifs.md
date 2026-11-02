# ADR-0005 — Livrer le moteur en paquets natifs, binaire Linux statique, service système désactivé

**Statut** : Accepté
**Date** : 2026-11-01
**Décideur** : Eric Lemesre — seul (porteur), D-2026-11-07 au registre
**Portée** : durable (la signature des paquets macOS et Windows rouvrira
la section « Signature »)

## Item de conception

`dsn~paquets-natifs~1`

Au tag, une chaîne unique (`paquets.yml`, appelée par `release.yml`)
construit sur des runners natifs un binaire Linux statique (musl) par
architecture, en tire un deb (cargo-deb) et un rpm (cargo-generate-rpm)
qui posent une unité systemd désactivée, assemble un binaire macOS
universel dans un `.pkg` livré en `.dmg`, et un MSI Windows (WiX v5) ;
chaque paquet est installé et interrogé avant d'être publié.

Covers:

- req~paquets-natifs~1
- req~installation-sans-dependance~1
- req~service-systeme-desactive~1

Needs: impl

## Contexte

La version 0.1.0 n'est livrée qu'en archive Linux x86-64, construite sur
la distribution du runner et liée à sa bibliothèque C : elle ne démarre
pas sur une distribution plus ancienne. L'ADR-0003 promet une
installation « sans environnement d'exécution à gérer », sur un poste
comme sur un petit serveur ; le public (conciliateurs, associations,
services publics locaux) travaille sous Windows, macOS et Linux, et
installe un logiciel par le moyen ordinaire de son système.

Sur un serveur, `greffier servir` est un service : il doit tourner sous
un utilisateur sans privilège, recevoir un jeton qu'il ne faut ni
exposer ni perdre, et ne pas démarrer avant qu'un savoir soit en place.

Les arbitrages du porteur (2026-11-01) : paquets non signés d'abord ;
x86-64 et ARM64 ; MSI pour Windows ; unité systemd dans les paquets
Linux.

## Décision

1. **Formats et architectures** : deb et rpm pour Linux x86-64 et ARM64,
   archive tar.gz pour les mêmes ; un `.dmg` macOS dont le `.pkg` pose un
   binaire universel (arm64 et x86_64, `lipo`) dans `/usr/local/bin` ;
   un MSI Windows x64, installation par machine dans
   `Program Files\Greffier`, dossier ajouté au PATH du système,
   `UpgradeCode` fixe pour qu'une version remplace la précédente.
2. **Binaire Linux statique** : cibles `*-unknown-linux-musl`, compilées
   sur des runners natifs de chaque architecture (pas de compilation
   croisée). Un même binaire sert le deb, le rpm et l'archive. Le client
   TLS (rustls) ne demande aucune bibliothèque du système.
3. **Outils** : cargo-deb et cargo-generate-rpm, configurés dans
   `Cargo.toml` ; WiX v5 (outil dotnet) et `packaging/windows/greffier.wxs` ;
   `pkgbuild` et `hdiutil` par `packaging/macos/construire-dmg.sh`. Les
   outils sont installés à version épinglée, les actions par SHA.
4. **Service système** (`packaging/linux/`) : unité `greffier.service`
   posée **désactivée et arrêtée** ; utilisateur système `greffier`, créé
   par le script d'après installation (commun au deb et au rpm) ;
   système de fichiers en lecture seule pour le service (le serveur ne
   fait que lire le savoir, index en mémoire), sans capacité ni
   élévation. Réglages dans `/etc/greffier/greffier.env` (0640,
   `root:greffier`), fichier de configuration que la mise à jour
   n'écrase pas ; `greffier servir` lit `GREFFIER_SAVOIR`,
   `GREFFIER_ECOUTE` et `GREFFIER_HOTES` comme ses options. Le savoir
   par défaut est `/var/lib/greffier/savoir`. Le retrait du paquet garde
   l'utilisateur et `/var/lib/greffier` : le savoir n'appartient pas au
   paquet.
5. **Preuve avant publication** : chaque paquet est installé sur un
   système de sa famille (runner Ubuntu pour le deb, conteneur Fedora pour
   le rpm, runner macOS, runner Windows) ; le binaire installé doit
   répondre, le service être désactivé, le fichier d'environnement
   garder ses droits et ses modifications, le binaire macOS porter les
   deux architectures. `paquets.yml` se joue aussi sur toute pull request
   qui touche à la construction des paquets.
6. **Signature** : aucune pour l'instant. Les empreintes SHA-256 sont
   publiées et vérifiées avant la release ; le README dit comment ouvrir
   un paquet non signé sous macOS (Gatekeeper) et Windows (SmartScreen).
   La signature (Apple Developer Program et notarisation ; certificat de
   signature de code Windows) fera l'objet d'une décision à part.

## Alternatives écartées

### cargo-dist

Produit archives et installateurs pour toutes les plateformes, mais ni
deb ni rpm, ni unité systemd ; il génère son propre workflow, qui
remplacerait notre chaîne épinglée et ses épreuves par les siennes.

### Binaire Linux lié à la bibliothèque C (glibc)

Plus simple à construire, mais lié à la version du système de
construction : il faut soit construire sur la plus ancienne distribution
visée, soit un paquet par distribution. Le binaire statique supprime la
question pour un coût nul ici (aucune dépendance native).

### cargo-wix

Outil établi, mais lié à WiX 3, qui n'est plus fourni par les images
Windows récentes ; WiX v5 s'installe comme outil dotnet, à version
épinglée, et son fichier source reste court.

### Service activé à l'installation

L'usage ordinaire d'un paquet serveur, mais le service démarrerait sans
savoir ni jeton ; l'activation est un geste de l'exploitant, une fois le
fichier d'environnement réglé.

## Conséquences

- Ce que cela apporte : une installation par le moyen ordinaire de
  chaque système, un binaire Linux valable sur toute distribution, un
  service serveur durci prêt à activer, et des paquets prouvés avant
  d'être publiés.
- Ce que cela coûte : quatre familles de runners par version ; des
  avertissements de sécurité à l'ouverture des paquets macOS et Windows
  tant qu'ils ne sont pas signés.
- Ce que cela ferme : la livraison d'un paquet qui n'a jamais été
  installé.

## Vérification

- `paquets.yml` : épreuves d'installation de chaque paquet (deb et rpm
  des deux architectures, dmg, MSI), liaison statique du binaire Linux,
  service désactivé et inactif, droits et préservation du fichier
  d'environnement, architectures du binaire macOS ; `release.yml` ne
  publie qu'après ces épreuves et revérifie les empreintes.
- Test d'intégration `servir_se_regle_par_ses_variables_d_environnement`
  (`tests/interfaces_itest.rs`).
- La traçabilité relie chaque exigence du domaine « distribution » à cet
  item de conception et à ses épreuves.

## Références

- ADR-0003, ADR-0004.
- `spec/02-exigences/03-distribution.md`.
- Méthode, ch. 8 (versionnement et release).
