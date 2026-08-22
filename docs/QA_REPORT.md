# Rapport QA — MECHA OVERDRIVE 2.2.0

Date de validation locale : 22 août 2026

Édition principale : Godot 4.7.2, export Web mono-thread

Décision locale : **GO**

## Périmètre livré

- garage 3D manipulable utilisant le même `MechaFactory` que les courses ;
- aperçu immédiat du châssis, de la peinture et des trois modules équipés ;
- rotation automatique, glisser-déplacer, boutons, molette, zoom et recentrage ;
- 18 modules, soit six noyaux, six mobilités et six utilitaires ;
- fiches avec fabricant, rôle, lore, niveau, puissance, affinités, coût et effets ;
- préréglages Équilibre, Vitesse, Contrôle et Armure ;
- achat, peinture et équipement appliqués dans une transaction atomique ;
- inventaire persistant et migration de sauvegarde v3 vers v4 ;
- douze textures bitmap OpenAI documentées, dont huit nouvelles pour les armures, modules, pistes et baie du garage ;
- compatibilité maintenue avec 10 châssis, 5 divisions, 8 circuits, 6 championnats et les vues TPS/cockpit.

## Contrôles automatisés

| Gate | Résultat |
|---|---|
| `node tools/validate-godot.mjs` | PASS — 10 châssis, 5 divisions, 8 circuits, 18 modules, 6 championnats, 12 textures, garage 3D, TPS/FPS, save v4 |
| `npm run qa` | PASS |
| Validation statique web | 115/115 |
| Tests moteur du compagnon web | 12/12 |
| Tests d’intégration du compagnon web | 21/21 |
| Import/parse Godot 4.7.2 | PASS |
| `godot/tests/smoke_test.gd` | PASS |
| `godot/tests/runtime_flow_test.gd` | PASS |
| `git diff --check` | PASS |

Le smoke test Godot couvre le catalogue, les textures, l’aperçu garage, la sauvegarde v4, l’achat atomique, la migration, les coupes, le pilote, l’audio et les vues TPS/FPS. Le parcours runtime instancie la vraie application, ouvre le garage 3D, vérifie le changement visuel de modules, revient au menu puis joue une course jusqu’aux résultats et contrôle les coupes dédiée et Open.

## Export navigateur

| Propriété | Valeur |
|---|---|
| Version jeu | `2.2.0` |
| Moteur | `4.7.2` |
| Preset | `Web` |
| Threads | `false` |
| Empreinte source | `411e995089295f28f8f44dbc929c97198bf030bca10df34e831febd883a92004` |
| PCK | 26 081 204 octets |
| WASM | 39 514 754 octets |
| Artefacts attestés | 9/9 |

`tools/stamp-godot-web.mjs` normalise le HTML exporté puis `godot3d/build.json` atteste l’empreinte de chaque artefact et celle des sources Godot. Le validateur refuse un export périmé ou modifié.

## QA visuelle locale

La version exportée a été servie localement puis pilotée dans Chromium à 1280 × 720 avec WebGL2 via SwiftShader :

- HTTP 200 et titre `MECHA OVERDRIVE: Circuit Zero` ;
- canvas interne et affiché en 1280 × 720 ;
- WebGL2 actif ;
- aucune erreur console ;
- aucune erreur de page ;
- aucune requête échouée ;
- menu principal lisible sans rognage ;
- garage complet lisible sans glyphes manquants ;
- châssis 3D visible avec baie texturée ;
- passage au préréglage Vitesse visible sur les modules et les statistiques ;
- panneaux, liste des dix châssis, fiches et contrôles contenus dans le viewport.

## Sauvegarde et économie

La v4 conserve l’inventaire global `owned_modules` et les loadouts propres aux dix châssis. Les neuf modules historiques restent acquis lors d’une migration. Les modules inconnus, incompatibles ou non possédés sont normalisés. `purchase_and_apply_garage()` débite une seule fois les pièces manquantes et applique peinture/loadout ensemble ; toute erreur d’écriture restaure crédits, peinture et configuration.

## Assets et provenance

Les huit nouvelles textures sont des créations originales OpenAI de 1254 × 1254. Le manifeste de schéma 2 contient leur identifiant de génération, prompt, usage, dimensions et SHA-256. Les douze textures runtime sont chargées explicitement et testées ; aucun asset artistique tiers n’est requis.

## Publication distante

Les identifiants du commit d’implémentation, du run GitHub Actions, du déploiement Vercel et de la release seront ajoutés après leur validation distante. Cette section n’est pas un substitut aux gates locales ci-dessus.
