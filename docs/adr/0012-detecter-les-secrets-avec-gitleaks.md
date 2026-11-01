# ADR-0012 — Détecter les secrets avec gitleaks, bloquant en CI, signalant en local

**Statut** : Accepté
**Date** : 2026-08-08
**Décideur** : Éric Lemesre — consultation directe (voir D-2026-08-10, registre des décisions)
**Portée** : durable

## Item de conception

`dsn~porte-secrets~1`

La détection de secrets utilise gitleaks (binaire unique épinglé en version
8.30.1 et par empreinte SHA-256 par plateforme dans `tools/secrets.sh`, même
mécanique que le jar OpenFastTrace) : balayage complet bloquant en CI,
balayage des fichiers indexés dans le hook pre-commit quand l'outil est
disponible — avertissement bruyant sinon, la CI restant l'arbitre. Les faux
positifs passent par le fichier d'exceptions `.gitleaks.toml`, chaque entrée
justifiée en commentaire.

Covers:
- req~detection-secrets~1

## Contexte

La porte anti-secrets est le seul contrôle de la phase « basique » des
référentiels de pipeline sécurisé qui manquait au gabarit — ergonomia
l'appliquait déjà (gitleaks en hook et en CI). Contrairement au jar
OpenFastTrace (un artefact unique multiplateforme), gitleaks est un binaire
natif par plateforme, ce qui pose la question du comportement quand le poste
ne peut pas l'obtenir.

## Décision

Adopter gitleaks, standard de fait du domaine, avec une asymétrie assumée :
**bloquant en CI** (environnement maîtrisé, binaire linux épinglé téléchargé
et vérifié), **signalant en local** quand l'outil manque (quatre plateformes
épinglées ; à défaut, avertissement et renvoi vers la CI). Un blocage local
inconditionnel sur un poste sans réseau pousserait à contourner tout le hook
— pire que l'asymétrie.

## Alternatives écartées

### Motifs grep maison dans le hook

Sans base de règles maintenue, la porte rate l'essentiel et donne une fausse
assurance ; c'est l'anti-porte.

### Blocage local inconditionnel

Casse le commit sur tout poste sans binaire ni réseau ; incite à
ALM_SKIP_HOOKS permanent, qui désactiverait aussi les autres portes.

### trufflehog

Capable mais plus lourd (orienté vérification de validité des secrets par
appels réseau) ; gitleaks suffit au besoin et reste hors-ligne.

## Conséquences

- Ce que cela apporte : aucun secret ne passe la CI ; détection au plus tôt
  sur les postes équipés ; exceptions auditable.
- Ce que cela coûte : quatre empreintes à maintenir à chaque montée de
  version ; les faux positifs demandent une entrée justifiée dans
  `.gitleaks.toml`.
- Ce que cela ferme : rien — un projet peut durcir (blocage local
  inconditionnel) par sa propre décision.

## Vérification

`tools/secrets-test.sh` (câblé dans les deux façades CI) vérifie les deux
branches : un secret de synthèse injecté est détecté (échec attendu), un
dépôt sain passe. L'empreinte du binaire est vérifiée à chaque exécution ;
une empreinte invalide échoue bruyamment.

## Références

- Registre des décisions : D-2026-08-10.
- Exigence : req~detection-secrets~1 (`spec/02-exigences/securite.md`).
- Pratique de référence : pipeline sécurisé, gates « basique »
  (<https://blog.stephane-robert.info/docs/devops/fondamentaux/pipeline-securise/>).
