# Rapport QA — MECHA OVERDRIVE 2.3.0

Date de validation locale : 24 août 2026

Édition principale : Godot 4.7.2, export Web mono-thread

Décision locale : **GO**

## Périmètre livré

- 10 architectures de mécha, chacune dotée de 50 configurations locomotrices, soit 500 combinaisons jouables ;
- dix technologies : jambes, roues, chenilles, multi-appuis, sphères, gyroscope, hover, bi-propulseur Aether, rails et turbines ;
- cinq montages par technologie : compact, équilibré, large, endurance et pointe ;
- bi-propulseur Aether original à deux nacelles antigravité indépendantes, sans asset ni nom de franchise tierce ;
- garage 3D manipulable avec aperçu instantané de la locomotion, de la peinture, des modules et des statistiques ;
- 18 modules, fiches détaillées, préréglages et transaction atomique d’achat/équipement ;
- sauvegarde v5 avec migration, locomotion et caméra propres à chaque châssis, et ouverture Saison 03 persistante ;
- 5 divisions, 8 circuits et 6 championnats à grilles dédiées ou Open ;
- commandes mobile multi-touch, zones sûres, cibles de 88 px, vibration et disposition paysage/portrait ;
- IA profilée avec trajectoire, anticipation des virages et dangers, trafic, objets contextuels et rattrapage borné ;
- briefing de grille, compte à rebours bloquant, faux départ, arrivée cinématique, podium et classement complet ;
- intro/lore Saison 03 et codex Univers ;
- 17 textures bitmap OpenAI originales et documentées ;
- vues TPS/cockpit et compatibilité clavier/manette maintenues.

## Contrôles automatisés

| Gate | Résultat |
|---|---|
| `node tools/validate-godot.mjs` | PASS — 10 châssis, 500 locomotions, 5 divisions, 8 circuits, 18 modules, 6 championnats, 17 textures, mobile, podium, intro/lore, save v5 |
| `npm run qa` | PASS |
| Validation statique web | 115/115 |
| Tests moteur du compagnon web | 12/12 |
| Tests d’intégration du compagnon web | 21/21 |
| Import/parse Godot 4.7.2 | PASS |
| `godot/tests/smoke_test.gd` | PASS |
| `godot/tests/locomotion_catalog_test.gd` | PASS — 10 familles, 50 configurations/famille, 500 au total |
| `godot/tests/runtime_flow_test.gd` | PASS |
| `git diff --check` | PASS |

Le smoke test couvre locomotions, textures, garage, save v5, mobile multi-touch, profils IA, audio et vues TPS/FPS. Le test locomotion valide exhaustivement le produit cartésien 10 × 50. Le parcours runtime instancie la vraie application et vérifie intro, garage 3D, briefing, compte à rebours bloquant, faux départ, mouvement, cockpit, arrivée cinématique, podium, résultats et championnats dédié/Open.

## Export navigateur

| Propriété | Valeur |
|---|---|
| Version jeu | `2.3.0` |
| Moteur | `4.7.2` |
| Preset | `Web` |
| Threads | `false` |
| Empreinte source | `903a68d9fabd0a2e12d043a8b8d8c7e009ffaf07520c25493139ffe808d59b39` |
| PCK | 36 371 036 octets |
| WASM | 39 514 754 octets |
| Artefacts attestés | 9/9 |

`tools/stamp-godot-web.mjs` normalise le HTML exporté puis `godot3d/build.json` atteste l’empreinte de chaque artefact et celle des sources Godot. Le validateur refuse un export périmé ou modifié.

La passe P1 finale vérifie en plus l’isolation des pièces locomotrices natives, les appuis 2/3/4/6/8/12, la texture Aether active, les effets physiques du train roulant équipé, la puissance locomotion + modules, les achats atomiques, les DNF, les grilles courtes et les contre-la-montre avec ou sans record.

## QA visuelle locale

La version exportée a été servie localement puis pilotée sous Chrome à 1280 × 720 et 844 × 390 avec WebGL2 via SwiftShader :

