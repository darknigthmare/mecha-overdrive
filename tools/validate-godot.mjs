import { existsSync, readFileSync } from 'node:fs';
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
  mainMenu: 'godot/scripts/ui/main_menu.gd',
  smoke: 'godot/tests/smoke_test.gd',
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

check(source.database.includes('static var CHASSIS:'), 'catalogue: initialisation CHASSIS doit être parse-safe');
check(source.save.includes('const SAVE_VERSION := 3'), 'sauvegarde: version 3 absente');
check(source.save.includes('"loadouts": loadouts'), 'sauvegarde: loadouts modulaires absents');
check(source.save.includes('"camera_view": "tps"'), 'sauvegarde: préférence caméra absente');
for (const divisionId of ['command', 'stabilized', 'swarm', 'ground', 'experimental']) {
  check(source.database.includes(`"id": "${divisionId}"`), `division absente: ${divisionId}`);
}
for (const cupId of ['command_cup', 'stabilized_cup', 'swarm_cup', 'ground_cup', 'experimental_cup', 'nexus_open']) {
  check(source.database.includes(`"id": "${cupId}"`), `championnat absent: ${cupId}`);
}
for (const moduleId of ['core_balanced', 'core_overdrive', 'core_bastion', 'mobility_vector', 'mobility_sprint', 'mobility_adaptive', 'utility_coolant', 'utility_aegis', 'utility_scanner']) {
  check(source.database.includes(`"id": "${moduleId}"`), `module absent: ${moduleId}`);
}
check(source.session.includes('return "mixed" if value == "mixed" else "division"'), 'session: grille fail-closed absente');
check(source.raceController.includes('switch_camera_view'), 'course: bascule TPS/FPS absente');
check(source.mechaFactory.includes('MaterialLibrary.mecha'), 'méchas: matériau OpenAI non branché');
check(source.visualModules.includes('"CameraTPS"') && source.visualModules.includes('"CameraFPS"'), 'méchas: ancres caméra absentes');
check(source.mainMenu.includes('championship_select') && source.mainMenu.includes('grid_policy_select'), 'menu: options championnat/grille absentes');
for (const texture of ['mecha_armor.png', 'track_surface.png', 'cockpit_composite.png', 'environment_panels.png']) {
  check(existsSync(resolve(root, 'godot/assets/textures/openai', texture)), `texture OpenAI absente: ${texture}`);
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
check(!existsSync(resolve(root, 'godot/scripts/systems/save_system.gd.stub')), 'nettoyage: save_system.gd.stub présent');
check(!existsSync(resolve(root, 'godot/scripts/data/game_database.gd.precanonical')), 'nettoyage: game_database.gd.precanonical présent');
check(source.project.includes('SaveSystem="*res://scripts/systems/save_system.gd"'), 'project: autoload SaveSystem absent');
check(source.project.includes('GameSession="*res://scripts/systems/game_session.gd"'), 'project: autoload GameSession absent');

if (failures.length) {
  console.error(`Godot static validation: FAIL (${failures.length})`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log('Godot static validation: PASS');
  console.log('10 chassis · 5 divisions · 8 tracks · 9 modules · 6 championships · TPS/FPS · save v3');
}
