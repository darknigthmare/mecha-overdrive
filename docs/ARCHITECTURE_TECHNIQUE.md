# Architecture technique — MECHA OVERDRIVE: Circuit Zero

## 1. Vue d’ensemble

MECHA OVERDRIVE est une application web statique sans compilation et sans dépendance d’exécution. Le navigateur charge dix scripts classiques dans un ordre déterministe ; tous partagent l’espace de noms `window.MO`, ce qui permet de conserver un déploiement très simple tout en séparant clairement les responsabilités.

La simulation et le rendu tournent dans une boucle `requestAnimationFrame`. Le pas de temps est borné à 50 ms afin d’éviter les bonds physiques après une perte de focus ou une baisse ponctuelle de fréquence.

## 2. Modules

| Fichier | Responsabilité |
|---|---|
| `js/core.js` | Version, mathématiques, couleurs, formatage, clonage, RNG déterministe et bus d’événements |
| `js/data.js` | Châssis, circuits, objets, difficultés, pilotes, récompenses et améliorations |
| `js/storage.js` | Schéma de sauvegarde, normalisation, crédits, garage, records et statistiques |
| `js/audio.js` | Synthèse Web Audio, moteur, bruitages et séquence musicale |
| `js/input.js` | Clavier AZERTY/QWERTY, Gamepad API et boutons tactiles |
| `js/track.js` | Construction des segments, décoration, dangers et mini-carte |
| `js/renderer.js` | Projection pseudo‑3D, environnements et méchas procéduraux |
| `js/game.js` | États de course, physique, IA, objets, collisions, tours et championnat |
| `js/ui.js` | Menus, garage, paramètres, HUD, pause, résultats et notifications |
| `js/main.js` | Assemblage des systèmes, boucle principale et service worker |

## 3. Démarrage et boucle principale

`main.js` :

1. récupère le Canvas principal et celui de la mini-carte ;
2. crée `MO.GameRenderer` ;
3. crée `MO.Game` avec les adaptateurs d’entrée, audio et stockage ;
4. crée `MO.UI` ;
5. démarre `requestAnimationFrame` ;
6. met automatiquement la course en pause lorsque l’onglet est masqué ;
7. enregistre le service worker sous HTTP/HTTPS ;
8. expose l’application pour les tests et le débogage.

```js
MO.app = {
  renderer,
  game,
  ui,
  version: MO.VERSION,
};
```

À chaque trame, le moteur :

- calcule un `dt` sécurisé ;
- met à jour la simulation ;
- dessine la course ou l’arrière-plan du menu ;
- met à jour le HUD ;
- ajuste le son du moteur ;
- anime les aperçus de méchas.

## 4. États et événements

`MO.Game` utilise quatre états principaux :

- `idle` : aucun mode actif ;
- `countdown` : grille de départ et compte à rebours ;
- `racing` : simulation complète ;
- `finished` : résultat calculé, course arrêtée.

Les propriétés `active` et `paused` complètent ces états. La communication entre le moteur, l’interface et la sauvegarde utilise `MO.Events` :

- `race:started`
- `race:countdown`
- `race:go`
- `race:pause`
- `race:item`
- `race:finished`
- `race:quit`
- `ui:toast`
- `save:changed`
- `settings:changed`

Le bus d’événements évite une dépendance directe de la logique de course envers le DOM.

## 5. Modèle d’un pilote

Un pilote est construit à partir d’une entrée de roster et d’un châssis. Il contient notamment :

- identité, indicatif, peinture et catégorie ;
- position de grille et position au classement ;
- `progress`, `distance`, `speed`, `x` et valeurs visuelles ;
- vitesse maximale, accélération, freinage, direction, masse et adhérence ;
- blindage, chaleur, refroidissement et état de surchauffe ;
- objet transporté et temporisations d’effets ;
- tours, temps au tour, meilleur tour et arrivée ;
- statistiques de course ;
- paramètres d’IA pour les concurrents non joueurs.

La progression absolue n’est pas remise à zéro à chaque tour. La piste est consultée avec un modulo, tandis que `distance` et `finishDistance` restent monotones. Cette séparation simplifie la détection d’arrivée et le classement.

## 6. Génération des circuits

Chaque entrée de `MO.Data.TRACKS` contient :

- palette, météo et famille de décors ;
- longueur d’un segment ;
- suite de commandes `straight`, `curve` et `s` ;
- fréquence des caisses et dangers ;
- difficulté, description et temps de référence.

`MO.Track.build(spec)` :

1. transforme les commandes en segments avec courbe et altitude interpolées ;
2. ramène progressivement l’altitude finale vers le point de départ ;
3. ajoute une zone de fermeture ;
4. place caisses, pads de boost, dangers et décors avec un RNG basé sur l’identifiant ;
5. calcule une mini-carte normalisée ;
6. met le résultat en cache.

Chaque segment contient deux points 3D, ses couleurs, sa courbure et ses objets. Les méthodes `findSegment`, `segmentAtIndex` et `progressToSegmentIndex` donnent un accès constant au tracé.

## 7. Simulation de conduite

`Game.update(dt)` exécute dans l’ordre :

1. lecture d’une trame d’entrée ;
2. gestion de la pause et du compte à rebours ;
3. diminution des temporisations ;
4. simulation du joueur ;
5. simulation de chaque IA ;
6. mise à jour des mines et projectiles ;
7. résolution des collisions entre pilotes ;
8. mise à jour du classement ;
9. détection et calcul de la fin de course.

`applyDrive` concentre le modèle de conduite :

