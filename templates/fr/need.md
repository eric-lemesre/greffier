# Besoin — {{ titre lisible }}

<!-- À placer dans spec/01-besoins/. Un fichier peut regrouper plusieurs
     besoins d'un même domaine. -->

## {{ Titre du besoin }}

`feat~nom-en-kebab~1`
Status: draft

<!-- « Status: draft » (collé sous l'identifiant) tient le besoin hors de la
     porte de traçabilité ; on le retire quand ses exigences sont approuvées
     (ADR-0021). -->

{{ Ce que le porteur veut obtenir, en langage métier, sans solution technique.
La forme user story (En tant que… je veux… afin de…) est admise ici. }}

Rationale:
{{ Pourquoi ce besoin existe, quelle valeur il produit. C'est cette
justification qui permettra d'arbitrer les cas que le texte ne prévoit pas. }}

Needs: req

<!-- Métadonnées hors outil, à conserver dans la prose du fichier :
     - Porteur : {{ qui exprime le besoin et arbitrera les questions ouvertes }}
     - Sources : {{ renvois vers spec/01-besoins/sources/ }} -->
