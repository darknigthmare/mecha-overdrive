(function (MO) {
  'use strict';

  const U = MO.Util;
  const D = MO.Data;

  const BASE = Object.freeze({
    topSpeed: 6200,
    acceleration: 2700,
    braking: 5600,
    handling: 1.78,
    armor: 100,
    heatRate: 25,
    cooling: 18,
  });

  const ITEM_WEIGHTS = Object.freeze({
    front: [
      ['shield', 5], ['mine', 4], ['repair', 2.5], ['ion', 1.5], ['overdrive', 1], ['emp', 0.6],
    ],
    middle: [
      ['ion', 4], ['shield', 3], ['mine', 2.5], ['overdrive', 3], ['repair', 2], ['emp', 2.4], ['shockwave', 2], ['rail', 1.5],
    ],
    back: [
      ['overdrive', 5], ['rail', 4], ['ion', 4], ['emp', 3.5], ['repair', 3], ['shockwave', 3], ['shield', 1.5], ['mine', 0.5],
    ],
    time: [
      ['overdrive', 7], ['repair', 2], ['shield', 2],
    ],
  });

  const GRID_LANES = [-0.42, 0.42, -0.18, 0.18, -0.68, 0.68, -0.02, 0.02];
  const CONTROL_KEYS = ['shieldTimer', 'empTimer', 'spinTimer', 'stunTimer', 'invulnerableTimer', 'overdriveTimer', 'padBoostTimer', 'miniBoostTimer', 'recoveryBoostTimer', 'slipTimer', 'itemCooldown'];

  function down(value, dt) {
    return Math.max(0, (value || 0) - dt);
  }

  function safeCall(fn, fallback = null) {
    try {
      return fn();
    } catch (error) {
      console.error('[MECHA OVERDRIVE]', error);
      return fallback;
    }
  }

  class Game {
    constructor(options = {}) {
      this.input = options.input || MO.Input;
      this.audio = options.audio || MO.Audio;
      this.store = options.store || MO.Storage;
      this.rng = new MO.RNG(Date.now());
      this.active = false;
      this.paused = false;
      this.state = 'idle';
      this.mode = 'quick';
      this.track = null;
      this.racers = [];
      this.player = null;
      this.dynamic = { mines: [], projectiles: [] };
      this.visualCurve = 0;
      this.raceTime = 0;
      this.elapsed = 0;
      this.laps = 3;
      this.difficulty = D.DIFFICULTIES.pilot;
      this.countdown = 0;
      this.lastCountdown = null;
      this.currentConfig = null;
      this.lastResult = null;
      this.championship = null;
      this.pairCooldowns = new Map();
      this.finishDistance = 0;
      this._completing = false;
    }

    createChampionship(config) {
      const startIndex = Math.max(0, D.TRACKS.findIndex((track) => track.id === config.trackId));
      const tracks = D.TRACKS.map((_, index) => D.TRACKS[(startIndex + index) % D.TRACKS.length].id);
      const roster = this.makeRoster(false);
      this.championship = {
        tracks,
        roster,
        round: 0,
        points: Object.fromEntries(roster.map((entry) => [entry.id, 0])),
        scoredRounds: new Set(),
        difficulty: config.difficulty || 'pilot',
        laps: Math.max(1, Number(config.laps) || 3),
      };
      return this.championship;
    }

    makeRoster(timeTrial = false) {
      const save = this.store.get();
      const selected = D.getChassis(save.selectedChassis);
      const roster = [{
        id: 'player',
        isPlayer: true,
        name: save.pilotName,
        callsign: save.pilotName.slice(0, 10),
        chassisId: selected.id,
        paint: save.paints[selected.id] || selected.paint,
      }];

      if (timeTrial) return roster;

      const chassis = this.rng.shuffle(D.CHASSIS.filter((entry) => entry.id !== selected.id));
      const pilots = this.rng.shuffle(D.PILOTS);
      for (let index = 0; index < 7; index += 1) {
        const pilot = pilots[index % pilots.length];
        const machine = chassis[index % chassis.length];
        roster.push({
          id: `ai-${index + 1}`,
          isPlayer: false,
          name: pilot.name,
          callsign: pilot.callsign,
          chassisId: machine.id,
          paint: pilot.paint || machine.paint,
        });
      }
      return roster;
    }

    start(config = {}) {
      const mode = ['quick', 'grand-prix', 'time-trial'].includes(config.mode) ? config.mode : 'quick';
      const difficultyId = D.DIFFICULTIES[config.difficulty] ? config.difficulty : 'pilot';
      let trackId = config.trackId || D.TRACKS[0].id;
      let roster;

      this.mode = mode;
      this.difficulty = D.DIFFICULTIES[difficultyId];

      if (mode === 'grand-prix') {
        if (!this.championship || config.newChampionship || this.championship.round >= this.championship.tracks.length) {
          this.createChampionship({ ...config, difficulty: difficultyId });
        }
        trackId = this.championship.tracks[this.championship.round];
        this.difficulty = D.DIFFICULTIES[this.championship.difficulty] || this.difficulty;
        this.laps = this.championship.laps;
        roster = this.championship.roster;
      } else {
        this.championship = null;
        this.laps = U.clamp(Math.floor(Number(config.laps) || D.getTrack(trackId).defaultLaps), 1, 5);
        roster = this.makeRoster(mode === 'time-trial');
      }

      const trackSpec = D.getTrack(trackId);
      this.track = MO.Track.build(trackSpec);
      this.resetTrackObjects();
      this.finishDistance = this.track.trackLength * this.laps;
      this.rng = new MO.RNG(U.hashString(`${trackId}-${Date.now()}-${Math.random()}`));
      this.currentConfig = {
        mode,
        trackId: trackSpec.id,
        difficulty: this.difficulty.id,
        laps: this.laps,
      };

      const orderedRoster = this.gridOrder(roster);
      this.racers = orderedRoster.map((entry, gridIndex) => this.createRacer(entry, gridIndex));
      this.player = this.racers.find((racer) => racer.isPlayer);
      this.dynamic = { mines: [], projectiles: [] };
      this.pairCooldowns.clear();
      this.visualCurve = 0;
      this.raceTime = 0;
      this.elapsed = 0;
      this.countdown = 3.25;
      this.lastCountdown = 4;
      this.state = 'countdown';
      this.active = true;
      this.paused = false;
      this.lastResult = null;
      this._completing = false;

      this.audio.ensure?.();
      this.audio.startMusic?.('race');
      MO.Events.emit('race:started', {
        mode: this.mode,
        track: trackSpec,
        laps: this.laps,
        racers: this.racers,
        championship: this.championship,
      });
      return this;
    }

    gridOrder(roster) {
      const copy = roster.map((entry) => ({ ...entry }));
      if (this.mode === 'time-trial') return copy;

      if (this.mode === 'grand-prix' && this.championship?.round > 0) {
        return copy.sort((a, b) => {
          const pointDifference = (this.championship.points[a.id] || 0) - (this.championship.points[b.id] || 0);
          if (pointDifference) return pointDifference;
          return a.isPlayer ? 1 : b.isPlayer ? -1 : this.rng.next() - 0.5;
        });
      }

      return copy.sort((a, b) => (a.isPlayer ? 1 : b.isPlayer ? -1 : 0));
    }

    createRacer(entry, gridIndex) {
      const chassis = D.getChassis(entry.chassisId);
      const save = this.store.get();
      const difficulty = this.difficulty;
      const isPlayer = !!entry.isPlayer;
      const upgradeLevels = isPlayer
        ? save.upgrades[chassis.id]
        : {
          engine: difficulty.id === 'ace' ? 2 : difficulty.id === 'pilot' ? 1 : 0,
          servos: difficulty.id === 'ace' ? 2 : difficulty.id === 'pilot' ? 1 : 0,
          reactor: difficulty.id === 'ace' ? 1 : 0,
          armor: difficulty.id === 'ace' ? 1 : 0,
        };

      const engineBonus = 1 + (upgradeLevels.engine || 0) * D.UPGRADES.engine.perLevel;
      const servoBonus = 1 + (upgradeLevels.servos || 0) * D.UPGRADES.servos.perLevel;
      const reactorBonus = 1 + (upgradeLevels.reactor || 0) * D.UPGRADES.reactor.perLevel;
      const armorBonus = 1 + (upgradeLevels.armor || 0) * D.UPGRADES.armor.perLevel;
      const aiSkill = isPlayer ? 1 : U.clamp(difficulty.skill + this.rng.range(-0.08, 0.08), 0.35, 0.98);
      const aiSpeed = isPlayer ? 1 : difficulty.speed * this.rng.range(0.965, 1.025);
      const startGap = gridIndex * 185;
      const startBase = this.track.segmentLength * 8 + 1800;
      const maxArmor = BASE.armor * chassis.physics.armor * armorBonus;

      return {
        id: entry.id,
        isPlayer,
        name: entry.name,
        callsign: entry.callsign,
        chassisId: chassis.id,
        paint: entry.paint || chassis.paint,
        seed: this.rng.range(0, Math.PI * 2),
        gridIndex,
        x: GRID_LANES[gridIndex % GRID_LANES.length],
        targetX: GRID_LANES[gridIndex % GRID_LANES.length],
        progress: startBase - startGap,
        distance: -startGap,
        speed: 0,
        topSpeed: BASE.topSpeed * chassis.physics.topSpeed * engineBonus * aiSpeed,
        acceleration: BASE.acceleration * chassis.physics.acceleration * servoBonus,
        braking: BASE.braking * (0.96 + chassis.physics.mass * 0.04),
        handling: BASE.handling * chassis.physics.handling * servoBonus,
        maxArmor,
        armor: maxArmor,
        mass: chassis.physics.mass,
        offroadGrip: chassis.physics.offroad,
        heatRate: BASE.heatRate * chassis.physics.heat / reactorBonus,
        cooling: BASE.cooling * reactorBonus / Math.max(0.75, chassis.physics.heat),
        heat: 0,
        overheated: false,
        overheatTimer: 0,
        shieldTimer: 0,
        empTimer: 0,
        spinTimer: 0,
        stunTimer: 0,
        invulnerableTimer: 0,
        overdriveTimer: 0,
        padBoostTimer: 0,
        miniBoostTimer: 0,
        recoveryBoostTimer: 0,
        slipTimer: 0,
        respawnTimer: 0,
        itemCooldown: 0,
        item: null,
        boostActive: false,
        drifting: false,
        driftCharge: 0,
        visualSteer: 0,
        offroad: false,
        wasOffroad: false,
        brakeLatch: false,
        lap: 1,
        completedLaps: 0,
        lapStartTime: 0,
        lapTimes: [],
        bestLap: null,
        finished: false,
        finishTime: null,
        position: gridIndex + 1,
        objectCooldowns: new Map(),
        ai: isPlayer ? null : {
          skill: aiSkill,
          aggression: U.clamp(difficulty.aggression + this.rng.range(-0.12, 0.12), 0.05, 1),
          laneTimer: this.rng.range(0.8, 2.4),
          useTimer: this.rng.range(2.5, 6),
          preferredLane: GRID_LANES[gridIndex % GRID_LANES.length],
        },
        stats: {
          distance: 0,
          itemsUsed: 0,
          impacts: 0,
          damageTaken: 0,
        },
      };
    }

    resetTrackObjects() {
      if (!this.track) return;
      for (const segment of this.track.segments) {
        for (const pickup of segment.pickups) {
          pickup.active = true;
          pickup.respawnAt = 0;
        }
      }
    }

    update(dt) {
      if (!this.active) {
        this.input.endFrame?.();
        return;
      }

      const delta = U.clamp(Number(dt) || 0, 0, 0.05);
      const controls = this.input.frame?.() || {};

      if (controls.pausePressed && this.state !== 'finished') {
        this.togglePause();
        this.input.endFrame?.();
        return;
      }

      if (this.paused) {
        this.input.endFrame?.();
        return;
      }

      this.elapsed += delta;

      if (this.state === 'countdown') {
        this.updateCountdown(delta, controls);
        this.input.endFrame?.();
        return;
      }

      if (this.state !== 'racing') {
        this.input.endFrame?.();
        return;
      }

      this.raceTime += delta;
      this.updateRacerTimers(delta);
      this.updatePlayer(this.player, controls, delta);
      for (const racer of this.racers) {
        if (!racer.isPlayer) this.updateAI(racer, delta);
      }
      this.updateDynamic(delta);
      this.resolveRacerCollisions();
      this.updatePositions();

      if (this.player?.finished && !this._completing) this.completeRace();
      if (this.raceTime > 900 && !this._completing) this.completeRace(true);

      this.input.endFrame?.();
    }

    updateCountdown(dt, controls) {
      this.countdown -= dt;
      const current = Math.max(1, Math.ceil(this.countdown));
      if (current !== this.lastCountdown && this.countdown > 0) {
        this.lastCountdown = current;
        this.audio.sfx?.('count');
        MO.Events.emit('race:countdown', { value: String(current) });
      }

      if (this.player && this.countdown < 0.9 && controls.accelerate) {
        this.player.driftCharge = U.clamp(this.player.driftCharge + dt, 0, 1);
      }

      if (this.countdown <= 0) {
        this.state = 'racing';
        this.raceTime = 0;
        if (this.player?.driftCharge > 0.25) {
          this.player.miniBoostTimer = 1.15 + this.player.driftCharge * 0.55;
          this.player.driftCharge = 0;
        }
        this.audio.sfx?.('go');
        MO.Events.emit('race:countdown', { value: 'GO', go: true });
        MO.Events.emit('race:go', { track: this.track.spec });
      }
    }

    updateRacerTimers(dt) {
      for (const racer of this.racers) {
        for (const key of CONTROL_KEYS) racer[key] = down(racer[key], dt);

        if (racer.overheated) {
          racer.overheatTimer = down(racer.overheatTimer, dt);
          racer.heat = U.approach(racer.heat, 52, racer.cooling * 1.35 * dt);
          if (racer.overheatTimer <= 0 && racer.heat <= 58) racer.overheated = false;
        }

        if (racer.respawnTimer > 0) {
          racer.respawnTimer = down(racer.respawnTimer, dt);
          racer.speed = U.approach(racer.speed, 0, racer.braking * dt);
          if (racer.respawnTimer <= 0 && racer.armor <= 0) {
            racer.armor = racer.maxArmor * 0.62;
            racer.speed = racer.topSpeed * 0.27;
            racer.x = 0;
            racer.invulnerableTimer = 2.8;
          }
        }
      }

      for (const [key, expiry] of this.pairCooldowns) {
        if (expiry <= this.raceTime) this.pairCooldowns.delete(key);
      }
    }

    updatePlayer(racer, controls, dt) {
      if (!racer || racer.finished) return;
      if (controls.resetPressed) this.resetRacer(racer, true);
      if (controls.itemPressed) this.useItem(racer);
      this.applyDrive(racer, {
        steer: Number(controls.steer) || 0,
        accelerate: !!controls.accelerate,
        brake: !!controls.brake,
        boost: !!controls.boost,
        drift: !!controls.drift,
        speedCap: 1,
      }, dt);
    }

    updateAI(racer, dt) {
      if (racer.finished) return;
      const ai = racer.ai;
      ai.laneTimer -= dt;
      ai.useTimer -= dt;

      const segment = this.track.findSegment(racer.progress);
      let curvePressure = 0;
      for (let step = 2; step <= 18; step += 4) {
        const ahead = this.track.segmentAtIndex(segment.index + step);
        curvePressure = Math.max(curvePressure, Math.abs(ahead.curve));
      }

      if (ai.laneTimer <= 0) {
        ai.laneTimer = this.rng.range(1.3, 3.8) / (0.65 + ai.skill * 0.55);
        const candidates = [-0.66, -0.32, 0, 0.32, 0.66];
        let best = candidates[this.rng.int(0, candidates.length - 1)];
        let bestScore = -Infinity;
        for (const lane of candidates) {
          let score = this.rng.range(-0.2, 0.2) - Math.abs(lane) * 0.12;
          for (const other of this.racers) {
            if (other === racer || other.finished) continue;
            const gap = other.progress - racer.progress;
            if (gap > -500 && gap < 1300 && Math.abs(other.x - lane) < 0.24) score -= 1.2;
          }
          for (const hazard of segment.hazards) {
            if (Math.abs(hazard.offset - lane) < hazard.width + 0.14) score -= 0.9;
          }
          if (score > bestScore) {
            bestScore = score;
            best = lane;
          }
        }
        ai.preferredLane = best;
      }

      const curveAssist = segment.curve * (0.44 + ai.skill * 0.22);
      const correction = (ai.preferredLane - racer.x) * (1.6 + ai.skill * 1.5);
      let steer = U.clamp(correction + curveAssist, -1, 1);
      if (racer.offroad) steer = U.clamp(-racer.x * 1.8 + curveAssist, -1, 1);
      if (racer.slipTimer > 0) steer += Math.sin(this.raceTime * 8 + racer.seed) * 0.25;

      const speedCap = U.clamp(1.02 - curvePressure * (0.12 + (1 - ai.skill) * 0.15), 0.67, 1.02);
      const boost = curvePressure < 0.28 && racer.heat < 73 && !racer.overheated && this.rng.chance(dt * (0.16 + ai.skill * 0.2));
      const drift = curvePressure > 0.65 && Math.abs(steer) > 0.2 && racer.speed > racer.topSpeed * 0.42;

      this.applyDrive(racer, {
        steer,
        accelerate: true,
        brake: curvePressure > 1.05 && racer.speed > racer.topSpeed * speedCap,
        boost,
        drift,
        speedCap,
      }, dt);

      if (racer.item && ai.useTimer <= 0) {
        if (this.shouldAIUseItem(racer)) {
          this.useItem(racer);
          ai.useTimer = this.rng.range(2.8, 6.2) / (0.75 + ai.aggression * 0.35);
        } else {
          ai.useTimer = this.rng.range(0.5, 1.2);
        }
      }
    }

    shouldAIUseItem(racer) {
      const item = racer.item;
      if (!item) return false;
      const armorRatio = racer.armor / racer.maxArmor;
      const target = this.findTargetAhead(racer, 16000);
      const nearby = this.racers.filter((other) => other !== racer && !other.finished && Math.abs(other.progress - racer.progress) < 4200);
      if (item === 'repair') return armorRatio < 0.68;
      if (item === 'shield') return armorRatio < 0.75 || nearby.length >= 2;
      if (item === 'overdrive') return Math.abs(this.track.findSegment(racer.progress).curve) < 0.4;
      if (item === 'mine') return this.racers.some((other) => other !== racer && racer.progress - other.progress > 0 && racer.progress - other.progress < 3500);
      if (item === 'emp' || item === 'shockwave') return nearby.length >= 1;
      if (item === 'ion' || item === 'rail') return !!target;
      return this.rng.chance(0.5);
    }

    applyDrive(racer, control, dt) {
      if (!racer || racer.finished || racer.respawnTimer > 0) return;
      const chassis = D.getChassis(racer.chassisId);
      const segment = this.track.findSegment(racer.progress);
      const speedRatio = U.clamp(racer.speed / Math.max(1, racer.topSpeed), 0, 1.5);
      const disabled = racer.stunTimer > 0;
      const spinning = racer.spinTimer > 0;
      let steer = disabled ? 0 : U.clamp(control.steer || 0, -1, 1);
      if (spinning) steer = Math.sin(this.raceTime * 15 + racer.seed) * 0.75;
      if (racer.slipTimer > 0) steer += Math.sin(this.raceTime * 11 + racer.seed) * 0.22;

      const wasDrifting = racer.drifting;
      racer.drifting = !disabled && !spinning && !!control.drift && Math.abs(steer) > 0.12 && speedRatio > 0.34;
      if (racer.drifting) {
        racer.driftCharge = U.clamp(racer.driftCharge + dt, 0, 2.2);
        racer.speed = Math.max(0, racer.speed - 105 * dt);
        if (chassis.id === 'monowheel') racer.heat = Math.max(0, racer.heat - 5.5 * dt);
      } else if (wasDrifting) {
        const bonus = U.clamp(racer.driftCharge * 0.48, 0, 1.05) + (chassis.id === 'monowheel' ? 0.38 : 0);
        if (bonus > 0.18) {
          racer.miniBoostTimer = Math.max(racer.miniBoostTimer, bonus);
          if (racer.isPlayer) this.audio.sfx?.('boost');
        }
        racer.driftCharge = 0;
      }

      const boostRequested = !disabled && !spinning && !!control.boost;
      racer.boostActive = boostRequested && !racer.overheated && racer.empTimer <= 0 && racer.heat < 100;
      if (racer.boostActive) {
        racer.heat += racer.heatRate * dt;
        if (racer.heat >= 100) {
          racer.heat = 100;
          racer.overheated = true;
          racer.overheatTimer = 2.5;
          racer.boostActive = false;
          if (racer.isPlayer) {
            this.audio.sfx?.('error');
            this.toast('RÉACTEUR VERROUILLÉ — SURCHAUFFE', 'warning');
          }
        }
      } else if (!racer.overheated) {
        racer.heat = Math.max(0, racer.heat - racer.cooling * dt * (racer.speed < racer.topSpeed * 0.35 ? 1.25 : 1));
      }

      let cap = racer.topSpeed * U.clamp(control.speedCap || 1, 0.4, 1.1);
      if (racer.empTimer > 0) cap *= 0.66;
      if (racer.overdriveTimer > 0) cap *= 1.34;
      if (racer.padBoostTimer > 0) cap *= 1.22;
      if (racer.miniBoostTimer > 0) cap *= 1.14;
      if (racer.recoveryBoostTimer > 0) cap *= 1.12;
      if (racer.boostActive) cap *= 1.25;
      if (racer.armor / racer.maxArmor < 0.22) cap *= 0.91;

      racer.wasOffroad = racer.offroad;
      racer.offroad = Math.abs(racer.x) > 1.02;
      if (racer.offroad) {
        const offroadCap = racer.topSpeed * U.clamp(0.55 + racer.offroadGrip * 0.28, 0.66, 0.985);
        cap = Math.min(cap, offroadCap);
      }
      if (chassis.id === 'quadruped' && racer.wasOffroad && !racer.offroad) {
        racer.recoveryBoostTimer = Math.max(racer.recoveryBoostTimer, 2.15);
      }

      const throttle = !disabled && !!control.accelerate;
      const braking = !disabled && !!control.brake;
      let acceleration = racer.acceleration;
      if (racer.boostActive) acceleration *= 1.7;
      if (racer.overdriveTimer > 0) acceleration *= 1.45;
      if (racer.padBoostTimer > 0 || racer.miniBoostTimer > 0 || racer.recoveryBoostTimer > 0) acceleration *= 1.28;
      if (racer.empTimer > 0) acceleration *= 0.58;
      if (racer.offroad) acceleration *= U.clamp(0.6 + racer.offroadGrip * 0.22, 0.65, 1.02);

      if (throttle) racer.speed += acceleration * dt;
      else racer.speed -= (260 + racer.speed * 0.035) * dt;
      if (braking) racer.speed -= racer.braking * dt;
      if (racer.offroad && racer.speed > cap) racer.speed -= (900 + (racer.speed - cap) * 1.7) * dt;
      if (racer.speed > cap) racer.speed = U.approach(racer.speed, cap, (900 + racer.speed * 0.18) * dt);
      racer.speed = U.clamp(racer.speed, 0, racer.topSpeed * 1.48);

      if (chassis.id === 'quadruped' && braking && !racer.brakeLatch && speedRatio > 0.52) {
        racer.recoveryBoostTimer = Math.max(racer.recoveryBoostTimer, 1.25);
      }
      racer.brakeLatch = braking;

      let handling = racer.handling * (0.35 + speedRatio * 0.72);
      if (racer.drifting) handling *= 1.24;
      if (racer.empTimer > 0) handling *= 0.68;
      if (racer.slipTimer > 0) handling *= 0.58;
      if (chassis.id === 'hexapod' && speedRatio < 0.55) handling *= 1.25;
      if (chassis.id === 'tripod' && Math.abs(segment.curve) > 0.45) handling *= 1.12;

      racer.x += steer * handling * dt;
      const curveResistance = chassis.id === 'tripod' ? 0.76 : chassis.id === 'tracked' ? 0.9 : 1;
      racer.x -= segment.curve * speedRatio * speedRatio * 0.47 * curveResistance * dt;
      if (racer.slipTimer > 0) racer.x += Math.sin(this.raceTime * 7 + racer.seed) * 0.12 * dt;

      if (Math.abs(racer.x) > 1.48) {
        racer.x = U.clamp(racer.x, -1.48, 1.48);
        racer.speed *= Math.pow(0.88, dt * 6);
      }
      racer.visualSteer = U.lerp(racer.visualSteer, U.clamp(steer + segment.curve * 0.18, -1, 1), 1 - Math.pow(0.001, dt));

      const advance = racer.speed * dt;
      racer.progress += advance;
      racer.distance += advance;
      racer.stats.distance += advance;

      this.checkTrackInteractions(racer);
      this.checkLaps(racer);
    }

    checkTrackInteractions(racer) {
      if (racer.finished || racer.respawnTimer > 0) return;
      const segment = this.track.findSegment(racer.progress);
      const phase = U.percentRemaining(racer.progress, this.track.segmentLength);
      if (phase < 0.2 || phase > 0.82) return;

      for (const pickup of segment.pickups) {
        if (!pickup.active && pickup.respawnAt <= this.raceTime) pickup.active = true;
        if (!pickup.active || racer.item || Math.abs(racer.x - pickup.offset) > 0.25) continue;
        pickup.active = false;
        pickup.respawnAt = this.raceTime + 7.5;
        this.giveItem(racer);
        break;
      }

      for (const pad of segment.boostPads) {
        const key = `pad:${pad.id}`;
        if ((racer.objectCooldowns.get(key) || 0) > this.raceTime) continue;
        if (Math.abs(racer.x - pad.offset) <= pad.width * 0.72) {
          racer.objectCooldowns.set(key, this.raceTime + 2.2);
          racer.padBoostTimer = Math.max(racer.padBoostTimer, 1.25);
          racer.speed = Math.max(racer.speed, racer.topSpeed * 0.76);
          if (racer.isPlayer) this.audio.sfx?.('boost');
        }
      }

      for (const hazard of segment.hazards) {
        const key = `hazard:${hazard.id}`;
        if ((racer.objectCooldowns.get(key) || 0) > this.raceTime) continue;
        if (Math.abs(racer.x - hazard.offset) <= hazard.width * 0.68) {
          racer.objectCooldowns.set(key, this.raceTime + 2.5);
          this.triggerHazard(racer, hazard);
        }
      }
    }

    triggerHazard(racer, hazard) {
      const chassis = D.getChassis(racer.chassisId);
      if (hazard.type === 'sand') {
        if (chassis.id !== 'tracked') racer.speed *= chassis.id === 'hover' ? 0.91 : 0.74;
      } else if (hazard.type === 'ice') {
        racer.slipTimer = Math.max(racer.slipTimer, chassis.id === 'tripod' ? 0.55 : 1.25);
        this.applyImpact(racer, { damage: 4, spin: 0.45, speedLoss: 0.08, type: 'ice', severity: 3 });
      } else if (hazard.type === 'vent') {
        this.applyImpact(racer, { damage: 15, spin: 0.4, speedLoss: 0.22, type: 'vent', severity: 8 });
      } else if (hazard.type === 'gravity') {
        racer.x = U.clamp(racer.x + (racer.x >= 0 ? 0.25 : -0.25), -1.48, 1.48);
        this.applyImpact(racer, { damage: 8, spin: 0.8, speedLoss: 0.14, type: 'gravity', severity: 7 });
      } else if (hazard.type === 'debris' && chassis.id !== 'tracked') {
        this.applyImpact(racer, { damage: 10, spin: 0.36, speedLoss: 0.18, type: 'debris', severity: 6 });
      }
    }

    giveItem(racer) {
      const group = this.mode === 'time-trial'
        ? ITEM_WEIGHTS.time
        : racer.position <= 2
          ? ITEM_WEIGHTS.front
          : racer.position >= Math.max(5, this.racers.length - 2)
            ? ITEM_WEIGHTS.back
            : ITEM_WEIGHTS.middle;
      racer.item = U.weightedChoice(group.map(([value, weight]) => ({ value, weight })), () => this.rng.next());
      if (racer.isPlayer) {
        this.audio.sfx?.('pickup');
        const item = D.getItem(racer.item);
        this.toast(`${item?.name || 'OBJET'} ACQUIS`, 'reward');
        MO.Events.emit('race:item', { racer, item: racer.item });
      }
    }

    useItem(racer) {
      if (!racer?.item || racer.itemCooldown > 0 || racer.respawnTimer > 0 || racer.finished) return false;
      const item = racer.item;
      racer.item = null;
      racer.itemCooldown = 0.42;
      racer.stats.itemsUsed += 1;

      if (item === 'shield') {
        racer.shieldTimer = Math.max(racer.shieldTimer, 6.2);
        this.audioFor(racer, 'shield');
      } else if (item === 'overdrive') {
        racer.overdriveTimer = Math.max(racer.overdriveTimer, 4.1);
        racer.heat = Math.max(0, racer.heat - 18);
        racer.speed = Math.max(racer.speed, racer.topSpeed * 0.78);
        this.audioFor(racer, 'boost');
      } else if (item === 'repair') {
        racer.armor = Math.min(racer.maxArmor, racer.armor + racer.maxArmor * 0.36);
        this.audioFor(racer, 'repair');
      } else if (item === 'mine') {
        this.dynamic.mines.push({
          id: `mine-${this.raceTime}-${this.rng.next()}`,
          ownerId: racer.id,
          progress: racer.progress - 210,
          x: racer.x,
          life: 32,
          armedAt: this.raceTime + 0.6,
          seed: this.rng.range(0, Math.PI * 2),
        });
        this.audioFor(racer, 'mine');
      } else if (item === 'ion' || item === 'rail') {
        const target = this.findTargetAhead(racer, item === 'rail' ? 22000 : 18000);
        this.dynamic.projectiles.push({
          id: `${item}-${this.raceTime}-${this.rng.next()}`,
          type: item === 'ion' ? 'missile' : 'rail',
          ownerId: racer.id,
          targetId: target?.id || null,
          progress: racer.progress + 180,
          x: racer.x,
          speed: item === 'ion' ? racer.topSpeed * 1.72 : racer.topSpeed * 2.25,
          damage: item === 'ion' ? 24 : 31,
          life: item === 'ion' ? 6 : 2.2,
          seed: this.rng.range(0, Math.PI * 2),
        });
        this.audioFor(racer, item === 'ion' ? 'missile' : 'boost');
      } else if (item === 'emp') {
        for (const target of this.racers) {
          if (target === racer || target.finished) continue;
          const gap = Math.abs(target.progress - racer.progress);
          if (gap <= 7800) {
            this.applyImpact(target, {
              source: racer,
              damage: 10,
              spin: 0.32,
              speedLoss: 0.15,
              emp: 2.5,
              type: 'emp',
              severity: 7,
            });
          }
        }
        this.audioFor(racer, 'emp');
      } else if (item === 'shockwave') {
        for (const target of this.racers) {
          if (target === racer || target.finished) continue;
          const gap = Math.abs(target.progress - racer.progress);
          if (gap <= 4300) {
            const direction = target.x >= racer.x ? 1 : -1;
            target.x = U.clamp(target.x + direction * 0.28, -1.48, 1.48);
            this.applyImpact(target, {
              source: racer,
              damage: 13,
              spin: 0.92,
              speedLoss: 0.2,
              type: 'shockwave',
              severity: 9,
            });
          }
        }
        this.audioFor(racer, 'hit');
      }

      if (racer.isPlayer) {
        const data = D.getItem(item);
        this.toast(`${data?.name || item} DÉPLOYÉ`, 'reward');
      }
      return true;
    }

    audioFor(racer, effect) {
      if (racer.isPlayer) this.audio.sfx?.(effect);
    }

    findTargetAhead(racer, maxDistance = Infinity) {
      return this.racers
        .filter((other) => other !== racer && !other.finished && other.respawnTimer <= 0)
        .map((other) => ({ other, gap: other.progress - racer.progress }))
        .filter((entry) => entry.gap > 0 && entry.gap <= maxDistance)
        .sort((a, b) => a.gap - b.gap)[0]?.other || null;
    }

    updateDynamic(dt) {
      const projectiles = [];
      for (const projectile of this.dynamic.projectiles) {
        projectile.life -= dt;
        const owner = this.racers.find((racer) => racer.id === projectile.ownerId);
        const target = this.racers.find((racer) => racer.id === projectile.targetId && !racer.finished && racer.respawnTimer <= 0);
        const beforeGap = target ? target.progress - projectile.progress : Infinity;

        if (projectile.type === 'missile' && target) {
          projectile.x = U.lerp(projectile.x, target.x, 1 - Math.pow(0.0015, dt));
          projectile.speed = U.lerp(projectile.speed, Math.max(projectile.speed, target.speed * 1.35), 0.08);
        }
        projectile.progress += projectile.speed * dt;

        let hit = null;
        if (target) {
          const afterGap = target.progress - projectile.progress;
          if ((afterGap <= 170 || (beforeGap > 0 && afterGap <= 0)) && Math.abs(target.x - projectile.x) < (projectile.type === 'rail' ? 0.28 : 0.38)) hit = target;
        }
        if (!hit) {
          hit = this.racers.find((racer) => racer !== owner
            && !racer.finished
            && racer.respawnTimer <= 0
            && Math.abs(racer.progress - projectile.progress) < 145
            && Math.abs(racer.x - projectile.x) < (projectile.type === 'rail' ? 0.22 : 0.34));
        }

        if (hit) {
          this.applyImpact(hit, {
            source: owner,
            damage: projectile.damage,
            spin: projectile.type === 'missile' ? 1.05 : 0.62,
            speedLoss: projectile.type === 'missile' ? 0.3 : 0.25,
            emp: projectile.type === 'missile' ? 1.2 : 0,
            type: projectile.type,
            severity: projectile.type === 'missile' ? 10 : 9,
          });
          if (hit.isPlayer || owner?.isPlayer) this.audio.sfx?.('hit');
        } else if (projectile.life > 0) {
          projectiles.push(projectile);
        }
      }
      this.dynamic.projectiles = projectiles;

      const mines = [];
      for (const mine of this.dynamic.mines) {
        mine.life -= dt;
        const owner = this.racers.find((racer) => racer.id === mine.ownerId);
        let detonated = false;
        if (this.raceTime >= mine.armedAt) {
          for (const racer of this.racers) {
            if (racer.id === mine.ownerId || racer.finished || racer.respawnTimer > 0) continue;
            if (D.getChassis(racer.chassisId).id === 'hover') continue;
            if (Math.abs(racer.progress - mine.progress) < 150 && Math.abs(racer.x - mine.x) < 0.26) {
              this.applyImpact(racer, {
                source: owner,
                damage: 22,
                spin: 1.3,
                speedLoss: 0.34,
                type: 'mine',
                severity: 10,
              });
              detonated = true;
              if (racer.isPlayer || owner?.isPlayer) this.audio.sfx?.('mine');
              break;
            }
          }
        }
        if (!detonated && mine.life > 0) mines.push(mine);
      }
      this.dynamic.mines = mines;
    }

    resolveRacerCollisions() {
      for (let firstIndex = 0; firstIndex < this.racers.length; firstIndex += 1) {
        const first = this.racers[firstIndex];
        if (first.finished || first.respawnTimer > 0 || first.speed < 250) continue;
        for (let secondIndex = firstIndex + 1; secondIndex < this.racers.length; secondIndex += 1) {
          const second = this.racers[secondIndex];
          if (second.finished || second.respawnTimer > 0 || second.speed < 250) continue;
          if (Math.abs(first.progress - second.progress) > 185 || Math.abs(first.x - second.x) > 0.22) continue;
          const key = first.id < second.id ? `${first.id}|${second.id}` : `${second.id}|${first.id}`;
          if ((this.pairCooldowns.get(key) || 0) > this.raceTime) continue;
          this.pairCooldowns.set(key, this.raceTime + 0.62);

          const relativeSpeed = Math.abs(first.speed - second.speed);
          const momentumSpeed = (first.speed * first.mass + second.speed * second.mass) / (first.mass + second.mass);
          const firstChassis = D.getChassis(first.chassisId);
          const secondChassis = D.getChassis(second.chassisId);
          const firstRam = firstChassis.id === 'octopod' ? 1.42 : 1;
          const secondRam = secondChassis.id === 'octopod' ? 1.42 : 1;
          const baseDamage = 3.5 + relativeSpeed * 0.0025;
          const firstSource = first.progress <= second.progress ? first : second;
          const secondSource = firstSource === first ? second : first;

          this.applyImpact(first, {
            source: secondSource,
            damage: baseDamage * secondRam * (second.mass / first.mass),
            spin: 0.22 + Math.max(0, second.mass - first.mass) * 0.22,
            speedLoss: firstChassis.id === 'octopod' || firstChassis.id === 'tracked' ? 0.04 : 0.11,
            type: 'collision',
            severity: 5,
          });
          this.applyImpact(second, {
            source: firstSource,
            damage: baseDamage * firstRam * (first.mass / second.mass),
            spin: 0.22 + Math.max(0, first.mass - second.mass) * 0.22,
            speedLoss: secondChassis.id === 'octopod' || secondChassis.id === 'tracked' ? 0.04 : 0.11,
            type: 'collision',
            severity: 5,
          });

          first.speed = U.lerp(first.speed, momentumSpeed, firstChassis.id === 'octopod' ? 0.12 : 0.3);
          second.speed = U.lerp(second.speed, momentumSpeed, secondChassis.id === 'octopod' ? 0.12 : 0.3);
          const push = first.x <= second.x ? -0.08 : 0.08;
          first.x = U.clamp(first.x + push, -1.48, 1.48);
          second.x = U.clamp(second.x - push, -1.48, 1.48);
        }
      }
    }

    applyImpact(target, impact = {}) {
      if (!target || target.finished || target.respawnTimer > 0 || target.invulnerableTimer > 0) return false;
      const chassis = D.getChassis(target.chassisId);
      if (target.shieldTimer > 0) {
        target.shieldTimer = Math.max(0, target.shieldTimer - 1.4);
        if (target.isPlayer) {
          this.audio.sfx?.('shield');
          this.toast('BOUCLIER — IMPACT ABSORBÉ', 'reward');
        }
        return false;
      }

      let damage = Math.max(0, Number(impact.damage) || 0);
      let spin = Math.max(0, Number(impact.spin) || 0);
      if (chassis.id === 'tripod') {
        damage *= 0.72;
        spin *= 0.48;
      }
      if (chassis.id === 'biped') spin *= 0.6;
      if (chassis.id === 'hover' && impact.type === 'shockwave') {
        damage *= 1.3;
        spin *= 1.25;
      }

      target.armor = Math.max(0, target.armor - damage);
      target.stats.damageTaken += damage;
      target.stats.impacts += 1;
      target.speed *= 1 - U.clamp(Number(impact.speedLoss) || 0, 0, 0.7);
      target.spinTimer = Math.max(target.spinTimer, spin);
      if (impact.emp) target.empTimer = Math.max(target.empTimer, Number(impact.emp) || 0);
      if (impact.stun) target.stunTimer = Math.max(target.stunTimer, Number(impact.stun) || 0);
      if (chassis.id === 'quadruped') target.recoveryBoostTimer = Math.max(target.recoveryBoostTimer, 1.8);

      MO.Events.emit('race:impact', {
        target,
        source: impact.source || null,
        type: impact.type || 'impact',
        severity: Number(impact.severity) || 5,
        damage,
      });

      if (target.isPlayer) this.audio.sfx?.('hit');
      if (target.armor <= 0) this.destroyRacer(target, impact.source);
      return true;
    }

    destroyRacer(racer, source = null) {
      racer.armor = 0;
      racer.speed = 0;
      racer.respawnTimer = 1.85;
      racer.invulnerableTimer = 3.1;
      racer.spinTimer = 0;
      racer.empTimer = 0;
      racer.item = null;
      racer.x = 0;
      if (racer.isPlayer) this.toast(source ? `UNITÉ DÉTRUITE PAR ${source.callsign}` : 'UNITÉ DÉTRUITE — RECONSTRUCTION', 'warning');
    }

    resetRacer(racer, manual = false) {
      if (!racer || racer.finished) return;
      racer.x = 0;
      racer.speed = Math.min(racer.speed, racer.topSpeed * 0.28);
      racer.spinTimer = 0;
      racer.slipTimer = 0;
      racer.heat = Math.min(racer.heat, 55);
      racer.invulnerableTimer = Math.max(racer.invulnerableTimer, 0.8);
      if (manual && racer.isPlayer) this.toast('RECALAGE SUR LA TRAJECTOIRE', 'warning');
    }

    checkLaps(racer) {
      if (racer.finished) return;
      const completed = Math.max(0, Math.floor(racer.distance / this.track.trackLength));
      while (racer.completedLaps < completed) {
        const lapTime = this.raceTime - racer.lapStartTime;
        racer.lapTimes.push(lapTime);
        racer.bestLap = racer.bestLap == null ? lapTime : Math.min(racer.bestLap, lapTime);
        racer.completedLaps += 1;
        racer.lapStartTime = this.raceTime;
        if (racer.isPlayer && racer.completedLaps < this.laps) {
          this.audio.sfx?.('ui');
          this.toast(`TOUR ${racer.completedLaps}/${this.laps} — ${U.formatTime(lapTime)}`, 'reward');
          MO.Events.emit('race:lap', { racer, lap: racer.completedLaps, lapTime });
        }
      }
      racer.lap = Math.min(this.laps, racer.completedLaps + 1);
      if (racer.distance >= this.finishDistance) {
        if (racer.lapTimes.length < this.laps) {
          const lapTime = this.raceTime - racer.lapStartTime;
          racer.lapTimes.push(lapTime);
          racer.bestLap = racer.bestLap == null ? lapTime : Math.min(racer.bestLap, lapTime);
        }
        racer.finished = true;
        racer.finishTime = this.raceTime;
        racer.lap = this.laps;
      }
    }

    updatePositions() {
      const ordered = this.racers.slice().sort((a, b) => {
        if (a.finished && b.finished) return a.finishTime - b.finishTime;
        if (a.finished) return -1;
        if (b.finished) return 1;
        return b.distance - a.distance;
      });
      ordered.forEach((racer, index) => {
        racer.position = index + 1;
      });
    }

    completeRace(forced = false) {
      if (this._completing || !this.player) return;
      this._completing = true;

      if (!this.player.finished) {
        this.player.finished = true;
        this.player.finishTime = this.raceTime;
      }

      for (const racer of this.racers) {
        if (racer.finished) continue;
        const remaining = Math.max(0, this.finishDistance - racer.distance);
        const pace = Math.max(racer.topSpeed * 0.68, racer.speed || racer.topSpeed * 0.68);
        racer.finishTime = this.raceTime + remaining / pace * this.rng.range(0.96, 1.07);
        racer.finished = true;
        if (racer.bestLap == null) racer.bestLap = racer.finishTime / this.laps;
      }
      this.updatePositions();

      const ordered = this.racers.slice().sort((a, b) => a.finishTime - b.finishTime);
      const playerPosition = ordered.findIndex((racer) => racer.isPlayer) + 1;
      const previousBest = this.store.get().bestTimes[this.track.id];
      const playerBestLap = this.player.bestLap || this.player.finishTime / this.laps;
      const newBest = this.store.recordBestTime(this.track.id, playerBestLap);
      const cleanRace = this.player.stats.impacts <= 1;
      const beaten = Math.max(0, ordered.length - playerPosition);
      const rewardBase = this.mode === 'time-trial' ? 210 : D.REWARDS.base;
      const rewardBreakdown = {
        participation: Math.round(rewardBase * this.difficulty.reward),
        classement: Math.round(beaten * D.REWARDS.perOpponent * this.difficulty.reward),
        maîtrise: cleanRace ? D.REWARDS.cleanRace : 0,
        record: newBest ? D.REWARDS.bestTime : 0,
        championnat: 0,
      };

      let championshipResult = null;
      if (this.mode === 'grand-prix' && this.championship) {
        const roundIndex = this.championship.round;
        if (!this.championship.scoredRounds.has(roundIndex)) {
          ordered.forEach((racer, index) => {
            this.championship.points[racer.id] += D.CHAMPIONSHIP_POINTS[index] || 0;
          });
          this.championship.scoredRounds.add(roundIndex);
        }
        this.championship.round += 1;
        const final = this.championship.round >= this.championship.tracks.length;
        const standings = this.championship.roster
          .map((entry) => ({
            ...entry,
            points: this.championship.points[entry.id] || 0,
            chassisName: D.getChassis(entry.chassisId).name,
          }))
          .sort((a, b) => b.points - a.points || (a.isPlayer ? -1 : 1));
        const won = final && standings[0]?.isPlayer;
        if (won) rewardBreakdown.championnat = 1400;
        championshipResult = {
          round: roundIndex + 1,
          totalRounds: this.championship.tracks.length,
          final,
          nextTrackId: final ? null : this.championship.tracks[this.championship.round],
          standings,
          won,
        };
      }

      const reward = Object.values(rewardBreakdown).reduce((sum, value) => sum + value, 0);
      this.store.addCredits(reward);
      this.store.addRaceStats({
        position: playerPosition,
        distance: this.player.stats.distance,
        itemsUsed: this.player.stats.itemsUsed,
        impacts: this.player.stats.impacts,
        championshipWon: !!championshipResult?.won,
      });

      const result = {
        mode: this.mode,
        forced,
        track: this.track.spec,
        laps: this.laps,
        raceTime: this.player.finishTime,
        position: playerPosition,
        totalRacers: ordered.length,
        bestLap: playerBestLap,
        previousBest,
        newBest,
        cleanRace,
        reward,
        rewardBreakdown,
        championship: championshipResult,
        rows: ordered.map((racer, index) => ({
          id: racer.id,
          isPlayer: racer.isPlayer,
          position: index + 1,
          name: racer.name,
          callsign: racer.callsign,
          chassisId: racer.chassisId,
          chassisName: D.getChassis(racer.chassisId).name,
          time: racer.finishTime,
          bestLap: racer.bestLap,
          points: this.mode === 'grand-prix' ? D.CHAMPIONSHIP_POINTS[index] || 0 : null,
        })),
      };

      this.lastResult = result;
      this.state = 'finished';
      this.active = false;
      this.paused = false;
      this.audio.stopMusic?.();
      this.audio.sfx?.('finish');
      MO.Events.emit('race:finished', result);
    }

    togglePause() {
      if (!this.active || this.state === 'finished') return;
      this.paused = !this.paused;
      MO.Events.emit('race:pause', { paused: this.paused });
    }

    resume() {
      if (!this.active) return;
      this.paused = false;
      MO.Events.emit('race:pause', { paused: false });
    }

    restart() {
      if (!this.currentConfig) return;
      const config = { ...this.currentConfig };
      if (this.mode === 'grand-prix') {
        const scoredCurrentRound = this.championship?.scoredRounds.has(this.championship.round);
        if (scoredCurrentRound) return;
      }
      this.start(config);
    }

    startNextChampionshipRound() {
      if (!this.championship || this.championship.round >= this.championship.tracks.length) return false;
      this.start({
        mode: 'grand-prix',
        trackId: this.championship.tracks[0],
        difficulty: this.championship.difficulty,
        laps: this.championship.laps,
      });
      return true;
    }

    startNewChampionship() {
      const config = { ...(this.currentConfig || {}), mode: 'grand-prix', newChampionship: true };
      this.start(config);
    }

    replayLast() {
      if (!this.currentConfig) return false;
      if (this.mode === 'grand-prix') return false;
      this.start({ ...this.currentConfig });
      return true;
    }

    quit() {
      const wasChampionship = this.mode === 'grand-prix';
      this.active = false;
      this.paused = false;
      this.state = 'idle';
      this.audio.stopMusic?.();
      this.audio.updateEngine?.(0, 0, 0, false);
      this.input.reset?.();
      if (wasChampionship) this.championship = null;
      MO.Events.emit('race:quit', {});
    }

    toast(text, type = '') {
      MO.Events.emit('ui:toast', { text, type });
    }

    get speedKmh() {
      return this.player ? Math.round(this.player.speed * 0.116) : 0;
    }
  }

  Game.BASE = BASE;
  Game.ITEM_WEIGHTS = ITEM_WEIGHTS;
  MO.Game = Game;
})(window.MO = window.MO || {});
