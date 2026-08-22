# Rapport QA — MECHA OVERDRIVE: Circuit Zero

## 1. Portée et règle de preuve

Ce rapport distingue les deux surfaces du dépôt :

- **Godot 3D**, édition principale sous Godot **4.7.2** ;
- **web**, édition compagnon statique à la racine.

Un fichier de test présent dans le dépôt indique une couverture prévue, pas un résultat. Un gate n’est marqué comme réussi qu’après exécution sur la révision courante. La QA Node, le validateur statique, l’import strict, le smoke, le flux runtime Godot, le contrat d’export Web et les parcours Chromium locaux ont été confirmés.

## 2. Matrice de release courante

| Gate | Commande ou surface | État documenté |
|---|---|---|
| Validation Node | `npm test` | **PASS** — 26 JS/MJS, 115 contrôles de validation, 12/12 moteur, 21 intégration |
| Contrat structurel Godot | `node tools/validate-godot.mjs` | **PASS** — 10 châssis, 4 circuits, 8 objets, 4 modes |
| Agrégat web + structure Godot | `npm run qa` | **PASS** — agrège les deux gates précédents |
| Import et parse Godot | `godot --headless --path godot --editor --quit` | **PASS** — Godot 4.7.2, code 0, aucune erreur |
| Smoke Godot | `godot --headless --path godot --script res://tests/smoke_test.gd` | **PASS** — catalogue, récupération de sauvegarde, résultats, Grand Prix, garage, pads, 10 aptitudes et audio |
| Flux runtime Godot | `godot --headless --path godot --script res://tests/runtime_flow_test.gd` | **PASS** — menu, course 3D, HUD, audio stream, caméra, 8 pilotes, mouvement, DNF, résultats et retour menu |
| Export Godot Web | preset `Web`, sortie `godot3d/` | **PASS** — profil mono-thread, 9 artefacts, tailles et SHA-256 contrôlés |
| Parcours Godot Web local | Chromium/Playwright HTTP, 1280 × 720 | **PASS** — menu puis vraie course 3D, 0 erreur console/page/réseau et 0 requête échouée |
| Déploiement Vercel 2.0.1 | `https://mecha-overdrive.vercel.app` | **EN ATTENTE** — publication et contrôle de production à exécuter après le push de la révision |

Les statuts locaux ci-dessus proviennent d’exécutions réelles sur la révision courante. Le statut Vercel reste volontairement en attente tant que le build 2.0.1 n’est pas publié et contrôlé sur l’URL publique.

## 3. QA Godot 3D

### 3.1 Environnement cible

- Godot **4.7.2 stable** ;
- renderer **GL Compatibility** ;
- scène principale `res://scenes/app.tscn` ;
- résolution de référence 1280 × 720, viewport logique 1920 × 1080 ;
- profil de sauvegarde v2, backup et Grand Prix actif dans `user://`.

### 3.2 Validation structurelle sans moteur

Commande :

```bash
node tools/validate-godot.mjs
```

Le validateur contrôle le contrat statique du projet, notamment :

- projet Godot et scène principale présents ;
- catalogue canonique de dix châssis ;
- quatre circuits avec relief et palettes complètes ;
- quatre modes `quick`, `time_trial`, `elimination`, `grand_prix` ;
- huit objets et sauvegarde version 2 ;
- présence des scènes, scripts et tests nécessaires ;
- contrat `max_armor` du snapshot de pilote ;
- absence de fichiers de reconstruction temporaires connus.

Résultat confirmé : **PASS** — 10 châssis, 4 circuits, 8 objets et 4 modes détectés.

Ce gate ne parse pas le GDScript et ne lance pas la simulation.

### 3.3 Import et parse Godot

Commande :

```bash
godot --headless --path godot --editor --quit
```

Ce passage doit terminer sans erreur de parse, ressource manquante ni erreur d’import. Les avertissements ne doivent pas masquer une erreur réelle. Résultat confirmé : **PASS** avec Godot 4.7.2, code de sortie `0` et aucune erreur.

### 3.4 Smoke test headless

Commande :

```bash
godot --headless --path godot --script res://tests/smoke_test.gd
```

