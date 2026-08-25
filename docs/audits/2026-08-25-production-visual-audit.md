# Audit visuel de production — MECHA OVERDRIVE 2.5.0

Date : 25 août 2026
Périmètre : export Web Godot 4.7.2 effectivement servi sur `http://127.0.0.1:8082/godot3d/mecha-overdrive.html`
Identité de l’export audité : `gameVersion 2.5.0`, preset Web mono-thread, `sourceSha256 73435a0e59657b3f9f718b3112833b2ecc006e67296386df5bb61eb88c4bad15`
Viewports : bureau 1440 × 900 et mobile paysage 844 × 390 avec émulation tactile

## Verdict final

L’export final servi passe le smoke visuel local sans P0/P1 observé : introduction, menu, garage plein écran avec mécha détaillé et équipage d’atelier, briefing, compte à rebours réel, course TPS, cockpit FPS, pause et commandes tactiles sont utilisables. Le rechargement instrumenté ne relève aucune exception JavaScript, warning/erreur console ou ressource réseau en échec.

Ce verdict s’applique strictement à l’empreinte finale ci-dessus, vérifiée dans `godot3d/build.json` avant le parcours.

Deux limites P2 restent visibles : l’interface mobile paysage est dense, particulièrement dans le garage, et la vue cockpit offre encore peu d’habillage intérieur. Elles ne bloquent pas le parcours testé, mais méritent une passe d’ergonomie sur appareils physiques.

## Environnement et méthode

- Serveur local : `node tools/server.mjs 8082`.
- Navigateur : Chrome headless isolé, rendu WebGL 2 Compatibility via SwiftShader, CDP sur `127.0.0.1:9333`.
- Bureau : métriques forcées à 1440 × 900 ; le canvas rapporte 1440 × 900.
- Mobile : métriques forcées à 844 × 390, `mobile: true`, dix points tactiles ; le canvas rapporte 844 × 390.
- Console : domaines CDP Runtime, Log et Network activés avant un rechargement sans cache, puis observation pendant 14 secondes.
- Les coordonnées ci-dessous sont fournies pour rendre les parcours reproductibles ; elles correspondent aux viewports indiqués.

## Parcours bureau — 1440 × 900

| Surface | Action reproduite | Résultat | Preuve |
| --- | --- | --- | --- |
| Introduction 01/03 | Chargement initial | Composition plein écran lisible, identité intergalactique nette, appel à l’action visible | [Introduction](assets/2.5.0-after/desktop-intro.png) |
| Introduction 02/03 et 03/03 | `Entrée`, puis `Entrée` | Les trois chapitres progressent dans l’ordre sans fuite vers la course | [Chapitre 02](assets/2.5.0-after/desktop-intro-02.png), [chapitre 03](assets/2.5.0-after/desktop-intro-03.png) |
| Menu principal | `Entrée` depuis 03/03 | Activités, championnat, garage, Codex, châssis actif et accessibilité tiennent dans le viewport | [Menu bureau](assets/2.5.0-after/desktop-main-menu.png) |
| Garage | Clic `(208, 556)` | La baie 3D occupe tout l’arrière-plan derrière les panneaux HUD ; aucun retour au petit cadre de preview | [Garage plein écran](assets/2.5.0-after/desktop-garage.png) |
| Châssis détaillé | Clic `(150, 280)` sur `MANTIS H6` | Le changement de châssis est visible immédiatement ; modèle multi-appuis, statistiques, locomotion et modules concordent | [Mantis H6 et atelier](assets/2.5.0-after/desktop-garage-detailed-mecha.png) |
| Briefing | Retour `(1350, 62)`, puis course rapide `(360, 378)` | Fonderie Néon, 3 tours, 8 partants et grille de division dédiée sont annoncés avant le départ | [Briefing de grille](assets/2.5.0-after/desktop-race-briefing.png) |
| Compte à rebours | Recommencer, puis capture dans la fenêtre mesurée après le chargement | Le panneau central affiche réellement `3`, `DÉPART VERROUILLÉ // FEUX 1/3` et un chronomètre encore à `00:00.000` | [Compte à rebours réel](assets/2.5.0-after/desktop-countdown-visible.png) |
| Course TPS | Fin du compte à rebours, puis touche `V` si nécessaire | La scène passe à la course active ; piste large, bordures lumineuses, props industriels, concurrents et mécha externe présents | [Course TPS](assets/2.5.0-after/desktop-race-tps.png) |
| Course FPS | Touche `V` | Le mécha externe disparaît, l’ancrage caméra passe au cockpit et le HUD confirme `VUE COCKPIT [V]` | [Vue cockpit](assets/2.5.0-after/desktop-race-fps.png) |
| Pause | `Échap` | Reprendre, recommencer et abandonner sont lisibles ; l’arrière-plan est assombri sans rupture de scène | [Pause bureau](assets/2.5.0-after/desktop-pause.png) |

