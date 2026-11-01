# 16. Validation des écrans

Les écrans sont le point où la validation humaine s'engorge : tester chaque
parcours à la main est lent, partiel et jamais rejoué. La méthode remplace la
validation systématique par un **mécanisme à trois étages** — du plus
déterministe au plus interprétatif — et recentre l'humain sur ce qu'aucun
outil ne juge : le veto et le goût.

## Les trois étages

### Étage 1 — matrice de parcours (exhaustivité par construction)

Une **matrice écrans × états**, tenue dans le dépôt, jouée par un outillage
de bout en bout (Playwright ou équivalent) contre le **vrai backend** sur une
**base jetable recréée à chaque exécution** — jamais un backend simulé : ce
qu'on valide, c'est l'application, pas un décor.

- Chaque écran livré figure dans la matrice, dans ses états significatifs
  (vide, peuplé, erreur) ; un écran sans parcours est un écart, pas un oubli
  tolérable.
- Les parcours **cliquent** réellement : formulaires soumis, fichiers versés,
  actions déclenchées, refus provoqués.
- L'**accessibilité** est une porte du même passage (axe-core ou équivalent) :
  aucune violation sérieuse ou critique n'est tolérée.
- Les assertions portent sur le **contenu**, jamais sur la seule présence d'un
  gabarit : un écran d'erreur qui « s'affiche » n'est pas un écran qui marche
  (leçon d'origine du mécanisme : une référence visuelle avait été enregistrée
  sur un état « service injoignable » que le test laissait passer).

### Étage 2 — instantanés visuels (rien ne change sans être vu)

Chaque écran × état de la matrice a son **instantané de référence commité**.
Toute dérive visuelle fait échouer la porte avec un diff d'image ; une
évolution voulue se ré-enregistre explicitement — **le diff des images EST la
revue visuelle**, versionnée dans la pull request.

- Les zones dynamiques (identifiants horodatés, dates) sont **masquées** à la
  capture : le déterminisme est une exigence du mécanisme, pas un vœu.
- Une tolérance de comparaison étroite absorbe l'anticrénelage, rien d'autre.

### Étage 3 — revue d'agent (le jugement outillé)

Un **agent** relit les captures produites par l'étage 1 et déroule une
**check-list versionnée** (gabarit `templates/fr/check-list-ecrans.md`) :
langue correcte partout, libellés cohérents avec les référentiels, états non
muets, hiérarchie, densité, sécurité d'usage, données sensibles. Il rend une
**fiche de validation** archivée avec les revues (gabarit
`templates/fr/validation-ecrans.md`) : verdict par écran, réserves triées —
bloquantes ou consignées en dette datée, jamais tues.

## Ce que l'humain garde

Le mécanisme remplace la validation **systématique**, pas la souveraineté :

- le **veto par échantillonnage** — le valideur humain lit la fiche et les
  captures (quelques minutes), et peut bloquer ;
- les **choix de goût** — style, thème, parcours d'usage : aucun étage ne les
  tranche à sa place.

Ce partage se **consigne** (ADR ou amendement de la convention de revue du
projet) : qui valide quoi n'est jamais implicite.

## Câblage

- Une **cible unique** (`task ecrans` ou équivalent) joue les étages 1-2 ;
  elle entre dans la gate locale et la CI, débrayable par variable
  d'environnement documentée — jamais silencieusement.
- Le harnais de bout en bout ainsi créé porte le **niveau e2e de la
  traçabilité** : les exigences de niveau e2e basculent leurs `Needs:` vers
  lui au lieu d'attendre indéfiniment un outillage futur
  (voir [5. Tests et vérification](05-tests-et-verification.md)).
- La règle R3 s'applique : à sa mise en place, la porte se teste sur son cas
  d'échec (un parcours cassé volontairement, un instantané altéré).

## Anti-motifs

- Valider contre un backend simulé : on valide alors le simulateur.
- Des assertions de présence (« la page se charge ») : elles laissent passer
  les états d'erreur.
- Des instantanés sans masques : la porte devient un bruit qu'on finit par
  débrayer.
- Une check-list orale : ce qui n'est pas versionné dérive.