Le script `godot/tests/smoke_test.gd` vérifie :

1. dix châssis avec leurs identifiants et noms attendus ;
2. quatre circuits, huit objets, relief minimum et palettes complètes ;
3. migration/normalisation du profil v2 ;
4. rejet des crédits et chronos invalides ;
5. configuration des quatre modes ;
6. grille solo en contre-la-montre et grille à huit ailleurs ;
7. déterminisme d’un pilote simulé pendant 300 ticks ;
8. récupération d’un backup valide et persistance/reprise du Grand Prix ;
9. ciblage du châssis courant dans le garage et comportement des pads de boost ;
10. aptitudes spécialisées des dix châssis et initialisation audio.

Le succès attendu est un code de sortie `0` avec le marqueur :

```text
MECHA GODOT SMOKE: PASS (catalogue, save recovery, results, GP resume, garage, racer, pads, 10 abilities, audio)
```

Résultat confirmé : **PASS** avec code de sortie `0` et marqueur de succès observé.

### 3.5 Flux runtime automatisé et QA manuelle

Commande exécutée :

```bash
godot --headless --path godot --script res://tests/runtime_flow_test.gd
```

Le test instancie `app.tscn`, lance une vraie course à huit pilotes, vérifie le circuit, le HUD, le mouvement, la caméra et le flux audio, force un DNF, contrôle Results et revient au menu. La sauvegarde est isolée puis restaurée.

Résultat confirmé : **PASS**, code `0`, avec le marqueur :

```text
MECHA GODOT RUNTIME FLOW: PASS (menu, 3D race, HUD, stream audio, camera, 8 racers, movement, DNF, results, menu)
```

Après les gates headless, vérifier au minimum :

1. ouverture du menu principal ;
2. navigation garage et codex ;
3. sélection de chacun des dix châssis ;
4. lancement d’une Course rapide ;
5. accélération, direction, dérive, boost, objet, pause et recalage ;
6. passage d’un tour et mise à jour du classement ;
7. résultat terminé puis retour au menu ;
8. DNF sans crédits ni record ;
9. Contre-la-montre solo sans objets ;
10. cadence d’élimination ;
11. progression des quatre manches du Grand Prix ;
12. relecture d’un profil v2 après redémarrage.

Le noyau automatisé est confirmé. La liste manuelle étendue ci-dessus reste recommandée avant tout export binaire desktop.

## 4. QA des surfaces Web

### 4.1 Agrégat Node

Commande :

```bash
npm test
```

Elle enchaîne :

```bash
npm run check
npm run validate
npm run test:engine
npm run test:integration
```

La couverture vise la syntaxe JS/MJS, les références statiques, le manifeste et le cache PWA, les huit châssis web, les quatre circuits, les objets, la physique, le garage, les sauvegardes, le contre-la-montre, le Grand Prix et les non-régressions DNF/recalage.

Résultat confirmé : **PASS** — 26 fichiers JavaScript/MJS, 115 contrôles de validation, 12/12 tests moteur et 21 contrôles d’intégration.

### 4.2 Parcours de l’édition compagnon

Commandes disponibles :

```bash
npm run test:browser
npm run test:flow
```

Le parcours de release couvre :

- rendu du menu et du key art ;
- démarrage d’une Course rapide ;
- absence d’erreur console ;
- pause, reprise et recalage sans spam ;
- interaction manette sans conflit sur le bouton `A` ;
- commandes tactiles en paysage ;
- DNF par limite de temps ;
- persistance du Grand Prix web ;
- écran de résultats puis retour au menu.

Résultat local confirmé : **PASS** sous Chromium/Playwright via HTTP en vues bureau et mobile. Le menu et le key art répondent correctement (`200`), le service worker est actif, le garage expose 8 châssis, 4 améliorations et 8 peintures, la course démarre avec 8 concurrents, pause/reprise fonctionne et 9 commandes tactiles sont présentes. Le parcours n’a relevé aucune erreur ni requête échouée.

### 4.3 Export et parcours Godot Web

