# Architecture technique — MECHA OVERDRIVE: Circuit Zero

## 1. Vue d’ensemble

Le dépôt contient deux runtimes indépendants qui partagent la même identité de jeu mais pas le même moteur ni la même sauvegarde.

```text
                    MECHA OVERDRIVE
                           │
             ┌─────────────┴─────────────┐
             │                           │
      édition Godot 3D          compagnon Canvas/PWA
        principale                  tactile
   sources `godot/`          HTML/CSS/Canvas/JS racine
       Godot 4.7.2              navigateur/localStorage
             │                           │
      export `godot3d/`                  │
             └─────────────┬─────────────┘
                           ▼
                publication statique Vercel
```

- **Godot 3D** vit sous `godot/` et constitue l’édition principale.
- **Compagnon web** vit à la racine et reste une application statique autonome.
- **Godot Web** est un export explicite et attesté sous `godot3d/` ; Vercel sert les deux surfaces sans fusionner leurs sauvegardes.

## 2. Architecture de l’édition Godot 3D

Cette section décrit le contrat de la release **Godot 2.4.0**. La section 4 conserve séparément l’architecture historique du compagnon web ; ses limites ne définissent pas le contenu Godot actuel.

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
├── SeasonIntroScreen (premier lancement)
├── MainMenuScreen
├── GarageScreen
├── CodexScreen
├── RaceController (créé à la demande)
└── ResultsScreen
```

Le coordinateur écoute des signaux de haut niveau (`race_requested`, `screen_requested`, `race_finished`, `retry_requested`, `next_requested`) et remplace l’écran actif. Cette séparation empêche les menus d’écrire directement dans la simulation. Au premier lancement de cet arc, `app.gd` ouvre l’introduction en trois chapitres puis persiste la clé versionnée `season_intro_arc_2_seen`.

### 2.3 Catalogue de données

`scripts/data/game_database.gd` centralise les données immuables :

- dix châssis : Raptor R2, Triarch T3, Fenrir Q4, Mantis H6, Arachne O8, Wraith V0, Bastion C2, Cyclops M1, Orb S7 et Centurion S12 ;
- cinq divisions : `command`, `stabilized`, `swarm`, `ground` et `experimental` ;
- huit circuits/mondes : Fonderie Néon, Faille Écarlate, Arc Polaire, Cimetière Orbital, Canopée d’Azura, Couronne Tempête, Tranchée Hadale et Circuit Zero ;
- huit objets ;
- trois emplacements modulaires et dix-huit modules, six par emplacement ;
- trois classes de performance : `stock`, `tuned`, `unlimited` ;
- trois règlements de grille : `division_locked`, `open_mixed`, `elite_open` ;
- six championnats : cinq coupes dédiées à une division et le `nexus_open` « Grand Open des Huit Mondes », seule coupe ouverte aux divisions mélangées ;
- neuf pilotes IA canoniques, auxquels s’ajoute le joueur pour former une grille narrative de dix pilotes ;
- trois difficultés, quatre familles d’améliorations et barème de championnat.

`scripts/data/locomotion_catalog.gd` compose dix technologies et cinq montages pour chacune des dix familles, soit exactement 500 configurations. `scripts/data/lore_database.gd` expose huit archives originales au Codex. La Saison 03 « La Couronne Libre » relie la Nexus Grand League, les huit mondes de trois galaxies, Hangar 08 et l’antagoniste Mara Vex ; `race_broadcast.gd`, l’introduction, le menu, le Codex, les résultats et les épilogues consomment ce même canon.

Les consommateurs passent par les méthodes de recherche (`get_chassis`, `get_track`, `get_item`, `get_difficulty`) et reçoivent des copies profondes pour limiter les mutations accidentelles.

### 2.4 Construction procédurale des circuits

`scripts/world/track_factory.gd` transforme une spécification de circuit en un arbre `Node3D` complet :

1. génération déterministe d’une `Curve3D` fermée ;
2. calcul du relief à partir de plusieurs harmoniques et d’une seed ;
3. construction des meshes de route, accotements et rails lumineux ;
4. création de l’environnement, du brouillard et de la lumière ;
5. placement déterministe des décors et du complexe professionnel départ/arrivée ;
6. création de marqueurs de pickups et pads de boost ;
7. exposition de la courbe, de la longueur et des marqueurs via les métadonnées du nœud.

La méthode `sample_pose(track, distance, lane)` fournit un `Transform3D` commun à la simulation, aux visuels et à la caméra. La distance de course reste monotone ; seul l’échantillonnage sur la boucle utilise un modulo.

`scripts/world/track_safety.gd` est la source de vérité de l’homologation en mètres. Il impose une route d’au moins **35 m**, trois colonnes de dépassement, 1,50 m d’écart et de dégagement extérieur, calcule le gabarit des 500 configurations et adapte les limites de voie. `TrackFactory` élargit toute spécification trop étroite et publie un rapport d’homologation ; la grille à huit concurrents est disposée en **2 × 4** avec 10,5 m entre rangées.

`scripts/visual/track_visual_profiles.gd` applique le profil de tracé, le grip, les accessoires et les dangers propres à chacun des huit circuits. `scripts/visual/material_library.gd` charge les textures raster originales générées avec OpenAI ; le manifeste de schéma 2 atteste identifiant, prompt, usage, dimensions et SHA-256 de **19 bitmaps**, dont `intergalactic_crown_race.png` et `garage_crew.png`.

### 2.5 Construction procédurale des méchas

`scripts/mecha/mecha_factory.gd` génère une silhouette 3D propre à chaque architecture avec les primitives Godot. `scripts/visual/mecha_visual_modules.gd` installe les trois modules visibles et `scripts/visual/locomotion_visuals.gd` construit les roues, jambes, chenilles, appuis, sphères, propulseurs, rails ou turbines sélectionnés. `scripts/mecha/racer_visual.gd` anime les parties mobiles, rotors, boost et dégâts.

Le visuel ne possède pas la vérité physique. Il reçoit à chaque trame un snapshot du pilote puis est replacé sur la pose de piste. La simulation peut ainsi rester déterministe et indépendante de la fréquence d’affichage.

Chaque châssis expose des ancres TPS et cockpit. Le changement de vue masque les éléments extérieurs qui obstrueraient la vue interne, affiche l’habillage cockpit et persiste le choix par châssis. Les ancres sont définies par famille, mais l’audit visuel exhaustif des deux caméras sur les 500 configurations reste un P2.

### 2.6 Simulation de course

`scripts/race/race_controller.gd` orchestre le runtime et exécute la simulation à pas fixe de **1/120 s** :

1. briefing de grille et caméra panoramique ;
2. compte à rebours 3-2-1-GO, propulsion verrouillée et faux départ pénalisé ;
3. lecture des commandes du joueur ou calcul des commandes IA ;
4. mise à jour de chaque `RacerState` ;
5. contacts avec pickups et pads ;
6. collisions proches ;
7. classement ;
8. objets ;
9. élimination éventuelle ;
10. conditions de fin ou de DNF ;
11. arrivée cinématique, interpolation visuelle, caméra, HUD et audio ;
12. podium top 3 et résultats complets.

L’accumulateur est borné pour éviter une spirale de rattrapage lors d’un ralentissement prolongé. Les contacts actuels utilisent distance longitudinale, largeur réelle et écart latéral en mètres ; ce sont des enveloppes déterministes, pas encore de vraies collisions 3D avec réponse caméra.

### 2.7 État d’un pilote

`scripts/race/racer_state.gd` est un `RefCounted` sans dépendance directe au rendu. Son snapshot contient notamment :

- identifiants pilote/châssis, division et rôle joueur/IA ;
- distance, tour, voie, vitesse et position ;
- chaleur, blindage courant et `max_armor` ;
- boost, dérive, objet, bouclier et temporisations ;
- fin, DNF, élimination et motif ;
- paramètres physiques calculés depuis le châssis, les améliorations, les modules et la classe de performance.

L’IA utilise le même chemin de simulation que le joueur. Le contrôleur lui fournit courbure anticipée, ligne entrée/apex/sortie, danger, adhérence, trafic et situation de course. Les neuf profils de pilote pilotent agressivité, défense, dérive et usage contextuel des objets ; le rattrapage reste borné à 3,5 %. Le danger reste aujourd’hui un contexte de secteur global : son évaluation lane-aware est un P2.

`scripts/input/mobile_touch_controls.gd` fournit dix actions multitouch, des cibles d’au moins 88 px, les zones sûres, l’haptique et des dispositions paysage/portrait sans émuler les entrées clavier/manette.

### 2.8 Modes et résultats

`GameSession` accepte quatre modes :

| Mode | Contrat |
|---|---|
| `quick` | 2 à 8 pilotes, objets actifs |
| `time_trial` | 1 pilote, objets désactivés |
| `elimination` | grille, intervalle d’élimination borné |
| `grand_prix` | huit concurrents, grille stable, circuits de la coupe choisie et points cumulés |

Un résultat n’est commité qu’une fois par session. `complete_race` normalise position, temps, tours, classement et récompense avant de transmettre une copie à `SaveSystem`. Un abandon passe par le même contrat avec `finished=false` et `dnf=true`.

Par défaut, `GameSession` construit une grille de la division du châssis sélectionné. Le mélange n’est autorisé que par une demande explicite compatible avec `open_mixed` ou `elite_open`. Les classes appliquent aussi une politique réelle : configuration d’usine et améliorations nulles en `stock`, plafond de niveau 2 en `tuned`, plafond de niveau 4 en `unlimited`.

### 2.9 Sauvegarde v5

Le schéma courant est `SAVE_VERSION = 5` et le fichier principal :

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
loadouts[chassis_id][slot_id]
locomotions[chassis_id]
owned_modules[]
records[track_id][mode]
stats[races|wins|podiums|championships|credits_earned]
settings[accessibilité|audio|camera_view|season_intro_arc_2_seen]
championship[id|round|tracks|division_id|ruleset_id|grid_policy|performance_class|roster]
```

