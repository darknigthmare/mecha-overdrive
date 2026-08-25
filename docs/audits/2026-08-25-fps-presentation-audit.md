# Audit de présentation FPS — MECHA OVERDRIVE 2.5.1

Date : 25 août 2026
Périmètre : export Web Godot 4.7.2 local, non publié à distance
Identité des sources : `sourceSha256 e22798767175472d920ac522f766a667d793a4a84bcc338cacd8b8780871786`

## Verdict

**PASS local navigateur et présentation, sans P0/P1 observé.** La vue interne n’est plus une caméra générique commune à tous les méchas : le bipède présente un cockpit physique embarqué, stable dans la capture en mouvement à 105 km/h, tandis que le Mantis utilise un sensorium distant avec réticule et télémétrie propres. Les deux familles restent identifiables immédiatement par leur silhouette d’interface et par le libellé du HUD.

Ce verdict couvre uniquement l’export local et l’empreinte ci-dessus. Aucune publication GitHub, release ou Vercel de la version 2.5.1 n’a encore été effectuée ni vérifiée.

## Preuves finales inspectées

| Preuve | Fait visible | Résultat |
| --- | --- | --- |
| [Cockpit bipède desktop](assets/2.5.1-after/desktop-biped-cockpit-final.png) | Capture 1440 × 900 en mouvement à 105 km/h : cadre d’habitacle, montants latéraux, repères cyan, bandeau `HABITACLE // RAPTOR R2 // COCKPIT TACTIQUE` et HUD `VUE COCKPIT [V]` | La vue embarquée reste visible et stable à vitesse réelle, avec une ouverture centrale suffisante sur la piste et les concurrents. |
| [Sensorium Mantis desktop](assets/2.5.1-after/desktop-mantis-sensorium-final.png) | Capture 1440 × 900 : bandeau `LIAISON SENSORIUM // MANTIS H6`, réticule central `SYNC`, télémétrie distribuée dans deux panneaux latéraux et HUD `VUE CAPTEURS [V]` | Le pilotage distant est visuellement distinct du cockpit, sans faux pare-brise ni structure d’habitacle. |
| [Sensorium Mantis mobile](assets/2.5.1-after/mobile-mantis-sensorium-final.png) | Capture 844 × 390 : réticule et identité sensorium conservés, panneaux latéraux repliés, piste et HUD principal dégagés | L’adaptation mobile réduit l’encombrement sans perdre l’identité de la vue capteurs. |
| [Console finale](assets/2.5.1-after/console-final.json) | Rechargement instrumenté pendant 15 secondes sur l’URL locale marquée `build=e2279876` ; six entrées uniquement Godot/WebGL/Emscripten, toutes de niveau `log` | 0 exception JavaScript, 0 entrée `warning`/`error` et 0 chargement réseau échoué observé. |

## Contrat fonctionnel couvert par les tests

Les captures établissent la présentation finale ; les tests automatisés couvrent les comportements non démontrables par une image fixe :

- les dix architectures sont réparties en **sept cockpits embarqués** et **trois sensoriums distants** ;
- la vue interne ne devient active qu’au signal **GO**, après le briefing et le compte à rebours ;
- sur mobile, les panneaux sensorium sont repliés et leurs surfaces restent transparentes aux entrées tactiles, afin de ne pas bloquer les commandes de course.

Ces garanties sont donc rapportées comme résultats de tests, et non comme déductions tirées des trois captures.

## P2 et limites restantes

- **Montants du cockpit :** les deux piliers sombres donnent une identité mécanique forte, mais occupent une part notable de la vision périphérique. Une vérification en mouvement, sur écran ultralarge et avec plusieurs valeurs de FOV reste recommandée.
- **Lisibilité du sensorium :** les données cyan des panneaux desktop sont cohérentes mais petites et peu contrastées dans cette ambiance orange. Prévoir un contrôle sur les biomes plus lumineux et avec les réglages d’accessibilité texte/contraste.
- **Validation mobile :** le repli des panneaux est clairement visible ; une capture ne peut toutefois pas prouver le passage effectif des touchers. Cette propriété est couverte par les tests et doit encore être éprouvée sur téléphone physique.
- Ces preuves statiques ne certifient pas les performances, les animations de transition, les vibrations de caméra, l’audio ni le confort sur une course longue.

## Gate locale

Pour `sourceSha256 e22798767175472d920ac522f766a667d793a4a84bcc338cacd8b8780871786` : **PASS local navigateur FPS/PRÉSENTATION**. Les preuves finales montrent un cockpit bipède stable à 105 km/h, un sensorium Mantis desktop et son adaptation mobile, tandis que la trace console reste propre. La publication distante demeure volontairement hors de ce verdict.
