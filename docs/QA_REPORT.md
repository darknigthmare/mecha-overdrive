# Rapport QA — MECHA OVERDRIVE 2.5.0

Date de validation locale : 25 août 2026

Édition principale : sources Godot 4.7.2, renderer GL Compatibility

Décision locale : **GO technique final pour les sources, l’export Web 2.5.0 et la QA navigateur bureau/mobile. La publication distante reste en attente.**

## Périmètre livré dans les sources

- 10 architectures de mécha et 500 configurations locomotrices, soit 50 par châssis ;
- 18 modules sur 3 emplacements, achats/équipement atomiques et rendu immédiat ;
- 5 divisions, 8 circuits et 6 championnats à grilles dédiées ou Open ;
- Nexus Grand League, Saison 03 « La Couronne Libre » : Grand Tour de huit mondes dans trois galaxies ;
- introduction en trois chapitres, 8 archives Codex et 10 pilotes canoniques (joueur + 9 IA) ;
- garage 3D plein écran derrière le HUD avec rotation, zoom, peinture, modules et statistiques en direct ;
- quatre acteurs de stand animés — deux mécanos humanoïdes et deux robots — avec profil Web/mobile léger et mouvement réduit ;
- dix silhouettes enrichies, locomotions mécaniques animées et huit décors multi-LOD avec budgets Web/mobile contrôlés ;
- 21 assets bitmap OpenAI originaux, manifestés avec provenance et SHA-256 ;
- largeur de piste minimale de 35 m, trois colonnes de dépassement, gabarits physiques en mètres et grille 2 × 4 ;
- commandes clavier, manette et mobile multi-touch, HUD tactile compact et zones paysage/portrait non superposées ;
- briefing, 3-2-1-GO bloquant, faux départ, arrivée cinématique, podium, classement et épilogues de championnat ;
- sauvegarde v5 avec migrations et clé d’introduction versionnée `season_intro_arc_2_seen`.

## Contrôles locaux exécutés

| Gate | Résultat observé le 25 août 2026 |
|---|---|
| `npm run check` | PASS — 68 fichiers JavaScript |
| `npm run validate` | PASS — 115/115 |
| `npm run qa` | PASS — validation Web 115/115, moteur compagnon 12/12, intégration 21/21 et structure Godot |
| `npm run test:engine` | PASS — 12/12 |
| `npm run test:integration` | PASS — 21/21 |
| `npm run test:godot-structure` | PASS — 10 châssis, 500 locomotions, 8 pistes homologuées, 18 modules, 6 coupes, 21 assets OpenAI, détails de production, garage plein écran, mobile, Grand Tour, save v5 |
| Import/parse Godot 4.7.2 officiel | PASS |
| `godot/tests/smoke_test.gd` | PASS |
| `godot/tests/locomotion_catalog_test.gd` | PASS — 10 familles, 50 configurations/famille, 500 au total |
| `godot/tests/runtime_flow_test.gd` | PASS |
| `godot/tests/narrative_progression_test.gd` | PASS — verrou/reprise du Grand Open, tie-break déterministe, validation des titres et épilogues joueur/Vex/rival |
| `godot/tests/gameplay_safety_test.gd` | PASS — homologation, grille, contacts, classement/DNF et géométrie mobile |
| `godot/tests/garage_preview_test.gd` | PASS — plein écran, viewport réactif, live modules et 4 acteurs de stand animés |
| `godot/tests/mecha_detail_test.gd` | PASS — densité, textures et budgets meshes/triangles des 10 architectures et 18 modules |
| `godot/tests/mecha_animation_test.gd` | PASS — articulations, inertie, locomotions, mouvement réduit et budget polygonal |
| `godot/tests/track_scenery_production_test.gd` | PASS — 8 signatures, déterminisme, clearance, infrastructure texturée et plafond de nœuds |
| Tests d’intégrité de sauvegarde | PASS — rollback complet, aucun faux titre/couronne, retry avec feedback UI, aucune double récompense et cartes de podium homologué masquées pendant `save_failed` |

Le parse moteur couvre notamment les scènes d’introduction, Codex, garage, menu et résultats. Le parcours runtime instancie la vraie application et vérifie garage, briefing, compte à rebours, faux départ, mouvement, TPS/FPS, arrivée, podium, résultats et coupes dédiée/Open. Le test sécurité force le HUD mobile en paysage puis en portrait et contrôle l’absence de chevauchement des zones tactiles.

Les trois suites de production instancient réellement les dix architectures et les huit circuits : elles contrôlent densité polygonale, usage des nouvelles surfaces, animation par famille, réduction des mouvements, déterminisme, marge hors chaussée et budgets Web/mobile.

## Sécurité des pistes

`scripts/world/track_safety.gd` impose une largeur minimale calculée de 35 m, trois colonnes de dépassement, 1,50 m d’écart entre gabarits et une grille à deux concurrents sur quatre rangées. Les huit spécifications sont homologuées. `TrackFactory`, `RaceController` et `RacerState` partagent cette source de vérité pour la largeur, les limites de voie et les empreintes de véhicules.

Cette passe améliore les enveloppes déterministes de contact, mais ne constitue pas encore une simulation par colliders 3D. Les hazards restent décrits par secteur et ne sont pas encore lane-aware.

## Garage, narration et assets

La preview occupe la scène derrière les panneaux HUD au lieu d’un petit cadre. Un seul `SubViewport` réactif montre le mécha réel et préserve angle/zoom lors des changements de peinture ou de module. L’équipe mécano est limitée à quatre acteurs et à un budget géométrique léger ; le mode mouvement réduit fige l’animation et masque les étincelles.

