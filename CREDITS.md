# Crédits et provenance

## Conception et réalisation

Projet préparé pour **Darknigthmare** en 2026.

## Assets

MECHA OVERDRIVE — Circuit Zero ne charge aucun asset artistique tiers. Le projet contient un key art et douze matériaux bitmap originaux produits avec l’outil de génération d’images OpenAI :

- générations commandées spécifiquement pour ce jeu les 21 et 22 août 2026 ;
- aucune image de référence sous licence ni aucun asset officiel n’a été fourni au modèle ;
- prompt complet et contraintes d’originalité archivés dans `docs/ASSET_PROVENANCE.md`.
- `godot/assets/textures/openai/mecha_armor.png` — armures et modules ;
- `godot/assets/textures/openai/track_surface.png` — pistes et épaules ;
- `godot/assets/textures/openai/cockpit_composite.png` — cockpits ;
- `godot/assets/textures/openai/environment_panels.png` — décors et barrières ;
- `godot/assets/textures/openai/mecha_armor_light.png` — blindages légers et commandement ;
- `godot/assets/textures/openai/mecha_armor_heavy.png` — blindages lourds et stabilisés ;
- `godot/assets/textures/openai/module_energy.png` — noyaux et relais énergétiques ;
- `godot/assets/textures/openai/module_mobility.png` — propulseurs et systèmes de mobilité ;
- `godot/assets/textures/openai/module_utility.png` — utilitaires, capteurs et défenses ;
- `godot/assets/textures/openai/track_thermal.png` — surfaces thermiques ;
- `godot/assets/textures/openai/track_cryo.png` — surfaces cryogéniques ;
- `godot/assets/textures/openai/garage_bay.png` — baie d’atelier du garage 3D ;
- prompts complets et identifiants archivés dans `godot/assets/textures/openai/manifest.json`.

La géométrie, le son et les autres surfaces de l’expérience sont générés localement :

- les huit méchas du compagnon sont dessinés dans `js/renderer.js` ;
- les dix méchas de l’édition principale sont assemblés en primitives 3D par Godot ;
- les circuits, paysages, particules, objets et effets sont produits par Canvas 2D ou par la scène 3D procédurale ;
- les sons sont synthétisés à l’exécution par Web Audio ou `AudioStreamGenerator` ;
- l’interface utilise les polices système du navigateur ;
- l’icône SVG a été créée pour ce projet ;
- les captures de `media/preview-*.png` proviennent de cette version du jeu.

Aucun modèle, texture, son, logo, personnage, nom de circuit ou fichier provenant de Mario Kart, Star Wars: Episode I Racer, Podracer ou d’une autre licence n’est inclus.

## Technologies natives utilisées

Godot Engine 4.7.2, GDScript, WebGL2, HTML5, CSS, JavaScript, Canvas 2D, Web Audio API, Gamepad API, Pointer Events, Web Storage, Web App Manifest et Service Worker.

Les mentions de licence du runtime Godot sont regroupées dans [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
