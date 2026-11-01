"""Notification de fin de tâche — implémentation Python."""


# [impl->req~notification-terminale~1]
# [impl->req~echec-signale-distinctement~1]
def notifier(nom: str, duree_s: int, succes: bool = True) -> str:
    etat = "OK" if succes else "ÉCHEC"
    message = f"[{etat}] {nom} ({duree_s} s)"
    print(message)
    return message
