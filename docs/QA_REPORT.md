# Rapport QA — MECHA OVERDRIVE 2.4.0

Date de validation locale : 25 août 2026

Édition principale : sources Godot 4.7.2, renderer GL Compatibility

Décision locale : **GO technique Web pour le candidat 2.4.0 exporté, stampé et vérifié sur Chrome bureau/mobile.**

## Périmètre livré dans les sources

- 10 architectures de mécha et 500 configurations locomotrices, soit 50 par châssis ;
- 18 modules sur 3 emplacements, achats/équipement atomiques et rendu immédiat ;
- 5 divisions, 8 circuits et 6 championnats à grilles dédiées ou Open ;
- Nexus Grand League, Saison 03 « La Couronne Libre » : Grand Tour de huit mondes dans trois galaxies ;
- introduction en trois chapitres, 8 archives Codex et 10 pilotes canoniques (joueur + 9 IA) ;
- garage 3D plein écran derrière le HUD avec rotation, zoom, peinture, modules et statistiques en direct ;
- quatre acteurs de stand animés — deux mécanos humanoïdes et deux robots — avec profil Web/mobile léger et mouvement réduit ;
- 19 assets bitmap OpenAI originaux, manifestés avec provenance et SHA-256 ;
- largeur de piste minimale de 35 m, trois colonnes de dépassement, gabarits physiques en mètres et grille 2 × 4 ;
- commandes clavier, manette et mobile multi-touch, HUD tactile compact et zones paysage/portrait non superposées ;
- briefing, 3-2-1-GO bloquant, faux départ, arrivée cinématique, podium, classement et épilogues de championnat ;
- sauvegarde v5 avec migrations et clé d’introduction versionnée `season_intro_arc_2_seen`.

## Contrôles locaux exécutés

| Gate | Résultat observé le 25 août 2026 |
|---|---|
| `npm run check` | PASS — 61 fichiers JavaScript |
| `npm run validate` | PASS — 115/115 |
| `npm run qa` | PASS — Web, moteur compagnon, intégration et structure Godot |
| `npm run test:engine` | PASS — 12/12 |
| `npm run test:integration` | PASS — 21/21 |
| `npm run test:godot-structure` | PASS — 10 châssis, 500 locomotions, 8 pistes homologuées, 18 modules, 6 coupes, 19 assets OpenAI, garage plein écran, mobile, Grand Tour, save v5 |
| Import/parse Godot 4.7.2 officiel | PASS |
| `godot/tests/smoke_test.gd` | PASS |
| `godot/tests/locomotion_catalog_test.gd` | PASS — 10 familles, 50 configurations/famille, 500 au total |
| `godot/tests/runtime_flow_test.gd` | PASS |
| `godot/tests/gameplay_safety_test.gd` | PASS — homologation, grille, contacts, classement/DNF et géométrie mobile |
| `godot/tests/garage_preview_test.gd` | PASS — plein écran, viewport réactif, live modules et 4 acteurs de stand animés |
| `godot/tests/narrative_progression_test.gd` | PASS — qualification/reprise du Grand Open et épilogues joueur/Vex/rival |

Le parse moteur couvre notamment les scènes d’introduction, Codex, garage, menu et résultats. Le parcours runtime instancie la vraie application et vérifie garage, briefing, compte à rebours, faux départ, mouvement, TPS/FPS, arrivée, podium, résultats et coupes dédiée/Open. Le test sécurité force le HUD mobile en paysage puis en portrait et contrôle l’absence de chevauchement des zones tactiles.

Le test garage a été relancé isolément après un nouvel import du cache de classes Godot ; le résultat final observé est PASS.

## Sécurité des pistes

`scripts/world/track_safety.gd` impose une largeur minimale calculée de 35 m, trois colonnes de dépassement, 1,50 m d’écart entre gabarits et une grille à deux concurrents sur quatre rangées. Les huit spécifications sont homologuées. `TrackFactory`, `RaceController` et `RacerState` partagent cette source de vérité pour la largeur, les limites de voie et les empreintes de véhicules.

