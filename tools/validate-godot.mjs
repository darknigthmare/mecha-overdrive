import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const files = {
  project: 'godot/project.godot',
  database: 'godot/scripts/data/game_database.gd',
  save: 'godot/scripts/systems/save_system.gd',
  session: 'godot/scripts/systems/game_session.gd',
  racer: 'godot/scripts/race/racer_state.gd',
  raceController: 'godot/scripts/race/race_controller.gd',
  mechaFactory: 'godot/scripts/mecha/mecha_factory.gd',
  visualModules: 'godot/scripts/visual/mecha_visual_modules.gd',
  cockpitVisuals: 'godot/scripts/visual/cockpit_visuals.gd',
  firstPersonOverlay: 'godot/scripts/ui/first_person_overlay.gd',
  materialLibrary: 'godot/scripts/visual/material_library.gd',
  trackSafety: 'godot/scripts/world/track_safety.gd',
  mainMenu: 'godot/scripts/ui/main_menu.gd',
  garage: 'godot/scripts/ui/garage.gd',
  garagePreview: 'godot/scripts/ui/garage_preview.gd',
  garageScene: 'godot/scenes/garage.tscn',
  garagePreviewScene: 'godot/scenes/components/garage_preview.tscn',
  locomotionCatalog: 'godot/scripts/data/locomotion_catalog.gd',
  locomotionVisuals: 'godot/scripts/visual/locomotion_visuals.gd',
  mobileControls: 'godot/scripts/input/mobile_touch_controls.gd',
  raceHud: 'godot/scripts/ui/race_hud.gd',
  podium: 'godot/scripts/ui/podium_presenter.gd',
  resultsScene: 'godot/scenes/results.tscn',
  intro: 'godot/scripts/ui/season_intro.gd',
  introScene: 'godot/scenes/season_intro.tscn',
  lore: 'godot/scripts/data/lore_database.gd',
  manifest: 'godot/assets/textures/openai/manifest.json',
  smoke: 'godot/tests/smoke_test.gd',
  garagePreviewTest: 'godot/tests/garage_preview_test.gd',
  gameplaySafetyTest: 'godot/tests/gameplay_safety_test.gd',
  narrativeProgressionTest: 'godot/tests/narrative_progression_test.gd',
  mechaDetailTest: 'godot/tests/mecha_detail_test.gd',
  mechaAnimationTest: 'godot/tests/mecha_animation_test.gd',
  trackSceneryProductionTest: 'godot/tests/track_scenery_production_test.gd',
  fpsPresentationTest: 'godot/tests/fps_presentation_test.gd',
};

const failures = [];
const check = (condition, message) => {
  if (!condition) failures.push(message);
};
const source = {};

for (const [label, relativePath] of Object.entries(files)) {
  const absolutePath = resolve(root, relativePath);
  check(existsSync(absolutePath), `${label}: fichier absent (${relativePath})`);
  source[label] = existsSync(absolutePath) ? readFileSync(absolutePath, 'utf8') : '';
}

