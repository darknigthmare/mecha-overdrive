# Rapport QA — MECHA OVERDRIVE: Circuit Zero

## 1. Portée et règle de preuve

Ce rapport distingue les deux surfaces du dépôt :

- **Godot 3D**, édition principale sous Godot **4.7.2** ;
- **web**, édition compagnon statique à la racine.

Un fichier de test présent dans le dépôt indique une couverture prévue, pas un résultat. Un gate n’est marqué comme réussi qu’après exécution sur la révision courante. La QA Node, le validateur statique, l’import strict, le smoke et le flux runtime Godot ainsi que les parcours Chromium locaux ont été confirmés.

## 2. Matrice de release courante

| Gate | Commande ou surface | État documenté |
|---|---|---|
| Validation web Node | `npm test` | **PASS** — 17 JS, 79 contrôles structure/PWA, 12/12 moteur, 21 intégration |
| Contrat structurel Godot | `node tools/validate-godot.mjs` | **PASS** — 10 châssis, 4 circuits, 8 objets, 4 modes |
| Agrégat web + structure Godot | `npm run qa` | **PASS** — agrège les deux gates précédents |
| Import et parse Godot | `godot --headless --path godot --editor --quit` | **PASS** — Godot 4.7.2, code 0, aucune erreur |
| Smoke Godot | `godot --headless --path godot --script res://tests/smoke_test.gd` | **PASS** — code 0, marqueur de succès observé |
| Flux runtime Godot | `godot --headless --path godot --script res://tests/runtime_flow_test.gd` | **PASS** — menu, course 3D, HUD, mouvement, DNF, résultats et retour menu ; code 0, aucun avertissement |
| Parcours navigateur local | Chromium/Playwright HTTP, bureau + mobile | **PASS** — 0 erreur et 0 requête échouée |
| Déploiement Vercel | `https://mecha-overdrive.vercel.app` | **PASS** — production READY, HTTP 200, assets/PWA, parcours bureau/mobile et navigation hors ligne |

La production web a été vérifiée le 22 août 2026. Les statuts runtime et Vercel ci-dessus proviennent d’exécutions réelles, pas d’une déduction des validations statiques.

## 3. QA Godot 3D

### 3.1 Environnement cible

- Godot **4.7.2 stable** ;
- renderer **GL Compatibility** ;
- scène principale `res://scenes/app.tscn` ;
- résolution de référence 1280 × 720, viewport logique 1920 × 1080 ;
- profil de sauvegarde v2 dans `user://mecha_overdrive_profile.json`.

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
8. présence de `max_armor` et progression positive du pilote.

Le succès attendu est un code de sortie `0` avec le marqueur :

```text
MECHA GODOT SMOKE: PASS (catalogue, save, modes, deterministic racer)
```

Résultat confirmé : **PASS** avec code de sortie `0` et marqueur de succès observé.

### 3.5 Flux runtime automatisé et QA manuelle

Commande exécutée :

```bash
godot --headless --path godot --script res://tests/runtime_flow_test.gd
```

Le test instancie `app.tscn`, lance une vraie course à huit pilotes, vérifie Track/HUD/mouvement, force un DNF, contrôle Results et revient au menu. La sauvegarde est isolée puis restaurée.

Résultat confirmé : **PASS**, code `0`, marqueur `MECHA GODOT RUNTIME FLOW: PASS`, sans avertissement ni fuite ObjectDB.

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

## 4. QA de l’édition web

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

Résultat confirmé : **PASS** — 17 fichiers JavaScript/MJS, 79 contrôles de structure/PWA, 12/12 tests moteur et 21 contrôles d’intégration.

### 4.2 Parcours navigateur

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

### 4.3 Déploiement statique

Production vérifiée : [`https://mecha-overdrive.vercel.app`](https://mecha-overdrive.vercel.app).

- réponse HTTP 200 de `/` et `/index.html` ;
- chargement du key art, du manifeste et du service worker ;
- absence de ressource distante requise par le runtime ;
- parcours menu → course → pause → retour ;
- comportement hors ligne après une première ouverture HTTPS.

Résultat confirmé : **PASS**. Le déploiement `dpl_Cbx6DRzWJ6TaYfJivJ5z6Rwrxc2a` est `READY` et aliased sur l’URL publique. `/`, le key art, le manifeste et le service worker répondent correctement ; `/index.html` redirige proprement vers l’URL canonique `/`.

Le parcours Chromium de production confirme menu, garage, Course rapide à huit concurrents, pause/reprise et interface tactile, sans erreur console ni requête échouée.

La navigation PWA hors ligne a été validée après installation et prise de contrôle du service worker : les requêtes réseau ont été bloquées, puis un rechargement initié par la page a restauré le menu depuis le cache canonique.

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
- déploiement non `READY`, HTTP non 200 ou asset essentiel absent.

## 7. Limites connues du périmètre

- Le multijoueur réseau, l’écran partagé et les fantômes ne font pas partie de cette édition.
- L’édition web utilise un rendu Canvas pseudo-3D ; elle n’est pas un export Web de Godot.
- Les sauvegardes Godot et web sont indépendantes.
- Vercel publie l’édition web statique, pas un binaire desktop Godot.
- Un export Godot Windows/Linux/Web exige un gate d’export et un smoke test du binaire produit.

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
Vercel : READY/FAIL + URL
```
