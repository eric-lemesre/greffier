# 11. Cycle de vie des issues


Le dépôt est la mémoire, l'issue n'est que le lieu de coordination (principe
transverse 4) : toute décision finit dans `spec/`, `docs/adr/` ou
`docs/decisions/` — l'issue n'en est que le point de rendez-vous. Ce chapitre
décrit le parcours d'une issue, de son ouverture à sa fin de vie, pour les
trois flux d'un dépôt vivant. Processus éprouvé sur ergonomia
(`docs/00-organisation`), formulé en termes neutres de forge : étiquette,
assignation et commentaire existent partout (ADR-0010).

## Socle et défauts — ce qui s'arbitre à l'instanciation

Ce chapitre porte deux couches, arbitrées par l'ADR-0013 :

| Couche | Contenu | Statut |
| --- | --- | --- |
| **Socle** | la règle état/attente/acte ci-dessous ; le dépôt comme mémoire ; toute fin de vie motivée par écrit | **invariant** — s'applique à tout projet instancié |
| **Défauts** | flux `[Spec]`/`[Orga]`, jeu d'étiquettes, décideurs par domaine, valeurs (délais, limite de P1, cadences), automatismes | **arbitrable** — l'instanciateur adopte, adapte ou réduit, et le consigne au registre des décisions du projet |

Le socle ne dépend ni de l'équipe, ni du rythme, ni de la forge : il fonde
l'opposabilité des actes de coordination. Les défauts, eux, supposent un
contexte — un porteur solo n'a personne à consulter et peut réduire les flux
d'arbitrage à la question ouverte (ch. 6) ; une équipe de trois a besoin du
circuit complet. Sans choix explicite à l'instanciation, les défauts
s'appliquent tels quels. Un arbitrage est une décision : il se consigne, il ne
se constate pas après coup.

## La règle transverse : l'état, l'attente, l'acte — socle

| Artefact | Son rôle | Ses propriétés |
| --- | --- | --- |
| L'**étiquette** | dit l'**état** — où en est l'issue | se pose et se retire ; une seule étape à la fois ; ne prouve rien |
| L'**assignation** | dit **qui est attendu** — de qui le prochain geste dépend | se retire dès que la personne a fait son geste |
| Le **commentaire** | trace l'**acte** — ce qui a été fait, constaté, décidé | signé, daté, immuable ; cite la version quand l'acte porte sur une version ; **c'est lui qui fait foi** |

Trois conséquences, jamais négociées :

1. **Rien de nominatif dans une étiquette.** Quand un nom compte, c'est
   l'assignation qui le porte (tant que le geste est attendu) ou le
   commentaire (une fois le geste fait).
2. **Les automatismes dérivent l'état depuis l'acte, jamais l'inverse.** Un
   robot peut poser une étiquette ou désassigner quelqu'un *après* un
   commentaire ; aucun humain n'atteste en posant une étiquette, aucun robot
   ne décide à la place de quelqu'un.
3. **Aucun changement d'état sans motif écrit.** Retour en développement,
   clôture sans recette, changement de priorité : chaque transition
   s'accompagne d'un commentaire qui dit pourquoi.

Tout ce qui suit est le **défaut** du gabarit.

## Familles d'étiquettes

Quatre familles orthogonales — nature, enjeu, priorité, avancement —
l'avancement étant scindé en trois sous-familles :

| Sous-famille | Exclusivité | Rôle |
| --- | --- | --- |
| **étape** | une seule | où en est le parcours (`à-discuter`, `à-consulter`, `en-attente-de-PR`, `à-tester`, `à-clôturer`…) |
| **entrave** | cumulable | ce qui se superpose à une étape (`bloquant`, `en-attente-d-une-autre-issue`, `bug:régression`) |
| **sortie** | terminale | pourquoi l'issue est fermée (`livré` ; `doublon`, `invalide`, `ne-sera-pas-fait`, `abandonnée`, `différé`) |

La règle s'énonce alors sans exception : **une étape à la fois, autant
d'entraves que la réalité en impose, une seule sortie.**

Deux garde-fous contre la prolifération, leçons chiffrées d'ergonomia
(plusieurs étiquettes jamais employées en ~400 issues) :

