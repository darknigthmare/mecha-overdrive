# Audit gameplay et UX — MECHA OVERDRIVE 2.4.0

Date : 25 août 2026
Périmètre : édition principale Godot 4.7.2, export Web mono-thread 2.4.0
Viewports de référence : bureau 1258 × 622, mobile paysage 844 × 390

## Résultat

Le candidat 2.4.0 est **sain localement** pour une publication Web : parse Godot, six tests headless, agrégat Node, export stampé et parcours Chrome sont verts. Les limites P2 listées plus bas empêchent de le présenter comme certifié pour tous les stores ou tous les matériels, mais aucun blocage P0/P1 connu ne subsiste dans le parcours audité.

## 1. Baseline et parcours principal — Sain

Parcours observé : introduction → menu → garage → briefing/grille → compte à rebours → course → résultats/podium → Codex. Les états ont été capturés avant modification dans le même viewport que les captures finales.

- Avant : [introduction](assets/2.4.0-before/01-intro.png), [garage](assets/2.4.0-before/02-garage.png), [briefing](assets/2.4.0-before/03-grid-briefing.png), [course](assets/2.4.0-before/04-race-start.png), [Codex](assets/2.4.0-before/05-codex.png).
- Après : [introduction](assets/2.4.0-after/01-intro.png), [garage](assets/2.4.0-after/02-garage.png), [briefing](assets/2.4.0-after/03-grid-briefing.png), [course](assets/2.4.0-after/04-race-start.png), [Codex](assets/2.4.0-after/05-codex.png).
- Comparaison combinée inspectée : [planche avant/après](assets/2.4.0-comparison.jpg).

## 2. Garage et équipe mécano — Sain

Le petit cadre de preview a été remplacé par une scène 3D plein écran derrière des panneaux HUD translucides. Le mécha réel conserve son angle et son zoom lors des changements de peinture, locomotion ou module. Rotation, zoom, pincement et double-tap restent disponibles.

L’équipe du Hangar 08 comprend deux mécaniciens humanoïdes, un robot-outilleur et un drone diagnostic. Leurs outils, scans, déplacements, étincelles et couleurs rendent la baie vivante sans masquer le mécha. Le mode mouvement réduit fige les animations et supprime les étincelles. La texture `garage_crew.png` est une création originale OpenAI documentée dans le manifeste de provenance.

## 3. Narration et progression de championnat — Sain

L’ancienne exposition générique est remplacée par la Nexus Grand League, la Saison 03 « La Couronne Libre », huit mondes répartis dans trois galaxies, Hangar 08 et la rivalité avec Mara Vex. L’introduction en trois chapitres, les huit archives, l’onglet Pilotes, les briefings, les broadcasts et les épilogues emploient le même canon.

Le Grand Open des Huit Mondes est verrouillé jusqu’à la victoire dans une Coupe dédiée. L’interface expose la qualification ; une saison Open engagée est reprise. Les épilogues distinguent une Couronne remportée par le joueur, Mara Vex ou un autre rival. La touche Entrée ne fuit plus de l’introduction vers un lancement de course involontaire.

## 4. Pistes, IA et classement — Sain

Les huit pistes passent de 12–18 m à 35–42 m. Le contrat `TrackSafety` garantit au moins trois colonnes de dépassement, un écart de sécurité de 1,50 m et une grille 2 × 4. Les limites de voie, contacts de proximité et décisions de dépassement utilisent les gabarits physiques des véhicules.

Le dépassement IA cible désormais une voie absolue avec un écart calculé, évitant les décalages cumulés. Le classement officiel relègue DNF et éliminés, leur retire records/récompenses/points, et maintient un podium ainsi que des écarts cohérents lorsque le rival est champion.

## 5. Mobile et accessibilité — Sain après correction P1

À 844 × 390, la télémétrie est bornée à 68 px et placée dans le gutter entre direction et actions. Les zones tactiles paysage/portrait ne se chevauchent plus ; la largeur minimale et la limite de 22 % de hauteur sont couvertes par le test de sécurité. Capture finale : [mobile paysage](assets/2.4.0-after/06-mobile-landscape.png).

Le parcours vérifie aussi le focus UI, les entrées tactiles, le pincement du garage et le réglage de mouvement réduit. Les captures ne remplacent pas un audit lecteur d’écran, daltonisme ou parc matériel réel.

## 6. Export et portes de release — Sain localement

- Godot 4.7.2 import/parse : PASS.
- Six tests Godot : smoke, runtime, catalogue locomotion, garage, sécurité gameplay/mobile et narration/progression — PASS.
- `npm run qa` : PASS — 115/115 validations, 12/12 tests moteur, 21/21 intégration et contrat Godot statique.
- Export Web : version 2.4.0, preset Web, threads désactivés, 9/9 artefacts attestés.
- Empreinte source exportée : `ee2b4cc5b6e034a7dced01308b07a42f07fec09af6370ab533bc8f82bb9ad06c`.
- Chrome local : parcours bureau 1258 × 622 et mobile 844 × 390 vérifiés.
- GitHub Actions, release GitHub et Vercel : à renseigner après publication distante.

## P2 restant

1. Remplacer les enveloppes déterministes par de vrais colliders 3D et auditer leurs interactions caméra.
2. Rendre les hazards sensibles à la voie occupée.
3. Ajouter une confirmation avant écrasement d’un championnat actif.
4. Ajouter retry/feedback UI sur erreur de sauvegarde.
5. Fournir un remapping complet clavier, manette et tactile.
6. Étendre les déblocages progressifs aux châssis, modules, peintures et difficultés.
7. Ajouter les coupes personnalisées.
8. Auditer TPS/FPS sur les 500 configurations et un parc matériel plus large.
