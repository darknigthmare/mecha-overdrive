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
