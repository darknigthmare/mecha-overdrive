# Game Design Document — MECHA OVERDRIVE: Circuit Zero

## Contrat de jeu actuel — Godot 2.7.0

Cette section est la spécification autoritative de l’édition Godot. Elle remplace, pour cette édition, les quantités et limites de la baseline Canvas/PWA 1.0 archivée plus bas.

### Promesse narrative

Les Portes du Nexus relient huit mondes dans trois galaxies. Le Hangar 08, dernière écurie indépendante, engage le joueur dans le Grand Tour des Huit Mondes. Mara Vex, double championne de Meridian Apex, vise une troisième Couronne qui donnerait à son consortium le contrôle technique de la Ligue pendant dix cycles.

Le conflit traduit directement la personnalisation : Vex défend une architecture propriétaire unique, tandis que le Hangar 08 doit prouver que cinq cents configurations ouvertes peuvent gagner. Une victoire de Coupe vaut invitation sportive au Grand Open ; la huitième manche, exclusivement disputée sur Circuit Zero, décide de la Charte libre.

La saison compte exactement dix pilotes : le joueur et neuf rivaux persistants. Le Codex expose leurs équipes, origines, biographies et profils tactiques.

### Catalogue jouable

La release comprend **10 catégories**, chacune liée à un cadre de châssis et à une signature de mouvement propre :

| Catégorie | Châssis | Intention de pilotage |
|---|---|---|
| Pod vectoriel (`pod`) | Aether Lance P2 (`tracked`) | accélération et pointe extrêmes, direction réduite à haute vitesse |
| Cycle (`cycle`) | Valkyr C1 (`monowheel`) | inclinaison vive, lean-drift et relance |
| Rouleur (`roll`) | Orb S7 (`orb`) | inertie sphérique, pivot court et rebond |
| Bipède lourd (`biped`) | Raptor R2 | foulée lente, masse et anticipation |
| Tripode (`tripod`) | Triarch T3 | transferts d’appui méthodiques et ancrage |
| Quadrupède (`quadruped`) | Fenrir Q4 | sprint prédateur et reprise franche |
| Hexapode (`hexapod`) | Mantis H6 | six appuis adaptatifs et précision technique |
| Octopode (`octopod`) | Arachne O8 | stabilité, blindage et conservation d’élan |
| Hover (`hover`) | Wraith V0 | sustentation, dérive longue et faible contact au sol |
| Land Speeder (`land_speeder`) | Skimmer LS9 (`centurion`) | effet de sol, grandes courbes et glisse au freinage |

Les courses sont **dédiées à la catégorie du joueur par défaut**. Le roster utilise un seul `chassis_id`, y compris lorsque ses huit concurrents portent des locomotions modulaires différentes. Une grille mélangée n’existe que lorsque le joueur choisit explicitement une règle ou un championnat Open ; toute configuration incohérente est renormalisée avant la course. Les cinq divisions historiques restent une couche d’affinité technique pour les modules et les migrations de sauvegarde, pas une règle de mélange.

### Championnats et règlements

Les Grands Prix utilisent huit concurrents, un plateau stable entre les manches et le barème cumulé. Onze championnats sont livrés :

| Championnat | Grille | Classe | Circuits |
|---|---|---|---|
| Coupe Bipède | Bipède lourd uniquement, `division_locked` | `tuned` | Fonderie, Tempête, Glacier, Orbital |
| Coupe Tripode | Tripode uniquement, `division_locked` | `tuned` | Dunes, Canopée, Fonderie, Tranchée |
| Coupe Quadrupède | Quadrupède uniquement, `division_locked` | `tuned` | Fonderie, Canopée, Dunes, Tempête |
| Coupe Hexapode | Hexapode uniquement, `division_locked` | `tuned` | Canopée, Glacier, Tranchée, Orbital |
| Coupe Octopode | Octopode uniquement, `division_locked` | `tuned` | Tranchée, Fonderie, Glacier, Orbital |
| Coupe Pod Vectoriel | Pod uniquement, `division_locked` | `tuned` | Dunes, Fonderie, Tempête, Tranchée |
| Coupe Cycle | Cycle uniquement, `division_locked` | `tuned` | Tempête, Dunes, Fonderie, Orbital |
| Coupe Hover | Hover uniquement, `division_locked` | `tuned` | Orbital, Tempête, Tranchée, Glacier |
| Coupe Rouleur | Rouleur uniquement, `division_locked` | `tuned` | Glacier, Canopée, Orbital, Tempête |
| Coupe Land Speeder | Land Speeder uniquement, `division_locked` | `tuned` | Dunes, Tempête, Orbital, Tranchée |
| Grand Open des Huit Mondes (`nexus_open`) | dix catégories, `elite_open` | `unlimited` | les huit circuits, Circuit Zero en finale |

