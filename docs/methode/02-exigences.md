# 2. Exigences

<!-- [impl->req~format-exigence-ears~1] -->
<!-- [impl->req~cycle-de-vie-exigence~2] -->

Une exigence est un contrat vérifiable entre le besoin et la réalisation.
Format acté par l'[ADR-0004](../adr/0004-rediger-les-exigences-selon-ears.md) :
item OpenFastTrace de type **req**, formulation EARS, niveau normatif, critères
d'acceptation.

## Anatomie d'une exigence

Sous un titre de section lisible (« ## Accusé de réception du formulaire ») :

```markdown
`req~identifiant-en-kebab~1`

Quand l'utilisateur soumet le formulaire, le système DOIT accuser réception
en moins de 2 secondes.

Rationale:
Au-delà de 2 secondes, le taux d'abandon mesuré double (source : étude X).

Critères d'acceptation :

- Étant donné un formulaire valide, quand il est soumis, alors l'accusé
  apparaît en moins de 2 secondes.
- Étant donné un serveur indisponible, quand le formulaire est soumis, alors
  un message d'erreur explicite est affiché.

Covers:
- feat~besoin-parent~1

Needs: dsn, impl, utest
```

## Les cinq motifs EARS

| Motif | Gabarit (français) | Exemple |
| --- | --- | --- |
| Ubiquitaire | Le système DOIT… | Le système DOIT journaliser tout accès aux données de santé. |
| Événementiel | **Quand** \<déclencheur\>, le système DOIT… | Quand un fichier est déposé, le système DOIT l'analyser. |
| À état | **Tant que** \<état\>, le système DOIT… | Tant que le mode maintenance est actif, le système DOIT refuser les écritures. |
| Comportement indésirable | **Si** \<condition non voulue\>, **alors** le système DOIT… | Si la signature est invalide, alors le système DOIT rejeter le message et alerter. |
| Fonctionnalité optionnelle | **Là où** \<la fonctionnalité existe\>, le système DOIT… | Là où l'envoi SMS est configuré, le système DOIT notifier par SMS. |

Les motifs se combinent (Quand + Si…). Une phrase qui n'entre dans aucun motif
est presque toujours plusieurs exigences déguisées : découper.

## Niveaux normatifs

- **DOIT** : obligatoire, la non-conformité est un défaut.
- **DEVRAIT** : recommandé, s'en écarter exige une justification tracée.
- **PEUT** : permis, sans engagement.

Seules les exigences DOIT et DEVRAIT entrent au dénominateur de la couverture.

## Qualités exigées (inspirées de l'ingénierie des exigences classique)

Une exigence est : **nécessaire** (rattachée à un besoin — c'est le Covers),
**non ambiguë** (une seule lecture possible), **singulière** (une exigence, un
comportement), **vérifiable** (ses critères d'acceptation sont testables),
**cohérente** (ne contredit ni une autre exigence ni un ADR). La revue de PR
contrôle ces qualités ; la traçabilité contrôle les relations.

## Cycle de vie

```text
brouillon ──▶ proposée ──▶ approuvée ──▶ implémentée ──▶ vérifiée
     │             │
     └─────────────┴──▶ rejetée / dépréciée
```

- Le statut se lit dans la traçabilité, pas dans une colonne tenue à la main :
  une exigence est *implémentée* quand ses tags impl existent, *vérifiée* quand
  ses tests tagués passent. Les états amont (brouillon, proposée, approuvée)
  utilisent le mot-clé Status d'OpenFastTrace quand il faut exclure une
  exigence du dénominateur.
- **Toute modification du texte normatif incrémente la révision** de
  l'identifiant (par exemple rev 1 → rev 2). Les couvertures pointant l'ancienne
  révision deviennent des défauts de traçabilité : c'est voulu, chaque site
  d'implémentation doit être revisité et re-tagué en conscience.
- Une exigence ne se supprime pas : elle passe dépréciée (avec le motif et la
  date), et ses couvertures sont retirées.