Cette passe améliore les enveloppes déterministes de contact, mais ne constitue pas encore une simulation par colliders 3D. Les hazards restent décrits par secteur et ne sont pas encore lane-aware.

## Garage, narration et assets

La preview occupe la scène derrière les panneaux HUD au lieu d’un petit cadre. Un seul `SubViewport` réactif montre le mécha réel et préserve angle/zoom lors des changements de peinture ou de module. L’équipe mécano est limitée à quatre acteurs et à un budget géométrique léger ; le mode mouvement réduit fige l’animation et masque les étincelles.

Le canon relie la Nexus Grand League, Hangar 08, Mara Vex, le Grand Open des Huit Mondes et la finale Circuit Zero. Les mêmes termes sont employés dans l’introduction, le Codex, les pilotes, le menu, les broadcasts et les résultats.

Le manifeste de schéma 2 contient 19 bitmaps originaux OpenAI. Les deux ajouts 2.4.0 sont `intergalactic_crown_race.png` (1672 × 941, introduction) et `garage_crew.png` (1254 × 1254, équipe de stand/outils).

## Export navigateur

Le fichier `godot3d/build.json` atteste le build testé :

| Propriété | Valeur |
|---|---|
| Version jeu | `2.4.0` |
| Moteur | `4.7.2` |
| Preset | `Web` |
| Threads | `false` |
| Empreinte source | `f22a3ad2673593f7bd8f051faf1f8085bbe5e674de4d168bf2b52efcc537b9f1` |
| Artefacts attestés | 9/9 |

`tools/stamp-godot-web.mjs` a normalisé l’HTML et attesté chaque artefact. Le validateur a confirmé l’alignement de version, l’empreinte source et les neuf SHA-256.

La version exportée a été servie localement et pilotée dans Google Chrome :

- bureau 1258 × 622 : introduction en trois chapitres, retour menu sans fuite de touche Entrée, garage plein écran et équipe mécano, briefing, compte à rebours, course et Codex ;
- mobile paysage 844 × 390 : canvas et commandes tactiles visibles, télémétrie bornée à 68 px dans le gutter, sans chevauchement ;
- HTTP local et chargement WebGL2 réussis sur les captures finales.

Les preuves visuelles avant/après sont regroupées dans [`audits/2026-08-25-gameplay-ux-audit.md`](audits/2026-08-25-gameplay-ux-audit.md).

## P2 restants

1. Vraies collisions 3D et validation de leurs interactions avec les caméras TPS/FPS.
2. Hazards lane-aware.
3. Confirmation avant écrasement d’un championnat actif.
4. Retry de sauvegarde avec erreur et feedback UI.
5. Remapping complet clavier, manette et tactile.
6. Déblocages progressifs de châssis, modules, peintures et difficultés ; la qualification du Grand Open est déjà active.
7. Coupes personnalisées avec validation de règlement et rotation de pistes.
8. Audit des caméras TPS/FPS sur les 500 configurations.

## Qualification de release

- **Source et export Web Godot 2.4.0 : GO local.**
- **QA Chrome bureau/mobile : PASS.**
- **Publication distante 2.4.0 : à vérifier** après commit, CI, release et promotion Vercel.

| Gate distante 2.4.0 | Statut |
|---|---|
| Commit et push `main` | À vérifier après finalisation |
| GitHub Actions | À vérifier |
| Tag/release GitHub `v2.4.0` | À vérifier |
| Déploiement et alias Vercel | À vérifier |
| HTTP, WebGL2, console et réseau sur la production 2.4.0 | À vérifier |

Hors périmètre de cette qualification locale : certification console/store, audit juridique externe, localisation exhaustive, réseau multijoueur et QA sur parc matériel industriel.
