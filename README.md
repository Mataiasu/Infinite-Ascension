# Infinite Ascension

Prototype de jeu incremental RPG coopératif avec monde persistant et génération dynamique de contenu.

## Vision

- Solo et coop entre amis, 5 joueurs au départ
- Client Windows, Linux et Android
- Serveur autoritaire indépendant du client
- Monde persistant
- Niveau moyen du groupe utilisé pour faire avancer la frontière du monde
- Nouvelles zones, monstres, ressources, événements et boss au fil de la progression
- Système de Reborn : reset de progression temporaire, bonus permanents conservés
- Directeur IA : génération de contenu structurée, jamais autoritaire sur les règles du jeu
- Ollama prévu pour l’IA locale en développement et pour un service IA scalable en production
- Launcher séparé pour les mises à jour automatiques côté PC

## Structure

```text
Infinite-Ascension/
├── project.godot
├── Main.tscn
├── scripts/
│   └── game.gd
├── server/
│   ├── server.py
│   └── requirements.txt
└── .github/
    └── workflows/
```

## Développement

Le gameplay tourne dans Godot 4.x. Le serveur utilise FastAPI/WebSocket.

## Releases

Les builds publiques sont destinées à être publiées via GitHub Releases : Windows, Linux et Android.
