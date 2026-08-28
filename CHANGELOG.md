# Changelog

Toutes les évolutions notables de MECHA OVERDRIVE — Circuit Zero sont consignées ici.


## [2.6.0] — 2026-08-28

### Ajouté

- volumes de collision 3D orientés pour les 500 configurations locomotrices ;
- surfaces de piste et barrières physiques statiques sur les huit circuits ;
- trois zones dangereuses visibles et sensibles à la voie sur chaque tracé ;
- anticipation IA vers une voie sûre et alerte HUD dédiée ;
- protection de la caméra TPS par raycast contre la route et les barrières ;
- suite de régression physique couvrant volumes, contacts, circuits, dangers et masque caméra.

### Corrigé

- les contacts entre concurrents ne reposent plus sur une enveloppe plane approximative ;
- les hazards ne pénalisent plus les pilotes engagés dans une voie adjacente libre.


## [2.5.1] — 2026-08-25

### Ajouté

- profils FPS canoniques pour les dix architectures avec mode, géométrie, FOV, point de vue et présence opérateur ;
- sept habitacles physiques profilés avec verrière, cadres, tableau de bord, MFD, harnais et commandes ;
- trois sensoriums de téléprésence pour Mantis H6, Orb S7 et Centurion S12, sans faux cockpit ni pilote embarqué ;
- HUD capteurs plein écran : liaison, noyau, coque, vitesse, vecteur, horizon et réticule, compatible tactile ;
- suite `fps_presentation_test.gd` couvrant les dix profils, les groupes exclusifs, les ancres, les budgets et le mobile 844 × 390.

### Corrigé

- la vue FPS n’affiche plus le même petit cockpit générique sur toutes les machines ;
- les corps télépilotés ne reçoivent plus de verrière ou d’intérieur de pilote incohérent ;
- le HUD annonce désormais `VUE COCKPIT` ou `VUE CAPTEURS` selon le châssis ;
- une préférence FPS sauvegardée ne masque plus le mécha pendant le briefing et le compte à rebours ;
- la caméra FPS suit désormais rigidement la position et l'orientation de son ancre, sans retard visible à haute vitesse ;
- le briefing et tout le compte à rebours conservent la caméra extérieure, puis la vue interne s'active exactement au départ ;
- le FOV FPS est adapté à chaque architecture et reste fixe en mode mouvement réduit.

### Performance et validation

- intérieurs détaillés construits uniquement pour le mécha joueur ;
- budget par cockpit limité à 24 meshes et 3 500 triangles ;
- CI portée à dix suites Godot avec contrat statique cockpit/sensorium ;
- régressions smoke, runtime, locomotion, modèles détaillés, animation, garage, sécurité, narration et décors conservées au vert.

## [2.5.0] — 2026-08-25

### Ajouté

- deux textures OpenAI originales : micro-panneaux de mécha et infrastructures de circuit, avec prompts, identifiants et SHA-256 ;
- suites de régression dédiées aux modèles détaillés, aux animations mécaniques et aux huit décors de production.

### Amélioré

- dix architectures procédurales enrichies de panneaux superposés, actuateurs, capteurs, évents, trappes et signatures mécaniques distinctes ;
- les 18 modules reçoivent des micro-détails manufacturés visibles immédiatement dans le garage plein écran ;
- locomotion animée par technologie : marche articulée, braquage, suspension, chenilles, rails, rotors, propulseurs, inertie, freinage et impacts ;
- huit biomes reconstruits en niveaux avant-plan, landmarks de virage, infrastructures, paddock et silhouettes MultiMesh lointaines ;
- surfaces dédiées réellement branchées sur les panneaux secondaires, portiques, tribunes, tours et bâtiments de service.

### Corrigé

- qualification du Grand Open appliquée aussi dans le service de session, sans contournement possible du verrou du menu ;
- champion de championnat déterminé avec le même départage déterministe que le classement affiché ;
- titre de saison validé uniquement à partir d’un championnat complet dont le joueur est réellement champion, y compris après une finale DNF ;
- annonces de piste contextualisées selon Course rapide, Coupe de division ou Grand Open, et nomenclature `Circuit Zero` harmonisée.
- persistance de course rendue atomique : rollback complet en cas d’échec, aucun faux titre ou couronne, retry explicite avec feedback UI, aucune double récompense et cartes de podium homologué masquées pendant `save_failed` ;

### Performance et accessibilité

- LOD hero/course et budgets de meshes mesurés sur chaque châssis et chaque module ;
- décors plafonnés à 210 descendants, éclairage borné et silhouettes lointaines instanciées pour le Web/mobile ;
- cache d’animation procédurale sans recherche de nœuds par frame et pose stabilisée en mode mouvement réduit.

