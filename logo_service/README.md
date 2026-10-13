# Détourage local des logos

Les images sont traitées en mémoire sur la machine qui exécute la borne.
Le serveur écoute uniquement sur `127.0.0.1:3002`. Aucun logo n’est envoyé à un tiers.
Le modèle U²-Net est téléchargé une fois, puis le traitement fonctionne hors ligne.
Les PNG déjà transparents sont conservés. Le résultat peut retirer des détails du logo :
le bouton « Garder le logo original » permet de revenir à l’image importée avant d’enregistrer.

## Installation Linux / macOS

Depuis la racine du dépôt, avec Python 3.11, 3.12 ou 3.13 :

```sh
python3 -m venv .logo-venv
.logo-venv/bin/python -m pip install -r logo_service/requirements.txt
.logo-venv/bin/python logo_service/server.py
```

## Installation Windows (PowerShell)

Depuis la racine du dépôt, avec Python 3.11, 3.12 ou 3.13 :

```powershell
py -3.12 -m venv .logo-venv
.\.logo-venv\Scripts\python.exe -m pip install -r logo_service\requirements.txt
.\.logo-venv\Scripts\python.exe logo_service\server.py
```

Attendre « Détourage local prêt » avant d’importer un logo.
Garder ce serveur ouvert à côté de Flutter. Arrêter avec Ctrl+C.
L’aperçu web local doit être servi sur `http://127.0.0.1:8080` ou `http://localhost:8080`.
Un hébergement public HTTPS nécessitera une intégration adaptée ; cette configuration vise
la borne et son navigateur local.

Si le service est indisponible, l’application conserve le logo original et affiche un message.
Les paramètres et les paiements continuent de fonctionner.
