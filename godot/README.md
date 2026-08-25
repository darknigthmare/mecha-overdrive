# MECHA OVERDRIVE — édition Godot 3D

Cette arborescence contient l’édition principale **2.5.0** de **MECHA OVERDRIVE: Circuit Zero**, développée pour **Godot 4.7.2** en GDScript et 3D procédurale détaillée.

## Ouvrir le projet

Dans le gestionnaire de projets Godot :

1. choisir **Importer** ;
2. sélectionner `godot/project.godot` ;
3. ouvrir le projet ;
4. lancer le projet avec `F5`.

La scène principale configurée est `res://scenes/app.tscn`.

Depuis la racine du dépôt :

```bash
godot --editor --path godot
godot --path godot
```

Sous Windows, remplacez `godot` par le chemin de `Godot_v4.7.2-stable_win64.exe` ou de la variante console.

## Contenu

- **10 châssis** regroupés en **5 divisions** : Commandement, Stabilisés, Essaim, Sol et Expérimental ;
- **4 modes** : Course rapide, Contre-la-montre, Élimination et Grand Prix ;
- **8 circuits homologués de 35 à 42 m** : Fonderie Néon, Faille Écarlate, Arc Polaire, Cimetière Orbital, Canopée d’Azura, Couronne Tempête, Tranchée Hadale et Circuit Zero ;
- **6 championnats** : cinq coupes dédiées et le Grand Open des Huit Mondes ;
- **18 modules** répartis entre noyau, mobilité et utilitaire, avec affinités de division, coûts et silhouettes dédiées ;
- **500 configurations de locomotion** : 50 par châssis, issues de dix technologies et cinq géométries, avec aperçu et statistiques réelles ;
- garage plein écran avec vrai modèle 3D, HUD translucide, rotation, pincement, cadrage persistant et équipe mécano animée ;
- **8 objets** de combat/mobilité ;
- grilles dédiées par défaut, mélange interdivision uniquement en Open ;
- garage, peintures, améliorations, codex, HUD, résultats et progression ;
- **21 assets bitmap OpenAI** sur méchas, cockpits, pistes, décors, introduction et équipe mécano ;
- Grand Tour intergalactique, Mara Vex, onglet des dix pilotes, briefing, compte à rebours, arrivée, podium et épilogue ;
- commandes tactiles multitouch à dix actions et IA profilée avec anticipation, danger, trafic et objets contextuels ;
- grille de départ 2 × 4, contacts et dépassements IA tenant compte des gabarits ;
- circuits et silhouettes construits à l’exécution avec les primitives Godot.

Les classes **Série**, **Préparé** et **Prototype** imposent leurs politiques de modules et leurs plafonds d’amélioration. Les cinq coupes dédiées utilisent des rosters stables de huit concurrents ; le Grand Open mélange explicitement les cinq divisions sur huit manches et se termine exclusivement sur Circuit Zero.

## Contrôles

| Action | Clavier | Manette |
|---|---|---|
| Accélérer | `Z`, `W`, `↑` | `RB` |
| Freiner | `S`, `↓` | `LB` |
| Diriger | `Q`/`D`, `A`/`D`, `←`/`→` | stick gauche |
| Dérive | `Ctrl`, `C` | `B` |
| Surcharge | `Maj`, `X` | `X` |
| Objet | `Espace`, `E`, `Entrée` | `A` |
| Recalage | `R` | — |
| Basculer TPS / cockpit | `V`, `Tab` | `Y` |
| Pause | `Échap`, `P` | `Start` |

## Sauvegarde v5

`SaveSystem` enregistre le profil dans :

```text
user://mecha_overdrive_profile.json
```

Le profil conserve le pilote, les crédits, le châssis, les peintures, les améliorations, l’inventaire de modules possédés, les loadouts modulaires, les locomotions, la vue TPS/cockpit, les records, les statistiques et le championnat enrichi : coupe, division/Open, classe, roster stable et points. Les profils v2/v3/v4 migrent vers le schéma v5 en conservant les neuf modules historiques et en installant la locomotion constructeur. Les données sont normalisées et bornées ; une coupe v3 ne peut pas réécrire ses règles canoniques. Le garage applique achat, peinture, locomotion et équipement dans une transaction unique avec retour arrière sur échec. L’écriture utilise un fichier temporaire et un backup restaurable. Une course DNF ne peut pas créer de record ni verser de récompense.

