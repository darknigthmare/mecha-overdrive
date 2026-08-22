import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const memory = new Map();
const sandbox = {
  console,
  Intl,
  Math,
  Date,
  Number,
  String,
  Boolean,
  Array,
  Object,
  Map,
  Set,
  JSON,
  RegExp,
  Error,
  TypeError,
  structuredClone: globalThis.structuredClone,
  performance: { now: () => Date.now() },
  localStorage: {
    getItem: (key) => memory.has(key) ? memory.get(key) : null,
    setItem: (key, value) => memory.set(key, String(value)),
    removeItem: (key) => memory.delete(key),
    clear: () => memory.clear(),
  },
  addEventListener: () => {},
  removeEventListener: () => {},
  setTimeout,
  clearTimeout,
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

for (const file of ['core.js', 'data.js', 'storage.js', 'track.js', 'game.js']) {
  const source = readFileSync(join(root, 'js', file), 'utf8');
  vm.runInContext(source, sandbox, { filename: file });
}

const { MO } = sandbox;
const tests = [];
function test(name, body) {
  tests.push({ name, body });
}

const silentAudio = {
  ensure: () => true,
  startMusic: () => {},
  stopMusic: () => {},
  updateEngine: () => {},
  sfx: () => {},
};

function createInput(initial = {}) {
  return {
    controls: { ...initial },
    frame() { return { ...this.controls }; },
    endFrame() {},
    reset() { this.controls = {}; },
  };
}

test('Les huit architectures sont présentes et uniques', () => {
  assert.equal(MO.Data.CHASSIS.length, 8);
  assert.equal(new Set(MO.Data.CHASSIS.map((entry) => entry.id)).size, 8);
  assert.deepEqual(
    Array.from(MO.Data.CHASSIS, (entry) => entry.id),
    ['biped', 'tripod', 'quadruped', 'hexapod', 'octopod', 'hover', 'tracked', 'monowheel'],
  );
});

test('Les statistiques et multiplicateurs de chaque châssis sont valides', () => {
  for (const chassis of MO.Data.CHASSIS) {
    for (const value of Object.values(chassis.stats)) assert.ok(Number.isFinite(value) && value > 0 && value <= 100);
    for (const value of Object.values(chassis.physics)) assert.ok(Number.isFinite(value) && value > 0);
  }
});

test('Les quatre circuits procéduraux sont fermés, décorés et cartographiés', () => {
  assert.equal(MO.Data.TRACKS.length, 4);
  for (const specification of MO.Data.TRACKS) {
    const track = MO.Track.build(specification);
    assert.ok(track.segments.length > 1000, `${specification.id}: nombre de segments insuffisant`);
    assert.equal(track.trackLength, track.segments.length * track.segmentLength);
    assert.ok(track.mapPoints.length > 100);
    assert.ok(track.segments.some((segment) => segment.pickups.length));
    assert.ok(track.segments.some((segment) => segment.hazards.length));
    assert.ok(track.segments.some((segment) => segment.boostPads.length));
    for (const point of track.mapPoints) {
      assert.ok(point.x >= 0 && point.x <= 1);
      assert.ok(point.y >= 0 && point.y <= 1);
    }
  }
});

test('Les utilitaires de temps et le générateur aléatoire sont déterministes', () => {
  assert.equal(MO.Util.formatTime(65.432), '01:05.432');
  const first = new MO.RNG(123456);
  const second = new MO.RNG(123456);
  assert.deepEqual(
    Array.from({ length: 12 }, () => first.next()),
    Array.from({ length: 12 }, () => second.next()),
  );
});

test('La sauvegarde normalise les données et les crédits', () => {
  MO.Storage.reset();
  assert.equal(MO.Storage.get().credits, 2500);
  assert.equal(MO.Storage.get().selectedChassis, 'biped');
  assert.equal(MO.Storage.spendCredits(600), true);
  assert.equal(MO.Storage.get().credits, 1900);
  MO.Storage.addCredits(125);
  assert.equal(MO.Storage.get().credits, 2025);
});

test('Le contre-la-montre crée un seul pilote et sa physique avance', () => {
  MO.Storage.reset();
  const input = createInput({ accelerate: true, steer: 0.15 });
  const game = new MO.Game({ input, audio: silentAudio, store: MO.Storage });
  game.start({ mode: 'time-trial', trackId: 'foundry', laps: 1 });
  assert.equal(game.racers.length, 1);
  assert.equal(game.player.isPlayer, true);
  game.state = 'racing';
  game.raceTime = 0;
  const start = game.player.distance;
  for (let index = 0; index < 240; index += 1) game.update(1 / 60);
  assert.ok(game.player.distance > start + 1000);
  assert.ok(game.player.speed > 0);
  assert.ok(Number.isFinite(game.player.x));
});

test('Les objets de réparation et de bouclier fonctionnent', () => {
  MO.Storage.reset();
  const game = new MO.Game({ input: createInput(), audio: silentAudio, store: MO.Storage });
  game.start({ mode: 'time-trial', trackId: 'glacier', laps: 1 });
  game.state = 'racing';
  game.player.armor = game.player.maxArmor * 0.35;
  game.player.item = 'repair';
  const beforeRepair = game.player.armor;
  assert.equal(game.useItem(game.player), true);
  assert.ok(game.player.armor > beforeRepair);
  game.player.itemCooldown = 0;
  game.player.item = 'shield';
  game.useItem(game.player);
  const beforeImpact = game.player.armor;
  game.applyImpact(game.player, { damage: 50, spin: 1, speedLoss: 0.5 });
  assert.equal(game.player.armor, beforeImpact);
});

test('Une course rapide aligne huit châssis sans doublon', () => {
  MO.Storage.reset();
  const game = new MO.Game({ input: createInput(), audio: silentAudio, store: MO.Storage });
  game.start({ mode: 'quick', trackId: 'dunes', difficulty: 'pilot', laps: 2 });
  assert.equal(game.racers.length, 8);
  assert.equal(new Set(game.racers.map((racer) => racer.chassisId)).size, 8);
  assert.equal(game.player.gridIndex, 7);
});

test('Le Grand Prix attribue les points et passe au circuit suivant', () => {
  MO.Storage.reset();
  const game = new MO.Game({ input: createInput(), audio: silentAudio, store: MO.Storage });
  game.start({ mode: 'grand-prix', trackId: 'foundry', difficulty: 'pilot', laps: 1, newChampionship: true });
  assert.equal(game.championship.round, 0);
  game.state = 'racing';
  game.raceTime = 75;
  game.player.distance = game.finishDistance + 1;
  game.player.progress += game.finishDistance + 1;
  game.checkLaps(game.player);
  game.updatePositions();
  game.completeRace();
  assert.equal(game.lastResult.championship.round, 1);
  assert.equal(game.lastResult.championship.final, false);
  assert.ok(game.lastResult.championship.standings.find((entry) => entry.isPlayer).points > 0);
  assert.equal(game.startNextChampionshipRound(), true);
  assert.equal(game.track.id, 'dunes');
  assert.equal(game.championship.round, 1);
});

test('Tous les objets distribués appartiennent au catalogue', () => {
  MO.Storage.reset();
  const game = new MO.Game({ input: createInput(), audio: silentAudio, store: MO.Storage });
  game.start({ mode: 'quick', trackId: 'orbital', difficulty: 'ace', laps: 1 });
  const valid = new Set(MO.Data.ITEMS.map((item) => item.id));
  for (const racer of game.racers) {
    racer.position = racer.gridIndex + 1;
    racer.item = null;
    game.giveItem(racer);
    assert.ok(valid.has(racer.item));
  }
});

let passed = 0;
for (const { name, body } of tests) {
  try {
    await body();
    passed += 1;
    console.log(`✓ ${name}`);
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(error);
  }
}

if (passed !== tests.length) {
  console.error(`\n${passed}/${tests.length} tests réussis.`);
  process.exit(1);
}
console.log(`\n${passed}/${tests.length} tests réussis.`);
