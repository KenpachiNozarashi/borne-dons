## English translation at the bottom

# Donation POS

Une application Flutter minimale conçue pour collecter des dons via Stripe ou Sumup. Ce projet sert de système de Point de collecte léger qui guide les utilisateurs à travers la configuration du dispositif et permet le traitement sécurisé des paiements.

## 🚀 Fonctionnalités

- **Stockage Local Sécurisé** : Utilise `SharedPreferences` et `SecureStorage` pour stocker en toute sécurité les clés API Stripe et les identifiants du terminal sur l'appareil.
- **Mise en route** : Vérifie automatiquement la configuration au lancement.
  - Si configuré : Lance directement l'écran de **Paiement**.
  - Si non configuré : Lance l'écran de **Configuration** pour permettre à l'utilisateur de configurer l'application pour fonctionner avec Stripe ou Sumup.
- **UI Minimaliste** : Dispose d'un thème épuré pour une expérience utilisateur simple.

## 📂 Structure du Projet (source)

```
lib/
├── main.dart                           # Point d'entrée de l'application & gestionnaire de démarrage
├── core/
│   ├── constants.dart                  # Constantes de l'application
│   └── theme.dart                      # Définitions du thème
├── services/
│   └── storage_service.dart            # Gère le stockage local et les clés sécurisées
|   └── stripe_service.dart             # Gère les tâches liées à l'API Stripe
|   └── sumup_service.dart              # Gère les tâches liées à l'API Sumup
└── features/
    ├── colorpicker/
    │   └── colorpicker_dialog.dart     # Gère la fonction de sélection de couleur
    ├── setup/
    │   └── setup_screen.dart           # Écran d'inscription et de configuration
    └── payment/
        ├── widgets/
        |   └── amount_grid.dart        # Affiche le montant
        |   └── custom_stepper.dart     # Affiche 3 étapes en bas de l'application
        |   └── payment_dialog.dart     # Affiche les informations pendant la transaction
        └── payment_screen.dart         # Interface de collecte de dons
```

## 🛠️ Stack Technique

- **Flutter** : Framework UI pour le développement mobile cross-platform.
- **Dart** : Langage de programmation.
- **Stockage Local** : `SharedPreferences` (clés standards) & `SecureStorage` (crédentiels sensibles).

## 📝 Flux d'Utilisation

1. Obtenez votre version compilée (release).
2. Lancez l'application.
3. Remplissez les informations concernant votre association.
4. Sélectionnez votre fournisseur de paiement.
5. Entrez les clés requises
   ### Où trouver les informations nécessaires sur Sumup :
   1. Cliquer sur l'icone en haut à gauche pour pouvoir copier votre numéro commerçant
   2. Ensuite ouvrez les paramètres et déscendez pour trouver la section **Développeurs**
   3. Ouvrez la tab Clés APi et créez une nouvelle clé (la clé publique ne suffit pas)
      **Nommez la et n'oubliez pas de la copier**
   4. Ouvrez ensuite la tab Clés d'affiliation
   5. Vous y trouverez votre clé d'affiliation
   6. Il ne vous reste qu'à créer votre ID d'application 
    #### Vous avez désormais votre numéro commerçant, votre clé api, votre ID d'application et votre clé d'affiliation

    https://github.com/user-attachments/assets/9a551e37-7c1c-42b4-a8bd-73ce53c62404

  ### Comment obtenir le pairing code sur le terminal Solo
  1. Configurer le terminal pour le wifi et mettre à jour si besoin
  2. Toucher et glisser vers le bas de l'écran
  3. Sélectionner le mode Cloud API
  4. saisir le code qui apparait dans l'application
    
  https://github.com/user-attachments/assets/9a4d710a-09d7-437c-9d88-4981a5127e6f




7. Cliquez sur **Initialiser la borne**.

## ⚠️ Notes Importantes

- **Permissions** : Assurez-vous que l'application dispose des permissions de stockage nécessaires sur l'appareil cible.
- **Sécurité** : Les clés sensibles sont stockées en toute sécurité ; assurez-vous que l'appareil n'est pas rooté/jailbreaké en production.

---


# Donation POS

A minimal Flutter application designed for collecting donations via Stripe or Sumup Terminal. This project serves as a lightweight Point of Sale (POS) system that guides users through device setup and enables secure payment processing.

## 🚀 Features

- **Secure Local Storage**: Utilizes `SharedPreferences` and `SecureStorage` to safely store Stripe API keys and reader credentials on the device.
- **Smart Bootstrapping**: Automatically checks for configuration upon launch.
  - If configured: Launches directly to the **Payment Screen**.
  - If unconfigured: Launches the **Setup Screen** to let the user setup the app to work with either Stripe or Sumup.
- **Minimalist UI**: Features a clean theme for a modern user experience.

## 📂 Project Structure (source)

```
lib/
├── main.dart                           # App entry point & bootstrapper
├── core/
│   ├── constants.dart                  # App-wide constants
│   └── theme.dart                      # Shadcn-style theme definitions
├── services/
│   └── storage_service.dart            # Handles local storage & secure keys
|   └── stripe_service.dart             # Handle Stripe API related tasks
|   └── sumup_service.dart              # Handles Sumup API related tasks
└── features/
    ├── colorpicker/
    │   └── colorpicker_dialog.dart     # Handles color selection feature
    ├── setup/
    │   └── setup_screen.dart           # Onboarding & configuration UI
    └── payment/
        ├── widgets/
        |   └── amount_grid.dart        # Displays amount
        |   └── custom_stepper.dart     # Displays 3 steps at the bottom of the app
        |   └── payment_dialog.dart     # Displays information during transaction
        └── payment_screen.dart         # Donation collection interface
```

## 🛠️ Tech Stack

- **Flutter**: UI framework for cross-platform mobile development.
- **Dart**: Programming language.
- **Local Storage**: `SharedPreferences` (standard keys) & `SecureStorage` (sensitive credentials).

## 📝 Usage Flow

1. Get your compiled release.
2. Launch the app.
3. fill up information about your association
4. Select your payment provider
5. Enter the required keys and 
6. Click **Initialiser la borne**

## ⚠️ Important Notes

- **Permissions**: Ensure the app has necessary storage permissions on the target device.
- **Security**: Sensitive keys are stored securely; ensure the device is not rooted/jailbroken in production.

