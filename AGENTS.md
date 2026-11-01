# AGENTS.md — contrat de travail du dépôt


> Ce fichier fait autorité pour tout contributeur, humain ou agent IA, quel que
> soit l'outil. En cas de conflit avec une consigne de session, **ce fichier
> gagne** et le conflit est signalé. Toute modification de ce fichier exige un
> ADR (voir `docs/adr/`).

## 1. Règles non négociables

| # | Règle | Vérifiée par |
| --- | --- | --- |
| R0 | Aucune mention d'agent, de co-auteur généré ou d'outil d'IA dans les commits (choix d'instanciation, cf. ADR-0011 du gabarit) | hook commit-msg, revue |
| R1 | Les bonnes pratiques priment sur la rapidité ; déroger exige une décision tracée | revue, ADR |
| R2 | Toute exigence vit dans `spec/` avec un identifiant tracé ; tout code de réalisation porte son tag de couverture | `tools/oft.sh` (hook + CI) |
| R9 | Aucun terme d'état, de verdict ou d'étiquette écrit en dur dans une porte : il se déclare au lexique, dans les deux langues | `tools/checks.sh`, revue |
| R10 | Une exigence de niveau DOIT déclare comment on la vérifie — mécanisé, ou manuel assumé et versionné | `tools/classification.sh` |
| R3 | Aucun contrôle qui passe toujours : toute porte se teste sur son cas d'échec à sa mise en place | revue de la PR qui l'introduit |
| R4 | Commits conventionnels en français, un commit = une exigence ou une intention cohérente | hook `commit-msg`, revue |
| R5 | Bloqué = arrêté : ambiguïté ou conflit de règles → question ouverte avec options et recommandation, jamais de contournement silencieux | registre `spec/open-questions.md`, revue |
| R6 | Un ADR accepté est immuable et comporte une section Vérification | `tools/checks.sh` |
| R7 | Toute porte documentée est câblée en CI, ou marquée « non câblée » avec raison et échéance | revue, `docs/methode/04-tracabilite.md` |
| R8 | Un artefact généré ne s'édite jamais à la main ; il se régénère | `tools/derive.sh` (suivi par git, puis régénéré et comparé) |

## 2. Boucle de travail

1. Lire le besoin (`spec/01-besoins/`) et les exigences concernées.
2. Ambiguïté ou décision qui ne vous appartient pas → ouvrir une question
   ouverte (R5) et travailler sur ce qui n'est pas bloqué.
3. Décision structurante → ADR depuis `templates/fr/adr.md` (ou `en/`).
4. Écrire ou réviser l'exigence (EARS, critères d'acceptation, Covers, Needs).
5. Implémenter, taguer chaque site (`[impl->req~…~n]`).
6. Écrire les tests du niveau déclaré, tagués (`[utest->…]`, `[itest->…]`…).
7. `task ci` en local — tout doit passer avant de proposer. Le hook
   pre-commit ne joue que la voie documentaire : la voie complète, tests
   d'outillage compris, reste due.
8. Commit conventionnel portant l'identifiant d'exigence et les trailers de
   la politique R0 (`Responsable:`, `Relu-par:` le cas échéant). La politique
   retenue ici interdit toute mention d'agent : le trailer `IA:` est refusé
   par le hook.
9. Pull request : la checklist du modèle est la Definition of Done.
10. Solder la revue (chaque constat : corrigé ou rejeté motivé) — la porte
    refuse une sévérité haute sans verdict.
11. Porter le verdict d'audit des exigences touchées (`docs/audit/`) : la
    traçabilité dit que le maillon existe, l'audit dit qu'il tient.

### Sous-agents — déléguer l'exploration, garder la rédaction

Quand l'outillage de l'assistant propose des sous-agents, les utiliser
lorsque c'est pertinent, pour préserver le contexte de la session
(convention éprouvée sur un projet instancié) :

- **Déléguer** les tâches d'**exploration** : fouille large du dépôt,
  recherches documentaires, analyses transverses dont seule la conclusion
  importe — le sous-agent lit beaucoup, ne rapporte que l'essentiel.
