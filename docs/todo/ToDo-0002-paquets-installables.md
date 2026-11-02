# ToDo-0002 — Paquets installables

**Statut : 🚧 en cours**

Livrer Greffier par le moyen ordinaire de chaque système : paquets deb et
rpm (Linux x86-64 et ARM64), image disque macOS universelle, installateur
MSI pour Windows, et sur un serveur Linux un service prêt à régler. Il
existe parce que la version 0.1.0 n'est livrée qu'en archive Linux liée à
la bibliothèque C de son système de construction, alors que le public du
moteur installe un logiciel comme on installe un logiciel.

## Reste à faire

- Lot 1 — paquets et service (ADR-0005, D-2026-11-07) : chaîne
  `paquets.yml` (construction et épreuve d'installation de chaque
  paquet), unité systemd désactivée, `greffier servir` réglable par
  l'environnement. Reste : la première publication avec les paquets
  (version 0.2.0), sur demande du porteur.
- Lot 2 — signature :
  - MSI et `greffier.exe` : SignPath Foundation (D-2026-11-10). Le
    porteur dépose la candidature (page d'accueil du projet : le dépôt
    GitHub) et active l'authentification à deux facteurs sur GitHub et
    SignPath ; ensuite, politique de signature publiée dans le README et
    étape de signature dans `paquets.yml` (action de SignPath, artefact non
    signé soumis, artefact signé publié), ADR à écrire avec elle.
  - dmg : Apple Developer Program et notarisation, non décidé.
  - deb et rpm : signature du dépôt de paquets si l'un est ouvert.

## Renvois

- Exigences : req~paquets-natifs~1, req~installation-sans-dependance~1,
  req~service-systeme-desactive~1
- Décisions : ADR-0005, D-2026-11-07, D-2026-11-10
- Issues : —
