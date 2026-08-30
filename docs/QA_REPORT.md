# Rapport QA — MECHA OVERDRIVE 2.7.0

Date de validation locale : 30 août 2026

Édition principale : sources Godot 4.7.2, renderer GL Compatibility

Décision de release 2.7.0 : **GO local — 12/12 suites Godot, `npm run qa` et export/stamp 9/9 sont PASS. Publication distante à qualifier après déploiement.**

## Candidat catégories 2.7.0

- dix catégories homologuées : Pod vectoriel, Cycle, Rouleur, Bipède lourd, Tripode, Quadrupède, Hexapode, Octopode, Hover et Land Speeder ;
- dix signatures de conduite distinctes sur l’accélération, la direction, le braquage à haute vitesse, l’adhérence en dérive et le freinage ;
- 50 configurations modulaires par catégorie, soit 500 combinaisons ;
- dix championnats à grille strictement mono-catégorie et un Grand Open explicitement mixte ;
- IA variée à l’intérieur de la catégorie autorisée et validation runtime des engagés ;
- sauvegarde v6 avec migration canonique des championnats et conservation des finales de Circuit Zero ;
- nouvelle suite `race_category_test.gd` intégrée à la CI ;
- silhouettes Pod Aether et Land Speeder Skimmer reconstruites sans les anciennes géométries de char/myriapode ;
- migration v1-v5 des Coupes de division vers la catégorie exacte, avec locomotions IA persistées et homologuées ;
- empreinte source exportée : `c16d47513d47d5ae8c2a825cced5bcf179331ccd7475ccbde9866c90595358d9`.

## Baseline physique 2.6.0

- volumes OBB 3D dimensionnés pour les 500 configurations ;
- route et barrières en corps statiques sur les huit circuits ;
- trois zones dangereuses physiques, visibles et lane-aware par tracé ;
- anticipation IA et alerte HUD de dégagement latéral ;
- caméra TPS protégée par raycast, cockpit/sensorium FPS inchangés ;
- suite `physics_hazard_test.gd` PASS et intégrée à la CI ;
- empreinte source exportée : `5d69b4c31a7b889c2a809933b4774ebd9a869be3446e443e6d42be08a5005e3c`.

## Périmètre livré dans les sources

- 10 architectures de mécha et 500 configurations locomotrices, soit 50 par châssis ;
- 18 modules sur 3 emplacements, achats/équipement atomiques et rendu immédiat ;
- 10 catégories, 8 circuits, 10 championnats fermés et un Grand Open ;
- Nexus Grand League, Saison 03 « La Couronne Libre » : Grand Tour de huit mondes dans trois galaxies ;
- introduction en trois chapitres, 8 archives Codex et 10 pilotes canoniques (joueur + 9 IA) ;
- garage 3D plein écran derrière le HUD avec rotation, zoom, peinture, modules et statistiques en direct ;
- quatre acteurs de stand animés — deux mécanos humanoïdes et deux robots — avec profil Web/mobile léger et mouvement réduit ;
- dix silhouettes enrichies, locomotions mécaniques animées et huit décors multi-LOD avec budgets Web/mobile contrôlés ;
- présentation FPS homologuée : sept cockpits pilotés profilés, trois sensoriums autonomes, géométries exclusives et HUD mobile compact ;
- 21 assets bitmap OpenAI originaux, manifestés avec provenance et SHA-256 ;
- largeur de piste minimale de 35 m, trois colonnes de dépassement, gabarits physiques en mètres et grille 2 × 4 ;
- commandes clavier, manette et mobile multi-touch, HUD tactile compact et zones paysage/portrait non superposées ;
- briefing, 3-2-1-GO bloquant, faux départ, arrivée cinématique, podium, classement et épilogues de championnat ;
- sauvegarde v6 avec migrations de catégories et clé d’introduction versionnée `season_intro_arc_2_seen`.

## Contrôles locaux exécutés

### Candidat catégories 2.7.0

| Gate | Résultat sur le candidat 2.7.0 |
|---|---|
| Empreinte source exportée | `c16d47513d47d5ae8c2a825cced5bcf179331ccd7475ccbde9866c90595358d9` |
| Douze suites Godot | PASS — 12/12, code 0, ordre CI strictement séquentiel |
| `godot/tests/race_category_test.gd` | PASS — 10 comportements, 10 coupes fermées, un Grand Open et 500 configurations |
| `npm run qa` | PASS — 22 JS, validation Web 115/115, moteur 12/12, intégration 21/21 et structure Godot |
| Export Web mono-thread | PASS — version 2.7.0, source synchronisée et 9/9 artefacts attestés |

