# 5. Tests et vérification


La vérification transforme les critères d'acceptation en preuves mécanisées.
Une exigence n'est *vérifiée* que lorsqu'un test tagué la couvre et passe.

## Choisir le niveau de test

Chaque exigence DOIT/DEVRAIT reçoit, à son approbation, un niveau de
vérification déclaré dans son mot-clé Needs :

| Niveau | Type OFT | Quand |
| --- | --- | --- |
| Unitaire | utest | règle de calcul, logique pure, cas limites |
| Intégration | itest | interaction entre composants, persistance, contrat d'API |
| Système / bout en bout | stest | parcours utilisateur, exigence visible de l'extérieur |
| Manuel | mtest | exigence non automatisable (ergonomie, conformité documentaire) |

Règles de choix : tester au niveau le plus bas qui prouve l'exigence ; un
parcours E2E ne remplace pas les cas limites unitaires ; une exigence de
comportement indésirable (motif EARS « Si… alors ») exige un test du cas
d'échec, pas seulement du chemin nominal.

## Écrire le lien test → exigence

Le test porte le tag dans un commentaire adjacent, et son nom reprend le
comportement vérifié :

```python
def test_echeance_fin_de_mois_reportee_au_dernier_jour():
    ...
```

Un test peut couvrir plusieurs exigences (un tag par ligne). Un test sans tag
est autorisé (tests de robustesse interne) ; une exigence sans test ne l'est
pas — c'est la traçabilité qui le détecte, pas la discipline.

## Exigences non automatisables

Jamais « sans vérification ». La procédure manuelle est un fichier versionné
dans `docs/verification-manuelle/`, tagué mtest, décrivant : préconditions,
étapes, résultat attendu, fréquence d'exécution (à chaque release au minimum),
et le journal des exécutions (date, exécutant, verdict). Une exigence bascule
de mtest vers un niveau automatisé dès que c'est techniquement possible.
Cet engagement est **outillé** (`req~classification-exigences~2`) : une
exigence du niveau le plus contraignant couverte par mtest seul fait
**échouer** la porte de classification, sauf report explicite —
l'identifiant suivi du marqueur « (à élever : motif) » dans une fiche de la
feuille de route (`docs/todo/`) — auquel cas la dette est nommée à chaque
passage. Assumer durablement une vérification manuelle reste légitime (R10) :
c'est alors un motif consigné qui le dit, jamais un signal ignoré.

## Qualité du parc de tests

- **Anti-fragilité** : pas d'attente temporelle arbitraire dans les tests E2E ;
  un test instable est corrigé ou retiré sous 48 h — un test instable toléré
  apprend à ignorer le rouge.
- **Oracle avant réinvention** : quand le projet réécrit un système existant,
  figer les comportements observés de l'existant dans des fixtures versionnées
  et tester contre elles — c'est ce qui empêche de « réinventer » une règle
  métier plausible mais fausse (pratique éprouvée sur wallos-rs).
- **Couverture de code** : seuil plancher défini par projet instancié et câblé
  en CI le jour où il est déclaré ; la couverture d'exigences (traçabilité) et
  la couverture de code mesurent deux choses différentes et ne se substituent
  pas.
- **Tests de mutation et tests par propriétés** : recommandés sur le cœur
  métier ; à câbler comme travail planifié, pas comme intention.
