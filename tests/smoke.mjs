#!/usr/bin/env node

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');

const memory = new Map();
globalThis.window = globalThis;
globalThis.localStorage = {
  getItem(key) { return memory.has(key) ? memory.get(key) : null; },
  setItem(key, value) { memory.set(key, String(value)); },
  removeItem(key) { memory.delete(key); },
  clear() { memory.clear(); },
};

globalThis.addEventListener = () => {};
globalThis.removeEventListener = () => {};
Object.defineProperty(globalThis, 'navigator', { value: { getGamepads: () => [], maxTouchPoints: 0 }, configurable: true });
globalThis.matchMedia = () => ({ matches: false });

function loadScript(relativePath) {
  const filename = path.join(ROOT, relativePath);
  const source = fs.readFileSync(filename, 'utf8');
  vm.runInThisContext(source, { filename });
}

for (const script of [
  'js/core.js',
  'js/data.js',
  'js/storage.js',
  'js/track.js',
  'js/game.js',
]) {
  loadScript(script);
}

const { MO } = globalThis;
const checks = [];

function check(name, test) {
  try {
    test();
    checks.push({ name, ok: true });
    console.log(`✓ ${name}`);
  } catch (error) {
    checks.push({ name, ok: false, error: error.message });
    console.error(`✗ ${name}`);
    throw error;
  }
}

const controls = {
  steer: 0,
  accelerate: false,
  brake: false,
  boost: false,
  drift: false,
  itemPressed: false,
  pausePressed: false,
  resetPressed: false,
};

const input = {
  frame: () => ({ ...controls }),
  endFrame: () => {},
  reset: () => Object.assign(controls, {
    steer: 0,
    accelerate: false,
    brake: false,
    boost: false,
    drift: false,
    itemPressed: false,
    pausePressed: false,
    resetPressed: false,
  }),
};

const audio = new Proxy({}, {
  get: () => () => {},
});

function makeGame() {
  return new MO.Game({ input, audio, store: MO.Storage });
}

check('version du jeu', () => assert.equal(MO.VERSION, '1.0.0'));
check('huit architectures', () => assert.equal(MO.Data.CHASSIS.length, 8));
check('quatre circuits', () => assert.equal(MO.Data.TRACKS.length, 4));
check('huit objets', () => assert.equal(MO.Data.ITEMS.length, 8));
check('identifiants de châssis uniques', () => {
  const ids = MO.Data.CHASSIS.map((entry) => entry.id);
  assert.equal(new Set(ids).size, ids.length);
});

check('génération complète des circuits', () => {
  for (const specification of MO.Data.TRACKS) {
    const track = MO.Track.build(specification);
    assert.equal(track.id, specification.id);
    assert.ok(track.segments.length > 300, `${specification.id}: piste trop courte`);
    assert.ok(track.trackLength > 50_000, `${specification.id}: longueur invalide`);
    assert.ok(track.mapPoints.length > 30, `${specification.id}: mini-carte incomplète`);
    assert.ok(track.segments.some((segment) => segment.pickups.length > 0), `${specification.id}: aucune caisse`);
    assert.ok(track.segments.some((segment) => segment.hazards.length > 0), `${specification.id}: aucun danger`);
    assert.ok(track.segments.some((segment) => segment.boostPads.length > 0), `${specification.id}: aucun accélérateur`);
  }
});

MO.Storage.reset();
check('sauvegarde initiale normalisée', () => {
  const save = MO.Storage.get();
  assert.equal(save.credits, 2500);
  assert.equal(save.selectedChassis, 'biped');
  assert.equal(Object.keys(save.upgrades).length, 8);
});

check('achat et équipement dans le garage', () => {
  assert.equal(MO.Storage.selectChassis('tripod'), true);
  const before = MO.Storage.get().credits;
  const result = MO.Storage.buyUpgrade('tripod', 'engine');
  assert.equal(result.ok, true);
  assert.equal(MO.Storage.get().upgrades.tripod.engine, 1);
  assert.ok(MO.Storage.get().credits < before);
});

