# Borne de dons — versions candidates

Ces fichiers doivent être validés sur la machine cible avant tout encaissement réel.

## Windows 11 — PC Intel / AMD 64 bits

Extraire toute l’archive dans un dossier permanent, puis ouvrir directement `borne_dons.exe`.
Conserver le dossier `logo-service`, les DLL et le dossier `data` à côté de l’exécutable.
Le runtime Microsoft Visual C++ 2015–2022 x64 peut être nécessaire.

## Ubuntu — PC Intel / AMD 64 bits

Paquet compilé sur Ubuntu 22.04. À tester sur la version exacte de la borne.
Installer les dépendances système :

```sh
sudo apt install libgtk-3-0 libsecret-1-0 gnome-keyring
```

Une session graphique et un trousseau de clés disponible sont nécessaires.
Extraire toute l’archive, puis lancer :

```sh
chmod +x borne_dons logo-service/logo-service
./borne_dons
```

L’application démarre automatiquement le service de détourage local. Aucun lanceur séparé n’est nécessaire.
Le modèle de détourage est inclus dans les archives produites ; aucun téléchargement
supplémentaire n’est nécessaire pour détourer les logos sur place.

## Paramétrage et validation

Créer la configuration en mode simulateur, puis vérifier l’affichage de la borne,
les montants, l’import du logo et le parcours de don.
Après configuration, les paramètres sont accessibles en maintenant 5 secondes
à l’ancien emplacement de la roue dentée, en haut à droite.

Tester ensuite Stripe avec une configuration de test appropriée, puis faire valider
le fonctionnement du terminal réel par le responsable avant la mise en production.
L’accès caché évite les ouvertures accidentelles ; il n’est pas une authentification.

## Mise à jour

Fermer l’application et le service de détourage, puis remplacer le dossier de distribution.
Les réglages sont stockés sur la machine, en dehors du dossier de l’application.
Ne pas effacer le profil utilisateur ou son trousseau de clés.

Le verset et sa traduction sont intégrés comme valeurs par défaut. Les textes déjà enregistrés restent prioritaires pour préserver la personnalisation.
