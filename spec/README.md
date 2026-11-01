# Spécification d'alm-forge

Ce répertoire applique à alm-forge sa propre méthode : le gabarit est son premier
projet instrumenté. La chaîne complète est vérifiée par OpenFastTrace à chaque
commit et en CI (voir [la méthode, chapitre traçabilité](../docs/methode/04-tracabilite.md)).

| Répertoire | Artefact | Type OFT | Identifiant |
| --- | --- | --- | --- |
| `01-besoins/` | Expression de besoin | feat | `feat~nom~rev` |
| `02-exigences/` | Exigence système | req | `req~nom~rev` |
| `../docs/adr/` | Décision de conception | dsn | `dsn~nom~rev` |
| code, docs, outillage | Implémentation | impl | tag `[impl->…]` |
| tests | Vérification mécanisée | utest / itest / stest | tag `[utest->…]` |

Les questions ouvertes (blocages en attente d'arbitrage humain) sont dans
[open-questions.md](open-questions.md).

Dans un projet instancié depuis ce gabarit, remplacez le contenu de `01-besoins/`
et `02-exigences/` par vos propres besoins et exigences, en conservant les
conventions décrites dans `docs/methode/`.