Les trois règlements sont `division_locked`, `open_mixed` et `elite_open`. Le nom interne historique `division_locked` verrouille désormais la grille à la **catégorie exacte** ; les deux autres autorisent explicitement le mélange, `elite_open` imposant aussi la classe Prototype.

### Classes et personnalisation modulaire

Trois classes de performance encadrent l’écart de puissance :

| ID | Nom affiché | Modules | Améliorations |
|---|---|---|---|
| `stock` | Série | configuration d’usine | niveau 0 |
| `tuned` | Préparé | choix libre parmi les modules | niveau maximal 2 |
| `unlimited` | Prototype | choix libre parmi les modules | niveau maximal 4 |

Chaque châssis possède un chargement enregistré dans **3 emplacements** — Noyau, Mobilité, Utilitaire — avec **18 modules** au total, soit six options par emplacement. Les neuf pièces historiques restent universelles et acquises ; neuf pièces spécialisées ajoutent affinités de division, tier, consommation, fabricant, rôle et lore. Le garage affiche le vrai modèle 3D de course et compare la base à la configuration finale avant tout achat.

La locomotion constitue un quatrième axe de préparation. Chaque châssis reçoit **50 configurations** : dix technologies (jambes mécaniques, roues vectorielles, chenilles segmentées, appuis distribués, sphères omnidirectionnelles, gyro-roue, patins magnétiques, bi-propulseur Aether, rails articulés et turbines carénées) combinées à cinq montages (compact, équilibré, voie large, endurance et pointe). Le garage plein écran filtre ces choix à l’architecture active, reconstruit immédiatement le modèle 3D sans perdre le cadrage et additionne leurs compromis aux statistiques de course. Deux mécaniciens humanoïdes, un robot-outilleur et un drone de diagnostic animent le paddock ; le mouvement réduit neutralise leurs animations secondaires.

Le bi-propulseur Aether est une conception originale à deux nacelles antigravité et cockpit central. Il exploite le principe général de poussée différentielle sans reprendre nom, silhouette, symbole ou asset d’une franchise tierce.

### Huit circuits

Les quatre pistes historiques restent Fonderie Néon (`foundry`), Faille Écarlate (`dunes`), Arc Polaire (`glacier`) et Cimetière Orbital (`orbital`). Le catalogue comprend aussi :

- **Canopée d’Azura** (`canopy`) : boue, spores et raccourcis vivants ;
- **Couronne Tempête** (`tempest`) : pluie, vents latéraux et tracé urbain vertical ;
- **Tranchée Hadale** (`abyss`) : courants, pression et spirale abyssale ;
- **Circuit Zero** (`caldera`) : lave, éruptions et couronne volcanique de la Caldeira IX.

Chaque circuit définit son grip, son profil de tracé, ses matériaux, ses accessoires et ses dangers. Les chaussées mesurent désormais **35 à 42 mètres** et respectent un contrat d’homologation de trois méchas de 9,5 m de large, avec espaces de dépassement. La grille utilise quatre rangées de deux, espacées selon les longueurs maximales ; les contacts, limites de voie et décisions de dépassement IA emploient l’empreinte de la configuration active.

Canopée et Glacier utilisent des courbes continues sans cassure de ruban. Les décors restent proches des accotements après élargissement et huit cases de grille sont visibles dans le complexe de départ.

### Caméras, direction visuelle et persistance

