# Crédits et provenance

## Conception et réalisation

Projet préparé pour **Darknigthmare** en 2026.

## Assets

MECHA OVERDRIVE — Circuit Zero ne charge aucun asset tiers. Le projet contient un key art original produit avec l’outil de génération d’images OpenAI et conservé dans `media/openai/mecha-overdrive-hero.png` :

- génération commandée spécifiquement pour ce jeu le 21 août 2026 ;
- aucune image de référence sous licence ni aucun asset officiel n’a été fourni au modèle ;
- prompt complet et contraintes d’originalité archivés dans `docs/ASSET_PROVENANCE.md`.

Le reste de l’expérience est généré localement :

- les huit méchas sont dessinés procéduralement dans `js/renderer.js` ;
- les circuits, paysages, particules, objets et effets sont produits par Canvas 2D ;
- les sons et la musique sont synthétisés à l’exécution avec Web Audio ;
- l’interface utilise les polices système du navigateur ;
- l’icône SVG a été créée pour ce projet ;
- les captures de `media/preview-*.png` proviennent de cette version du jeu.

Aucun modèle, texture, son, logo, personnage, nom de circuit ou fichier provenant de Mario Kart, Star Wars: Episode I Racer, Podracer ou d’une autre licence n’est inclus.

## Technologies natives utilisées

HTML5, CSS, JavaScript, Canvas 2D, Web Audio API, Gamepad API, Pointer Events, Web Storage, Web App Manifest et Service Worker.
