# Architecture technique — MECHA OVERDRIVE: Circuit Zero

## 1. Vue d’ensemble

Le dépôt contient deux runtimes indépendants qui partagent la même identité de jeu mais pas le même moteur ni la même sauvegarde.

```text
                    MECHA OVERDRIVE
                           │
             ┌─────────────┴─────────────┐
             │                           │
      édition Godot 3D             édition web
        principale                  compagnon
       Godot 4.7.2             HTML/CSS/Canvas/JS
       godot/user://           navigateur/localStorage
             │                           │
       source desktop             publication Vercel
```

- **Godot 3D** vit sous `godot/` et constitue l’édition principale.
- **Web** vit à la racine et reste une application statique autonome.
- Vercel sert l’édition web ; il ne transforme pas automatiquement le projet Godot en export Web.

## 2. Architecture de l’édition Godot 3D

### 2.1 Configuration du projet

`godot/project.godot` cible Godot **4.7.2**, le renderer **GL Compatibility** et la scène principale `res://scenes/app.tscn`.

Deux services sont autoloadés :

| Autoload | Script | Responsabilité |
|---|---|---|
| `SaveSystem` | `scripts/systems/save_system.gd` | profil versionné, migration, progression, records et paramètres |
| `GameSession` | `scripts/systems/game_session.gd` | configuration de course, normalisation du résultat et championnat |

Le viewport logique est 1920 × 1080 avec une fenêtre de référence 1280 × 720 et un étirement `canvas_items`.

### 2.2 Composition des scènes

`scenes/app.tscn` instancie `MechaOverdriveApp`, le coordinateur d’écrans. Il ne contient pas la simulation elle-même :

```text
MechaOverdriveApp
├── MainMenuScreen
├── GarageScreen
├── CodexScreen
├── RaceController (créé à la demande)
└── ResultsScreen
```

Le coordinateur écoute des signaux de haut niveau (`race_requested`, `screen_requested`, `race_finished`, `retry_requested`, `next_requested`) et remplace l’écran actif. Cette séparation empêche les menus d’écrire directement dans la simulation.

### 2.3 Catalogue de données

`scripts/data/game_database.gd` centralise les données immuables :

- dix châssis : Raptor R2, Triarch T3, Fenrir Q4, Mantis H6, Arachne O8, Wraith V0, Bastion C2, Cyclops M1, Orb S7 et Centurion S12 ;
- quatre circuits : Fonderie Néon, Faille Écarlate, Arc Polaire et Cimetière Orbital ;
- huit objets ;
- pilotes IA, trois difficultés et quatre familles d’améliorations ;
- barème du championnat.

Les consommateurs passent par les méthodes de recherche (`get_chassis`, `get_track`, `get_item`, `get_difficulty`) et reçoivent des copies profondes pour limiter les mutations accidentelles.

### 2.4 Construction procédurale des circuits

`scripts/world/track_factory.gd` transforme une spécification de circuit en un arbre `Node3D` complet :

1. génération déterministe d’une `Curve3D` fermée ;
2. calcul du relief à partir de plusieurs harmoniques et d’une seed ;
3. construction des meshes de route, accotements et rails lumineux ;
4. création de l’environnement, du brouillard et de la lumière ;
5. placement déterministe des décors ;
6. création de marqueurs de pickups et pads de boost ;
7. exposition de la courbe, de la longueur et des marqueurs via les métadonnées du nœud.

La méthode `sample_pose(track, distance, lane)` fournit un `Transform3D` commun à la simulation, aux visuels et à la caméra. La distance de course reste monotone ; seul l’échantillonnage sur la boucle utilise un modulo.

### 2.5 Construction procédurale des méchas

`scripts/mecha/mecha_factory.gd` génère une silhouette 3D propre à chaque architecture avec les primitives Godot. `scripts/mecha/racer_visual.gd` anime les parties mobiles, le boost et l’état de dégâts.

Le visuel ne possède pas la vérité physique. Il reçoit à chaque trame un snapshot du pilote puis est replacé sur la pose de piste. La simulation peut ainsi rester déterministe et indépendante de la fréquence d’affichage.

### 2.6 Simulation de course

`scripts/race/race_controller.gd` orchestre le runtime et exécute la simulation à pas fixe de **1/120 s** :