### Validation

- contrats dédiés sur les dix architectures, les huit circuits, les familles de locomotion, les budgets et les textures réellement utilisées ;
- manifeste OpenAI schema 2 porté à 21 assets originaux et vérifiés par empreinte.
- scénarios de régression sur échec de persistance, retry UI, absence de faux titre/couronne et unicité des récompenses.

## [2.4.0] — 2026-08-25

### Ajouté

- Grand Tour intergalactique des Huit Mondes, Mara Vex et conflit de la Couronne libre ;
- introduction en trois chapitres, huit archives réécrites et onglet Codex des dix pilotes ;
- key art intergalactique OpenAI plein écran avec provenance complète ;
- garage plein écran derrière le HUD, cadrage persistant et gestes tactiles de rotation/pincement ;
- équipe animée du Hangar 08 : deux mécaniciens humanoïdes, robot-outilleur, drone diagnostic, outils et étincelles ;
- texture OpenAI originale de paddock pour les mécaniciens et équipements ;
- contrat `TrackSafety`, huit cases de grille et suite `gameplay_safety_test.gd` ;
- tests dédiés du garage plein écran et de la sécurité gameplay dans la CI.

### Corrigé

- chaussées élargies de 12–18 m à 35–42 m pour les plus grands méchas et trois lignes de dépassement ;
- grille de départ auparavant superposée, désormais organisée en quatre rangées de deux ;
- contacts, hors-piste et décisions de dépassement IA désormais calculés à partir des gabarits ;
- profils Canopée et Glacier lissés pour éviter les cassures après élargissement ;
- multiplicateur de difficulté retiré du joueur afin de rendre les records chrono comparables ;
- DNF et concurrents éliminés exclus des points de championnat ;
- résultat chronométré normalisé sur `finish_time`, écarts calculés et libellé `RECORD COURSE` ;
- réduction des mouvements appliquée aux méchas, caméra et équipe du garage ;
- commandes tactiles séparées du HUD en paysage et en portrait, avec télémétrie compacte ;
- ancienne introduction réaffichée via une clé narrative versionnée ;
- la touche Entrée ne traverse plus la fin de l’introduction pour lancer involontairement une course ;
- télémétrie mobile 844 × 390 bornée à 68 px et maintenue dans le gutter entre commandes ;
- classement officiel : DNF/éliminés relégués sans points, podium rival et écarts cohérents ;
- dépassement IA positionné sur une voie absolue avec écart physique plutôt que par décalage cumulatif.

### Amélioré

- Circuit Zero devient la finale exclusive du Grand Open des Huit Mondes ;
- le Grand Open exige une Coupe remportée, affiche sa qualification et reprend une saison déjà engagée ;
- Mara Vex reste présente dans la grille de saison et dispose d’une vraie identité d’écurie ;
- briefings, menu, résultats, podium et épilogues alignés sur la Nexus Grand League ;
- épilogues distincts selon une Couronne remportée par le joueur, Mara Vex ou un autre rival ;
- manifeste OpenAI porté à 19 assets avec dimensions et empreintes SHA-256.

### Validation

- import/parse Godot 4.7.2, smoke, locomotions, runtime, sécurité gameplay, garage plein écran et narration/progression exécutés localement ;
- test narration/progression ajouté à GitHub Actions ;
- audit visuel bureau/mobile, export Web, publication GitHub et déploiement Vercel documentés dans `docs/QA_REPORT.md`.

## [2.3.0] — 2026-08-24

### Ajouté

- 500 configurations de locomotion : 50 par châssis, dix technologies et cinq géométries ;
- bi-propulseur Aether original à deux nacelles antigravité, sans asset ou identité de franchise tierce ;
- sélecteur locomotion au garage, aperçu 3D instantané, effets statistiques et persistance v5 ;
- ouverture narrative Saison 03 et huit archives d’univers dans le Codex ;
- briefing de grille, compte à rebours bloquant, faux départ, arrivée cinématique et podium top 3 ;
- commandes mobiles multitouch à dix actions avec zones sûres, haptique et disposition responsive ;
- cinq textures OpenAI originales pour décors, biomes, ville humide, cérémonie et propulsion.

### Amélioré

- IA avec profils de pilote, anticipation des virages/dangers, évitement du trafic, objets contextuels et rattrapage borné ;
- circuits densifiés avec complexes départ/arrivée, tribunes, signaux et accessoires propres à chaque biome ;
- garage, course et résultats reliés au même contrat de locomotion visuelle et physique ;
- manifeste de provenance étendu à 17 textures, toutes munies de dimensions et SHA-256 vérifiables.

### Validation

- validateur statique, import Godot, smoke global, test locomotion ciblé et parcours runtime complets réussis localement.

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