- accélération, freinage et limite de vitesse ;
- direction dépendante de la vitesse ;
- force centrifuge liée à la courbe ;
- dérive et mini-boost ;
- surcharge thermique et verrouillage du réacteur ;
- hors-piste et adhérence ;
- effets propres à chaque architecture ;
- progression et interactions de piste.

Les effets temporaires sont stockés en secondes et décrémentés sans valeur négative.

## 8. Combat, dégâts et collisions

Les objets instantanés modifient directement les pilotes. Les objets persistants sont placés dans :

```js
game.dynamic = {
  mines: [],
  projectiles: [],
};
```

`applyImpact` centralise :

- dégâts de blindage ;
- absorption par bouclier ;
- invulnérabilité ;
- perte de vitesse ;
- rotation et étourdissement ;
- EMP ;
- source et gravité de l’impact.

Les collisions entre méchas combinent distance longitudinale, écart latéral, vitesse relative et masse. Les architectures lourdes conservent mieux leur élan et infligent davantage d’énergie au contact.

À zéro blindage, `destroyRacer` lance une reconstruction temporisée. Le pilote repart avec une intégrité partielle et une courte invulnérabilité, sans être éliminé définitivement.

## 9. Intelligence artificielle

L’IA utilise le même `applyDrive` que le joueur. Son contrôle est produit à partir :

- de la courbe actuelle et de plusieurs segments futurs ;
- d’une voie préférée recalculée périodiquement ;
- de la présence des rivaux et dangers ;
- de la compétence et de l’agressivité ;
- du niveau de chaleur ;
- de l’objet détenu et de la situation de course.

Les trois difficultés modifient vitesse, précision, agressivité, améliorations et récompenses, sans téléporter les concurrents.

## 10. Rendu pseudo‑3D

Le renderer projette les segments de piste vers le Canvas depuis une caméra placée derrière le joueur. La route est dessinée du lointain vers le proche sous forme de polygones, avec :

- dénivelé et courbure accumulée ;
- brouillard et palette par environnement ;
- bandes de rive et lignes de voie ;
- caisses, pads et dangers ;
- décors et particules météo ;
- rivaux triés par profondeur.

Les méchas sont construits avec des primitives Canvas. Le renderer sélectionne une géométrie spécifique à chaque architecture et applique la peinture sauvegardée. La même famille de fonctions sert à la course, au garage et à l’aperçu du menu.

## 11. Audio procédural

`audio.js` ne charge aucun média. Après la première interaction, il crée :

- un gain master ;
- deux oscillateurs continus pour le moteur ;
- un filtre passe-bas ;
- des oscillateurs temporaires pour les bruitages ;
- des buffers de bruit pour les impacts et boosts ;
- une séquence musicale légère pilotée par minuterie.

Le rapport vitesse/boost/dégâts module le moteur en temps réel.

## 12. Sauvegarde

Clé actuelle : `mecha_overdrive_circuit_zero_save_v1`.

```text
version
pilotName
credits
selectedChassis
paints[chassisId]
upgrades[chassisId][engine|servos|reactor|armor]
bestTimes[trackId]
settings[volume|quality|reducedMotion|highContrast|forceTouch]
stats[races|wins|podiums|distance|itemsUsed|impacts|creditsEarned|championships]
```

La sauvegarde est normalisée à chaque lecture et écriture. Les identifiants inconnus sont remplacés, les niveaux sont bornés, les couleurs sont validées et les données numériques invalides sont réparées.

## 13. PWA et déploiement

`manifest.webmanifest` demande un affichage plein écran en paysage. `service-worker.js` pré-cache tous les fichiers nécessaires au runtime, supprime les anciennes versions de cache et fournit un repli vers `index.html` en cas d’indisponibilité réseau.

Le service worker exige HTTP/HTTPS. Les options fournies sont :

- `npm start` avec le serveur Node ;
- `python3 tools/serve.py` ;
- `LANCER_JEU.bat` ou `LANCER_JEU.sh` ;
- déploiement statique via `vercel.json`, GitHub Pages, Netlify ou équivalent.

Aucune compilation n’est nécessaire.

## 14. Ajouter du contenu

### Nouveau châssis

1. Ajouter une entrée dans `CHASSIS` (`data.js`).
2. Définir `stats` et `physics`.
3. Implémenter l’aptitude dans `game.js` si elle dépasse les multiplicateurs génériques.
4. Ajouter sa géométrie dans `renderer.js`.
5. Étendre les tests d’unicité et de physique.

Le garage, les peintures, les améliorations, la sauvegarde et le roster s’adaptent automatiquement au catalogue.

### Nouveau circuit

1. Ajouter une spécification dans `TRACKS`.
2. Définir palette, décor, météo et commandes de tracé.
3. Ajouter les variantes de décor/danger nouvelles dans `track.js` et `renderer.js`.
4. Ajouter toute nouvelle ressource au service worker.
5. Exécuter les validations de longueur, décoration et mini-carte.

### Nouvel objet

1. Ajouter la métadonnée dans `ITEMS`.
2. L’ajouter aux tables pondérées dans `game.js`.
3. Implémenter son comportement dans `useItem`.
4. Ajouter son rendu dynamique et son bruitage si nécessaire.
5. Ajouter les tests correspondants.

## 15. Outils et tests

- `tools/check.mjs` : validation syntaxique récursive de tous les JS/MJS.
- `tools/validate.mjs` : 73 contrôles de présence, cache, structure, données et absence de dépendances réseau.
- `tests/run-tests.mjs` : 10 tests du moteur dans un contexte VM Node.
- `tests/smoke.mjs` : 21 contrôles d’intégration sur progression, garage, modes et course.
- `tests/browser_smoke.py` : parcours Chromium de l’interface et de la course.
- `tests/full_flow_qa.py` : championnat complet, persistance et validation tactile.