const quick = makeGame();
quick.start({ mode: 'quick', trackId: 'orbital', difficulty: 'ace', laps: 2 });
check('course rapide configurée', () => {
  assert.equal(quick.active, true);
  assert.equal(quick.mode, 'quick');
  assert.equal(quick.track.id, 'orbital');
  assert.equal(quick.laps, 2);
  assert.equal(quick.racers.length, 8);
  assert.equal(quick.player.chassisId, 'tripod');
});

check('les huit divisions sont présentes sur la grille', () => {
  const chassis = new Set(quick.racers.map((racer) => racer.chassisId));
  assert.equal(chassis.size, 8);
});

quick.state = 'racing';
quick.countdown = 0;
controls.accelerate = true;
for (let frame = 0; frame < 90; frame += 1) quick.update(1 / 60);
check('accélération du joueur', () => assert.ok(quick.player.speed > 1000));

controls.boost = true;
for (let frame = 0; frame < 45; frame += 1) quick.update(1 / 60);
controls.boost = false;
check('surcharge et chaleur', () => {
  assert.ok(quick.player.heat > 0);
  assert.ok(quick.player.speed > 0);
});

check('utilisation du bouclier', () => {
  quick.player.item = 'shield';
  quick.useItem(quick.player);
  assert.equal(quick.player.item, null);
  assert.ok(quick.player.shieldTimer > 0);
});

check('pause et reprise', () => {
  quick.togglePause();
  assert.equal(quick.paused, true);
  quick.resume();
  assert.equal(quick.paused, false);
});

const creditsBeforeFinish = MO.Storage.get().credits;
quick.player.finished = true;
quick.player.finishTime = quick.raceTime;
quick.player.bestLap = quick.raceTime;
quick.completeRace();
check('classement et récompense de course rapide', () => {
  assert.equal(quick.active, false);
  assert.equal(quick.state, 'finished');
  assert.equal(quick.lastResult.rows.length, 8);
  assert.ok(quick.lastResult.reward > 0);
  assert.ok(MO.Storage.get().credits > creditsBeforeFinish);
});

const timeTrial = makeGame();
timeTrial.start({ mode: 'time-trial', trackId: 'glacier', laps: 1 });
check('contre-la-montre solo', () => {
  assert.equal(timeTrial.mode, 'time-trial');
  assert.equal(timeTrial.racers.length, 1);
  assert.equal(timeTrial.laps, 1);
});
timeTrial.raceTime = 75;
timeTrial.player.bestLap = 75;
timeTrial.player.finished = true;
timeTrial.player.finishTime = 75;
timeTrial.completeRace();
check('record du contre-la-montre enregistré', () => {
  assert.ok(Number.isFinite(MO.Storage.get().bestTimes.glacier));
});

const grandPrix = makeGame();
grandPrix.start({ mode: 'grand-prix', trackId: 'dunes', difficulty: 'pilot', laps: 1, newChampionship: true });
const firstTrack = grandPrix.track.id;
check('création du Grand Prix', () => {
  assert.equal(grandPrix.championship.round, 0);
  assert.equal(grandPrix.championship.tracks.length, 4);
  assert.equal(grandPrix.racers.length, 8);
});
grandPrix.player.finished = true;
grandPrix.player.finishTime = 80;
grandPrix.player.bestLap = 80;
grandPrix.completeRace();
check('points de la première manche', () => {
  const result = grandPrix.lastResult.championship;
  assert.equal(result.round, 1);
  assert.equal(result.final, false);
  assert.equal(result.standings.length, 8);
  assert.equal(Object.values(grandPrix.championship.points).reduce((sum, value) => sum + value, 0), 43);
});
check('passage à la manche suivante', () => {
  assert.equal(grandPrix.startNextChampionshipRound(), true);
  assert.equal(grandPrix.active, true);
  assert.equal(grandPrix.championship.round, 1);
  assert.notEqual(grandPrix.track.id, firstTrack);
});

grandPrix.quit();
check('sortie propre de la course', () => {
  assert.equal(grandPrix.active, false);
  assert.equal(grandPrix.state, 'idle');
  assert.equal(grandPrix.championship, null);
});

console.log(`\n${checks.length} contrôles réussis — noyau de jeu opérationnel.`);
