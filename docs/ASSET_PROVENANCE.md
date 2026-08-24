# Provenance des assets

## Key art MECHA OVERDRIVE

- **Fichier** : `media/openai/mecha-overdrive-hero.png`
- **Date de génération** : 21 août 2026
- **Outil** : générateur d’images OpenAI intégré à Codex
- **Références fournies** : aucune
- **Usage** : menu web, présentation du dépôt et écran d’accueil Godot

### Prompt archivé

> Use case: stylized-concept. Asset type: 16:9 game menu and public presentation hero background. Primary request: original cinematic key art for MECHA OVERDRIVE, a high-speed science-fiction mech racing game. Scene/backdrop: an elevated orbital-industrial race circuit curving through a vast neon shipyard above a planet, magnetic guard rails, sparks, heat haze and distant construction gantries. Subject: three unmistakably different original racing machines in the lower half: a fast athletic biped racer leading, a wide armored tripod challenging on the inside line, and a sleek hover racer boosting on the outside; silhouettes of quadruped and tracked competitors farther back. Style/medium: premium real-time 3D game key art, stylized realism, physically plausible hard-surface materials, original designs. Composition/framing: wide 16:9 chase-camera angle close to the track, strong depth and readable racing lines, focal machines kept below the middle, darker clean negative space across the upper center for menu UI. Lighting/mood: electric cyan track light, restrained magenta reactor glow, amber sparks, cold orbital darkness, urgent competitive energy. Color palette: deep navy and graphite, cyan, controlled magenta, small amber highlights. Materials/textures: battle-worn painted metal, carbon composite, glowing reactor vents, rubberized joints, polished magnetic rails. Constraints: original franchise-neutral mech designs; clearly racing vehicles rather than humanoid warriors; accurate number of supports for the biped and tripod; no weapons firing; no characters outside vehicles; no text, no logo, no UI, no watermark, no collage. Avoid: resemblance to Transformers, Gundam, Star Wars, Mario Kart, or any existing licensed design; illegible machinery; extra limbs on the foreground racers.

### Statut

Asset original créé pour le projet. Aucune œuvre de franchise n’a été copiée ou fournie comme référence d’entrée. Une vérification juridique séparée reste recommandée avant exploitation commerciale ou dépôt de marque.

## Matériaux gameplay OpenAI — édition Godot 2.1.0

Les quatre images suivantes ont été créées le 22 août 2026 avec la génération d’images intégrée d’OpenAI, en mode **nouvelle génération raster**, sans image de référence :

| Fichier | Identifiant de génération | Usage runtime |
|---|---|---|
| `godot/assets/textures/openai/mecha_armor.png` | `exec-16c591eb-ae6f-4299-8676-8b64e361df05` | armures et panneaux modulaires des dix méchas |
| `godot/assets/textures/openai/track_surface.png` | `exec-051ea44d-aee8-4ca1-af66-c742959fca37` | chaussées et épaules magnétiques des huit circuits |
| `godot/assets/textures/openai/cockpit_composite.png` | `exec-12d4b298-d001-412b-b218-70544aed3470` | verrières, intérieurs et composites de cockpit |
| `godot/assets/textures/openai/environment_panels.png` | `exec-02f22be6-b9a3-4b1f-9ab1-cdb51b864226` | barrières, accessoires et décors procéduraux |

Le manifeste machine lisible [`../godot/assets/textures/openai/manifest.json`](../godot/assets/textures/openai/manifest.json) archive les prompts complets, les contraintes d’originalité, les identifiants, la date, le générateur et les usages. Les images ne contiennent ni texte, ni logo, ni marque, ni élément provenant d’une franchise tierce.

### Intégration

`MaterialLibrary` charge les quatre PNG et leur applique répétition UV, filtrage anisotrope, métallicité et rugosité. `MechaFactory`, `MechaVisualModules` et `TrackFactory` les consomment sur les dix architectures, leurs modules, les huit pistes et leurs décors. Les géométries restent originales et procédurales ; seules leurs surfaces sont bitmap.

