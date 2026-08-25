import { createHash } from 'node:crypto';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const GODOT_ROOT = join(ROOT, 'godot');
export const GODOT_WEB_ROOT = join(ROOT, 'godot3d');

export const GODOT_WEB_ARTIFACTS = [
  'mecha-overdrive.html',
  'mecha-overdrive.js',
  'mecha-overdrive.wasm',
  'mecha-overdrive.pck',
  'mecha-overdrive.audio.worklet.js',
  'mecha-overdrive.audio.position.worklet.js',
  'mecha-overdrive.png',
  'mecha-overdrive.icon.png',
  'mecha-overdrive.apple-touch-icon.png',
];

const SOURCE_ROOTS = ['project.godot', 'export_presets.cfg', 'assets', 'scenes', 'scripts'];
const EXCLUDED_DIRECTORIES = new Set(['.godot', 'export', 'tests']);
const EXCLUDED_FILE_SUFFIXES = ['.import', '.rej'];

function collect(path) {
  const information = statSync(path);
  if (information.isFile()) {
    if (EXCLUDED_FILE_SUFFIXES.some((suffix) => path.endsWith(suffix))) return [];
    return [path];
  }
  const files = [];
  for (const entry of readdirSync(path, { withFileTypes: true })) {
    if (entry.isDirectory() && EXCLUDED_DIRECTORIES.has(entry.name)) continue;
    files.push(...collect(join(path, entry.name)));
  }
  return files;
}

const TEXT_EXTENSIONS = new Set([
  '.cfg', '.gd', '.gdshader', '.godot', '.json', '.md',
  '.shader', '.svg', '.tres', '.tscn', '.txt', '.uid',
]);

function readSource(path) {
  const bytes = readFileSync(path);
  if (!TEXT_EXTENSIONS.has(extname(path).toLowerCase())) return bytes;
  return Buffer.from(bytes.toString('utf8').replaceAll('\r\n', '\n'));
}

export function sourceFiles() {
  return SOURCE_ROOTS.flatMap((entry) => collect(join(GODOT_ROOT, entry)))
    .sort((left, right) => left.localeCompare(right, 'en'));
}

export function sha256File(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

export function computeGodotSourceDigest() {
  const hash = createHash('sha256');
  for (const path of sourceFiles()) {
    const name = relative(GODOT_ROOT, path).replaceAll('\\', '/');
    hash.update(name);
    hash.update('\0');
    hash.update(readSource(path));
    hash.update('\0');
  }
  return hash.digest('hex');
}

export function artifactContract() {
  return Object.fromEntries(GODOT_WEB_ARTIFACTS.map((name) => {
    const path = join(GODOT_WEB_ROOT, name);
    return [name, { bytes: statSync(path).size, sha256: sha256File(path) }];
  }));
}