Tous les châssis fournissent une vue TPS et une vue FPS avec ancres et FOV dédiés. Le joueur bascule en course avec `V`, `Tab` ou `Y` à la manette ; le choix est sauvegardé. Le briefing, le compte à rebours et toute pause pré-GO conservent la caméra extérieure même si la préférence est FPS. Une fois la course lancée, la caméra FPS est verrouillée rigidement à l’ancre du mécha à 60 Hz afin d’éviter toute dérive du cadre. Sept architectures pilotées affichent un habitacle 3D propre au cadre. Mantis H6, Orb S7 et Skimmer LS9, sans pilote embarqué, affichent un sensorium plein écran avec liaison, réticule, horizon, vecteur et diagnostics. Le mode dépend du châssis, jamais du pilote sélectionné ni des 50 locomotions.

La bibliothèque de matériaux couvre l’armure légère et lourde, les micro-panneaux de détail, les trois familles de modules, les surfaces standard, thermiques et cryogéniques, le cockpit, les infrastructures et la baie du garage. Vingt-et-un assets raster originaux OpenAI incluent le key art intergalactique, l’équipe mécano et deux surfaces de production dédiées aux méchas et aux décors. Les fichiers, identifiants de génération, prompts, dimensions, empreintes SHA-256 et usages sont consignés dans `godot/assets/textures/openai/manifest.json`.

### Sauvegarde et continuité

Le profil Godot utilise `SAVE_VERSION = 6`. Il conserve les chargements, locomotions, inventaire de modules et caméra par châssis, la clé versionnée `season_intro_arc_2_seen`, ainsi que l’identité, la manche, la grille stable, la catégorie exacte, le règlement et la classe du championnat actif. Les profils antérieurs reçoivent le montage constructeur manquant et leurs anciennes Coupes de division sont remappées vers la Coupe du châssis sélectionné. Le seuil anti-altération des circuits reste fixé au schéma championnat v3 : la montée en v6 ne rend jamais les circuits sauvegardés autoritatifs.

## Annexe — Spécification historique du compagnon web 1.0

Toutes les sections numérotées 1 à 13 ci-dessous décrivent la baseline Canvas/PWA 1.0 conservée à la racine du dépôt. Elles expliquent son historique de conception, mais leurs comptes de châssis, de circuits, de modes, de progression et de rendu ne remplacent pas le contrat Godot 2.7.0 ci-dessus.

## 1. Vision

**MECHA OVERDRIVE: Circuit Zero** est un jeu de course-combat arcade où la forme du véhicule n’est pas cosmétique : son nombre d’appuis, sa masse et son mode de locomotion déterminent réellement son pilotage. L’objectif est de réunir la lisibilité immédiate d’un kart racer, la sensation de vitesse d’une course antigravité et la personnalité tactique de méchas spécialisés, dans un univers original.

La version 1.0 est un jeu navigateur complet et autonome conçu comme un titre arcade compact : choisir un châssis, apprendre sa physique, affronter sept rivaux, gagner des crédits, améliorer sa machine et progresser sur quatre circuits de difficulté croissante.

## 2. Piliers de conception

### Architecture = gameplay

Chaque catégorie répond à une question de pilotage différente : faut-il privilégier la stabilité, la masse, la reprise, le hors-piste, la vitesse ou la dérive ? Les caractéristiques et aptitudes doivent être perceptibles dès le premier tour.

### Vitesse sous contrôle

La surcharge du réacteur n’est pas un boost gratuit. Elle augmente l’accélération et la vitesse, mais génère de la chaleur. Le joueur doit choisir les lignes droites où pousser la machine et les zones où refroidir.

### Combat lisible

Les objets doivent produire une conséquence claire sans interrompre durablement la course. Boucliers, réparations, attaques ciblées, zones de contrôle et rattrapage servent la bataille de positions.

### Rejouabilité courte

Une course peut être lancée en quelques secondes. Le garage, les records et le Grand Prix donnent un objectif durable sans bloquer l’accès aux dix châssis.

## 3. Boucle principale

1. Choisir un mode et un circuit.
2. Sélectionner une architecture dans le garage.
3. Piloter : trajectoire, dérive, surcharge, objets et gestion des dégâts.
4. Terminer la course et consulter classement, meilleur tour et récompense.
5. Dépenser les crédits dans les quatre branches d’amélioration.
6. Changer de châssis, battre un record ou poursuivre le Grand Prix.

## 4. Modes de jeu

### Course rapide

Une course sur le circuit choisi, de un à cinq tours, contre sept rivaux. Les trois niveaux de difficulté modifient la vitesse, la précision, l’agressivité et les gains de crédits de l’IA.

