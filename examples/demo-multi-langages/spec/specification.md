# Spécification de l'exemple

## Besoin

### Être prévenu de la fin d'une tâche longue

`feat~notification-fin-de-tache~1`

En tant qu'utilisateur lançant des tâches longues, je veux être prévenu quand
une tâche se termine, afin de ne pas surveiller l'écran.

Rationale:
La surveillance manuelle fait perdre le bénéfice de l'automatisation.

Needs: req

## Exigences

### Notification en fin de tâche

`req~notification-terminale~1`

Quand une tâche se termine, le système DOIT émettre une notification
comportant le nom de la tâche et sa durée.

Critères d'acceptation :

- Étant donné une tâche nommée « build » durant 42 s, quand elle se termine,
  alors la notification contient « build » et « 42 ».

Covers:
- feat~notification-fin-de-tache~1

Needs: dsn, impl, utest

### Échec signalé distinctement

`req~echec-signale-distinctement~1`

Si la tâche s'est terminée en échec, alors la notification DOIT le signaler
distinctement du succès.

Rationale:
Motif EARS « comportement indésirable » : le cas d'échec exige son propre test.

Critères d'acceptation :

- Étant donné une tâche en échec, quand la notification est émise, alors elle
  porte la mention ÉCHEC.

Covers:
- feat~notification-fin-de-tache~1

Needs: impl, utest
