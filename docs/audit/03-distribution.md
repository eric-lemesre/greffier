# Audit — 03-distribution

<!-- Miroir de spec/02-exigences/03-distribution.md. Les verdicts sont écrits À
     LA MAIN : c'est le jugement que la porte ne sait pas rendre. Le tableau
     de bord docs/audit/README.md, lui, est généré — ne pas l'éditer.
     Squelette des lignes manquantes :
       sh tools/audit.sh --squelette 03-distribution -->

Verdicts admis : `conforme` · `écart` · `non examiné`.

Domaine actif depuis D-2026-11-07 : trois exigences approuvées
(ADR-0005).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~paquets-natifs~1` | conforme | `.github/workflows/paquets.yml` : deb et rpm (x86-64, ARM64), dmg universel, MSI x64, empreinte de chacun ; épreuves d'installation (runner Ubuntu, conteneur Fedora, runner macOS avec `lipo -archs`, runner Windows avec PATH et désinstallation) ; `release.yml` ne publie qu'après elles et revérifie les empreintes. Épreuve locale du 2026-11-01 : deb sur Debian 12, rpm sur Fedora 42 |
| `req~installation-sans-dependance~1` | conforme | cibles `*-unknown-linux-musl` ; épreuve `file` (« static-pie linked ») dans `paquets.yml` ; le deb construit sur une distribution récente s'installe et répond sur Debian 12 (épreuve locale du 2026-11-01) |
| `req~service-systeme-desactive~1` | conforme | `packaging/linux/` : unité durcie, utilisateur `greffier`, fichier d'environnement 0640 `root:greffier`, `conf-files` (deb) et `config(noreplace)` (rpm) ; épreuves de `paquets.yml` (service désactivé et inactif, droits, modification préservée à la réinstallation, drapeaux `cn` du rpm) ; test `servir_se_regle_par_ses_variables_d_environnement` |