1. compte à rebours ;
2. lecture des commandes du joueur ou calcul des commandes IA ;
3. mise à jour de chaque `RacerState` ;
4. contacts avec pickups et pads ;
5. collisions proches ;
6. classement ;
7. objets ;
8. élimination éventuelle ;
9. conditions de fin ou de DNF ;
10. interpolation visuelle, caméra, HUD et audio.

L’accumulateur est borné pour éviter une spirale de rattrapage lors d’un ralentissement prolongé.

### 2.7 État d’un pilote

`scripts/race/racer_state.gd` est un `RefCounted` sans dépendance directe au rendu. Son snapshot contient notamment :

- identifiants pilote/châssis et rôle joueur/IA ;
- distance, tour, voie, vitesse et position ;
- chaleur, blindage courant et `max_armor` ;
- boost, dérive, objet, bouclier et temporisations ;
- fin, DNF, élimination et motif ;
- paramètres physiques calculés depuis le châssis et les améliorations.

L’IA utilise le même chemin de simulation que le joueur. Le contrôleur lui fournit la courbure, le danger, l’adhérence et la situation de course.

### 2.8 Modes et résultats

`GameSession` accepte quatre modes :

| Mode | Contrat |
|---|---|
| `quick` | 2 à 8 pilotes, objets actifs |
| `time_trial` | 1 pilote, objets désactivés |
| `elimination` | grille, intervalle d’élimination borné |
| `grand_prix` | quatre circuits dans l’ordre canonique et points cumulés |

Un résultat n’est commité qu’une fois par session. `complete_race` normalise position, temps, tours, classement et récompense avant de transmettre une copie à `SaveSystem`. Un abandon passe par le même contrat avec `finished=false` et `dnf=true`.

### 2.9 Sauvegarde v2

Le schéma courant est `SAVE_VERSION = 2` et le fichier principal :

```text
user://mecha_overdrive_profile.json
```

Contrat simplifié :

```text
version
pilot_name
credits
selected_chassis
owned_chassis[]
paints[chassis_id]
unlocked_paints[]
upgrades[chassis_id][engine|servos|reactor|armor]
records[track_id][mode]
stats[races|wins|podiums|championships|credits_earned]
settings[accessibilité|audio]
```

À chaque lecture, le service reconstruit un profil par défaut puis n’accepte que les valeurs valides et bornées. L’écriture suit un flux temporaire → backup → remplacement. Un JSON invalide est archivé en `.corrupt.json`. Les DNF n’accordent ni crédits ni record.

### 2.10 UI, accessibilité et audio

Les scripts `scripts/ui/` construisent les écrans de menu, garage, codex, HUD et résultats. `ui_theme.gd` centralise la direction visuelle. Les réglages persistants couvrent contraste élevé, mouvement réduit, texte agrandi, secousse caméra, unités métriques et volumes.

`scripts/audio/audio_director.gd` génère l’ambiance moteur et les événements de course à l’exécution. Aucun fichier audio externe n’est requis par cette branche.

### 2.11 Entrées

`scripts/app.gd` installe les actions à l’exécution si elles n’existent pas. Les aliases AZERTY/QWERTY sont conservés :

- `race_accelerate`, `race_brake`, `race_left`, `race_right` ;
- `race_drift`, `race_boost`, `race_item` ;
- `race_reset`, `race_pause`.

La manette utilise le stick gauche, `LB`/`RB`, `A`, `B`, `X` et `Start`. Le système repose sur l’InputMap Godot : un remapping futur peut être ajouté sans modifier `RaceController`.

## 3. Flux Godot de bout en bout

```text
MainMenuScreen
   │ demande Dictionary
   ▼
GameSession.configure
   │ configuration normalisée
   ▼
RaceController
   ├── TrackFactory ──► Node3D circuit
   ├── RacerState[] ──► simulation fixe
   ├── MechaFactory ──► RacerVisual[]
   ├── RaceHUD
   └── AudioDirector
   │ résultat brut
   ▼
GameSession.complete_race
   ├── championnat
   └── SaveSystem.record_race_result
   │ résultat normalisé
   ▼
ResultsScreen
```

## 4. Architecture de l’édition web

L’édition web est une application statique sans compilation et sans dépendance d’exécution. Dix scripts classiques partagent l’espace de noms `window.MO`.

