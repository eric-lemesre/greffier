"""Tests mécanisés de l'exemple — niveau unitaire (Python)."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from notify import notifier


# [utest->req~notification-terminale~1]
def test_notification_contient_nom_et_duree():
    message = notifier("build", 42)
    assert "build" in message
    assert "42" in message


# [utest->req~echec-signale-distinctement~1]
def test_echec_porte_la_mention_echec():
    message = notifier("deploy", 7, succes=False)
    assert "ÉCHEC" in message
    assert "OK" not in message
