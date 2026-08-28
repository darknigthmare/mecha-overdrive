import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  GODOT_WEB_ROOT,
  artifactContract,
  computeGodotSourceDigest,
} from './godot-web-contract.mjs';

const htmlOutput = join(GODOT_WEB_ROOT, 'mecha-overdrive.html');
const normalizedHtml = `${readFileSync(htmlOutput, 'utf8').trimEnd()}\n`;
writeFileSync(htmlOutput, normalizedHtml, 'utf8');

const gameVersion = readFileSync(join(GODOT_WEB_ROOT, '..', 'VERSION'), 'utf8').trim();
const manifest = {
  schema: 1,
  gameVersion,
  godotVersion: '4.7.2',
  preset: 'Web',
  threads: false,
  sourceSha256: computeGodotSourceDigest(),
  artifacts: artifactContract(),
};

const output = join(GODOT_WEB_ROOT, 'build.json');
writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(`Godot Web build stamped: ${manifest.sourceSha256}`);
