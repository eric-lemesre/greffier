# Matériel d'automatismes de forge — prêt à câbler

**Non câblé dans le gabarit** (règle R7), pour une raison qui ne se lèvera
pas : ces automatismes écrivent sur les issues d'une forge. Ils exigent une
API, un jeton et des droits que le gabarit n'a pas, et leur cas d'échec ne
peut être éprouvé que sur un dépôt vivant. Les déclarer non câblés avec leur
raison est la seule position honnête.

Comme `templates/bootstrap.d/` et `templates/orchestrators/`, ce répertoire est
du matériel post-instanciation : hors du périmètre de traçabilité du gabarit.

## Ce que contient ce répertoire

| Chemin | Rôle |
| --- | --- |
| `tools/automatismes.sh` | toute la logique, en POSIX sh, vocabulaire pris au lexique |
| `github/workflows/*.yml` | façades GitHub Actions — déclencheurs seulement |
| `gitlab/automatismes.yml` | façade GitLab CI — mêmes appels |

Le partage est celui du gabarit (ADR-0007, ADR-0010) : la logique vit dans un
script, les forges ne reçoivent que des déclencheurs.

## Les cinq automatismes

| Sous-commande | Déclencheur | Effet |
| --- | --- | --- |
| `lecture` | commentaire `/vu` (ou `/seen`) sur une consultation | coche la case du lecteur, le désassigne |
| `retombee` | fusion modifiant un document consulté | décoche les lectures, réassigne, commente le comparatif |
| `a-cloturer` | liste de vérification complétée | pose l'étiquette de clôture, prévient l'auteur |
| `dormantes` | planification hebdomadaire | rappelle les recettes sans activité depuis N jours |
| `fermeture` | pose d'une étiquette de sortie négative | ferme l'issue en « non planifiée » |

## Câbler ces automatismes

1. Copier `tools/automatismes.sh` dans le `tools/` du projet et
   `github/workflows/*.yml` (ou `gitlab/automatismes.yml`) au bon endroit.
2. Créer les étiquettes citées par le lexique du projet.
3. **Éprouver chaque automatisme sur son cas d'échec** (R3) : commentaire
   `/vu` d'un tiers non attendu, document de procédure modifié, liste
   partiellement cochée, étiquette de sortie sur une issue déjà fermée.
4. Retirer la mention « non câblée » du chapitre 11 pour ceux qui le sont, et
   consigner l'arbitrage au registre des décisions du projet (ADR-0013).

## Le sens unique, à ne jamais inverser

Un automatisme **dérive l'état depuis l'acte**, jamais l'inverse, et **signale
sans décider**. L'étiquette de clôture n'est jamais posée à la main : elle
reflète l'état d'une liste de vérification. Et poser cette étiquette ne ferme
rien — la clôture revient à l'auteur, qui vérifie que les validations existent
et citent la version en cours. Une case cochée ne prouve rien par elle-même.

Deux pièges vécus sur ergonomia, à connaître avant de câbler :

- **La retombée des lectures doit exclure les documents de procédure.** Cités
  par le gabarit d'issue, ils déclenchaient la retombée sur toutes les
  consultations ouvertes à la fois, sans qu'aucun dossier de fond ait bougé.
- **Et ce filtre doit se prouver.** Il est écrit en chemins : un répertoire
  renommé le laisse syntaxiquement valide et fonctionnellement mort, sans la
  moindre erreur. C'est exactement ce qui est arrivé là-bas — le filtre est
  resté vert vingt-quatre heures en ne filtrant plus rien. `verifier_filtre`
  refuse désormais de s'exécuter si un chemin exclu n'existe pas ; et la porte
  des liens (`tools/liens.sh`) couvre les fichiers de forge pour la même
  raison.
- **Un rappel ne doit pas se rappeler lui-même.** Le commentaire de rappel
  rafraîchit l'activité de l'issue : sans la garde correspondante, l'automatisme
  se redéclenche indéfiniment.