Le chemin absolu de `user://` dépend du système ; Godot permet de l’ouvrir depuis l’éditeur via **Projet > Ouvrir le dossier de données utilisateur**.

## Tests

Depuis la racine du dépôt, le contrat statique peut être contrôlé sans Godot :

```bash
node tools/validate-godot.mjs
```

Pour forcer l’import et le parse avec le moteur réel :

```bash
godot --headless --path godot --editor --quit
```

Puis lancer le smoke test :

```bash
godot --headless --path godot --script res://tests/smoke_test.gd
```

Puis le flux de la vraie application :

```bash
godot --headless --path godot --script res://tests/runtime_flow_test.gd
```

Puis les contrats spécialisés :

```bash
godot --headless --path godot --script res://tests/gameplay_safety_test.gd
godot --headless --path godot --script res://tests/garage_preview_test.gd
godot --headless --path godot --script res://tests/mecha_detail_test.gd
godot --headless --path godot --script res://tests/mecha_animation_test.gd
godot --headless --path godot --script res://tests/track_scenery_production_test.gd
```

Le smoke contrôle le contrat 10 châssis / 500 locomotions / 5 divisions / 8 circuits / 18 modules / 6 championnats / 21 assets OpenAI, la sauvegarde v5, le mobile, l’IA, le briefing, le podium, les migrations et la simulation déterministe. Le flux runtime vérifie le parcours réel. Les suites spécialisées couvrent chaussées/gabarits/grille/contacts/difficulté/DNF, le garage plein écran, les budgets meshes/triangles, les animations par locomotion et les huit décors multi-LOD. Les résultats confirmés sont consignés dans [`../docs/QA_REPORT.md`](../docs/QA_REPORT.md).

## Organisation

```text
godot/
├── project.godot
├── assets/
│   └── textures/openai/  vingt-et-un PNG et manifeste de provenance
├── scenes/
│   ├── app.tscn
│   ├── main_menu.tscn
│   ├── garage.tscn
│   ├── codex.tscn
│   └── results.tscn
├── scripts/
│   ├── data/       catalogue canonique
│   ├── systems/    sauvegarde et session
│   ├── world/      génération des circuits
│   ├── mecha/      silhouettes et animation
│   ├── race/       simulation et orchestration
│   ├── ui/         écrans et HUD
│   ├── audio/      feedback procédural
│   └── visual/     matériaux OpenAI, modules et profils de circuit
└── tests/
    ├── gameplay_safety_test.gd
    ├── garage_preview_test.gd
    ├── mecha_animation_test.gd
    ├── mecha_detail_test.gd
    ├── smoke_test.gd
    ├── track_scenery_production_test.gd
    └── runtime_flow_test.gd
```

## Export Web reproductible

Le preset `Web` mono-thread produit l’application dans `../godot3d/`. Les templates d’export officiels Godot 4.7.2 doivent être installés :

```bash
godot --headless --path godot --export-release Web ../godot3d/mecha-overdrive.html
npm run stamp:godot-web
npm run validate
```

Le manifeste `godot3d/build.json` contient l’empreinte des sources et de chaque artefact. Toute modification du projet exige donc un nouvel export et un nouveau stamp avant publication.

L’export Web cible les ordinateurs et mobiles compatibles WebGL2, avec clavier, manette ou commandes tactiles selon l’appareil. L’édition compagnon à la racine conserve en plus son mode PWA hors ligne.

## Frontière avec l’édition web

L’application web à la racine n’est pas un export de ce projet. Elle possède huit châssis et sa propre sauvegarde `localStorage` v1. `godot3d/` est, lui, l’export navigateur exact de cette édition principale. Vercel publie les deux éditions sous le même domaine sans fusionner leurs sauvegardes.
