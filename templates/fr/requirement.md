# Exigences — domaine {{ domaine }}

**Statut : PROPOSITION** — passe ACTIVE quand une décision du registre l'acte.

<!-- À placer dans spec/02-exigences/. Un fichier par domaine fonctionnel.
     Le statut ci-dessus est celui du DOMAINE : il dit si le document est
     arbitré. Celui de chaque exigence, ci-dessous, dit où en est SA
     réalisation. Deux axes, deux questions (ADR-0018). -->

## {{ Titre lisible de l'exigence }}

`req~nom-en-kebab~1`

**Statut : brouillon**

<!-- Déclarés : brouillon · proposée · approuvée · rejetée · dépréciée.
     JAMAIS déclarés : « implémentée » et « vérifiée » — ils se CALCULENT
     depuis la couverture réellement posée, et la porte refuse qu'on les
     écrive. Une exigence n'est approuvée que dans un domaine actif. -->

{{ Formulation EARS avec niveau normatif DOIT / DEVRAIT / PEUT :
- Ubiquitaire : Le système DOIT …
- Événementiel : Quand <déclencheur>, le système DOIT …
- À état : Tant que <état>, le système DOIT …
- Comportement indésirable : Si <condition non voulue>, alors le système DOIT …
- Optionnel : Là où <la fonctionnalité existe>, le système DOIT … }}

Rationale:
{{ Justification, si le motif n'est pas évident. }}

Critères d'acceptation :

- Étant donné {{ contexte }}, quand {{ action }}, alors {{ résultat vérifiable }}.
- Étant donné {{ cas défavorable }}, quand {{ action }}, alors {{ comportement attendu }}.

Covers:

- feat~besoin-parent~1

Needs: impl, utest

<!-- Needs selon le niveau de vérification déclaré : dsn si une décision de
     conception est attendue ; utest / itest / stest / mtest selon le niveau
     de test (méthode, ch. 5). -->