- **Garder en direct** les **éditions normatives**, où la précision du texte
  prime : exigences et items OpenFastTrace, messages de commit — déléguer
  obligerait à transmettre les textes exacts et coûterait plus qu'éditer
  directement.
- Les sous-agents lancés en parallèle le sont **en un seul envoi** ; on ne
  relance pas soi-même une recherche déjà déléguée.

## 3. Commandes

L'orchestrateur est une façade interchangeable (ADR-0007) : la logique vit
dans `tools/*.sh`, appelables directement sans aucun runner.

| Commande (façade Task) | Équivalent direct | Effet |
| --- | --- | --- |
| `task` | — | liste des tâches |
| `task ci` | `sh tools/ci.sh` | **tout ce que la CI exécute**, voie constatée (`--complet`, `--rapide`) |
| `task trace` | `sh tools/oft.sh trace` | traçabilité complète (échoue si un maillon manque) |
| `task report` | `sh tools/oft.sh report` | rapport HTML dans `build/tracabilite.html` |
| `task check` | `sh tools/checks.sh` | contrôles de cohérence (ADR, templates, version) |
| `task secrets` | `sh tools/secrets.sh scan` | porte anti-secrets (gitleaks épinglé, ADR-0012) |
| `task liens` | `sh tools/liens.sh` | intégrité des liens internes de la documentation |
| `task audit` | `sh tools/audit.sh` | périmètre de l'audit de réalisation (`--squelette <domaine>`) |
| `task derive` | `sh tools/derive.sh` | anti-dérive des artefacts générés |
| `task matrice` | `sh tools/matrice.sh` | matrice de traçabilité (**informative**, absente de `task ci`) dans `docs/tracabilite/matrice.md` |
| `task regen` | — | régénère feuille de route, suivi de revue, audit, badges, avancement, matrice |
| `task issues` | `sh tools/issues.sh` | conformité des issues (**hors porte** : réseau requis) |
| `task hooks` | `git config core.hooksPath .githooks` | installe les hooks git du dépôt |
| `task setup` | `sh tools/setup.sh` | accueil après clone : bootstrap + hooks + portes |
| `task bootstrap` | `sh tools/bootstrap.sh` | dépendances, flux consenti : socle + modules du projet (`tools/bootstrap.d/`) |
| `task clean` (`-- --all` : cache inclus) | `sh tools/clean.sh` | nettoie les artefacts locaux (chemins déclarés uniquement) |
| `task adr-new -- titre` | `sh tools/adr-new.sh titre` | crée l'ADR suivant depuis le modèle |
| `task bump -- X.Y.Z` | `sh tools/bump.sh X.Y.Z` | met à jour VERSION (journal à compléter à la main) |

## 4. Interdits explicites

- Pousser, ouvrir ou fermer une pull request sans demande explicite du
  responsable du dépôt.
- Créer un item de spécification hors de `spec/` ou `docs/adr/`.
- Modifier un ADR accepté, un relevé figé ou une question ouverte résolue
  (l'addendum daté est la seule voie).
- Introduire une dépendance d'outillage sans ADR (le gabarit n'exige que git,
  un shell `sh` POSIX, curl et Java 17+ ; la façade d'orchestration — Task par
  défaut — est un confort optionnel, ADR-0007).
- Placer de la logique dans une façade d'orchestration (Taskfile, justfile…)
  ou dans une façade CI : la logique vit dans `tools/`, la façade délègue.
- Écrire en dur, dans une porte, un terme que le lexique déclare : la porte
  deviendrait muette — sans erreur — dans un projet instancié dans l'autre
  langue.
- Modifier à la main un artefact généré (index de feuille de route, suivi de
  revue, tableau de bord d'audit, badges, colonne Avancement de
  `spec/02-exigences/README.md`) ou une section de journal déjà publiée.

## 5. Décisions déjà arbitrées

Ne pas rouvrir sans nouvel élément : voir l'index des ADR (`docs/adr/README.md`)
et le registre des décisions (`docs/decisions/registre.md`).