| Fichier | Responsabilité |
|---|---|
| `js/core.js` | version, mathématiques, RNG déterministe et événements |
| `js/data.js` | huit châssis web, circuits, objets, difficultés et équilibrage |
| `js/storage.js` | sauvegarde web v1, garage, records et statistiques |
| `js/audio.js` | synthèse Web Audio |
| `js/input.js` | clavier, Gamepad API et tactile |
| `js/track.js` | construction des segments et mini-carte |
| `js/renderer.js` | rendu Canvas pseudo-3D |
| `js/game.js` | physique, IA, combat, tours et championnat |
| `js/ui.js` | menus, garage, HUD, pause et résultats |
| `js/main.js` | assemblage, boucle `requestAnimationFrame` et service worker |

### 4.1 Boucle et simulation web

`main.js` crée le renderer, le moteur, l’UI et la boucle d’affichage. Le `dt` est borné à 50 ms. `MO.Game` maintient les états `idle`, `countdown`, `racing` et `finished`, complétés par `active` et `paused`.

Le renderer projette les segments de piste sur Canvas, trie les rivaux par profondeur et dessine les huit géométries web. L’audio est synthétique ; aucune ressource distante n’est nécessaire au runtime.

### 4.2 Sauvegarde web

La clé navigateur reste :

```text
mecha_overdrive_circuit_zero_save_v1
```

Elle conserve crédits, châssis, peintures, améliorations, meilleurs temps, statistiques, paramètres et état du Grand Prix web. Elle n’est ni migrée vers le profil Godot v2 ni partagée avec lui.

### 4.3 PWA et Vercel

`manifest.webmanifest` configure l’installation en paysage. `service-worker.js` pré-cache le runtime statique et nettoie ses anciens caches. `vercel.json` configure la publication de la racine du dépôt.

Les chemins de déploiement concernent uniquement l’édition web :

- `npm start` ou `python3 tools/serve.py` en local ;
- Vercel, GitHub Pages, Netlify ou autre hébergement HTTPS ;
- ouverture directe possible, sans garantie PWA/service worker.

## 5. Outils de validation

### Godot

- `tools/validate-godot.mjs` : contrat statique des ressources et données Godot.
- `godot/tests/smoke_test.gd` : catalogue, sauvegarde v2, quatre modes et déterminisme.
- `godot/tests/runtime_flow_test.gd` : vraie scène, course 3D, HUD, mouvement, résultats et retour menu avec sauvegarde isolée.
- `godot --headless --path godot --editor --quit` : import et parse par le vrai moteur.

### Web

- `tools/check.mjs` : syntaxe récursive JS/MJS.
- `tools/validate.mjs` : structure, données, PWA, cache et références.
- `tests/run-tests.mjs` : tests moteur.
- `tests/smoke.mjs` : intégration Node.
- `tests/browser_smoke.py` et `tests/full_flow_qa.py` : parcours Chromium.

### Agrégat

```bash
npm run qa
```

Cet agrégat combine la QA Node web et le validateur statique Godot. Le parse/import et le smoke Godot doivent être exécutés séparément avec Godot 4.7.2.

## 6. Ajouter du contenu Godot

### Nouveau châssis

1. Ajouter une entrée canonique dans `GameDatabase.CHASSIS`.
2. Fournir statistiques, multiplicateurs physiques, aptitude et couleurs.
3. Ajouter ou adapter la géométrie dans `MechaFactory`.
4. Implémenter l’effet spécialisé dans `RacerState` si les multiplicateurs ne suffisent pas.
5. Étendre le smoke test et le validateur structurel.

### Nouveau circuit

1. Ajouter la spécification dans `GameDatabase.TRACKS`.
2. Définir seed, rayon, largeur, relief, palette, dangers et temps de référence.
3. Étendre `TrackFactory` seulement si une nouvelle primitive visuelle ou mécanique est nécessaire.
4. Tester la fermeture, le relief, les poses, les marqueurs et une course complète.

### Nouvel objet

1. Ajouter la métadonnée dans `GameDatabase.ITEMS`.
2. Définir son acquisition et son activation dans `RacerState`/`RaceController`.
3. Ajouter feedback HUD/audio.
4. Tester joueur, IA, portée, cooldown et fin de course.

## 7. Frontières de release

- Une validation Node ne prouve pas qu’un script GDScript se parse.
- Un smoke headless ne remplace pas un parcours visuel et input complet.
- Un déploiement Vercel `READY` ne prouve que l’édition web.
- Un export Godot doit être produit et testé séparément pour chaque cible.
- Toute annonce doit citer les gates réellement exécutés sur le commit publié.