const chassis = [
  ['biped', 'Raptor R2'], ['tripod', 'Triarch T3'], ['quadruped', 'Fenrir Q4'],
  ['hexapod', 'Mantis H6'], ['octopod', 'Arachne O8'], ['hover', 'Wraith V0'],
  ['tracked', 'Bastion C2'], ['monowheel', 'Cyclops M1'], ['orb', 'Orb S7'],
  ['centurion', 'Centurion S12'],
];
for (const [id, name] of chassis) {
  check(source.database.includes(`_chassis("${id}"`), `catalogue: identifiant absent ${id}`);
  check(source.database.includes(`"${name}"`), `catalogue: nom absent ${name}`);
}
check((source.database.match(/^\s*_chassis\("/gm) ?? []).length === 10, 'catalogue: exactement 10 châssis requis');
check(!/"(?:wheeled|serpentine)"/.test(source.database), 'catalogue: anciennes architectures détectées');

for (const trackId of ['foundry', 'dunes', 'glacier', 'orbital', 'canopy', 'tempest', 'abyss', 'caldera']) {
  check(source.database.includes(`"id": "${trackId}"`), `circuit absent: ${trackId}`);
}
check((source.database.match(/^\s*\{"id": "(?:ion|emp|shield|overdrive|mine|repair|shockwave|rail)"/gm) ?? []).length === 8, 'catalogue: exactement 8 objets requis');
const verticalities = [...source.database.matchAll(/"verticality":\s*([0-9.]+)/g)].map((match) => Number(match[1]));
check(verticalities.length === 8, 'circuits: huit valeurs verticality requises');
check(verticalities.every((value) => value >= 4 && value <= 30), 'circuits: verticality doit être exprimée en mètres réalistes');
check(new Set(verticalities).size === 8, 'circuits: huit reliefs distincts requis');
const trackWidths = [...source.database.matchAll(/"width":\s*([0-9.]+)/g)].map((match) => Number(match[1]));
check(trackWidths.length === 8 && trackWidths.every((value) => value >= 35), 'circuits: les huit chaussées Open doivent mesurer au moins 35 m');
check(source.trackSafety.includes('REQUIRED_SIDE_BY_SIDE := 3') && source.trackSafety.includes('vehicle_footprint'), 'circuits: homologation des gabarits absente');

check(source.database.includes('static var CHASSIS:'), 'catalogue: initialisation CHASSIS doit être parse-safe');
check(source.save.includes('const SAVE_VERSION := 5'), 'sauvegarde: version 5 absente');
check(!source.save.includes('`t'), 'sauvegarde: séquence littérale `t invalide détectée');
check(source.save.includes('"loadouts": loadouts'), 'sauvegarde: loadouts modulaires absents');
check(source.save.includes('"locomotions": locomotions'), 'sauvegarde: choix locomoteurs absents');
check(source.save.includes('"owned_modules": HISTORIC_MODULE_IDS.duplicate()'), 'sauvegarde: propriété des modules historiques absente');
check(source.save.includes('"camera_view": "tps"'), 'sauvegarde: préférence caméra absente');
check(source.save.includes('func purchase_and_apply_garage('), 'sauvegarde: transaction garage atomique absente');
check(source.save.includes('var snapshot := profile.duplicate(true)') && source.save.includes('profile = snapshot'), 'sauvegarde: rollback atomique absent');
check(source.save.includes('not counted.has(module_id)'), 'sauvegarde: protection anti-débit double absente');
check(source.save.includes('source_version < CHAMPIONSHIP_SCHEMA_VERSION'), 'sauvegarde: migration championnat v3 absente');
check(source.save.includes('definition.get("track_ids"'), 'sauvegarde: canonicalisation des circuits de championnat absente');
for (const divisionId of ['command', 'stabilized', 'swarm', 'ground', 'experimental']) {
  check(source.database.includes(`"id": "${divisionId}"`), `division absente: ${divisionId}`);
}
for (const cupId of ['command_cup', 'stabilized_cup', 'swarm_cup', 'ground_cup', 'experimental_cup', 'nexus_open']) {
  check(source.database.includes(`"id": "${cupId}"`), `championnat absent: ${cupId}`);
}
const modulesBySlot = {
  core: ['core_balanced', 'core_overdrive', 'core_bastion', 'core_tactical_relay', 'core_hive_capacitor', 'core_phase_lattice'],
  mobility: ['mobility_vector', 'mobility_sprint', 'mobility_adaptive', 'mobility_gyro_rail', 'mobility_multileg', 'mobility_phase_skates'],
  utility: ['utility_coolant', 'utility_aegis', 'utility_scanner', 'utility_command_uplink', 'utility_impact_ram', 'utility_phase_sink'],
};
const moduleIds = Object.values(modulesBySlot).flat();
for (const moduleId of moduleIds) {
  check(source.database.includes(`"id": "${moduleId}"`), `module absent: ${moduleId}`);
  check(source.visualModules.includes(`"${moduleId}"`), `silhouette module absente: ${moduleId}`);
}
check(moduleIds.length === 18 && new Set(moduleIds).size === 18, 'catalogue: exactement 18 modules uniques requis');
const declaredModuleIds = [...source.database.matchAll(/"id": "((?:core|mobility|utility)_[a-z_]+)"/g)].map((match) => match[1]);
check(declaredModuleIds.length === 18 && new Set(declaredModuleIds).size === 18, 'catalogue: 18 déclarations de modules uniques requises');
for (const [slotId, expectedIds] of Object.entries(modulesBySlot)) {
  check(declaredModuleIds.filter((id) => id.startsWith(`${slotId}_`)).length === 6, `catalogue: 6 modules requis pour ${slotId}`);
  check(expectedIds.every((id) => declaredModuleIds.includes(id)), `catalogue: contrat incomplet pour ${slotId}`);
}
check(source.session.includes('return "mixed" if value == "mixed" else "division"'), 'session: grille fail-closed absente');
check(source.raceController.includes('switch_camera_view'), 'course: bascule TPS/FPS absente');
check(source.database.includes('static func _first_person_spec('), 'FPS: profils canoniques de châssis absents');
check((source.database.match(/"mode": "sensorium"/g) ?? []).length === 3, 'FPS: exactement trois sensoriums distants requis');
check(source.cockpitVisuals.includes('class_name CockpitVisuals') && source.cockpitVisuals.includes('FPSInteriorRoot'), 'FPS: fabrique d’habitacles physiques absente');
check(source.cockpitVisuals.includes('HERO_INTERIOR_MESH_LIMIT := 24') && source.cockpitVisuals.includes('HERO_INTERIOR_TRIANGLE_LIMIT := 3500'), 'FPS: budgets Web cockpit absents');
check(source.firstPersonOverlay.includes('class_name FirstPersonOverlay') && source.firstPersonOverlay.includes('SensoriumOverlay'), 'FPS: HUD sensorium dédié absent');
check(source.raceHud.includes('first_person_interface_mode') && source.raceHud.includes('sensor_overlay_visible'), 'FPS: contrat cockpit/capteurs non exposé par le HUD');
check(source.raceController.includes('_apply_player_camera_mode') && source.raceController.includes('camera_active_view'), 'FPS: séparation caméra grille/course absente');
check(source.mechaFactory.includes('MaterialLibrary.mecha_for'), 'méchas: matériau OpenAI v2.2 non branché');
check(source.materialLibrary.includes('MECHA_DETAIL_PANELS') && source.materialLibrary.includes('TRACK_INFRASTRUCTURE_DETAIL'), 'production: chemins des nouvelles textures absents de MaterialLibrary');
check(source.materialLibrary.includes('static func mecha_detail(') && source.materialLibrary.includes('static func infrastructure('), 'production: matériaux de détail v2.5 absents');
check(source.mechaFactory.includes('MaterialLibrary.mecha_detail(') && source.visualModules.includes('MaterialLibrary.mecha_detail('), 'production: micro-panneaux mécha non branchés');
check(source.visualModules.includes('"CameraTPS"') && source.visualModules.includes('"CameraFPS"'), 'méchas: ancres caméra absentes');
check(!source.visualModules.includes('.contains('), 'méchas: dispatch module par sous-chaîne encore présent');
check((source.visualModules.match(/MaterialLibrary\.module_for\(/g) ?? []).length >= 3, 'méchas: matériaux de slot v2.2 non branchés');
check(source.mainMenu.includes('championship_select') && source.mainMenu.includes('grid_policy_select'), 'menu: options championnat/grille absentes');
check(source.garage.includes('%GaragePreview') && source.garage.includes('call(&"configure"'), 'garage: aperçu 3D non branché');
check(source.garagePreview.includes('class_name GaragePreview') && /MechaFactory\w*\.build\(/.test(source.garagePreview), 'garage: script d’aperçu 3D incomplet');
check(source.garagePreviewScene.includes('SubViewport') && source.garagePreviewScene.includes('garage_bay.png'), 'garage: scène d’aperçu v2.2 incomplète');
check(source.garageScene.includes('garage_preview.tscn'), 'garage: composant d’aperçu absent de la scène');
check(source.locomotionCatalog.includes('DRIVE_OPTIONS') && source.locomotionCatalog.includes('MOUNT_OPTIONS'), 'locomotion: catalogue combinatoire absent');
check(source.locomotionCatalog.includes('get_total_configuration_count'), 'locomotion: contrat de total absent');
check((source.locomotionCatalog.match(/"id": "(?:mecha_legs|wheels|treads|multi_support|sphere_drive|mono_gyro|hover_skids|twin_antigrav|articulated_rail|ducted_fans)"/g) ?? []).length === 10, 'locomotion: dix technologies requises');
check((source.locomotionCatalog.match(/"id": "(?:compact|balanced|wide|endurance|racing)"/g) ?? []).length === 5, 'locomotion: cinq géométries requises');
check(source.locomotionVisuals.includes('"twin_antigrav"') && source.locomotionVisuals.includes('_twin_antigrav'), 'locomotion: bi-propulseur Aether visuel absent');
check(source.mechaFactory.includes('LocomotionVisuals.install'), 'locomotion: installation visuelle non branchée');
check(source.garage.includes('locomotion_option') && source.garage.includes('_on_locomotion_selected'), 'garage: sélecteur locomotion absent');
check(source.mobileControls.includes('class_name MobileTouchControls') && source.mobileControls.includes('MIN_TOUCH_TARGET'), 'mobile: contrôleur tactile professionnel absent');
for (const action of ['race_accelerate', 'race_brake', 'race_left', 'race_right', 'race_drift', 'race_boost', 'race_item', 'race_pause', 'race_camera', 'race_reset']) {
  check(source.mobileControls.includes(action), `mobile: commande absente ${action}`);
}
check(source.raceHud.includes('show_race_briefing') && source.raceHud.includes('show_false_start'), 'course: briefing/faux départ absents');
check(source.podium.includes('class_name PodiumPresenter') && source.resultsScene.includes('podium_presenter.tscn'), 'résultats: podium top 3 absent');
check(source.intro.includes('HUIT MONDES') && source.intro.includes('MARA VEX') && source.intro.toUpperCase().includes('HANGAR 08'), 'intro: arc intergalactique incomplet');
check(source.introScene.includes('intergalactic_crown_race.png'), 'intro: key art intergalactique OpenAI absent');
check((source.lore.match(/"id":/g) ?? []).length === 8, 'lore: huit archives originales requises');

const textures = [
  'mecha_armor.png', 'track_surface.png', 'cockpit_composite.png', 'environment_panels.png',
  'mecha_armor_light.png', 'mecha_armor_heavy.png', 'module_energy.png', 'module_mobility.png',
  'module_utility.png', 'track_thermal.png', 'track_cryo.png', 'garage_bay.png',
  'prop_industrial.png', 'prop_biome.png', 'prop_urban_wet.png', 'race_ceremonial.png',
  'locomotion_antigrav.png', 'intergalactic_crown_race.png', 'garage_crew.png',
  'mecha_detail_panels.png', 'track_infrastructure_detail.png',
];
const textureDir = resolve(root, 'godot/assets/textures/openai');
for (const texture of textures) {
  check(existsSync(resolve(textureDir, texture)), `texture OpenAI absente: ${texture}`);
}
const deliveredPngs = existsSync(textureDir)
  ? readdirSync(textureDir).filter((name) => name.toLowerCase().endsWith('.png')).sort()
  : [];
check(deliveredPngs.length === 21 && textures.every((name) => deliveredPngs.includes(name)), 'textures OpenAI: exactement les 21 PNG v2.5 sont requis');
let manifest = {};
try {
  manifest = JSON.parse(source.manifest);
} catch {
  check(false, 'textures OpenAI: manifest.json invalide');
}
check(Number(manifest.schema_version) === 2, 'textures OpenAI: manifest schema 2 requis');
const manifestAssets = Array.isArray(manifest.assets) ? manifest.assets : [];
const manifestFiles = manifestAssets.map((asset) => asset?.file).filter(Boolean);
check(manifestAssets.length === 21, 'textures OpenAI: 21 entrées de manifeste requises');
check(new Set(manifestFiles).size === 21 && textures.every((name) => manifestFiles.includes(name)), 'textures OpenAI: manifeste incomplet ou dupliqué');
const specialDimensions = { 'intergalactic_crown_race.png': [1672, 941] };
for (const asset of manifestAssets) {
  const file = String(asset?.file ?? '');
  const dimensions = Array.isArray(asset?.dimensions) ? asset.dimensions : [];
  const expectedDimensions = specialDimensions[file] ?? [1254, 1254];
  check(/^exec-[a-z0-9-]+$/i.test(String(asset?.generation_id ?? '')), `textures OpenAI: génération absente pour ${file}`);
  check(/^[a-f0-9]{64}$/i.test(String(asset?.sha256 ?? '')), `textures OpenAI: SHA-256 absent pour ${file}`);
  check(dimensions.length === 2 && dimensions[0] === expectedDimensions[0] && dimensions[1] === expectedDimensions[1], `textures OpenAI: dimensions invalides pour ${file}`);
  const assetPath = resolve(textureDir, file);
  if (existsSync(assetPath) && /^[a-f0-9]{64}$/i.test(String(asset?.sha256 ?? ''))) {
    const actualHash = createHash('sha256').update(readFileSync(assetPath)).digest('hex');
    check(actualHash === String(asset.sha256).toLowerCase(), `textures OpenAI: empreinte incohérente pour ${file}`);
  }
}
check(source.save.includes('if not finished:'), 'sauvegarde: garde DNF/records absente');
check(source.save.includes('record_valid'), 'sauvegarde: validation de record absente');
for (const mode of ['quick', 'time_trial', 'elimination', 'grand_prix']) {
  check(source.session.includes(`"${mode}"`), `session: mode absent ${mode}`);
}
for (const key of ['racer_id', 'display_name', 'distance', 'lane', 'speed', 'max_armor', 'armor_ratio', 'heat_ratio', 'item', 'boosting', 'finished', 'dnf', 'eliminated']) {
  check(source.racer.includes(`"${key}"`), `racer snapshot: clé absente ${key}`);
}
for (const inputKey of ['throttle', 'brake', 'steer', 'drift', 'boost']) {
  check(source.racer.includes(`"${inputKey}"`), `racer controls: clé absente ${inputKey}`);
}
check(source.smoke.includes('_test_deterministic_racer'), 'smoke: test déterministe absent');
check(source.smoke.includes('_test_module_purchase_contract'), 'smoke: achat atomique des nouveaux modules absent');
check(source.smoke.includes('_test_asset_manifest_contract'), 'smoke: contrat manifeste schema 2 absent');
check(source.smoke.includes('_test_garage_preview_contract'), 'smoke: contrat scène garage preview absent');
check(source.gameplaySafetyTest.includes('MECHA GAMEPLAY SAFETY: PASS'), 'sécurité gameplay: test dédié absent');
check(source.gameplaySafetyTest.includes('_test_runtime_homologation'), 'sécurité gameplay: homologation runtime non couverte');
check(source.gameplaySafetyTest.includes('_test_classification_contract'), 'sécurité gameplay: classement officiel non couvert');
check(source.gameplaySafetyTest.includes('_test_championship_dnf_contract'), 'sécurité gameplay: DNF championnat non couvert');
check(source.gameplaySafetyTest.includes('_test_mobile_control_geometry') && source.gameplaySafetyTest.includes('_assert_regions_do_not_overlap') && source.gameplaySafetyTest.includes('control_regions'), 'sécurité gameplay: géométrie mobile paysage/portrait non couverte');
check(source.narrativeProgressionTest.includes('MECHA NARRATIVE PROGRESSION: PASS'), 'narration: test de progression dédié absent');
check(source.narrativeProgressionTest.includes('Grand Open lock/unlock/resume') && source.narrativeProgressionTest.includes('player/Vex/rival epilogues'), 'narration: verrouillage Open ou fins de saison non couverts');
check(!existsSync(resolve(root, 'godot/scripts/systems/save_system.gd.stub')), 'nettoyage: save_system.gd.stub présent');
check(!existsSync(resolve(root, 'godot/scripts/data/game_database.gd.precanonical')), 'nettoyage: game_database.gd.precanonical présent');
check(source.garagePreviewTest.includes('GARAGE PREVIEW: PASS'), 'garage: test plein écran dédié absent');
check(source.mechaDetailTest.includes('MECHA DETAIL PRODUCTION: PASS') && source.mechaDetailTest.includes('visual_triangle_count'), 'production: test de densité mécha absent');
check(source.mechaAnimationTest.includes('MECHA ANIMATION: PASS') && source.mechaAnimationTest.includes('_test_polygon_budget'), 'production: test animation/polygones absent');
check(source.trackSceneryProductionTest.includes('MECHA TRACK SCENERY PRODUCTION: PASS') && source.trackSceneryProductionTest.includes('track_infrastructure_detail.png'), 'production: test décors/infrastructure absent');
check(source.fpsPresentationTest.includes('MECHA FPS PRESENTATION: PASS') && source.fpsPresentationTest.includes('sensor_overlay_visible'), 'FPS: test dédié cockpit/sensorium absent');
check(source.trackSceneryProductionTest.includes('_assert_trackside_clearance') && source.trackSceneryProductionTest.includes('_test_budget_guardrails'), 'production: garde-fous clearance/budget décors absents');
check(source.project.includes('SaveSystem="*res://scripts/systems/save_system.gd"'), 'project: autoload SaveSystem absent');
check(source.project.includes('GameSession="*res://scripts/systems/game_session.gd"'), 'project: autoload GameSession absent');

if (failures.length) {
  console.error(`Godot static validation: FAIL (${failures.length})`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log('Godot static validation: PASS');
  console.log('10 chassis · 500 locomotions · 5 divisions · 8 tracks homologués · 18 modules · 6 championships · 21 assets OpenAI · détails production · garage plein écran · mobile · Grand Tour · save v5');
}