À chaque lecture, le service reconstruit un profil par défaut puis n’accepte que les valeurs valides et bornées. Une sauvegarde v2 est migrée vers un chargement par châssis, une vue persistante et la coupe dédiée correspondant à la division sélectionnée. Une sauvegarde v3 conserve ses chargements et reçoit les neuf modules historiques ; une v4 reçoit dix locomotions constructeur valides. Les propriétés immuables d’un championnat sont ensuite recopiées depuis le catalogue canonique : une sauvegarde modifiée ne peut pas injecter des circuits, une division ou un règlement arbitraires. L’écriture suit un flux temporaire → backup → remplacement. Un JSON invalide est archivé en `.corrupt.json`. Les DNF n’accordent ni crédits ni record.

### 2.10 UI, accessibilité et audio

Les scripts `scripts/ui/` construisent l’introduction, les écrans de menu, garage, codex, HUD et résultats. Le menu expose division, politique de grille, championnat et classe de performance. Le garage place un unique `SubViewport` Web-friendly sur toute la surface derrière les panneaux HUD : le vrai mécha, sa peinture, sa locomotion, ses modules et ses statistiques réagissent au brouillon sans réinitialiser angle ou zoom. `garage_pit_crew.gd` ajoute deux mécanos humanoïdes et deux robots légers, texturés par `garage_crew.png` ; le réglage mouvement réduit fige leurs animations et masque les étincelles. `ui_theme.gd` centralise la direction visuelle. Les réglages persistants couvrent contraste élevé, mouvement réduit, texte agrandi, secousse caméra, unités métriques et volumes.

