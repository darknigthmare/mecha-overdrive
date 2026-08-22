# Changelog

Toutes les évolutions notables de MECHA OVERDRIVE — Circuit Zero sont consignées ici.

## [2.2.0] — 2026-08-22

### Ajouté

- garage visuel fondé sur le vrai modèle 3D de course, avec plateau tournant, glisser, zoom, recadrage et respect du mouvement réduit ;
- filtres par division, préréglages Équilibre/Vitesse/Contrôle/Armure et fiche détaillée de chaque pièce ;
- neuf nouveaux modules spécialisés, portant le catalogue à dix-huit pièces et six choix dans chacun des trois emplacements ;
- inventaire modulaire, coûts effectifs et achat plus application atomiques, sans redébiter une pièce déjà acquise ;
- huit nouvelles textures originales OpenAI : armures légère/lourde, trois familles de module, pistes thermique/cryo et baie d’atelier.

### Amélioré

- comparaison base vers configuration finale pour les six statistiques, incluant modules et améliorations permanentes ;
- aperçu instantané de la peinture, des silhouettes modulaires et des préréglages avant toute dépense ;
- matériaux distincts selon division, famille de module et environnement de piste ;
- dix-huit silhouettes modulaires explicites à la place du dispatch générique par fragments d’identifiant ;
- sauvegarde v4 avec migration des neuf pièces historiques offertes et préservation stricte des championnats v3 canoniques.

### Ergonomie

- cibles d’action agrandies, atelier organisé en onglets et détails importants visibles sans dépendre des infobulles ;
- validation et annulation explicites des changements, coût restant et manque de crédits affichés avant achat ;
- rotation clavier Q/E, souris, molette et boutons accessibles directement dans la prévisualisation.

## [2.1.0] — 2026-08-22

### Ajouté

- cinq divisions d’homologation regroupant les dix architectures, avec grilles dédiées par défaut ;
- cinq coupes de division à quatre manches et Grand Open du Nexus à huit manches, seul championnat explicitement interdivision ;
- roster de huit concurrents stable et persistant pendant tout un championnat ;
- trois emplacements de customisation — noyau, mobilité et utilitaire — et neuf modules visibles avec effets physiques ;
- classes Série, Préparé et Prototype imposant réellement leurs modules et plafonds d’amélioration ;
- bascule à chaud TPS/cockpit avec ancres propres aux dix châssis, coque occultée et intérieur visible en première personne ;
- Canopée d’Azura, Couronne Tempête, Tranchée Hadale et Caldeira Zéro, portant le catalogue à huit circuits ;
- dangers jouables pour boue, spores, pluie, vent latéral, courant, pression, lave et éruption ;
- quatre matériaux bitmap originaux générés avec OpenAI pour armure, piste, cockpit et environnement, avec prompts et identifiants archivés.

### Amélioré

- sauvegarde v3 avec loadouts par châssis, vue caméra, identité/règlement/classe de coupe et roster enrichi ;
- migration des Grand Prix v2 vers la coupe dédiée correspondant au châssis actif dans chacune des cinq divisions ;
- règles de coupe canoniques protégées contre la réécriture par une sauvegarde altérée ;
- géométries, accessoires et répétition de surface propres aux huit profils de circuit ;
- garage enrichi avec constructeur, lore, division, trois sélecteurs de module et bilan statistique net ;
- menu principal enrichi avec politique de grille, sélection du championnat et avertissements d’incompatibilité de division ;
- résultats enrichis avec nom de coupe, manche réelle et règle dédiée/Open.

### Corrigé

- incohérence possible entre règlement Open et grille dédiée ;
- Grand Prix pouvant lancer moins de concurrents que son classement persistant ;
- division des concurrents perdue lors de la normalisation d’une sauvegarde ;
- ancre TPS par châssis déclarée mais ignorée par la caméra de course ;
- nouveaux dangers de circuit décoratifs sans incidence sur la simulation.

### Validation

- contrat statique réussi : 10 châssis, 5 divisions, 8 circuits, 9 modules, 6 championnats, TPS/FPS et sauvegarde v3 ;
- import et parse strict réussis avec Godot 4.7.2 officiel ;
- smoke Godot enrichi réussi, incluant migrations v2 des cinq divisions, anti-altération, huit fabriques 3D et textures ;
- flux runtime réussi : menu, roster dédié, modules physiques/visuels, TPS/cockpit, DNF, résultats, coupe dédiée et Open.

## [2.0.1] — 2026-08-22

### Ajouté

