# Roadmap après Godot 2.6.0

Godot 2.6.0 ajoute le socle physique de course et les dangers par voie au contrat de production visuelle 2.5.1. Son export, ses validations et sa publication sont suivis dans `docs/QA_REPORT.md`.

## Livré dans la source Godot 2.5.1

- 10 châssis originaux répartis dans 5 divisions : Commandement, Stabilisés, Essaim, Sol et Expérimental ;
- 500 configurations locomotrices, soit 50 par châssis, et 18 modules visibles répartis sur 3 emplacements ;
- courses dédiées à une division par défaut, mélange uniquement via un règlement Open explicite et 6 championnats ;
- 8 circuits du Grand Tour, tous homologués à au moins 35 m, avec trois colonnes de dépassement et une grille 2 × 4 ;
- gabarits de véhicules exprimés en mètres, limites de voie adaptées au châssis et contacts proches tenant compte de la largeur réelle ;
- garage 3D plein écran derrière le HUD, rotation/zoom, peinture, locomotion, modules et statistiques mis à jour immédiatement ;
- équipe de stand légère animée : deux mécanos humanoïdes et deux robots originaux, avec arrêt complet en mouvement réduit ;
- histoire intergalactique originale de la Nexus Grand League, Saison 03 « La Couronne Libre », sur huit mondes et trois galaxies ;
- introduction en trois chapitres, 8 archives Univers, onglet Pilotes et grille canonique de 10 pilotes (joueur + 9 IA) ;
- vues TPS/FPS par architecture : sept cockpits pilotés profilés et trois sensoriums autonomes, préférence persistante, géométries exclusives, verrouillage FPS rigide à l’ancre à 60 Hz et HUD mobile responsive ;
- briefing de grille, compte à rebours bloquant, faux départ, arrivée cinématique, podium, résultats et épilogues de championnat ;
- 21 assets bitmap OpenAI originaux et manifestés, dont l’illustration du Grand Tour, l’équipe mécano et les surfaces détaillées méchas/infrastructures ;
- sauvegarde v5 avec migrations et clé versionnée `season_intro_arc_2_seen` ;
- résultat homologué uniquement après écriture réussie, rollback complet, feedback explicite et relance de sauvegarde sans double récompense.

## P2 restants — priorité release

1. ~~Remplacer les enveloppes de proximité par de vraies collisions 3D et valider leurs interactions avec les caméras TPS/FPS.~~ Livré en 2.6.0.
2. ~~Rendre chaque hazard sensible à la voie occupée au lieu d’appliquer seulement un contexte global de secteur.~~ Livré en 2.6.0.
3. Demander confirmation avant d’écraser un championnat actif par une nouvelle coupe.
4. Fournir un remapping complet clavier, manette et profils tactiles.
5. Étendre les déblocages progressifs aux châssis, modules, peintures et difficultés ; le Grand Open est déjà qualifié après une Coupe remportée.
6. Auditer les caméras TPS/FPS sur les 500 configurations locomotrices, y compris les gabarits extrêmes.
7. Ajouter des coupes personnalisées avec validation de division, règlement, classe et rotation de pistes.

## Suites après P2

- équilibrage inter-châssis et budget énergétique à partir de télémétrie et de tests utilisateurs ;
- nouveaux circuits avec mécanique centrale testable et hazards lane-aware ;
- optimisation WebGL et réduction des temps de chargement ;
- CI, release GitHub et promotion Vercel vérifiées pour chaque nouveau build.

## Extensions structurelles envisagées

- écran partagé local ;
- fantômes locaux puis vérifiés en contre-la-montre ;
- comptes et sauvegarde cloud ;
- matchmaking privé puis public avec serveur autoritaire ;
- interpolation, réconciliation, anti-triche et classements saisonniers ;
- éditeur de livrées et partage contrôlé de configurations ;
- rivalités de pilotes et événements narratifs courts.

## Archive — roadmap du compagnon web 1.0

Les sections ci-dessous reproduisent l’ancien plan établi pour la baseline Canvas/PWA 1.0. Certaines intentions — passage en 3D, modules, circuits supplémentaires et championnats — ont depuis été livrées différemment dans Godot 2.5.0 ; elles ne constituent donc plus des travaux ouverts pour la branche principale.

## Mise à jour 1.1 — Saison des Arènes

- deux circuits supplémentaires ;
- événements de course configurables : miroir, élimination, objet unique, météo extrême ;
- fantôme local en contre-la-montre ;
- profils de difficulté personnalisés ;
- statistiques détaillées par châssis ;
- défis quotidiens locaux et médailles de maîtrise.

## Mise à jour 1.2 — Constructeur de mécha

- modules visuels interchangeables ;
- choix du cockpit, des appuis, du moteur et du blindage ;
- budget de puissance pour éviter les combinaisons dominantes ;
- partage de configurations par code JSON ;
- éditeur de livrées et numéros de pilote.

## Extension — Circuit Zero: Rivals

- écran partagé local ;
- championnats personnalisés ;
- équipes et relais ;
- rivalités de pilotes avec événements narratifs courts ;
- boss mécaniques et courses contre des machines géantes.

## Version réseau

- comptes et sauvegarde cloud ;
- matchmaking privé puis public ;
- serveur autoritaire pour positions, objets et résultats ;
- interpolation/réconciliation réseau ;
- classements saisonniers et fantômes vérifiés ;
- anti-triche et télémétrie de balance.

## Évolution 3D

Le modèle actuel peut servir de référence de gameplay pour une version 3D sous moteur dédié :

- reproduction des multiplicateurs physiques par architecture ;
- rigs spécifiques à 1, 2, 3, 4, 6 et 8 appuis ;
- animation procédurale des jambes avec placement au sol ;
- suspension/IK, déformation des chenilles et stabilisation du cockpit ;
- pistes modulaires et destruction visuelle ;
- caméra vitesse, effets de proximité et audio spatial.

## Production commerciale

Avant une publication commerciale élargie :

- tests utilisateurs sur la lisibilité du HUD et l’équilibrage ;
- passe d’accessibilité complète ;
- politique de confidentialité si une télémétrie ou des comptes sont ajoutés ;
- classification d’âge selon les territoires visés ;
- traduction et QA linguistique ;
- identité visuelle, bande-annonce et page de boutique ;
- choix explicite d’une licence pour le code et les contenus.

## Principes à conserver

- aucune architecture ne doit être strictement supérieure partout ;
- la différence de locomotion doit rester visible et jouable ;
- le rattrapage ne doit pas annuler la maîtrise ;
- les améliorations doivent offrir une progression sans rendre le jeu injuste ;
- toute monétisation future doit rester cosmétique ou liée à des extensions de contenu, sans avantage compétitif acheté.
