# Rapport QA — MECHA OVERDRIVE: Circuit Zero 1.0.0

**Date de validation : 10 août 2026**  
**Statut : validé — aucun défaut bloquant détecté.**

## 1. Environnement de référence

- Node.js **22.16.0** et npm **10.9.2** ;
- Python **3.13.5** ;
- Chromium **144.0.7559.96** en mode headless ;
- bureau simulé en **1440 × 900** ;
- mobile paysage simulé en **844 × 390**, tactile activé ;
- application chargée sans ressource distante et sans étape de compilation.

## 2. Résumé chiffré

| Domaine | Résultat |
|---|---:|
| Fichiers JavaScript/MJS contrôlés récursivement | **16/16 valides** |
| Contrôles structure, données, manifeste, cache et circuits | **73/73 réussis** |
| Tests moteur ciblés | **10/10 réussis** |
| Contrôles d’intégration Node | **21/21 réussis** |
| Erreurs JavaScript dans Chromium | **0** |
| Erreurs console Chromium | **0** |
| Avertissements console Chromium | **0** |
| Architectures détectées | **8/8** |
| Circuits détectés | **4/4** |
| Objets détectés | **8/8** |
| Grand Prix parcouru | **4/4 manches** |
| Commandes tactiles visibles et actives | **6/6** |
| Références locales et liens de documentation | **41/41 valides** |

## 3. Validation complète sans navigateur

Commande :

```bash
npm test
```

La commande enchaîne quatre couches.

### 3.1 Syntaxe récursive

```bash
npm run check
```

`tools/check.mjs` parcourt le projet et lance `node --check` sur tous les fichiers `.js` et `.mjs`.

Résultat : **16 fichiers valides**.

### 3.2 Validation de livraison

```bash
npm run validate
```

`tools/validate.mjs` vérifie :

- la présence de tous les fichiers d’exécution ;
- l’ordre contractuel des dix scripts ;
- les éléments DOM indispensables ;
- le manifeste PWA et son icône ;
- la présence de chaque asset dans le cache du service worker ;
- la version et l’unicité des identifiants ;
- huit châssis, quatre circuits, huit objets, trois difficultés et quatre améliorations ;
- la génération, la longueur et la mini‑carte de chaque circuit ;
- l’absence de dépendance réseau dans le runtime.

Résultat : **73 contrôles réussis**.

### 3.3 Tests moteur

```bash
npm run test:engine
```

Cas couverts :

1. présence et unicité des huit architectures ;
2. validité des statistiques et multiplicateurs physiques ;
3. construction, décoration et cartographie des quatre circuits ;
4. formatage du temps et déterminisme du RNG ;
5. normalisation de sauvegarde et opérations de crédits ;
6. création solo et progression physique du contre‑la‑montre ;
7. réparation, bouclier et absorption d’impact ;
8. grille de huit châssis uniques en course rapide ;
9. points de Grand Prix et passage à la manche suivante ;
10. validité de tous les objets distribués.

Résultat : **10/10 tests réussis**.

### 3.4 Intégration du noyau

```bash
npm run test:integration
```

Cette suite vérifie notamment l’achat et l’équipement au garage, la création des trois modes, l’accélération, la chaleur, le bouclier, la pause, les récompenses, les records, les points de championnat et la sortie propre d’une session.

Résultat : **21 contrôles réussis**.

## 4. Parcours Chromium bureau

Commande facultative :

```bash
npm run test:browser
```

Scénario validé :

- démarrage sur le menu principal ;
- catalogue de huit châssis ;
- quatre améliorations et huit peintures ;
- quatre cartes de circuit ;
- lancement d’une course rapide à huit concurrents ;
- sortie normale du compte à rebours ;
- accélération et progression ;
- attribution et utilisation d’un Overdrive ;
- pause et reprise ;
- fin de course, récompense et huit lignes de classement ;
- lancement d’un contre‑la‑montre solo ;
- initialisation d’un Grand Prix à quatre manches.

Résultat : **aucune erreur, aucun avertissement console**.

Les captures de référence sont enregistrées dans `media/` : menu, garage, sélection du circuit, course et résultats.

## 5. QA approfondie bureau et mobile

Commande facultative :

```bash
npm run test:flow
```

### 5.1 Garage et paramètres

- sélection et persistance du Mantis H6 ;
- sauvegarde du volume à 0,35 ;
- qualité élevée ;
- contraste renforcé appliqué immédiatement ;
- tactile forcé persisté.

### 5.2 Course rapide

- difficulté As ;
- huit concurrents ;
- utilisation d’un objet ;
- pause et reprise ;
- arrivée en première position ;
- récompense calculée ;
- huit résultats générés.

### 5.3 Contre‑la‑montre

- deux tours ;
- un seul pilote ;
- difficulté désactivée dans l’interface ;
- meilleur tour calculé à **45,5 s** dans le scénario contrôlé.

### 5.4 Grand Prix complet

Ordre validé :

1. Fonderie Néon ;
2. Faille Écarlate ;
3. Arc Polaire ;
4. Cimetière Orbital.

Le roster reste stable, les huit classements sont produits, les points sont cumulés, les trois boutons **Manche suivante** apparaissent au bon moment, puis **Nouveau Grand Prix** redémarre correctement à la manche zéro.

### 5.5 Mobile tactile

Configuration : **844 × 390**, `is_mobile` et `has_touch` activés.

- commandes tactiles automatiquement visibles ;
- six boutons présents : gauche, droite, frein, objet, boost et gaz ;
- événements `pointerdown`/`pointerup` acceptés ;
- utilisation d’un bouclier depuis le bouton tactile ;
- aucune erreur de page.

Résultat global : **QA approfondie réussie**.

## 6. Serveurs locaux et robustesse de livraison

Les deux solutions de lancement ont été testées :

- `tools/server.mjs` sert les fichiers avec les bons types MIME, protège contre les chemins invalides et sélectionne automatiquement le port suivant lorsque le port demandé est occupé ;
- `tools/serve.py` sert correctement l’HTML, le CSS, les scripts, le manifeste et l’icône, puis ouvre le navigateur sur le port réellement choisi.

Un test d’occupation forcée du port a confirmé le basculement automatique de **8120 vers 8121**. Un chemin URL malformé renvoie **HTTP 403** sans interrompre le serveur.

## 7. Références et propreté du paquet

Un audit final a vérifié :

- les `src` et `href` de `index.html` ;
- les éventuelles ressources CSS ;
- le manifeste et `vercel.json` ;
- tous les assets listés par le service worker ;
- les liens relatifs des fichiers Markdown ;
- l’absence de `node_modules`, `__pycache__`, journaux ou fichiers système parasites.

Résultat : **41 références valides, aucun fichier manquant**.

## 8. Limites connues non bloquantes

- Le service worker exige HTTP/HTTPS, conformément aux règles des navigateurs.
- Les records et améliorations restent locaux au navigateur.
- Le tactile est conçu prioritairement pour le paysage.
- La physique est volontairement arcade et pseudo‑3D, sans moteur rigide externe.
- Le multijoueur réseau, l’écran partagé, les fantômes et les vibrations de manette ne font pas partie du périmètre 1.0.

## 9. Conclusion

La version 1.0.0 est jouable de bout en bout dans ses trois modes, possède un garage persistant, huit architectures réellement différenciées, quatre circuits, une IA complète, un système d’objets et un championnat à quatre manches. Les flux bureau, tactile, serveurs locaux, cache PWA, sauvegarde et packaging sont validés.
