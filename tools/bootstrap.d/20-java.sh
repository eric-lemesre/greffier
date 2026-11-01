# [impl->req~onboarding-outille~2]
# Module bootstrap — Java 17+ : requis par OpenFastTrace (ADR-0002).
# Vérifie la présence ET la version, contrairement aux outils à simple commande.
# Contrat : sourcé par tools/bootstrap.sh, PHASE=annonce puis PHASE=verifie.
case "${PHASE}" in
    annonce)
        echo "    - Java 17+ — traçabilité OpenFastTrace"
        ;;
    verifie)
        JV=""
        if command -v java >/dev/null 2>&1; then
            JV="$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -n1)"
        fi
        if [ "${JV:-0}" -ge 17 ] 2>/dev/null; then
            echo "ok — Java ${JV} (OpenFastTrace requiert 17+)"
        else
            echo "MANQUANT — Java 17+ (version détectée : ${JV:-aucune})"
            MANQUANTS=$((MANQUANTS + 1))
            ABSENTS="${ABSENTS} java"
            installer "Java 17+" "openjdk-17-jre-headless" "java-17-openjdk-headless" "openjdk@17" "EclipseAdoptium.Temurin.17.JRE"
        fi
        ;;
esac
