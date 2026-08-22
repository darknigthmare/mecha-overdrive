import { readFileSync, existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const runtime = [
  'index.html', 'styles.css', 'manifest.webmanifest', 'service-worker.js',
  'media/icon.svg',
  'js/core.js', 'js/data.js', 'js/storage.js', 'js/audio.js', 'js/input.js',
  'js/track.js', 'js/renderer.js', 'js/game.js', 'js/ui.js', 'js/main.js',
];
const scriptOrder = [
  'js/core.js', 'js/data.js', 'js/storage.js', 'js/audio.js', 'js/input.js',
  'js/track.js', 'js/renderer.js', 'js/game.js', 'js/ui.js', 'js/main.js',
];
const failures = [];
const checks = [];

function check(condition, label) {
  if (condition) checks.push(label);
  else failures.push(label);
}

for (const file of runtime) check(existsSync(join(ROOT, file)), `Fichier présent : ${file}`);

for (const file of scriptOrder) {
  const result = spawnSync(process.execPath, ['--check', join(ROOT, file)], { encoding: 'utf8' });
  check(result.status === 0, `Syntaxe JavaScript : ${file}${result.stderr ? ` — ${result.stderr.trim()}` : ''}`);
}

const html = readFileSync(join(ROOT, 'index.html'), 'utf8');
const loadedScripts = [...html.matchAll(/<script\s+defer\s+src="([^"]+)"/g)].map((match) => match[1]);
check(JSON.stringify(loadedScripts) === JSON.stringify(scriptOrder), 'Ordre de chargement des scripts');
for (const id of ['gameCanvas', 'minimapCanvas', 'screen-main', 'screen-mode', 'screen-garage', 'screen-results', 'hud', 'pauseOverlay']) {
  check(html.includes(`id="${id}"`), `Élément d’interface : #${id}`);
}

let manifest;
try {
  manifest = JSON.parse(readFileSync(join(ROOT, 'manifest.webmanifest'), 'utf8'));
  check(manifest.name === 'MECHA OVERDRIVE — Circuit Zero', 'Nom du manifeste');
  check(manifest.display === 'fullscreen', 'Affichage plein écran du manifeste');
  check(Array.isArray(manifest.icons) && manifest.icons.every((icon) => existsSync(join(ROOT, icon.src))), 'Icônes du manifeste');
} catch (error) {
  failures.push(`Manifeste JSON valide — ${error.message}`);
}

const serviceWorker = readFileSync(join(ROOT, 'service-worker.js'), 'utf8');
for (const file of runtime.filter((entry) => !entry.startsWith('media/preview') && entry !== 'service-worker.js')) {
  const cachePath = file === 'index.html' ? './index.html' : `./${file}`;
  check(serviceWorker.includes(cachePath), `Asset mis en cache : ${file}`);
}

try {
  const context = { window: {}, console, structuredClone, Intl, setTimeout, clearTimeout };
  context.window.window = context.window;
  vm.createContext(context);
  for (const file of ['js/core.js', 'js/data.js', 'js/track.js']) {
    vm.runInContext(readFileSync(join(ROOT, file), 'utf8'), context, { filename: file });
  }
  const { MO } = context.window;
  const unique = (values) => new Set(values).size === values.length;
  check(MO.VERSION === '1.0.0', 'Version du moteur');
  check(MO.Data.CHASSIS.length === 8, 'Huit architectures de méchas');
  check(unique(MO.Data.CHASSIS.map((entry) => entry.id)), 'Identifiants de châssis uniques');
  check(MO.Data.TRACKS.length === 4, 'Quatre circuits');
  check(unique(MO.Data.TRACKS.map((entry) => entry.id)), 'Identifiants de circuits uniques');
  check(MO.Data.ITEMS.length === 8, 'Huit objets de combat');
  check(unique(MO.Data.ITEMS.map((entry) => entry.id)), 'Identifiants d’objets uniques');
  check(Object.keys(MO.Data.DIFFICULTIES).length === 3, 'Trois difficultés');
  check(Object.keys(MO.Data.UPGRADES).length === 4, 'Quatre branches d’amélioration');

  for (const spec of MO.Data.TRACKS) {
    const track = MO.Track.build(spec);
    check(track.segments.length > 300, `Circuit généré : ${spec.name}`);
    check(track.trackLength > 50_000, `Longueur cohérente : ${spec.name}`);
    check(track.mapPoints.length > 20, `Mini-carte générée : ${spec.name}`);
  }
} catch (error) {
  failures.push(`Chargement des données et génération des circuits — ${error.stack || error.message}`);
}

const externalRuntimeUrls = runtime
  .filter((file) => /\.(?:html|css|js)$/.test(file))
  .flatMap((file) => {
    const text = readFileSync(join(ROOT, file), 'utf8');
    return [...text.matchAll(/https?:\/\/[^\s"')]+/g)].map((match) => `${file}: ${match[0]}`);
  });
check(externalRuntimeUrls.length === 0, `Aucune dépendance réseau${externalRuntimeUrls.length ? ` — ${externalRuntimeUrls.join(', ')}` : ''}`);

if (failures.length) {
  console.error('\nVALIDATION ÉCHOUÉE\n');
  for (const failure of failures) console.error(`✗ ${failure}`);
  console.error(`\n${checks.length} contrôles réussis, ${failures.length} échec(s).\n`);
  process.exit(1);
}

console.log('\nMECHA OVERDRIVE — VALIDATION RÉUSSIE\n');
for (const label of checks) console.log(`✓ ${label}`);
console.log(`\n${checks.length} contrôles réussis, aucun échec.\n`);
