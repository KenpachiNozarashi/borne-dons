# Initialisation SumUp sur Windows : correctif TLS

## Constat vérifié

Sur la borne, l’ancien client Dart échoue avec `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`. Au même moment, `curl.exe` utilisant Schannel valide HTTPS vers le même domaine et reçoit HTTP 404 sur `/` (réponse attendue pour ce test sans identifiants).

L’archive historique fournie date du 12 octobre 2026 et contient le moteur deb287481e et Dart 3.13.5, identiques au SDK Flutter 3.47.7 utilisé ici. Le code original du collègue emploie la même requête d’association. Les éléments disponibles ne prouvent donc ni une régression du SDK ni une erreur des clés ; ils montrent une différence de validation TLS dans les conditions de l’essai. L’émetteur exact manquant n’est pas identifié.

## Changement

- Sous Windows uniquement, le transport SumUp utilise rhttp 0.18.0 et sa validation de plateforme Windows (rustls-platform-verifier).
- Vérification des certificats et du nom du serveur maintenue. Aucun certificat embarqué ajouté à la confiance, aucun contournement `badCertificateCallback`.
- Destination limitée à HTTPS, api.sumup.com, port 443, sans identifiants dans l’URL. Redirections désactivées pour éviter la transmission des clés à un autre domaine.
- Pas de relance automatique des POST. Les interruptions HTTP existantes sont reliées au jeton natif ; l’interface reste asynchrone.
- L’association est bornée à 15 secondes et affiche les erreurs sans réponse serveur brute ni clés. Une expiration ne prouve pas que le Solo n’a pas reçu l’association.
- Un code déjà enregistré ne permet plus de sauter l’association lorsqu’aucun lecteur n’est enregistré ou que le compte marchand a changé.
- Le service Stripe et les transports web/Linux restent inchangés.

## Validation

Le workflow Windows compile et exécute le véritable exécutable livré avec son DLL rhttp : accès HTTPS sans identifiants à SumUp, puis rejet obligatoire d’un certificat local auto-signé. Le rapport est publié dans l’artefact `diagnostic-tls-windows`. Le mode `--tls-diagnostic` est réservé à ce test avec `tool/tls_fixture.py` actif ; il ne charge pas les réglages et ne lance aucun paiement.

Sur la borne : conserver l’ancienne version, extraire entièrement la nouvelle archive (dont rhttp.dll), fermer l’ancienne application et ouvrir le nouvel exécutable. Ne supprimer aucun réglage. Vérifier l’association avec un code Solo valide, puis vérifier le parcours sans carte avant tout essai de paiement. La validation CI ne remplace pas cet essai sur le poste concerné.

Dépendance MIT, source : https://pub.dev/packages/rhttp ; vérificateur : https://github.com/rustls/rustls-platform-verifier
