# Exemple — chaîne complète multi-langages


Démonstration minimale mais réelle de la méthode, du besoin jusqu'aux tests
mécanisés, avec la même exigence implémentée en **Python, Rust et shell** : la
traçabilité ne dépend pas du langage. Cet exemple est scanné par la même
commande `task trace` (ou `sh tools/oft.sh trace`) que le reste du dépôt — s'il casse, la CI casse.

| Maillon | Fichier |
| --- | --- |
| Besoin (feat) | `spec/specification.md` |
| Exigences (req) | `spec/specification.md` |
| Décision (dsn) | `docs/adr/0001-notifier-sur-la-sortie-standard.md` |
| Implémentations (impl) | `src/notify.py`, `src/notify.rs`, `src/notify.sh` |
| Tests (utest) | `tests/test_notify.py`, `tests/notify_test.rs` |

À lire en regard du chapitre [traçabilité](../../docs/methode/04-tracabilite.md) :
chaque fichier montre où placer les identifiants et les tags dans son langage.