### Grand Prix Circuit Zero

Les cinq Coupes dédiées disputent quatre manches et le Grand Open en dispute huit, dans l’ordre de circuits défini par leur catalogue. Chaque championnat conserve le même plateau de huit pilotes et châssis. Les points attribués aux concurrents classés sont **15, 12, 10, 8, 6, 5, 4, 3** ; les DNF et éliminés marquent zéro point. Le classement cumulé détermine le champion.

### Contre-la-montre

Mode solo sans rivaux. Les objets disponibles sont limités aux outils compatibles avec la recherche de performance. Le meilleur tour est sauvegardé par circuit.

## 5. Architectures jouables

| ID | Division et modèle | Profil | Aptitude passive | Risque principal |
|---|---|---|---|---|
| `biped` | Bipède — Raptor R2 | Équilibré | Réduit fortement les pertes de contrôle | Aucun avantage extrême |
| `tripod` | Tripode — Triarch T3 | Stable et blindé | Résistance aux impacts et adhérence en courbe | Accélération et pointe réduites |
| `quadruped` | Quadrupède — Fenrir Q4 | Reprise et agressivité | Boost de récupération après freinage/impact/hors-piste | Blindage léger |
| `hexapod` | Hexapode — Mantis H6 | Technique | Pénalité hors-piste réduite et braquage à basse vitesse | Vitesse seulement moyenne |
| `octopod` | Octopode — Arachne O8 | Forteresse | Collisions puissantes et faible perte d’élan | Machine lourde et lente à lancer |
| `hover` | Aéroglisseur — Wraith V0 | Très haute vitesse | Ignore les mines au sol et glisse mieux hors-piste | Blindage et stabilité faibles |
| `tracked` | Chenilles — Bastion C2 | Couple et franchissement | Ignore presque les terrains meubles | Virages lents et faible pointe |
| `monowheel` | Monopode à roue — Cyclops M1 | Dérive experte | La dérive refroidit et déclenche une micro-poussée | Très faible protection |

### Statistiques affichées

- Vitesse
- Accélération
- Maniabilité
- Blindage
- Stabilité
- Réacteur

### Paramètres physiques internes

- vitesse de pointe ;
- accélération et freinage ;
- coefficient de direction ;
- intégrité maximale ;
- adhérence hors-piste ;
- taux de chauffe/refroidissement ;
- masse et transfert d’énergie lors des collisions.

## 6. Circuits

### Fonderie Néon — Nexus Industriel 7

Piste d’apprentissage technique, avec courbes variées, fours, évents brûlants et lignes magnétiques. Elle récompense un pilotage équilibré.

### Faille Écarlate — Désert de Vermillon

Le circuit le plus rapide : longues lignes droites, sable pénalisant et ravins. Les châssis à haute vitesse ou à chenilles y excellent.

### Arc Polaire — Lune Cryo Khepri

Enchaînement d’épingles et de zones glissantes. La stabilité, la maniabilité et la discipline thermique sont prioritaires.

### Cimetière Orbital — Anneau de Morrigan

Piste experte suspendue dans l’espace, avec ruptures de gravité, débris et courbes serrées. Elle combine toutes les compétences apprises.

### Composition procédurale déterministe

Les circuits sont construits à partir de commandes de ligne droite, courbe, dénivelé et enchaînement en S. Une graine liée à l’identifiant de piste place ensuite décors, caisses, pads de boost et dangers. Un même circuit garde donc une identité stable à chaque lancement.

## 7. Pilotage

### Accélération et freinage

La vitesse tend vers une limite qui dépend du châssis, des améliorations, du terrain, de la difficulté et des effets temporaires. Le freinage sert à négocier les courbes et déclenche l’aptitude de reprise du quadrupède.

### Direction et force centrifuge

La direction est modulée par la vitesse. La courbure de la piste pousse progressivement le mécha vers l’extérieur. La masse, la stabilité et la catégorie réduisent ou amplifient cette dérive naturelle.

### Dérive

À vitesse suffisante, maintenir la commande de dérive dans un virage accumule une charge. Relâcher donne un mini-boost proportionnel. Le Cyclops M1 reçoit un bonus supplémentaire et refroidit son réacteur durant la dérive.

### Surcharge du réacteur

