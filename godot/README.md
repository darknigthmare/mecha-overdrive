# MECHA OVERDRIVE — édition Godot 3D

Cette arborescence contient l’édition principale **2.1.0** de **MECHA OVERDRIVE: Circuit Zero**, développée pour **Godot 4.7.2** en GDScript et 3D procédurale.

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
- **8 circuits** : Fonderie Néon, Faille Écarlate, Arc Polaire, Cimetière Orbital, Canopée d’Azura, Couronne Tempête, Tranchée Hadale et Caldeira Zéro ;
- **6 championnats** : cinq coupes dédiées et le Grand Open du Nexus ;
- **9 modules** répartis entre noyau, mobilité et utilitaire ;
- **8 objets** de combat/mobilité ;
- grilles dédiées par défaut, mélange interdivision uniquement en Open ;
- garage, peintures, améliorations, codex, HUD, résultats et progression ;
- matériaux bitmap OpenAI sur méchas, cockpits, pistes et décors ;
- circuits et silhouettes construits à l’exécution avec les primitives Godot.

Les classes **Série**, **Préparé** et **Prototype** imposent leurs politiques de modules et leurs plafonds d’amélioration. Les cinq coupes dédiées utilisent des rosters stables de huit concurrents ; le Grand Open mélange explicitement les cinq divisions sur huit manches.

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

## Sauvegarde v3

`SaveSystem` enregistre le profil dans :

```text
user://mecha_overdrive_profile.json
```

Le profil conserve le pilote, les crédits, le châssis, les peintures, les améliorations, les loadouts modulaires, la vue TPS/cockpit, les records, les statistiques et le championnat enrichi : coupe, division/Open, classe, roster stable et points. Les profils v2 migrent vers la coupe dédiée du châssis actif. Les données sont normalisées et bornées ; une coupe v3 ne peut pas réécrire ses règles canoniques. L’écriture utilise un fichier temporaire et un backup restaurable. Une course DNF ne peut pas créer de record ni verser de récompense.

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

Le smoke contrôle le contrat 10 châssis / 5 divisions / 8 circuits / 9 modules / 6 championnats, les classes, les migrations v2, l’anti-altération, les huit fabriques de piste et la simulation déterministe. Le flux runtime vérifie roster dédié, modules physiques/visuels, ancres TPS/cockpit, coupes dédiée/Open, DNF, résultats et retour menu, tout en isolant la sauvegarde. Les résultats confirmés sont consignés dans [`../docs/QA_REPORT.md`](../docs/QA_REPORT.md).

## Organisation

```text
godot/
├── project.godot
├── assets/
│   └── textures/openai/  quatre PNG et manifeste de provenance
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
    ├── smoke_test.gd
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

L’export Web cible les ordinateurs avec WebGL2, clavier ou manette. L’édition compagnon à la racine conserve les commandes tactiles et la PWA hors ligne.

## Frontière avec l’édition web

L’application web à la racine n’est pas un export de ce projet. Elle possède huit châssis et sa propre sauvegarde `localStorage` v1. `godot3d/` est, lui, l’export navigateur exact de cette édition principale. Vercel publie les deux éditions sous le même domaine sans fusionner leurs sauvegardes.
