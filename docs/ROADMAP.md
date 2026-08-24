# Roadmap après Godot 2.3.0

La release Godot 2.3.0 est la branche principale. Cette roadmap distingue ce qui est déjà livré, les suites encore envisagées et l’ancien plan du compagnon web conservé à titre historique.

## Livré dans Godot 2.3.0

- 10 châssis originaux répartis dans 5 divisions : Commandement, Stabilisés, Essaim, Sol et Expérimental ;
- courses dédiées à une division par défaut et mélange uniquement via une option Open explicite ;
- 6 championnats : 5 coupes dédiées de quatre manches et le Grand Open du Nexus sur les 8 circuits ;
- règlements `division_locked`, `open_mixed`, `elite_open` et grilles de Grand Prix stables à huit concurrents ;
- classes `stock`, `tuned`, `unlimited`, avec plafonds d’amélioration et politique de modules effectivement appliqués ;
- personnalisation par 3 emplacements et 18 modules, avec affinités, inventaire, économie, statistiques et silhouettes visibles ;
- 500 configurations locomotrices, soit 50 par châssis, avec aperçu, statistiques et sauvegarde ;
- garage 3D interactif avec rotation, zoom, peinture immédiate, comparaison base/configuration, brouillon et validation atomique ;
- 8 circuits, dont Canopée d’Azura, Couronne Tempête, Tranchée Hadale et Caldeira Zéro ;
- dangers physiques, profils de tracé, grip, accessoires et matériaux propres aux pistes ;
- vues TPS et cockpit/FPS pour les 10 châssis, avec ancres dédiées et préférence persistante ;
- dix-sept textures OpenAI originales pour armures, modules, pistes, cockpits, décors, cérémonie et antigravité ;
- intro Saison 03, lore Codex, briefing, 3-2-1-GO, faux départ, arrivée et podium ;
- commandes mobiles complètes et IA à profils, trajectoires et objets contextuels ;
- sauvegarde v5, migration des profils v2/v3/v4, conservation des modules historiques et canonicalisation des championnats.

## Priorités après 2.3.0

- affiner l’équilibrage inter-châssis à partir de télémétrie locale et de tests utilisateurs ;
- affiner le budget énergétique et les tiers des 18 modules dans les trois classes de performance ;
- ajouter des championnats personnalisés qui valident explicitement division, règlement, classe et rotation de pistes ;
- créer de nouveaux circuits avec une mécanique centrale testable, des profils visuels originaux et des dangers simulés ;
- ajouter le remapping complet des commandes et des profils tactiles ;
- poursuivre l’optimisation de l’export WebGL et des temps de chargement.

## Extensions structurelles envisagées

- écran partagé local ;
- fantômes locaux puis vérifiés en contre-la-montre ;
- comptes et sauvegarde cloud ;
- matchmaking privé puis public avec serveur autoritaire ;
- interpolation, réconciliation, anti-triche et classements saisonniers ;
- éditeur de livrées et partage contrôlé de configurations ;
- rivalités de pilotes et événements narratifs courts.

## Archive — roadmap du compagnon web 1.0

Les sections ci-dessous reproduisent l’ancien plan établi pour la baseline Canvas/PWA 1.0. Certaines intentions — passage en 3D, modules, circuits supplémentaires et championnats — ont depuis été livrées différemment dans Godot 2.3.0 ; elles ne constituent donc plus des travaux ouverts pour la branche principale.

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
