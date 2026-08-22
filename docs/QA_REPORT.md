# Rapport QA — MECHA OVERDRIVE 2.1.0

Date de la passe locale : **22 août 2026**
Moteur : **Godot 4.7.2 stable officiel**
Surface principale : **Godot 3D Web**, 1280 × 720
Empreinte source de l'export : `89733407256952290424b5364fd8e06aa80154af07d84561b6b22030ec1cbc89`

## Règle de preuve

Un test présent dans le dépôt n'est pas une preuve de succès. Un gate n'est marqué **PASS** ci-dessous que s'il a été exécuté sur la révision 2.1.0 courante. La publication reste **EN ATTENTE** tant que le commit final, GitHub Actions et Vercel n'ont pas été contrôlés.

## Matrice locale 2.1.0

| Gate | Résultat observé |
|---|---|
| `npm run qa` | **PASS** — 115 validations, 12/12 tests moteur web, 21 intégrations |
| Validation structurelle Godot | **PASS** — 10 châssis, 5 divisions, 8 circuits, 9 modules, 6 championnats, TPS/FPS, sauvegarde v3 |
| Smoke Godot | **PASS** — catalogue, divisions, modules, caméras, reprise Grand Prix, pilote et audio |
| Flux runtime Godot | **PASS** — menu, roster par division, modules, cockpit, mouvement, DNF, résultats, coupe dédiée et Open |
| Export Web | **PASS** — WASM 39 514 754 octets, PCK 10 078 424 octets, empreintes alignées à `build.json` |
| Chargement direct du PCK | **PASS** — Godot ouvre le paquet exporté, code 0 |
| Chromium local | **PASS** — 5 écrans distincts, ressources JS/WASM/PCK chargées, aucune erreur |
| `git diff --check` | **PASS** — aucune erreur d'espace ou de fin de ligne |
| GitHub Actions | **EN ATTENTE DE PUBLICATION** |
| Vercel production | **EN ATTENTE DE PUBLICATION** |

Marqueurs Godot observés :

```text
MECHA GODOT SMOKE: PASS (10 chassis, 5 divisions, 8 tracks, 6 cups, 9 modules, TPS/FPS, save v3, GP resume, racer, audio)
MECHA GODOT RUNTIME FLOW: PASS (menu, division roster, modules, TPS/FPS cockpit, movement, DNF, results, dedicated cup, Open cup)
```

## Contrats gameplay vérifiés

- Les cinq coupes de division n'acceptent que leurs deux architectures dédiées.
- Le **Grand Open du Nexus** est la seule coupe interdivision par défaut et annonce explicitement son règlement mixte.
- Les courses personnalisées restent dédiées sauf activation volontaire de l'option interdivision.
- Un Grand Prix utilise huit concurrents stables, conserve son roster, ses points et sa difficulté lors de la reprise.
- La sauvegarde v3 migre les profils v2, canonise le championnat et rejette les données de coupe falsifiées.
- Les dix châssis disposent de trois emplacements modulaires : noyau, mobilité et utilitaire.
- Les neuf modules modifient réellement les statistiques et disposent d'une représentation 3D.
- La classe de performance `stock`, `tuned` ou `unlimited` est appliquée au règlement de grille.
- La préférence TPS/FPS est mémorisée par châssis. En FPS, la coque extérieure est masquée et l'intérieur reste visible pendant l'animation.
- Les huit circuits appliquent leurs profils visuels et leurs dangers physiques : boue, spores, pluie, vent latéral, courant, pression, lave et éruption.
- Recommencer une course recrée une transaction propre ; terminer un championnat permet de le relancer.

## Preuve navigateur locale

Le parcours Chromium/Playwright Core a chargé l'export par HTTP puis capturé cinq états différents :

1. menu principal ;
2. garage avec dix architectures, cinq divisions et sélecteurs de modules ;
3. sélection du Grand Open avec résumé `OPEN / INTERDIVISION` ;
4. course en vue TPS ;
5. course en vue cockpit FPS.

Résultat observé :

```text
distinctScreens: 5
consoleErrors: 0
consoleWarnings: 0
pageErrors: 0
requestFailures: 0
httpErrors: 0
```

Le navigateur intégré et le binaire `agent-browser` n'étaient pas utilisables dans cet environnement. La preuve a donc été effectuée avec **Playwright Core et Google Chrome installé**, en mode headless WebGL/SwiftShader.

## Export et intégrité

`godot3d/build.json` atteste la version du moteur, le preset mono-thread, l'empreinte source et les SHA-256 des neuf artefacts Web. `npm run validate` refuse notamment :

- un WASM inférieur à 30 Mo ;
- un PCK inférieur à 500 Ko ;
- un fichier dont la taille ou le SHA divergent du manifeste ;
- un export multi-thread ou non aligné aux sources ;
- une CSP ou des en-têtes incompatibles avec Godot Web.

Pendant cette passe, la saturation du disque C: a effectivement produit un WASM vide puis un PCK incomplet. Les validateurs et Chromium ont bloqué ces artefacts. Le paquet final a été reconstruit sur un volume temporaire, chargé directement par Godot, puis copié et ré-estampillé.

## Assets OpenAI

Les textures générées pour cette version sont conservées sous `godot/assets/textures/openai/` :

- `mecha_armor.png` ;
- `track_surface.png` ;
- `cockpit_composite.png` ;
- `environment_panels.png`.

`manifest.json` conserve pour chaque bitmap le prompt complet, l'identifiant de génération et sa destination. Les matériaux procéduraux des châssis, modules, cockpits, pistes et décors consomment ces textures.

## Limites connues, non bloquantes

- La sélection modulaire est libre : les coûts de catalogue ne constituent pas encore une économie d'achat.
- Le champ descriptif `mechanic` des circuits n'implique pas de raccourcis dynamiques ; les dangers physiques, eux, sont actifs.
- Certains modules partagent une famille de silhouette procédurale, tout en gardant des statistiques et matériaux distincts.
- Le multijoueur réseau, l'écran partagé et les fantômes ne font pas partie de cette release.
- Les sauvegardes de l'édition compagnon Canvas et de Godot 3D restent indépendantes.

## Critères bloquants de publication

La release doit être refusée si l'un des cas suivants apparaît :

- échec d'un test Godot ou Node ;
- division dédiée contenant un châssis hors catégorie ;
- mode mixte activé sans choix explicite ;
- reprise de championnat perdant roster, difficulté ou points ;
- vue FPS masquée par la coque du joueur ;
- WASM/PCK vide, tronqué ou divergent de `build.json` ;
- erreur console/page/réseau pendant le parcours Chromium ;
- GitHub Actions non vert, Vercel non `READY`, ou asset public essentiel non HTTP 200.

## Consignation de publication

À compléter uniquement après vérification publique :

```text
Commit final : EN ATTENTE
GitHub Actions : EN ATTENTE
Release GitHub v2.1.0 : EN ATTENTE
Vercel production : EN ATTENTE
URL Godot : https://mecha-overdrive.vercel.app/godot3d/mecha-overdrive.html
```