- véritable export Web de l’édition Godot 3D sous `godot3d/`, produit avec les modèles officiels Godot 4.7.2 en profil mono-thread ;
- manifeste de build reproductible `godot3d/build.json` avec taille et SHA-256 des neuf artefacts exportés ;
- scripts de contrôle et d’estampillage du build Web Godot, intégrés à la validation Node ;
- lanceur visible depuis l’édition compagnon vers la course Godot 3D, avec cible bureau clavier/manette explicitée ;
- notices tierces et attribution du moteur Godot pour la distribution publique.

### Amélioré

- aptitudes spécialisées et déterministes des dix châssis, objets IA, pads de boost et contrats Course/Contre-la-montre/Grand Prix ;
- récupération réelle des sauvegardes de secours, persistance d’un Grand Prix actif et sélection garage fiable ;
- sélecteurs de circuit et de difficulté dans le menu principal Godot ;
- audio procédural Web via `AudioStreamGenerator`, caméra de course, winding des meshes de piste et temporisation du signal `OVERDRIVE!` ;
- règles CSP, cache et types MIME adaptés au runtime WebAssembly Godot sans affaiblir la CSP de l’édition compagnon.

### Validation

- `npm run qa` réussi : 26 fichiers JavaScript/MJS, 115 contrôles de validation, 12/12 tests moteur et 21 contrôles d’intégration ;
- import, smoke et flux runtime réussis avec Godot 4.7.2 officiel ;
- export Web mono-thread complet : neuf artefacts présents, tailles et empreintes vérifiées ;
- Chromium local : menu Godot puis vraie course 3D avec circuit, méchas, HUD et audio chargés, sans erreur console, page ou réseau.

## [2.0.0] — 2026-08-22

### Ajouté

- édition principale Godot 4.7.2 en 3D procédurale avec scène d’application complète ;
- dix châssis jouables, dont Orb S7 et Centurion S12 ;
- quatre modes : Course rapide, Contre-la-montre, Élimination et Grand Prix ;
- circuits 3D avec relief, garage, codex, HUD, résultats, audio procédural et sauvegarde v2 ;
- usage tactique et déterministe des huit objets par les pilotes IA ;
- key art original généré avec OpenAI, intégré aux deux éditions et documenté ;
- smoke test Godot et test de flux headless menu → course 3D → résultats → menu ;
- CI GitHub exécutant Node, l’import Godot 4.7.2 officiel et les tests headless ;
- configuration Vercel/PWA durcie pour l’édition web autonome.

### Corrigé

- typage strict GDScript sans abaisser les avertissements configurés comme erreurs ;
- initialisation prématurée du menu avant les champs `@onready` ;
- compte à rebours HUD recevant une valeur numérique dynamique ;
- effet EMP incomplet et objets IA conservés sans utilisation ;
- conflit du bouton `A` de la manette web, commandes tactiles manquantes, DNF et reprise du Grand Prix ;
- recalage web anti-spam et cache du service worker.

### Validation

- import Godot 4.7.2 strict sans erreur ;
- smoke Godot et flux runtime 3D headless réussis sans avertissement ;
- 17 fichiers JavaScript, 79 contrôles PWA/structure, 12/12 tests moteur et 21 contrôles d’intégration réussis ;
- parcours Chromium local bureau et tactile sans erreur console ni requête échouée.

## [1.0.0] — 2026-08-10

### Ajouté

- jeu de course-combat pseudo‑3D complet dans le navigateur ;
- huit architectures : bipède, tripode, quadrupède, hexapode, octopode, aéroglisseur, chenilles et monopode à roue ;
- quatre circuits originaux et leur mini-carte ;
- Course rapide, Grand Prix à quatre manches et Contre-la-montre ;
- grille de huit pilotes et IA à trois difficultés ;
- huit objets de combat et de soutien ;
- surcharge thermique, dérive, mini-boost, dégâts, reconstruction et dangers ;
- garage, peintures, quatre branches d’amélioration et économie de crédits ;
- sauvegarde locale, records et statistiques ;
- clavier, Gamepad API et interface tactile ;
- synthèse audio Web Audio ;
- paramètres de qualité, volume, contraste et réduction des mouvements ;
- installation PWA et cache hors ligne ;
- lanceurs Windows/macOS/Linux, serveur local et scripts de QA ;
- documentation de conception, architecture, tests et roadmap.

### Validation

- 10/10 tests moteur et 21/21 contrôles d’intégration réussis ;
- 73/73 contrôles structurels réussis ;
- 16 fichiers JavaScript/MJS validés ;
- QA Chromium bureau et mobile sans erreur ;
- cycle Grand Prix complet vérifié.
