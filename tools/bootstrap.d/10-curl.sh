# Module bootstrap — curl : téléchargements épinglés de l'outillage ALM
# (jar OpenFastTrace, binaire gitleaks — ADR-0002, ADR-0012).
# Contrat : sourcé par tools/bootstrap.sh, PHASE=annonce puis PHASE=verifie
# (voir l'en-tête de bootstrap.sh pour les variables et aides disponibles).
case "${PHASE}" in
    annonce)
        echo "    - curl     — téléchargements épinglés (OpenFastTrace, gitleaks)"
        ;;
    verifie)
        verifier "curl (téléchargements épinglés)" curl \
            "curl" "curl" "curl" "cURL.cURL" \
            "requis par tools/oft.sh et tools/secrets.sh"
        ;;
esac
