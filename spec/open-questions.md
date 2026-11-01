# Questions ouvertes

<!-- [impl->req~questions-ouvertes~1] -->

Registre des blocages en attente d'arbitrage humain. Protocole complet :
[méthode, ch. 6](../docs/methode/06-questions-ouvertes.md). Modèle :
`templates/fr/open-question.md`.

Règle : un contributeur (humain ou agent) bloqué par une ambiguïté du besoin,
un conflit de règles ou une décision qui ne lui appartient pas **s'arrête et
ouvre une entrée ici** plutôt que de trancher seul. Une question résolue reste
dans le registre (statut `resolved`), avec sa décision et le renvoi vers l'ADR
ou le relevé qui l'acte.

---

## OQ-001 — Choix de l'orchestrateur des portes qualité

- **Bloque** : outillage transverse (aucune exigence directement — la façade
  d'orchestration n'est pas une exigence tracée).
- **Contexte** : just exige un shell `sh` non garanti hors POSIX et son
  fichier sans extension échappe au scan OpenFastTrace ; le porteur souhaite
  par ailleurs que l'outil reste au choix du projet instancié.
- **Options** :
  - A) Basculer sur Task avec portes inlinées (Windows sans bash, outil imposé).
  - B) Portes en scripts POSIX autonomes + façade de délégation pure
    interchangeable (Task par défaut, variante just fournie).
  - C) Deux orchestrateurs complets avec contrôle de parité.
- **Recommandation** : B — seul découpage compatible avec le libre choix à
  l'instanciation ; l'argument « Windows sans bash » de A est théorique, git
  étant requis et Git pour Windows fournissant sh.
- **Décision** : B, actée le 2026-08-08 par Éric Lemesre →
  [ADR-0007](../docs/adr/0007-orchestrateur-en-facade-interchangeable.md).
- **Statut** : resolved

---

## OQ-002 — Assainissement de l'historique avant publication du dépôt

- **Bloque** : la mise en visibilité publique du dépôt (intendance — aucune
  exigence tracée).
- **Contexte** : l'historique git a été réécrit le 2026-08-11 pour retirer
  des références à un dépôt privé (fichiers et messages de commit). Or GitHub
  conserve des artefacts hors de portée d'une réécriture : instantanés
  `refs/pull/*/head` des pull requests, historique d'édition de leurs
  descriptions, commits orphelins jusqu'au ramasse-miettes. Le dépôt étant
  privé, il n'y a aucune exposition active — la question se tranche au moment
  de publier.
- **Options** :
  - A) Publier un **dépôt neuf** depuis l'historique purgé (garantie
    maximale ; les issues/PR historiques restent dans le dépôt privé).
  - B) Faire purger les refs et historiques d'édition par le support GitHub,
    puis basculer la visibilité du dépôt existant.
  - C) Basculer la visibilité telle quelle, en acceptant le résidu.
- **Recommandation** : A — seule option sans dépendance à un tiers ni résidu.
- **Décision** : —
- **Statut** : open

---

Format d'une nouvelle entrée :

```markdown
## OQ-001 — Titre court

- **Bloque** : req~identifiant~1
- **Contexte** : ce qui rend la décision nécessaire, en deux phrases.
- **Options** :
  - A) …
  - B) …
- **Recommandation** : B, car …
- **Décision** : (laissée vide jusqu'à l'arbitrage ; renvoyer vers l'ADR)
- **Statut** : open | resolved
```