Le compte à rebours n’est pas déduit d’une transition : la preuve fixe le chiffre `3` avant le démarrage du chronomètre, puis les captures TPS/FPS attestent le passage à la course active.

## Parcours mobile paysage — 844 × 390

| Surface | Action reproduite | Résultat | Preuve |
| --- | --- | --- | --- |
| Introduction | Remise à zéro du stockage du profil QA isolé, rechargement | Illustration, titre, texte et boutons restent dans la zone utile | [Introduction mobile](assets/2.5.0-after/mobile-intro.png) |
| Menu | `Entrée` trois fois | Les deux colonnes restent visibles sans troncature ; la typographie et les cibles sont cependant petites à 390 px de haut | [Menu mobile](assets/2.5.0-after/mobile-main-menu.png) |
| Garage | Clic `(170, 247)` | Preview plein écran conservée, listes et atelier présents ; forte densité autour du modèle et textes très petits | [Garage mobile](assets/2.5.0-after/mobile-garage.png) |
| Course active | Course rapide `(250, 159)`, attente 10 s | Le briefing et le compte à rebours débouchent sur `GO !`, chronomètre actif et course TPS sans blocage | [Après le départ](assets/2.5.0-after/mobile-race-after-countdown.png) |
| Surface tactile | Toucher neutre `(422, 190)` | Direction, drift, surcharge, objet, frein, gaz, recentrage, caméra et pause apparaissent dans des zones distinctes | [Commandes tactiles](assets/2.5.0-after/mobile-race-touch-controls.png) |
| Accélération tactile réelle | `GAZ` maintenu à `(693, 359)` pendant 2,2 s | Le bouton réagit, le mécha avance et le HUD atteint 70 km/h ; la vérification ne repose donc pas sur la seule présence visuelle des boutons | [Accélération tactile](assets/2.5.0-after/mobile-race-touch-accelerate.png) |

## Console et chargement

La trace instrumentée contient six messages d’information : deux séries de la bannière Godot 4.7.2, de l’initialisation WebGL 2 et de la configuration Emscripten mono-thread. La première série est rejouée lors de l’activation de Runtime, la seconde vient du rechargement demandé.

- Exceptions JavaScript : 0.
- Entrées console de niveau `warning` ou `error` : 0.
- Chargements réseau échoués : 0.
- Preuve brute finale : [console-final-mobile-reload.json](assets/2.5.0-after/console-final-mobile-reload.json).

## Constats et risques restants

### P0/P1

Aucun P0/P1 observé dans le parcours audité de l’export identifié. Le lancement et le recommencement de course, le décompte bloquant, le changement TPS/FPS, la pause et l’accélération tactile répondent réellement.

### P2 — Ergonomie mobile compacte

Le rendu 16:9 est conservé à l’intérieur du viewport 844 × 390, ce qui crée deux bandes latérales et réduit la largeur utile. Les commandes de course ne se chevauchent pas et répondent au toucher, mais leurs libellés sont petits. Le garage concentre simultanément liste, modèle, statistiques et atelier ; la preview reste visible mais perd sa priorité visuelle.

Recommandation : tester sur deux téléphones physiques, augmenter la taille apparente des cibles et polices en paysage court, puis prévoir un mode garage compact avec panneaux repliables ou onglets.

### P2 — Habillage cockpit

La touche `V` bascule correctement la caméra et le HUD annonce la vue cockpit. Le cadre intérieur reste minimal comparé au niveau de détail extérieur ; ajouter pare-brise, montant, instrumentation diegétique et vibrations très légères renforcerait la sensation FPS. Les mouvements de caméra devront respecter le réglage de mouvement réduit.

### Limites de cette passe

- Chrome headless et SwiftShader valident la fonctionnalité Web, pas les performances d’un GPU ou d’un téléphone réel.
- Aucun budget FPS, mémoire, température ou autonomie n’est certifié par ces captures.
- Audio, vibration matérielle, lecteur d’écran et daltonisme nécessitent une vérification dédiée.

## Gate de publication

Pour l’export final stampé identifié par `sourceSha256 73435a0e59657b3f9f718b3112833b2ecc006e67296386df5bb61eb88c4bad15` : **PASS local final**. Chargement, introduction, menu, garage, briefing, chiffre du compte à rebours, course active, bascule TPS/FPS, pause, commandes tactiles et accélération mobile sont validés ; console et réseau sont propres.
