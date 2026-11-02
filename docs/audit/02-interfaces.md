# Audit — 02-interfaces

<!-- Miroir de spec/02-exigences/02-interfaces.md. Les verdicts sont écrits À
     LA MAIN : c'est le jugement que la porte ne sait pas rendre. Le tableau
     de bord docs/audit/README.md, lui, est généré — ne pas l'éditer.
     Squelette des lignes manquantes :
       sh tools/audit.sh --squelette 02-interfaces -->

Verdicts admis : `conforme` · `écart` · `non examiné`.

Domaine actif depuis D-2026-11-06 : quatre exigences approuvées, réalisées
au lot 4 (ADR-0004).

| Exigence | Verdict | Preuve / écart |
| --- | --- | --- |
| `req~source-de-chaque-element~1` | conforme | `src/recherche.rs` : `Ancres::source` rend le lien conservé à la capture (en-tête `source`), celui de la version en vigueur à la date pour un identifiant chronologique ; chaque élément rendu porte ses `sources` (ligne de commande, MCP, HTTP) ; tests `une_page_rendue_porte_le_lien_de_la_version_en_vigueur_de_l_article_cite`, `une_decision_rendue_porte_le_lien_conserve_a_sa_capture` |
| `req~outils-mcp~1` | conforme | `src/mcp.rs` (SDK `rmcp`) et `src/service.rs` : quatre outils en lecture seule, date et mention dans chaque réponse de `chercher` et `lire_texte` ; `greffier mcp` (stdio) et `/mcp` (HTTP) ; tests unitaires de `service.rs`, test d'intégration `un_agent_mcp_liste_les_quatre_outils_et_ne_recoit_que_de_l_ancre` (session JSON-RPC réelle : liste, recherche sans élément non ancré, refus d'une citation inventée) |
| `req~api-http~1` | conforme | `src/http.rs` (axum) : routes `/recherche`, `/textes/{identifiant}`, `/citations/verification`, `/savoir/verification`, `/sante` ; erreurs JSON (400, 404, 500) sans chemin ni secret (`ErreurPublique`) ; test d'intégration `l_api_rend_des_elements_ancres_et_sources_et_des_erreurs_en_json` |
| `req~acces-http-protege~1` | conforme | `src/http.rs` : `controler_ecoute` refuse une écoute hors boucle locale sans `GREFFIER_JETON` ; jeton porteur comparé à temps constant sur toute route hors `/sante`, MCP compris ; en-tête `Host` contrôlé sur tout le routeur (boucle locale, adresse d'écoute, `--hote`), 403 sinon, contre le rattachement DNS ; tests `une_requete_sous_un_hote_non_admis_est_refusee_meme_en_local`, `le_nom_d_hote_est_lu_sans_son_port`, `hors_de_la_boucle_locale_le_jeton_est_exige`, `hors_de_la_boucle_locale_sans_jeton_le_serveur_refuse_de_demarrer`, `avec_un_jeton_toute_requete_sans_lui_est_refusee_sauf_la_sante` (jeton absent de l'annonce de démarrage) |
| `req~savoirs-multiples~1` | conforme | `src/configuration.rs` (`depots`, `controler_nom`), `src/http.rs` (routes `/savoirs/{nom}/…`, MCP par dépôt, routes de la 0.2.0 sur `defaut`, `depot_vise`) ; `tests/savoirs_itest.rs` : deux dépôts, dépôt inconnu 404, routes de la 0.2.0 ; tests unitaires des noms refusés |
| `req~jetons-a-portee~1` | conforme | `Clients::rassembler` et `reconnaitre` (empreintes SHA-256 à temps constant), `controler_acces` (401 sans jeton connu, 404 hors portée, `/savoirs` filtré) ; `tests/savoirs_itest.rs` : portée limitée, réponse hors portée identique à l'inconnu, empreinte, environnement prioritaire et signalé |