- **ne jamais dupliquer dans une étiquette ce que la forge modélise déjà**
  (une PR liée, un jalon, l'état ouvert/fermé) : l'information tenue à deux
  endroits diverge, et c'est toujours la copie manuelle qui ment ;
- **créer une étiquette sur manque avéré, jamais par symétrie** : la question
  n'est pas « où sont les `bug:*` ? » mais « quel état manque au parcours
  d'une anomalie ? ».

## Les trois flux

```text
(ouverture) ─ à-discuter ── en-attente-de-PR ─ à-tester ─ à-clôturer ─ livré   (réalisation)

(ouverture) ─ à-consulter ─┬─ spec:prêt-à-acter ─ spec:actée                   ([Spec] exigence)
                           └─ orga:prêt-à-acter ─ orga:actée                   ([Orga] méthode)
```

Les deux circuits ne partagent aucun artefact : l'un produit du logiciel,
l'autre une décision.

### `[Spec]` — arbitrage d'une exigence

1. **Le document d'abord.** L'exigence est rédigée (EARS, ch. 2) et fusionnée
   en `Status: draft` — hors dénominateur de couverture — avant toute
   discussion : on ne débat pas d'une intention, on débat d'un texte citable,
   diffable et amendable.
2. **Consultation.** Une issue `[Spec]` (formulaire dédié) porte le niveau
   d'enjeu, l'étiquette `à-consulter` et l'assignation des intervenants
   attendus. Deux verbes distincts en commentaire : **`/vu`** — « j'ai pris
   connaissance », sans engagement — et **`/acter`** — « je valide les
   défauts proposés », qui engage son auteur. Si le texte change en cours de
   consultation, les lectures retombent : « j'ai lu » porte sur une version.
3. **Adoption sans séance.** Quand chaque point à trancher porte une option
   par défaut et un décideur nommé, le silence à l'échéance vaut absence
   d'objection, et l'`/acter` de tous les intervenants vaut adoption
   immédiate. Une objection n'envoie en séance que le point concerné.
4. **La décision s'écrit.** Relevé au registre `docs/decisions/` (ch. 3) ;
   décision structurante → ADR. L'exigence perd son `Status: draft` et entre
   au dénominateur ; l'issue est fermée en référençant le relevé.

### `[Orga]` — arbitrage d'un document d'organisation

Même circuit, objet différent : un document de méthode ou de gouvernance
(`docs/methode/`, `AGENTS.md` — dont toute modification exige un ADR). Les
étiquettes d'étape sont préfixées `orga:` pour que « où en sont les
arbitrages de spécification ? » reste une question filtrable.

### `[Feature]` / `[Bug]` — réalisation et anomalie

1. **Triage** (voir ci-dessous) : priorité et jalon, `à-discuter` seulement
   si un arbitrage manque.
2. **Ventilation.** Une demande trop large pour une PR devient une ou
   plusieurs exigences dans `spec/` ; l'issue quitte alors `à-discuter` pour
   `feat:spécifiée`, avec les identifiants créés en commentaire — elle est le
   fil qui les rassemble et se ferme quand toutes sont livrées. Une issue ni
   traitée, ni abandonnée, ni en discussion mais restée `à-discuter` est un
   état faux.
3. **Développement puis recette** (ch. 7) : `en-attente-de-PR` → `à-tester` →
   validations par commentaire citant la version → `à-clôturer` → fermeture
   par l'auteur de l'issue avec la sortie `livré`. Une PR ne ferme jamais une
   issue : fermer, c'est confirmer que le besoin est couvert.
4. **Régression.** `bug:régression` est une entrave, pas une étape : elle
   signale un garde-fou manquant, et son correctif n'est recevable
   qu'accompagné d'un test de non-régression (R3 appliqué à l'existant).

**Fins de vie.** Toute fermeture autre que `livré` se fait « non planifiée »,
motif en commentaire (le motif écrit est du socle ; le jeu de sorties est du
défaut) :

| Fin de vie | Sortie | Nature |
| --- | --- | --- |
| Livrée, testée, acceptée | `livré` | l'aboutissement normal |
| Doublon | `doublon` | le commentaire renvoie à l'issue conservée |
| Mal posée | `invalide` | le commentaire dit en quoi |
| Refusée | `ne-sera-pas-fait` | une **décision**, motivée par qui l'a prise |
| Non reproduite | `invalide` | un **constat** : le commentaire dit ce qui a été essayé, avec quelle version |
| Abandonnée | `abandonnée` | un **silence** : personne ne porte plus le besoin |
| Reportée | `différé` | avec sa **condition de réouverture** — un jalon si la condition est une échéance |

Refus et abandon ne pèsent pas pareil : rouvrir une issue abandonnée est
naturel, rouvrir une issue refusée demande de rediscuter la décision.

## Triage : la gravité se constate, la priorité se décide

- **La gravité est un fait**, décrit par le déclarant dans le formulaire
  d'anomalie : **critique** (pas de contournement, ou données à risque),
  **gênant** (contournement coûteux), **mineur** (confort). Elle n'a pas
  d'étiquette : elle vit dans le texte de l'issue.
- **La priorité est une décision**, prise au triage — jamais demandée à la
  création — et définie par le *quand*, pas par le domaine :

| Étiquette | Quand s'en occupe-t-on ? |
| --- | --- |
| `P1` | **Avant tout le reste.** La prochaine session de travail commence par là. |
| `P2` | **Dans le jalon en cours ou le suivant.** |
| `P3` | **Un jour.** Au backlog, repassé en revue à chaque changement de jalon. |

- **Limite : jamais plus de 5 issues en P1** (défaut). Poser la sixième
  oblige à en redescendre une — et à dire laquelle et pourquoi, en
  commentaire. C'est l'antidote au « tout est P1 ».
- La gravité éclaire la priorité sans la fixer : un bug critique sur un écran
  que personne n'utilisera avant le jalon suivant peut attendre en `P2`, et
  le triage le dit.
- Revue périodique (hebdomadaire par défaut) des issues sans priorité ; le
  triage ne juge pas le fond, il répond à une seule question : **quand ?**

## Niveaux d'enjeu : la charge suit la réversibilité

| Niveau | Critère | Circuit |
| --- | --- | --- |
| **S — structurant** | porte irréversible : modèle de données, sécurité, conformité, engagement | circuit complet, arbitrage collégial obligatoire — et menaces STRIDE examinées (ch. 10) |
| **F — fonctionnel** | réversible en quelques jours | consultation asynchrone ; décision du décideur du domaine sauf objection dans le délai |
| **É — éditorial** | clarification sans effet sur une exigence | simple PR, aucune issue |

Le niveau est proposé par l'auteur ; **tout intervenant peut le relever,
personne ne l'abaisse seul**. Un doute se tranche vers le haut. L'enjeu n'est
pas la priorité : la priorité dit *quand* traiter, l'enjeu dit *quelle
cérémonie* appliquer — un sujet `P3` et structurant est précisément la
combinaison la plus dangereuse à traiter à la légère.

## Une spécification validée ne ferme rien

Une demande ne se ferme qu'à **la livraison**, ou par une sortie négative
motivée. Il n'y a pas de troisième sortie — et en particulier, **la validation
de la spécification n'en est pas une** : elle fait passer la demande d'« à
spécifier » à « spécifiée », état d'**attente** et non état terminal. Une
demande ventilée en plusieurs spécifications se ferme quand toutes sont
livrées ; elle est le fil qui les rassemble.

La raison est de fond : fermer à la spécification confond **l'artefact et le
besoin**. Personne ne demande une spécification — on demande que quelque chose
marche. Fermer à la spec revient à déclarer satisfait un besoin qui ne l'est
pas, et coupe au milieu la chaîne que cette méthode revendique : redescendre
de n'importe quelle demande jusqu'au test qui prouve qu'elle est tenue. Une
demande fermée à la spec ne redescend nulle part.

> **La leçon de méthode, plus large que le cas.** Ergonomia portait la règle
> inverse. La mesure l'a tranchée : **zéro** demande y a jamais été fermée à la
> validation de sa spécification, contre trente et une fermées à la livraison.
> Quand la totalité de la pratique dément une règle écrite, **c'est la règle
> qui est fausse** — pas la pratique. Avant de rappeler une règle à l'ordre,
> compter combien de fois elle a été suivie.

**Effet de bord assumé** : le nombre de demandes ouvertes augmente. C'est le
prix de l'exactitude — mieux vaut quarante demandes ouvertes dont l'état est
juste que trente fermées dont aucune n'est livrée à qui l'avait réclamée. En
contrepartie, le filtre « ouverte **et** spécifiée » devient le stock des
**engagements pris et non tenus**, qui n'était lisible nulle part.

Corollaire, qui rejoint le chapitre 13 : une fois la séance passée,
**l'arbitrage se lit dans le statut du fichier de spécification, pas dans une
étiquette**. L'étiquette dit où en est la demande ; le fichier dit ce qui est
décidé. Les faire porter la même information, c'est garantir qu'ils
divergeront.

## Familles : qualifier sans créer un second état

Les préfixes `bug:` et `feat:` (empruntés aux Conventional Commits, et
volontairement non traduits) qualifient la **nature** d'une demande —
`bug:régression`, `bug:données`, `feat:à-spécifier` — sans jamais dire où elle
en est. Ce sont des entraves ou des qualificatifs cumulables, pas des états.

La question se pose naturellement après l'introduction d'un espace de noms
d'arbitrage pour les spécifications : faut-il le même pour les anomalies et
les demandes ? La réponse tient à ce que cet espace réglait réellement. Une
spécification ne produit pas du logiciel mais **une décision** : entre « on en
discute » et « c'est décidé », il y a une étape que la chaîne d'avancement
ordinaire ne portait pas. Les anomalies et les demandes, elles, suivent déjà
cette chaîne de bout en bout — leur ajouter un espace de noms d'état
dupliquerait ce qui existe.

D'où la règle : **une famille qualifie, elle ne positionne pas**. Un
qualificatif qui commence à répondre à « où en est-on ? » est un état
déguisé — et deux systèmes d'état sur une même issue, c'est la garantie qu'ils
divergeront.

Créer une famille demande une justification chiffrée : combien d'issues
existantes en relèvent ? Un jeu d'étiquettes qui grossit sans que personne ne
filtre dessus est un coût de saisie sans contrepartie.

## Automatismes — fournis prêts à câbler, non câblés dans le gabarit


Les automatismes de coordination vivent côté forge. Le gabarit les **fournit**
dans [`templates/forge/`](../../templates/forge/README.md) — logique unique en
POSIX sh, façades de déclenchement pour GitHub et GitLab (ADR-0007, ADR-0010),
vocabulaire pris au lexique (ADR-0015) — et ne les **câble pas**.

| Automatisme | Déclencheur | Effet |
| --- | --- | --- |
| lecture | commentaire `/vu` sur une consultation | coche la case du lecteur, le désassigne |
| retombée | fusion modifiant un document consulté | décoche les lectures, réassigne, commente le comparatif |
| à clôturer | liste de vérification complétée | pose l'étiquette de clôture, prévient l'auteur |
| dormantes | planification hebdomadaire | rappelle les recettes sans activité |
| fermeture | pose d'une sortie négative | ferme en « non planifiée » |

**Portes non câblées** (R7) — raison : elles écrivent sur les issues d'une
forge, donc exigent une API, un jeton et des droits que le gabarit n'a pas ;
leur cas d'échec ne peut être éprouvé que sur un dépôt vivant. Échéance : à
l'instanciation, si le projet retient le circuit de consultation outillé.

Le projet qui les câble teste chaque automatisme sur son cas d'échec (R3) et
respecte le sens unique du socle : **l'automatisme dérive l'état depuis
l'acte, jamais l'inverse, et signale sans décider**. L'étiquette de clôture
n'est jamais posée à la main — elle reflète l'état d'une liste ; et la poser
ne ferme rien, la clôture revenant à l'auteur.

Deux pièges vécus, à connaître avant de câbler : la retombée des lectures doit
**exclure les documents de procédure** (cités par le gabarit d'issue, ils
faisaient retomber toutes les consultations à la fois), et un rappel ne doit
pas **se rappeler lui-même** — son propre commentaire rafraîchit l'activité de
l'issue, ce qui est précisément la garde qui l'empêche de boucler.

## Conformité des issues — un rapport, pas une porte


`tools/issues.sh` confronte les issues ouvertes au cycle de vie ci-dessus :
étiquette d'état unique, assignation présente quand une attente existe,
sortie négative jamais laissée sur une issue ouverte.

Il est **délibérément hors de la porte de vérification**. Il appelle l'API de
la forge, donc dépend du réseau et d'une session authentifiée — exactement ce
que les portes évitent pour rester reproductibles sur un poste déconnecté. Il
sert la revue de triage, pas l'intégration continue : la porte vérifie le
dépôt, pas la conformité organisationnelle des issues. Sans session, il
s'interrompt avec un message explicite et ne fait échouer aucune
vérification.

## Arbitrer les défauts à l'instanciation

L'arbitrage (ADR-0013) se rend à l'instanciation : l'option
L'option `--cycle-issues complet|reduit` de l'instanciation applique le choix
des flux
et le consigne au registre des décisions du projet — y compris quand c'est le
défaut qui s'applique, comme pour la politique d'attribution (ADR-0011). Il
porte sur :

- **les flux d'arbitrage** `[Spec]`/`[Orga]` : adoptés tels quels (`complet`,
  défaut), adaptés, ou réduits (`reduit` — les formulaires de consultation
  sont retirés, un porteur solo remplace la consultation par le registre des
  questions ouvertes, ch. 6, et l'ADR) ;
- **le jeu d'étiquettes** : créé sur la forge au démarrage, réduit au besoin
  avéré du projet ;
- **les décideurs par domaine** : qui tranche quoi, dérivé de l'équipe
  réelle ;
- **les valeurs** : délai de consultation (10 jours ouvrés), limite de P1
  (5), cadence de la revue de triage (hebdomadaire), cadence des séances
  d'arbitrage (mensuelle) ;
- **l'outillage des automatismes** ci-dessus.

Le socle — l'état, l'attente, l'acte — ne s'arbitre pas : un projet qui veut
y déroger ne configure pas le gabarit, il change de méthode par ADR local, en
en assumant la trace.