- HTTP 200 et titre `MECHA OVERDRIVE: Circuit Zero` ;
- canvas bureau interne et affiché en 1280 × 720 ;
- viewport mobile paysage 844 × 390 ;
- WebGL2 actif ;
- aucune erreur console ;
- aucune erreur de page ;
- aucune requête échouée ;
- intro Saison 03 et menu principal lisibles sans rognage ;
- garage complet, fiche technique et contrôles contenus dans le viewport ;
- configuration 40/50 « bi-propulseur Aether / pointe » visible avec statistiques mises à jour ;
- briefing de grille et compte à rebours visibles ;
- course active vérifiée sur bureau ;
- course active et commandes tactiles visibles sur mobile ;
- bascule tactile TPS/FPS vérifiée, coque extérieure masquée en cockpit.

## Sauvegarde et économie

La v5 conserve inventaire, loadouts, peinture, locomotion et caméra propres aux dix châssis, ainsi que l’ouverture Saison 03. Les anciens profils reçoivent une configuration constructeur valide. Les modules ou locomotions inconnus sont normalisés. `purchase_and_apply_garage()` reste atomique : toute erreur d’écriture restaure crédits, peinture, modules et configuration.

## IA et équité

Chaque pilote dispose d’un profil cohérent avec son tempérament. L’IA anticipe virages et dangers, choisit entrée/apex/sortie, évite le trafic et emploie ses objets selon la position, les menaces et l’état du mécha. Le rattrapage est borné à ±3,5 % et réduit en fin de course afin de préserver la valeur du pilotage.

## Assets et provenance

Les cinq nouvelles textures de cette passe sont des créations originales OpenAI de 1254 × 1254 pour les props industriels, biomes, ville humide, cérémonial de course et locomotion antigravité. Le manifeste de schéma 2 contient identifiant de génération, prompt, usage, dimensions et SHA-256 pour les 17 textures runtime. Aucun asset artistique tiers n’est requis.

## Qualification de release

Décision : **GO technique Web** pour une release publique originale et jouable de bout en bout.

- inclus : stabilité locale, export attesté, accessibilité de base, responsive, provenance artistique et sauvegarde migrée ;
- hors périmètre de cette validation : certification console/store, audit juridique externe, localisation exhaustive, réseau multijoueur et QA sur parc matériel industriel.

## Publication distante

Le commit d’implémentation a passé les gates distantes et son export a été promu sur l’alias public.

| Gate distante | Preuve |
|---|---|
| Commit d’implémentation | [`1d9ee03b77ea4bd2d11e1a48b63a54118c0d85b7`](https://github.com/darknigthmare/mecha-overdrive/commit/1d9ee03b77ea4bd2d11e1a48b63a54118c0d85b7) |
| GitHub Actions | [`Quality` 32770732834](https://github.com/darknigthmare/mecha-overdrive/actions/runs/32770732834) — `success` |
| Déploiement d’implémentation | `dpl_3BkxkQ5icGg7Dn6dkWAps27kPKYu` — `READY`, promotion vérifiée le 24 août 2026 |
| URL immuable | [mecha-overdrive-2pi2hxnn7-darknigthmares-projects.vercel.app](https://mecha-overdrive-2pi2hxnn7-darknigthmares-projects.vercel.app) — protection Vercel activée |
| Alias public | [Jouer à MECHA OVERDRIVE 2.3.0](https://mecha-overdrive.vercel.app/godot3d/mecha-overdrive) — HTTP 200 |
| Build public | [`build.json`](https://mecha-overdrive.vercel.app/godot3d/build.json) — version `2.3.0`, source `903a68d9fabd0a2e12d043a8b8d8c7e009ffaf07520c25493139ffe808d59b39` |
| Release | [`v2.3.0`](https://github.com/darknigthmare/mecha-overdrive/releases/tag/v2.3.0) — archive Web autonome jointe |
| Archive | `mecha-overdrive-godot-web-v2.3.0.zip` — 46 684 628 octets — SHA-256 `03599974bcf75218f7569a273c829cb73d1c5aaed04916c344878d5902bd0999` |

Chrome a chargé l’alias public en 1280 × 720 avec WebGL2 actif, canvas 1280 × 720, HTTP 200 et zéro erreur console, page ou réseau. L’URL immuable conserve la protection Vercel du compte ; l’alias de production est public.
