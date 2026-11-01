//! Tests mécanisés de l'exemple — niveau unitaire (Rust).

// [utest->req~notification-terminale~1]
#[test]
fn notification_contient_nom_et_duree() {
    let message = notifier("build", 42, true);
    assert!(message.contains("build"));
    assert!(message.contains("42"));
}

// [utest->req~echec-signale-distinctement~1]
#[test]
fn echec_porte_la_mention_echec() {
    let message = notifier("deploy", 7, false);
    assert!(message.contains("ÉCHEC"));
}
