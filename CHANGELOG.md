# Changelog

Toutes les évolutions notables de MECHA OVERDRIVE — Circuit Zero sont consignées ici.

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