`scripts/audio/audio_director.gd` génère l’ambiance moteur et les événements de course à l’exécution. Aucun fichier audio externe n’est requis par cette branche.

### 2.11 Entrées

`scripts/app.gd` installe les actions à l’exécution si elles n’existent pas. Les aliases AZERTY/QWERTY sont conservés :

- `race_accelerate`, `race_brake`, `race_left`, `race_right` ;
- `race_drift`, `race_boost`, `race_item` ;
- `race_reset`, `race_pause`, `race_camera`.

La vue bascule entre TPS et cockpit avec `V`/`Tab` ou le bouton `Y` de la manette. Le système repose sur l’InputMap Godot, mais l’écran de remapping complet clavier/manette/tactile reste un P2.

## 3. Flux Godot de bout en bout

```text
SeasonIntroScreen (premier lancement)
   │
   ▼
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
   ├── RaceHUD + MobileTouchControls
   └── AudioDirector
   │ résultat brut
   ▼
GameSession.complete_race
   ├── championnat
   └── SaveSystem.record_race_result
   │ résultat normalisé
   ▼
ResultsScreen + PodiumPresenter
```

## 4. Architecture historique de l’édition compagnon web

Cette section documente la baseline Canvas/PWA 1.0 conservée à la racine. Elle ne doit pas être interprétée comme le catalogue ou le contrat de progression de l’édition Godot 2.4.0. L’édition compagnon est une application statique sans compilation et sans dépendance d’exécution. Dix scripts classiques partagent l’espace de noms `window.MO`.

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

Elle conserve crédits, châssis, peintures, améliorations, meilleurs temps, statistiques, paramètres et état du Grand Prix web. Elle n’est ni migrée vers le profil Godot v3 ni partagée avec lui.

### 4.3 PWA, export Godot Web et Vercel

`manifest.webmanifest` configure l’installation en paysage du compagnon. `service-worker.js` pré-cache son runtime, nettoie ses anciens caches et exclut explicitement `/godot3d/`. Le jeu Godot Web reste donc une application connectée distincte.

`godot/export_presets.cfg` produit une cible Web mono-thread dans `godot3d/`. `godot3d/build.json` atteste la version Godot, le preset, le SHA des sources ainsi que la taille et le SHA-256 des neuf artefacts. `vercel.json` applique une CSP stricte au compagnon et une CSP dédiée au bootstrap WebAssembly sous `/godot3d/`.

Les deux surfaces sont publiées ensemble :