### Statut

Assets originaux créés pour MECHA OVERDRIVE. Une vérification juridique séparée reste recommandée avant exploitation commerciale ou dépôt de marque.

## Vague de matériaux OpenAI — édition Godot 2.2.0

Huit images supplémentaires ont été créées le 22 août 2026 avec le générateur d’images OpenAI intégré, en nouvelle génération raster et sans image de référence :

| Fichier | Identifiant de génération | Usage runtime |
|---|---|---|
| `mecha_armor_light.png` | `exec-f3283ae3-c283-4934-bec0-21fe701a8d89` | armures Commandement, Essaim et Expérimental |
| `mecha_armor_heavy.png` | `exec-6a5fb823-16bc-4636-a01c-a528ba12fe40` | armures Stabilisé et Sol |
| `module_energy.png` | `exec-eea59f4d-b101-4cfc-9993-4dcae020385b` | six silhouettes de noyau |
| `module_mobility.png` | `exec-9aafcc4a-cefa-4c81-b67a-8b58229f05f9` | six silhouettes de mobilité |
| `module_utility.png` | `exec-b66cb30c-f20f-48a0-adc9-ace8ea63cfd0` | six silhouettes utilitaires |
| `track_thermal.png` | `exec-c3543a32-c68c-4a26-b3f7-747ab5d7eeb5` | Fonderie Néon et Caldeira Zéro |
| `track_cryo.png` | `exec-1f760e08-e083-444a-a6bf-4316d996e711` | Arc Polaire et Tranchée Hadale |
| `garage_bay.png` | `exec-6bdc26bf-1421-4369-859e-34366af46e50` | sol et panneaux de la prévisualisation 3D |

Le manifeste schema 2 archive pour les dix-sept textures le rôle, les dimensions, les empreintes SHA-256, les prompts complets et l’identifiant de génération. Les originaux restent dans le dossier de générations Codex ; les copies runtime sont celles versionnées dans le projet.

### Statut

Ces surfaces sont des créations originales du projet, sans texte, logo, marque, UI ou référence d’image tierce. Elles sont réellement branchées sur `MaterialLibrary`, `MechaFactory`, `MechaVisualModules`, `TrackFactory` et la baie interactive du garage.

## Vague décors, cérémonie et locomotion — édition Godot 2.3.0

Cinq images supplémentaires ont été créées le 22 août 2026 avec le générateur d’images OpenAI intégré, sans image de référence :

| Fichier | Identifiant de génération | Usage runtime |
|---|---|---|
| `prop_industrial.png` | `exec-b7ff9eed-fc53-4054-9e38-f606ba8e7535` | accessoires industriels, portiques et structures orbitales |
| `prop_biome.png` | `exec-0196728b-09dc-43b2-992a-f228ab7ebbba` | racines, roches, cristaux, monolithes et biomes |
| `prop_urban_wet.png` | `exec-df7d346b-272f-4968-8e6a-c0f00a091bda` | tours, barrières et tribunes urbaines humides |
| `race_ceremonial.png` | `exec-0f574bb4-6b07-4846-8e62-05ad41336015` | départ/arrivée, introduction et podium |
| `locomotion_antigrav.png` | `exec-02f2e6d7-08b7-4f68-8c17-2577569c00e6` | bi-propulseur Aether, couplages et éléments antigravité |

Les dix-sept PNG mesurent 1254 × 1254. Le manifeste schema 2 contient dimensions et SHA-256 vérifié pour chaque fichier. Les prompts imposent une conception originale sans texte, logo, marque, watermark ni langage visuel reconnaissable de franchise. Les cinq originaux de cette vague sont conservés dans le dossier de générations Codex et les copies runtime sont versionnées sous `godot/assets/textures/openai/`.
