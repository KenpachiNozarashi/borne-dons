# Essais SumUp Solo : annulation et délai

Les appels du service Stripe restent inchangés. L’ancien point 8 est retiré : aucun suivi automatique au redémarrage, aucun blocage persistant de l’accueil, aucun bandeau sous le titre et aucun bouton « Vérifier le paiement ».

## Comportement retenu

- Bouton « Annuler le paiement » après 5 secondes, uniquement pendant un paiement SumUp non terminé. Un clic affiche « Annulation en cours… » et désactive les clics répétés.
- Le délai de 90 secondes commence après observation d’un Solo en ligne attendant la carte, le PIN, la signature ou le pourboire, pas au clic sur le montant.
- À expiration : demande d’arrêt au Solo s’il attend encore une action du donateur. Aucune tentative de forcer l’arrêt d’une autorisation bancaire en cours.
- Une réponse positive à la commande d’arrêt ne prouve pas l’annulation : le résultat du checkout et de la transaction est vérifié. Une réussite financière reste prioritaire.
- Après un résultat : bouton « Fermer » immédiat et fermeture automatique à 5 secondes. Message spécifique en cas de délai dépassé confirmé sans paiement abouti.
- Vérifications espacées de 2 secondes ; requêtes HTTP bornées à 4 secondes et interrompues à expiration. Aucun réessai automatique de création ou d’arrêt de paiement.
- Si le résultat reste inconnu : message « Résultat non confirmé », puis fermeture après 5 secondes et retour à l’accueil. Ce retour ne prouve pas que le Solo a arrêté le paiement : vérifier auprès du responsable avant de réessayer. Il n’y a ni reprise persistante, ni blocage après fermeture.
- Seul le journal technique local conserve les événements, sans clés API ni données de carte.

## Prérequis matériels

Le suivi de l’écran du Solo nécessite le logiciel 3.3.39.0 ou supérieur et les droits readers.read / readers.view. L’arrêt à distance nécessite au minimum 3.3.28.0 et readers.write / readers.checkouts.delete. Le suivi du checkout nécessite readers.checkouts.view.

Si l’état récent du lecteur ne peut pas être obtenu (hors ligne, droits manquants, ancien firmware), la borne ne peut pas identifier sa disponibilité : elle attend au maximum 60 secondes après acceptation, puis signale un résultat non confirmé. Elle ne prétend pas avoir annulé le paiement.

Après une demande d’arrêt, la confirmation est recherchée pendant une durée bornée : 15 secondes sur un terminal en attente, jusqu’à 30 secondes s’il peut être en traitement bancaire. Une dernière vérification suit. Ces durées viennent après le délai de paiement et les réponses réseau ajoutent leur latence.

## Essais Windows 11 et Solo physique

1. Lancer un paiement : vérifier le bouton « Annuler le paiement » à 5 secondes.
2. Annuler sur la borne sans présenter de carte : vérifier l’arrêt sur le Solo et la fermeture du résultat après 5 secondes.
3. Annuler directement sur le Solo : vérifier le retour rapide du résultat sans attendre 90 secondes.
4. Laisser le lecteur attendre : vérifier la demande d’arrêt à 90 secondes de disponibilité et le message de délai dépassé.
5. Faire aboutir un paiement pendant une annulation : une réussite confirmée ne doit jamais être affichée comme annulée.
6. Tester les doubles clics, la perte du réseau, une commande d’arrêt refusée et la fermeture manuelle des résultats.
7. Vérifier l’absence du bandeau, du bouton de vérification et de la reprise automatique après redémarrage.

Les tests automatisés utilisent des réponses SumUp simulées et ne remplacent pas la validation du matériel. Pour tester l’annulation physique sans paiement, ne présenter aucune carte.