- `/` : compagnon Canvas/PWA, adapté au tactile ;
- `/godot3d/mecha-overdrive` : édition Godot 3D, ciblée clavier, manette et tactile ;
- `npm start` sert localement les MIME `.wasm` et `.pck` nécessaires.

## 5. Outils de validation

### Godot

- `tools/validate-godot.mjs` : contrat statique des ressources et données Godot.
- `godot/tests/smoke_test.gd` : 10 châssis, 500 locomotions, 5 divisions, 8 circuits, 6 coupes, 18 modules, 19 assets OpenAI, sauvegarde v5, mobile, IA, podium, migrations et déterminisme.
- `godot/tests/locomotion_catalog_test.gd` : produit exhaustif 10 × 50, isolation visuelle et texture Aether.
- `godot/tests/runtime_flow_test.gd` : vraie scène, grille par division, modules, vues TPS/cockpit, mouvement, DNF, résultats et coupes dédiée/ouverte avec sauvegarde isolée.
- `godot/tests/gameplay_safety_test.gd` : homologation 35 m, grille 2 × 4, gabarits, contacts, classement/DNF et géométrie mobile paysage/portrait.
- `godot/tests/garage_preview_test.gd` : plein écran, viewport réactif, focus/tactile, cadre préservé, modules live et quatre acteurs de stand animés.
- `godot/tests/narrative_progression_test.gd` : verrouillage/déverrouillage/reprise du Grand Open et épilogues joueur/Vex/rival.
- `godot --headless --path godot --editor --quit` : import et parse par le vrai moteur.

### Web

- `tools/check.mjs` : syntaxe récursive JS/MJS.
- `tools/validate.mjs` : structure, données, PWA, cache, CSP et contrat complet de l’export Godot Web.
- `tools/stamp-godot-web.mjs` : manifeste reproductible des sources et artefacts `godot3d/`.
- `tests/run-tests.mjs` : tests moteur.
- `tests/smoke.mjs` : intégration Node.
- `tests/browser_smoke.py` et `tests/full_flow_qa.py` : parcours Chromium.

### Agrégat

```bash
npm run qa
```

Cet agrégat combine la QA Node, le contrat de l’export Godot Web et le validateur statique Godot. Pour 2.4.0, il réussit avec 115/115 contrôles Web, 12/12 tests moteur, 21/21 contrôles d’intégration et le contrat Godot statique. Le parse/import et les six tests Godot restent exécutés séparément avec Godot 4.7.2.

## 6. Ajouter du contenu Godot

### Nouveau châssis

1. Ajouter une entrée canonique dans `GameDatabase.CHASSIS`.
2. Fournir division, statistiques, multiplicateurs physiques, aptitude, chargement par défaut, ancres de caméra et textures.
3. Ajouter ou adapter la géométrie dans `MechaFactory` et les points modulaires dans `MechaVisualModules`.
4. Implémenter l’effet spécialisé dans `RacerState` si les multiplicateurs ne suffisent pas.
5. Étendre le smoke test et le validateur structurel.

### Nouveau circuit

1. Ajouter la spécification dans `GameDatabase.TRACKS`.
2. Définir seed, rayon, largeur, relief, palette, grip, profil, textures, accessoires, dangers et temps de référence.
3. Étendre `TrackFactory` ou `TrackVisualProfiles` seulement si une nouvelle primitive visuelle ou mécanique est nécessaire.
4. Tester la fermeture, le relief, les poses, les marqueurs et une course complète.

### Nouvel objet

1. Ajouter la métadonnée dans `GameDatabase.ITEMS`.
2. Définir son acquisition et son activation dans `RacerState`/`RaceController`.
3. Ajouter feedback HUD/audio.
4. Tester joueur, IA, portée, cooldown et fin de course.

## 7. Frontières de release

- Une validation Node ne prouve pas qu’un script GDScript se parse.
- Un smoke headless ne remplace pas un parcours visuel et input complet.
- Un déploiement Vercel `READY` prouve la publication, pas à lui seul le bon déroulement d’une course WebGL.
- Chaque modification des sources Godot impose un nouvel export, un nouveau stamp et un parcours navigateur du build produit.
- Toute annonce doit citer les gates réellement exécutés sur le commit publié.
- Pour 2.4.0, sources, export Web synchronisé, QA Chrome bureau/mobile, GitHub Actions, release GitHub et alias Vercel sont qualifiés ; les identifiants de preuve figurent dans `docs/QA_REPORT.md`.
- P2 connus : vraies collisions 3D/caméra, hazards lane-aware, confirmation avant écrasement d’un championnat, retry save/UI, remapping complet, déblocages progressifs de contenu, coupes personnalisées et audit caméra des 500 configurations.
