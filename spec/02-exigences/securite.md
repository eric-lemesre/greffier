# Exigences — domaine sécurité

**Statut : ACTIVE** — domaine acté le 2026-08-20 (D-2026-08-16). Le statut commande
le dénominateur des taux d'audit et de classification (méthode, ch. 13).

## Détection des secrets dans les contributions

`req~detection-secrets~1`

**Statut : approuvée**

Si un secret (clé d'API, jeton, mot de passe, clé privée) est présent dans une
contribution, alors les portes DOIVENT le détecter et refuser la contribution
en CI ; le hook local DOIT effectuer la même détection sur les fichiers
indexés quand l'outil est disponible, et signaler bruyamment son absence sans
bloquer sinon. L'outil de détection DOIT être épinglé par version et par
empreinte, et les faux positifs DOIVENT passer par une exception justifiée
versionnée, jamais par la désactivation de la porte.

Rationale:
Un secret commité est compromis dès la première poussée, même supprimé
ensuite (l'historique le conserve). L'asymétrie local/CI est assumée et
documentée : bloquant là où l'environnement est maîtrisé (CI), signalant sur
les postes où l'outil peut manquer — un blocage local inconditionnel
pousserait au contournement global (ADR-0012).

Critères d'acceptation :

- Étant donné un fichier contenant un motif de secret connu, quand la porte
  s'exécute, alors elle échoue en désignant le fichier.
- Étant donné un dépôt sain, quand la porte s'exécute, alors elle passe.
- Étant donné un poste sans l'outil ni accès réseau, quand le hook local
  s'exécute, alors il avertit et laisse la CI trancher.

Covers:
- feat~tracabilite-mecanisee~1

Needs: dsn, impl, utest

## Données hors du dépôt

`req~donnees-hors-depot~1`

**Statut : approuvée**

Le dépôt DOIT porter le modèle des données et NE DOIT PAS porter les données
elles-mêmes : les portes DOIVENT refuser tout export versionné — archive,
tableur, sauvegarde — et tout fichier SQL versionné porteur de données, seuls
les schémas étant admis.

Les portes DOIVENT en outre refuser tout chemin d'accès à un partage réseau
qualifié par un nom de serveur et un domaine.

Là où un projet a besoin de jeux d'essai versionnés, il DOIT en déclarer les
chemins dans la porte, en vérification de sa propre décision.

Rationale:
Un dépôt de spécification décrit un modèle ; ce que ce modèle contient
appartient au système d'information, et l'y recopier fait sortir de son
périmètre une donnée qui n'avait aucune raison d'en sortir. Le risque est
d'autant plus sournois qu'il ne ressemble pas à une fuite : personne ne
« publie » un jeu de données, on le dépose pour travailler et il reste.

Le contrôle porte sur le CONTENU. Un `.gitignore` ne protège que du geste
distrait : il n'empêche ni un ajout forcé, ni le suivi d'un fichier déjà
versionné, et il ne dit rien de ce qu'un fichier porte. Le cas le plus
insidieux est précisément celui qu'un nom ne trahit pas — un fichier SQL au
bon endroit, sous une extension légitime, dont seules les lignes d'insertion
révèlent qu'il transporte un extrait de production.

Le chemin de partage réseau relève de la même famille sans être une donnée :
nom de serveur et domaine d'annuaire renseignent sur l'infrastructure d'une
organisation, et ils arrivent au dépôt par le même chemin que le reste —
recopiés d'un code existant que l'on documente.

Critères d'acceptation :

- Étant donné une archive ou un tableur versionné, quand la porte s'exécute,
  alors elle échoue en désignant le fichier.
- Étant donné un fichier SQL versionné portant des insertions ou une copie de
  données, quand la porte s'exécute, alors elle échoue en désignant le
  fichier.
- Étant donné un schéma exporté depuis une base, sans donnée, quand la porte
  s'exécute, alors elle passe.
- Étant donné un chemin de partage réseau qualifié dans un fichier versionné,
  quand la porte s'exécute, alors elle échoue en désignant le fichier.
- Étant donné un chemin de jeux d'essai déclaré dans la porte, quand un SQL
  porteur de données s'y trouve, alors la porte passe ; et elle échoue pour le
  même fichier placé ailleurs.

Covers:
- feat~tracabilite-mecanisee~1

Needs: impl, utest

## Cadre de sécurité continue

`req~securite-continue~1`

**Statut : approuvée**

Le dépôt DOIT fournir un cadre de sécurité continue documenté et outillable :
modélisation légère des menaces (STRIDE) exigée pour les exigences de niveau
d'enjeu S avec report des menaces retenues en critères d'acceptation, politique
de traitement des vulnérabilités avec délais par sévérité et exceptions
justifiées, datées et portées par un responsable, et emplacement déclaré pour
la génération d'inventaire de composants (SBOM) à la release.

Rationale:
La sécurité qui repose sur la vigilance échoue (shift-left) ; le cadre
transforme les pratiques du domaine en artefacts du dépôt : menaces → critères
testables, vulnérabilités → délais et exceptions tracées, composants →
inventaire versionné.

Critères d'acceptation :

- Étant donné une exigence de niveau S, quand elle est approuvée, alors ses
  menaces STRIDE examinées figurent dans ses critères d'acceptation (contrôlé
  en revue via la Definition of Done).
- Étant donné une vulnérabilité non corrigeable dans les délais, quand elle
  est acceptée, alors une exception versionnée porte la justification, le
  responsable et l'échéance.

Covers:
- feat~gouvernance-agnostique~1

Needs: impl, mtest