La cible `Web` de `godot/export_presets.cfg` produit un build Godot 4.7.2 mono-thread sous `godot3d/`. Ce choix évite d’exiger l’isolation cross-origin et conserve une publication statique compatible Vercel. Le build courant comprend neuf artefacts : HTML, JavaScript, WebAssembly, PCK, deux worklets audio, deux icônes et l’image PNG de démarrage.

`npm run stamp:godot-web` génère `godot3d/build.json`. `npm run validate` vérifie ensuite :

- la présence et la taille minimale de chaque artefact ;
- l’empreinte SHA-256 et le nombre d’octets enregistrés dans le manifeste ;
- la cohérence du SHA source, de la version Godot et du preset ;
- l’absence de threads Web et d’extensions natives ;
- les règles CSP, cache, service worker et lanceur racine nécessaires.

Résultat confirmé : **PASS** — neuf artefacts cohérents. Chromium a chargé le menu Godot en WebGL2, puis lancé une vraie course montrant circuit, méchas et HUD. Les fichiers JS, WASM, PCK et worklets audio ont répondu `200`; le parcours a relevé **0** erreur console, **0** avertissement console, **0** erreur de page et **0** requête échouée. Le signal `OVERDRIVE!` s’est correctement masqué après le départ.

### 4.4 Déploiement Vercel

URL cible : [`https://mecha-overdrive.vercel.app`](https://mecha-overdrive.vercel.app).

Le push et le déploiement de la révision 2.0.1 n’étaient pas encore exécutés au moment de ce rapport. La production ne doit être déclarée conforme qu’après avoir vérifié :

- état du déploiement `READY` et association au commit publié ;
- HTTP `200` sur `/`, le lanceur Godot, le JS, le WASM, le PCK et les worklets ;
- MIME `application/wasm` pour le module WebAssembly ;
- CSP stricte à la racine et CSP Godot autorisant uniquement les besoins WebAssembly prévus ;
- parcours public menu Godot → vraie course, sans erreur console/page/réseau ;
- non-régression du compagnon PWA, y compris le cache hors ligne après une première visite HTTPS.

État de la gate 2.0.1 : **EN ATTENTE DE PUBLICATION**.

## 5. Baseline web historique importée

Le paquet web d’origine contenait un rapport daté du **10 août 2026** avec les résultats annoncés suivants : 16 fichiers JS/MJS valides, 73 contrôles de structure, 10 tests moteur, 21 contrôles d’intégration, un parcours Chromium bureau et un parcours tactile paysage.

Ces chiffres expliquent la couverture historique, mais les preuves de la révision courante sont les résultats confirmés aux sections 2 et 4.

## 6. Critères bloquants

La release est bloquée si l’un de ces cas est observé :

- erreur de parse ou import Godot ;
- smoke test Godot avec code non nul ;
- scène principale qui ne s’ouvre pas ;
- catalogue incomplet ou divergence des dix châssis ;
- mode impossible à démarrer ou à terminer ;
- DNF récompensé ou enregistré comme record ;
- sauvegarde v2 corrompue sans récupération ;
- exception JavaScript, test Node en échec ou référence statique manquante ;
- export Godot Web absent, incomplet, multi-thread ou divergent de `build.json` ;
- déploiement non `READY`, HTTP non 200 ou asset essentiel absent.

## 7. Limites connues du périmètre

- Le multijoueur réseau, l’écran partagé et les fantômes ne font pas partie de cette édition.
- Le build Godot Web est ciblé bureau clavier/manette ; l’édition compagnon Canvas/PWA reste la surface tactile mobile.
- Les sauvegardes Godot et web sont indépendantes.
- Le service worker du compagnon n’intercepte pas `godot3d/` : l’export Godot nécessite une connexion.
- Aucun binaire Windows/Linux natif n’est inclus dans cette gate.

## 8. Gabarit de consignation finale

```text
Commit : <sha>
Date : <ISO-8601>
Godot : 4.7.2 stable
npm run qa : PASS/FAIL
Import Godot : PASS/FAIL
Smoke Godot : PASS/FAIL
Runtime Godot : PASS/FAIL + surface vérifiée
Navigateur local : PASS/FAIL + viewport
Export Godot Web : PASS/FAIL + SHA du manifeste
Vercel : READY/FAIL + URL
```