Le canon relie la Nexus Grand League, Hangar 08, Mara Vex, le Grand Open des Huit Mondes et la finale Circuit Zero. Les mêmes termes sont employés dans l’introduction, le Codex, les pilotes, le menu, les broadcasts et les résultats.

Le manifeste de schéma 2 contient 21 bitmaps originaux OpenAI. Les deux ajouts 2.5.0 sont `mecha_detail_panels.png` et `track_infrastructure_detail.png` (1254 × 1254 chacun), branchés respectivement sur les panneaux secondaires/modules et sur les infrastructures de circuit.

## Export navigateur

Le fichier `godot3d/build.json` atteste le candidat exporté et validé structurellement :

| Propriété | Valeur |
|---|---|
| Version jeu | `2.5.0` |
| Moteur | `4.7.2` |
| Preset | `Web` |
| Threads | `false` |
| Empreinte source | `73435a0e59657b3f9f718b3112833b2ecc006e67296386df5bb61eb88c4bad15` |
| Artefacts attestés | 9/9 |

| Artefact | Octets | SHA-256 |
|---|---:|---|
| `mecha-overdrive.html` | 5 650 | `2d3757a1d193361c36568d8b429cf9d8ac091ffe1848165dedb82d37b7979327` |
| `mecha-overdrive.js` | 279 815 | `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` |
| `mecha-overdrive.wasm` | 39 514 754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `mecha-overdrive.pck` | 44 075 748 | `3ae8ac08d84cc02135c1130efd2dc6f408e80dfe3615e251011950698ea4e4d0` |
| `mecha-overdrive.audio.worklet.js` | 7 298 | `5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3` |
| `mecha-overdrive.audio.position.worklet.js` | 2 973 | `be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8` |
| `mecha-overdrive.png` | 21 443 | `3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e` |
| `mecha-overdrive.icon.png` | 5 700 | `ad3c35ad0facf487c618204bd98db543034fc95224eadc7f08c7a9ff38d5b3b5` |
| `mecha-overdrive.apple-touch-icon.png` | 11 944 | `01d4f63e525941e06ce74f5187dad030d20a8d52a07ce365ae4e94af97a3b1f5` |

`tools/stamp-godot-web.mjs` a normalisé l’HTML et attesté chaque artefact. Le validateur a confirmé l’alignement de version, l’empreinte source et les neuf SHA-256.

**QA navigateur finale 2.5.0 : PASS** sur l’empreinte exacte ci-dessus.

- bureau 1440 × 900 : introduction, garage plein écran, briefing, vrai chiffre `3`, TPS, cockpit FPS et pause ;
- mobile 844 × 390 : introduction, menu, garage, course, surface tactile et accélération maintenue jusqu’à 70 km/h ;
- console/reload instrumenté 14 s : 0 exception, 0 warning/erreur et 0 requête échouée ;
- preuves et méthode : [`audits/2026-08-25-production-visual-audit.md`](audits/2026-08-25-production-visual-audit.md).

Les captures de [`audits/2026-08-25-gameplay-ux-audit.md`](audits/2026-08-25-gameplay-ux-audit.md) restent les preuves historiques 2.4.0 et ne qualifient pas le candidat 2.5.0.

## P2 restants

1. Vraies collisions 3D et validation de leurs interactions avec les caméras TPS/FPS.
2. Hazards lane-aware.
3. Confirmation avant écrasement d’un championnat actif.
4. Remapping complet clavier, manette et tactile.
5. Déblocages progressifs de châssis, modules, peintures et difficultés ; la qualification du Grand Open est déjà active.
6. Coupes personnalisées avec validation de règlement et rotation de pistes.
7. Audit des caméras TPS/FPS sur les 500 configurations.

## Qualification de release

- **Sources, import, neuf suites Godot, agrégat Node et export Web 2.5.0 : GO local.**
- **QA Chrome bureau/mobile finale 2.5.0 : PASS sur `73435a0e…`.**
- **Publication distante 2.5.0 : GO — GitHub, release et Vercel vérifiés.**

| Gate distante 2.5.0 | Statut |
|---|---|
| Commit de release | [`68b440b`](https://github.com/darknigthmare/mecha-overdrive/commit/68b440ba51adb5f73891f809099b72f45f1b9270) poussé sur `main` |
| GitHub Actions | [Quality `32874920449`](https://github.com/darknigthmare/mecha-overdrive/actions/runs/32874920449) : PASS en 1 min 40 s, neuf suites Godot incluses |
| Tag/release GitHub | [`v2.5.0`](https://github.com/darknigthmare/mecha-overdrive/releases/tag/v2.5.0) publique, cible `68b440b`, ni draft ni prerelease |
| Archive Web | 54 381 642 octets ; SHA-256 `2742fa17d186ae4047558d3b3fd46511811001d31d1b583e6fa26564d9bb005c`, digest GitHub identique |
| Déploiement Vercel | `dpl_4ywg7N5SyGddErTtFawU7f8DPFDi` ; production `READY` ; build statique 325 ms |
| Alias public | [`mecha-overdrive.vercel.app/godot3d/mecha-overdrive`](https://mecha-overdrive.vercel.app/godot3d/mecha-overdrive) : HTTP 200, HTML 5 650 octets et en-têtes Godot/CSP attendus |
| Build public | Version 2.5.0, source `73435a0e…` et 9/9 empreintes strictement identiques au `build.json` local |
| Smoke navigateur public | PASS à 844 × 390 : canvas actif, six infos Godot/WebGL attendues, 0 exception, warning/erreur ou requête échouée |

Hors périmètre de cette qualification de release : certification console/store, audit juridique externe, localisation exhaustive, réseau multijoueur et QA sur parc matériel industriel.