`narrative_progression_test.gd` émet quatre warnings intentionnels « Impossible d’ouvrir le fichier temporaire » pour exercer le rollback, puis termine PASS/code 0.

### Candidat post-P1 2.5.1 — historique

| Gate | Résultat sur le candidat 2.5.1 |
|---|---|
| Empreinte source post-revue | `e22798767175472d920ac522f766a667d793a4a84bcc338cacd8b8780871786c` |
| Dix suites Godot | PASS — 10/10, code 0, ordre CI strictement séquentiel |
| `godot/tests/fps_presentation_test.gd` | PASS runtime post-revue — ancre FPS rigide à 60 Hz et caméra extérieure pendant briefing/countdown/pause pré-GO |
| `npm run qa` | PASS — 68 JS, 115/115, moteur 12/12, intégration 21/21 et structure Godot |
| Export Web mono-thread | PASS — version 2.5.1, source synchronisée et 9/9 artefacts attestés |
| QA navigateur FPS finale | PASS — cockpit Raptor à 105 km/h, sensorium Mantis bureau/mobile et console e227 propre |

La passe finale est sans échec. `narrative_progression_test.gd` émet quatre warnings intentionnels « Impossible d’ouvrir le fichier temporaire » pour exercer le rollback, puis termine PASS/code 0. Les preuves distantes sont consignées dans la qualification de release ci-dessous.

### Baseline publiée 2.5.0 — historique conservé

Les résultats ci-dessous documentent la release 2.5.0 et ne qualifient pas l’empreinte 2.5.1.

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

La baseline 2.6.0 ajoute les volumes OBB 3D, les corps statiques de route/barrières, les hazards visibles sensibles à la voie, leur anticipation IA et la protection TPS par raycast.

## Garage, narration et assets

La preview occupe la scène derrière les panneaux HUD au lieu d’un petit cadre. Un seul `SubViewport` réactif montre le mécha réel et préserve angle/zoom lors des changements de peinture ou de module. L’équipe mécano est limitée à quatre acteurs et à un budget géométrique léger ; le mode mouvement réduit fige l’animation et masque les étincelles.

Le canon relie la Nexus Grand League, Hangar 08, Mara Vex, le Grand Open des Huit Mondes et la finale Circuit Zero. Les mêmes termes sont employés dans l’introduction, le Codex, les pilotes, le menu, les broadcasts et les résultats.

Le manifeste de schéma 2 contient 21 bitmaps originaux OpenAI. Les deux ajouts 2.5.0 sont `mecha_detail_panels.png` et `track_infrastructure_detail.png` (1254 × 1254 chacun), branchés respectivement sur les panneaux secondaires/modules et sur les infrastructures de circuit.

## Export navigateur

Le fichier `godot3d/build.json` atteste le candidat post-revue exporté et stampé :

| Propriété | Valeur |
|---|---|
| Version jeu | `2.7.0` |
| Moteur | `4.7.2` |
| Preset | `Web` |
| Threads | `false` |
| Empreinte source | `c16d47513d47d5ae8c2a825cced5bcf179331ccd7475ccbde9866c90595358d9` |
| Artefacts attestés | 9/9 |

| Artefact | Octets | SHA-256 |
|---|---:|---|
| `mecha-overdrive.html` | 5 650 | `47fe5447be8522e30a03f4cedf0c04ff5be36b3cb8f6d179fc643f580a6da856` |
| `mecha-overdrive.js` | 279 815 | `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` |
| `mecha-overdrive.wasm` | 39 514 754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `mecha-overdrive.pck` | 44 120 612 | `593fa08bdebdab6761a1157725021111cc55f81c32c348127fb64d663c2c8b99` |
| `mecha-overdrive.audio.worklet.js` | 7 298 | `5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3` |
| `mecha-overdrive.audio.position.worklet.js` | 2 973 | `be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8` |
| `mecha-overdrive.png` | 21 443 | `3cb4495c0b98dfbe4b663cbf2b6836473572339beb66d902367893162a70be0e` |
| `mecha-overdrive.icon.png` | 5 700 | `ad3c35ad0facf487c618204bd98db543034fc95224eadc7f08c7a9ff38d5b3b5` |
| `mecha-overdrive.apple-touch-icon.png` | 11 944 | `01d4f63e525941e06ce74f5187dad030d20a8d52a07ce365ae4e94af97a3b1f5` |

`tools/stamp-godot-web.mjs` a attesté l’alignement de version, l’empreinte source et les neuf SHA-256.

La QA navigateur publique 2.7.0 est à qualifier après déploiement. Les preuves FPS 2.5.1 ci-dessous restent un historique distinct et ne sont pas réattribuées au nouveau candidat.

**QA navigateur FPS finale 2.5.1 : PASS** sur l’empreinte e227 historique.