Le boost manuel augmente fortement l’accélération et la limite de vitesse. La chaleur monte jusqu’à 100 %. Une surchauffe verrouille le boost et force une phase de refroidissement. L’Overdrive et les pads de piste créent des poussées temporaires complémentaires.

### Hors-piste et dangers

Le sable, la glace, les évents, les anomalies gravitationnelles et les débris ont des effets différents. Les catégories spécialisées peuvent réduire ou ignorer certaines pénalités.

### Dégâts et reconstruction

Les impacts retirent du blindage et peuvent imposer rotation, étourdissement, EMP ou perte de vitesse. À zéro blindage, le mécha est reconstruit après un court délai avec invulnérabilité temporaire : le joueur n’est jamais éliminé définitivement d’une course.

## 8. Objets de combat

| Objet | Fonction | Usage tactique |
|---|---|---|
| Missile ion | Projectile guidé vers un rival devant | Rattrapage ciblé |
| Impulsion EMP | Affecte les concurrents proches | Contrôle de groupe |
| Bouclier phase | Absorbe les impacts pendant plusieurs secondes | Défense en tête ou dans le peloton |
| Cellule Overdrive | Forte accélération, vitesse accrue et refroidissement immédiat | Dépassement / ligne droite |
| Mine gravitique | Danger déposé derrière le pilote | Défense de trajectoire |
| Drone réparateur | Restaure une partie du blindage | Survie |
| Onde cinétique | Repousse et endommage les rivaux proches | Sortie de mêlée |
| Railburst | Tir très rapide et puissant vers l’avant | Attaque de précision |

### Distribution équitable

Trois tables pondérées sont utilisées : tête, milieu et fond de classement. Les pilotes en tête reçoivent surtout défense et contrôle, tandis que les derniers obtiennent davantage de mobilité et d’armes de rattrapage. Le contre-la-montre utilise sa propre table non destructive.

## 9. IA

Chaque pilote IA possède :

- une compétence de trajectoire ;
- un niveau d’agressivité ;
- une préférence de voie évolutive ;
- une anticipation des courbes ;
- un évitement des concurrents et dangers ;
- une logique contextuelle d’utilisation des objets ;
- des améliorations adaptées à la difficulté.

L’IA ne triche pas avec une téléportation ou une vitesse arbitraire. Elle utilise le même modèle de conduite, avec des multiplicateurs de difficulté contrôlés.

## 10. Progression

### Crédits

Les gains combinent participation, concurrents battus, course propre, nouveau record et victoire finale en championnat. La difficulté augmente la récompense de base.

### Améliorations

Chaque châssis possède quatre branches indépendantes de quatre niveaux :

- moteur vectoriel : vitesse de pointe ;
- servomoteurs : direction et accélération ;
- refroidissement : durée utile de la surcharge ;
- blindage composite : intégrité et résistance.

Tous les châssis sont disponibles dès le début. La progression améliore la maîtrise plutôt que de verrouiller la variété fondamentale.

## 11. Interface et accessibilité

- HUD lisible avec position, tour, vitesse, objet, blindage et chaleur ;
- mini-carte générée depuis le tracé ;
- mode contraste renforcé ;
- réduction des mouvements et animations ;
- qualité graphique réglable ;
- commandes tactiles automatiques ou forcées ;
- navigation clavier/souris et boutons dimensionnés pour l’usage tactile ;
- textes et état de course annoncés par des zones ARIA lorsque pertinent.

## 12. Direction artistique et sonore

Le monde combine compétition industrielle, néons, arènes mécaniques et science-fiction. Les méchas sont dessinés par formes géométriques en Canvas selon leur architecture réelle. Les quatre environnements utilisent des palettes, silhouettes, particules et horizons spécifiques.

Les sons sont synthétisés en temps réel avec Web Audio : moteur à deux oscillateurs, impacts, UI, boost, surchauffe, objets et motif musical. Aucun fichier audio externe n’est requis.

## 13. Périmètre de la version 1.0

La version livrée constitue un jeu navigateur complet, jouable hors ligne après mise en cache, avec progression et trois modes. Une production commerciale plus large pourrait ajouter réseau, campagne, circuits et assets 3D, mais ces extensions ne sont pas nécessaires pour jouer à Circuit Zero tel qu’il est livré.
