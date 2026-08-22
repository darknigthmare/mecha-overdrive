# MECHA OVERDRIVE — édition Godot 3D

Cette arborescence contient l’édition principale de **MECHA OVERDRIVE: Circuit Zero**, développée pour **Godot 4.7.2** en GDScript et 3D procédurale.

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

- **10 châssis** : Raptor R2, Triarch T3, Fenrir Q4, Mantis H6, Arachne O8, Wraith V0, Bastion C2, Cyclops M1, Orb S7 et Centurion S12 ;
- **4 modes** : Course rapide, Contre-la-montre, Élimination et Grand Prix ;
- **4 circuits** : Fonderie Néon, Faille Écarlate, Arc Polaire et Cimetière Orbital ;
- **8 objets** de combat/mobilité ;
- garage, peintures, améliorations, codex, HUD, résultats et progression ;
- circuits et silhouettes construits à l’exécution avec les primitives Godot.

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
| Pause | `Échap`, `P` | `Start` |

## Sauvegarde v2

`SaveSystem` enregistre le profil dans :

```text
user://mecha_overdrive_profile.json
```

Le profil conserve le pilote, les crédits, le châssis, les peintures, les améliorations, les records, les statistiques, l’accessibilité et les volumes. Les données sont normalisées et bornées à la lecture. L’écriture utilise un fichier temporaire et un backup. Une course DNF ne peut pas créer de record ni verser de récompense.

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

Le smoke contrôle le catalogue 10/4/8, les quatre modes, la normalisation du profil v2 et une simulation déterministe. Le flux runtime vérifie menu, piste 3D, HUD, huit pilotes, mouvement, DNF, résultats et retour menu tout en isolant la sauvegarde. Les résultats confirmés sont consignés dans [`../docs/QA_REPORT.md`](../docs/QA_REPORT.md).

## Organisation

```text
godot/
├── project.godot
├── assets/
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
│   └── audio/      feedback procédural
└── tests/
    ├── smoke_test.gd
    └── runtime_flow_test.gd
```

## Frontière avec l’édition web

L’application web à la racine n’est pas un export de ce projet. Elle possède huit châssis et sa propre sauvegarde `localStorage` v1. Les deux éditions peuvent évoluer et être testées séparément ; Vercel publie la version web statique, tandis que ce dossier reste la source Godot principale.