- [`desktop-biped-cockpit-final.png`](audits/assets/2.5.1-after/desktop-biped-cockpit-final.png) : cockpit Raptor physique visible et stable à 105 km/h ;
- [`desktop-mantis-sensorium-final.png`](audits/assets/2.5.1-after/desktop-mantis-sensorium-final.png) : sensorium Mantis bureau ;
- [`mobile-mantis-sensorium-final.png`](audits/assets/2.5.1-after/mobile-mantis-sensorium-final.png) : sensorium Mantis mobile compact ;
- [`console-final.json`](audits/assets/2.5.1-after/console-final.json) : URL `?build=e2279876`, six logs Godot/WebGL/Emscripten normaux, zéro warning, erreur ou échec réseau.

L’audit de production 2.5.0 reste conservé comme preuve historique et n’est pas réattribué au candidat 2.5.1.

Les captures de [`audits/2026-08-25-gameplay-ux-audit.md`](audits/2026-08-25-gameplay-ux-audit.md) restent les preuves historiques 2.4.0 et ne qualifient pas le candidat 2.5.0.

## P2 restants

1. Confirmation avant écrasement d’un championnat actif.
2. Remapping complet clavier, manette et tactile.
3. Déblocages progressifs de châssis, modules, peintures et difficultés ; la qualification du Grand Open est déjà active.
4. Coupes personnalisées avec validation de règlement et rotation de pistes.
5. Audit des caméras TPS/FPS sur les 500 configurations.

## Qualification de release

- **Sources 2.7.0 : GO local sur `c16d4751…` — 12/12 suites Godot, `npm run qa` et export/stamp 9/9 PASS.**
- **Publication distante 2.7.0 : PASS — commit, CI, release GitHub, Vercel production et artefacts publics vérifiés.**
- **Publication distante 2.5.1 : historique PASS conservé ci-dessous.**

### Publication distante 2.7.0

| Gate distante 2.7.0 | Statut |
|---|---|
| Commit de release | [`64f1c4d`](https://github.com/darknigthmare/mecha-overdrive/commit/64f1c4d7f4c7c77276736bb550834a6ce5ee8361) poussé sur `main` |
| GitHub Actions | [Quality `33286966997`](https://github.com/darknigthmare/mecha-overdrive/actions/runs/33286966997) : PASS, douze suites Godot incluses |
| Tag/release GitHub | [`v2.7.0`](https://github.com/darknigthmare/mecha-overdrive/releases/tag/v2.7.0) publique, cible `64f1c4d`, ni draft ni prerelease |
| Déploiement Vercel | `dpl_CSu1EdirXKZuvY76NB87fw6scZbD` ; production `READY` ; aucun log d’erreur post-déploiement |
| Alias public | [`mecha-overdrive.vercel.app/godot3d/mecha-overdrive`](https://mecha-overdrive.vercel.app/godot3d/mecha-overdrive) : HTTP 200 avec CSP Godot/WebAssembly attendue |
| Build public | Version 2.7.0, source `c16d4751…`, PCK 44 120 612 octets et manifeste 9/9 strictement identique au local |
| Smoke public | Accueil, jeu Godot et PCK : HTTP 200 ; le contrôle navigateur automatisé n’a pas été revendiqué, le runtime Browser de l’hôte étant bloqué et Playwright Python absent |

### Publication distante 2.5.1

| Gate distante 2.5.1 | Statut |
|---|---|
| Commit de release | [`8ed5b72`](https://github.com/darknigthmare/mecha-overdrive/commit/8ed5b72a55d5ed328a375b7d1c0d0bd2d987c21d) poussé sur `main` |
| GitHub Actions | [Quality `32894483650`](https://github.com/darknigthmare/mecha-overdrive/actions/runs/32894483650) : PASS, dix suites Godot incluses |
| Tag/release GitHub | [`v2.5.1`](https://github.com/darknigthmare/mecha-overdrive/releases/tag/v2.5.1) publique, cible `8ed5b72`, ni draft ni prerelease |
| Déploiement Vercel | `dpl_4YSQLpQa1c3MRZzVu7qiauYc1Exr` ; production `READY` ; scan d’erreurs de la dernière heure vide |
| Alias public | [`mecha-overdrive.vercel.app/godot3d/mecha-overdrive`](https://mecha-overdrive.vercel.app/godot3d/mecha-overdrive) : HTTP 200 et canvas 1440 × 900 actif |
| Build public | Version 2.5.1, source `e2279876…` et 9/9 tailles/empreintes strictement identiques au `build.json` local |
| Smoke navigateur public | PASS : six infos Godot/WebGL attendues, 0 exception, warning/erreur ou requête échouée |

### Historique de publication 2.5.0

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
