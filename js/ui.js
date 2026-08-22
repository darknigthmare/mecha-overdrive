(function (MO) {
  'use strict';

  const U = MO.Util;
  const D = MO.Data;
  const $ = (id) => document.getElementById(id);
  const escapeHTML = (value) => String(value ?? '').replace(/[&<>'"]/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
  }[character]));

  const STAT_LABELS = Object.freeze({
    speed: 'VITESSE',
    acceleration: 'ACCÉLÉRATION',
    handling: 'MANIABILITÉ',
    armor: 'BLINDAGE',
    stability: 'STABILITÉ',
    reactor: 'RÉACTEUR',
  });

  class UI {
    constructor(renderer, game) {
      this.renderer = renderer;
      this.game = game;
      this.store = MO.Storage;
      this.mode = 'quick';
      this.selectedTrackId = D.TRACKS[0].id;
      this.garageChassisId = this.store.get().selectedChassis;
      this.currentScreen = 'main';
      this.lastResult = null;
      this.countdownTimer = 0;
      this.featuredCanvas = document.createElement('canvas');
      this.featuredCanvas.setAttribute('aria-label', 'Aperçu du mécha sélectionné');
      $('featuredMech').appendChild(this.featuredCanvas);
      this.cacheElements();
      this.bind();
      this.applySettings(this.store.get().settings);
      this.refreshAll();
      this.show('main');
    }

    cacheElements() {
      this.elements = {
        screens: Array.from(document.querySelectorAll('.screen')),
        hud: $('hud'),
        touchControls: $('touchControls'),
        pauseOverlay: $('pauseOverlay'),
        countdown: $('countdown'),
        homeButton: $('homeButton'),
        credits: $('creditsValue'),
        pilotName: $('pilotName'),
        selectedClass: $('selectedClassLabel'),
        selectedMech: $('selectedMechName'),
        selectedTrait: $('selectedMechTrait'),
        configMechName: $('configMechName'),
        trackCards: $('trackCards'),
        modeEyebrow: $('modeEyebrow'),
        modeTitle: $('modeTitle'),
        difficulty: $('difficultySelect'),
        laps: $('lapsSelect'),
        launch: $('launchRaceButton'),
        chassisList: $('chassisList'),
        garageCanvas: $('garageCanvas'),
        garageClass: $('garageClass'),
        garageName: $('garageName'),
        garageDescription: $('garageDescription'),
        garageStats: $('garageStats'),
        garageAbility: $('garageAbility'),
        garageAbilityDescription: $('garageAbilityDescription'),
        upgradeCredits: $('upgradeCredits'),
        upgradeList: $('upgradeList'),
        selectChassis: $('selectChassisButton'),
        paintSwatches: $('paintSwatches'),
        volume: $('volumeRange'),
        quality: $('qualitySelect'),
        reducedMotion: $('reducedMotionCheck'),
        highContrast: $('highContrastCheck'),
        touchSetting: $('touchControlsCheck'),
        audio: $('audioButton'),
        resultsEyebrow: $('resultsEyebrow'),
        resultsTitle: $('resultsTitle'),
        resultsSubtitle: $('resultsSubtitle'),
        resultsTable: $('resultsTable'),
        rewardSummary: $('rewardSummary'),
        resultsPrimary: $('resultsPrimaryButton'),
        hudPosition: $('hudPosition'),
        hudPositionSuffix: $('hudPositionSuffix'),
        hudRacers: $('hudRacers'),
        hudLap: $('hudLap'),
        hudLaps: $('hudLaps'),
        hudSpeed: $('hudSpeed'),
        hudItem: $('hudItem'),
        itemSlot: $('itemSlot'),
        armorBar: $('armorBar'),
        armorValue: $('armorValue'),
        heatBar: $('heatBar'),
        heatValue: $('heatValue'),
        raceMessage: $('raceMessage'),
        bestTimeHud: $('bestTimeHud'),
        bestTimeValue: $('bestTimeValue'),
      };
    }

    bind() {
      document.addEventListener('click', (event) => {
        const action = event.target.closest('[data-action]')?.dataset.action;
        if (!action) return;
        MO.Audio.ensure?.();
        MO.Audio.sfx?.(action === 'back-main' ? 'back' : 'ui');
        this.handleAction(action);
      });

      this.elements.launch.addEventListener('click', () => this.launchRace());
      this.elements.homeButton.addEventListener('click', () => this.show('main'));
      this.elements.selectChassis.addEventListener('click', () => this.selectGarageChassis());
      this.elements.audio.addEventListener('click', () => {
        MO.Audio.ensure?.();
        const muted = MO.Audio.toggleMute?.();
        this.elements.audio.textContent = muted ? '♩' : '♫';
        this.elements.audio.setAttribute('aria-label', muted ? 'Réactiver le son' : 'Couper le son');
      });

      this.elements.difficulty.addEventListener('change', () => MO.Audio.sfx?.('ui'));
      this.elements.laps.addEventListener('change', () => MO.Audio.sfx?.('ui'));
      this.elements.volume.addEventListener('input', () => this.saveSettings({ volume: Number(this.elements.volume.value) }));
      this.elements.quality.addEventListener('change', () => this.saveSettings({ quality: this.elements.quality.value }));
      this.elements.reducedMotion.addEventListener('change', () => this.saveSettings({ reducedMotion: this.elements.reducedMotion.checked }));
      this.elements.highContrast.addEventListener('change', () => this.saveSettings({ highContrast: this.elements.highContrast.checked }));
      this.elements.touchSetting.addEventListener('change', () => this.saveSettings({ forceTouch: this.elements.touchSetting.checked }));

      $('resetSaveButton').addEventListener('click', () => {
        if (!window.confirm('Réinitialiser définitivement les crédits, améliorations, peintures et records ?')) return;
        this.store.reset();
        this.garageChassisId = this.store.get().selectedChassis;
        this.applySettings(this.store.get().settings);
        this.refreshAll();
        this.toast('PROGRESSION RÉINITIALISÉE', 'warning');
        MO.Audio.sfx?.('back');
      });

      $('resumeButton').addEventListener('click', () => this.game.resume());
      $('restartButton').addEventListener('click', () => {
        this.elements.pauseOverlay.classList.add('hidden');
        this.game.restart();
      });
      $('quitRaceButton').addEventListener('click', () => this.game.quit());
      this.elements.resultsPrimary.addEventListener('click', () => this.handleResultsPrimary());

      document.addEventListener('keydown', (event) => {
        if (event.code === 'Escape' && !this.game.active && this.currentScreen !== 'main' && this.currentScreen !== 'results') {
          event.preventDefault();
          this.show('main');
        }
      });

      MO.Events.on('save:changed', () => this.refreshPersistentUI());
      MO.Events.on('settings:changed', (settings) => this.applySettings(settings));
      MO.Events.on('race:started', (payload) => this.onRaceStarted(payload));
      MO.Events.on('race:countdown', (payload) => this.onCountdown(payload));
      MO.Events.on('race:pause', ({ paused }) => this.onPause(paused));
      MO.Events.on('race:finished', (result) => this.showResults(result));
      MO.Events.on('race:quit', () => this.onRaceQuit());
      MO.Events.on('ui:toast', ({ text, type }) => this.toast(text, type));
    }

    handleAction(action) {
      if (action === 'quick-race') this.openMode('quick');
      else if (action === 'grand-prix') this.openMode('grand-prix');
      else if (action === 'time-trial') this.openMode('time-trial');
      else if (action === 'garage') this.show('garage');
      else if (action === 'help') this.show('help');
      else if (action === 'settings') this.show('settings');
      else if (action === 'back-main') this.show('main');
    }

    show(name) {
      this.currentScreen = name;
      for (const screen of this.elements.screens) screen.classList.toggle('active', screen.dataset.screen === name);
      const inRace = this.game.active;
      this.elements.hud.classList.toggle('hidden', !inRace);
      this.elements.pauseOverlay.classList.add('hidden');
      this.elements.homeButton.classList.toggle('hidden', name === 'main' || name === 'results' || inRace);
      if (!inRace) this.elements.touchControls.classList.add('hidden');

      if (name === 'main') this.renderMain();
      else if (name === 'mode') this.renderMode();
      else if (name === 'garage') this.renderGarage();
      else if (name === 'settings') this.renderSettings();
    }

    openMode(mode) {
      this.mode = mode;
      this.elements.launch.disabled = false;
      if (mode === 'grand-prix') {
        this.elements.modeEyebrow.textContent = 'CHAMPIONNAT // QUATRE MANCHES';
        this.elements.modeTitle.textContent = 'Grand Prix Circuit Zero';
        this.elements.launch.textContent = 'COMMENCER LE GRAND PRIX';
        this.elements.difficulty.disabled = false;
      } else if (mode === 'time-trial') {
        this.elements.modeEyebrow.textContent = 'TÉLÉMÉTRIE // SOLO';
        this.elements.modeTitle.textContent = 'Contre-la-montre';
        this.elements.launch.textContent = 'LANCER LE CHRONO';
        this.elements.difficulty.disabled = true;
      } else {
        this.elements.modeEyebrow.textContent = 'CONFIGURATION DE COURSE';
        this.elements.modeTitle.textContent = 'Course rapide';
        this.elements.launch.textContent = 'LANCER LA COURSE';
        this.elements.difficulty.disabled = false;
      }
      const track = D.getTrack(this.selectedTrackId);
      this.elements.laps.value = String(track.defaultLaps);
      this.show('mode');
    }

    launchRace() {
      this.elements.launch.disabled = true;
      window.setTimeout(() => { this.elements.launch.disabled = false; }, 450);
      this.game.start({
        mode: this.mode,
        trackId: this.selectedTrackId,
        difficulty: this.elements.difficulty.value,
        laps: Number(this.elements.laps.value),
        newChampionship: this.mode === 'grand-prix',
      });
    }

    renderMode() {
      const selected = this.store.get().selectedChassis;
      this.elements.configMechName.textContent = D.getChassis(selected).name;
      this.renderTrackCards();
    }

    renderTrackCards() {
      const save = this.store.get();
      this.elements.trackCards.replaceChildren();
      for (const track of D.TRACKS) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `track-card${track.id === this.selectedTrackId ? ' selected' : ''}`;
        button.style.setProperty('--track-a', U.rgba(track.palette.fog, 0.72));
        button.style.setProperty('--track-b', U.rgba(track.palette.glow, 0.38));
        const best = save.bestTimes[track.id];
        button.innerHTML = `
          <span class="eyebrow">${escapeHTML(track.region)}</span>
          <h4>${escapeHTML(track.name)}</h4>
          <p>${escapeHTML(track.description)}</p>
          <div class="track-meta">
            ${track.tags.map((tag) => `<span>${escapeHTML(tag)}</span>`).join('')}
            <span>${'◆'.repeat(track.difficulty)}${'◇'.repeat(5 - track.difficulty)}</span>
            <span>RECORD ${U.formatTime(best)}</span>
          </div>`;
        button.addEventListener('click', () => {
          this.selectedTrackId = track.id;
          this.elements.laps.value = String(track.defaultLaps);
          MO.Audio.sfx?.('ui');
          this.renderTrackCards();
        });
        this.elements.trackCards.appendChild(button);
      }
    }

    renderMain() {
      const save = this.store.get();
      const chassis = D.getChassis(save.selectedChassis);
      this.elements.pilotName.textContent = save.pilotName;
      this.elements.selectedClass.textContent = chassis.category;
      this.elements.selectedMech.textContent = chassis.name;
      this.elements.selectedTrait.textContent = chassis.subtitle;
    }

    renderGarage() {
      const save = this.store.get();
      if (!D.CHASSIS.some((entry) => entry.id === this.garageChassisId)) this.garageChassisId = save.selectedChassis;
      const chassis = D.getChassis(this.garageChassisId);
      const paint = save.paints[chassis.id] || chassis.paint;

      this.elements.chassisList.replaceChildren();
      for (const entry of D.CHASSIS) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = `chassis-card${entry.id === chassis.id ? ' selected' : ''}`;
        button.setAttribute('role', 'option');
        button.setAttribute('aria-selected', String(entry.id === chassis.id));
        button.innerHTML = `<span>${escapeHTML(entry.category)}</span><strong>${escapeHTML(entry.name)}</strong>`;
        button.addEventListener('click', () => {
          this.garageChassisId = entry.id;
          MO.Audio.sfx?.('ui');
          this.renderGarage();
        });
        this.elements.chassisList.appendChild(button);
      }

      this.elements.garageClass.textContent = `DIVISION ${chassis.category}`;
      this.elements.garageName.textContent = chassis.name;
      this.elements.garageDescription.textContent = chassis.description;
      this.elements.garageAbility.textContent = chassis.ability;
      this.elements.garageAbilityDescription.textContent = chassis.abilityDescription;
      this.elements.upgradeCredits.textContent = `${U.formatNumber(save.credits)} CR`;
      this.elements.selectChassis.textContent = save.selectedChassis === chassis.id ? 'CHÂSSIS ÉQUIPÉ' : 'ÉQUIPER CE CHÂSSIS';
      this.elements.selectChassis.disabled = save.selectedChassis === chassis.id;

      this.elements.garageStats.replaceChildren();
      const upgrade = save.upgrades[chassis.id];
      const effectiveStats = {
        ...chassis.stats,
        speed: chassis.stats.speed + (upgrade.engine || 0) * 3,
        acceleration: chassis.stats.acceleration + (upgrade.servos || 0) * 2,
        handling: chassis.stats.handling + (upgrade.servos || 0) * 3,
        armor: chassis.stats.armor + (upgrade.armor || 0) * 4,
        reactor: chassis.stats.reactor + (upgrade.reactor || 0) * 4,
      };
      for (const [key, label] of Object.entries(STAT_LABELS)) {
        const value = U.clamp(Math.round(effectiveStats[key]), 0, 100);
        const row = document.createElement('div');
        row.className = 'stat-row';
        row.innerHTML = `<span>${label}</span><div class="stat-meter"><i style="width:${value}%"></i></div><strong>${value}</strong>`;
        this.elements.garageStats.appendChild(row);
      }

      this.elements.paintSwatches.replaceChildren();
      for (const color of D.PAINTS) {
        const swatch = document.createElement('button');
        swatch.type = 'button';
        swatch.className = `paint-swatch${paint.toLowerCase() === color.toLowerCase() ? ' selected' : ''}`;
        swatch.style.background = color;
        swatch.setAttribute('aria-label', `Peinture ${color}`);
        swatch.addEventListener('click', () => {
          this.store.setPaint(chassis.id, color);
          MO.Audio.sfx?.('ui');
          this.renderGarage();
          this.renderMain();
        });
        this.elements.paintSwatches.appendChild(swatch);
      }

      this.elements.upgradeList.replaceChildren();
      for (const upgradeData of Object.values(D.UPGRADES)) {
        const level = save.upgrades[chassis.id][upgradeData.id] || 0;
        const maximum = level >= upgradeData.costs.length;
        const cost = maximum ? null : upgradeData.costs[level];
        const row = document.createElement('div');
        row.className = 'upgrade-row';
        const info = document.createElement('div');
        info.innerHTML = `<strong>${escapeHTML(upgradeData.name)}<span class="upgrade-pips">${Array.from({ length: 4 }, (_, index) => `<i class="${index < level ? 'on' : ''}"></i>`).join('')}</span></strong><small>${escapeHTML(upgradeData.description)} · NIV. ${level}/4</small>`;
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'upgrade-button';
        button.disabled = maximum;
        button.textContent = maximum ? 'MAX' : `${U.formatNumber(cost)} CR`;
        button.addEventListener('click', () => this.buyUpgrade(chassis.id, upgradeData.id));
        row.append(info, button);
        this.elements.upgradeList.appendChild(row);
      }
    }

    buyUpgrade(chassisId, upgradeId) {
      const result = this.store.buyUpgrade(chassisId, upgradeId);
      if (!result.ok) {
        MO.Audio.sfx?.('error');
        this.toast(result.reason === 'credits' ? `CRÉDITS INSUFFISANTS — ${U.formatNumber(result.cost)} CR` : 'AMÉLIORATION AU MAXIMUM', 'warning');
        return;
      }
      MO.Audio.sfx?.('purchase');
      this.toast(`AMÉLIORATION INSTALLÉE — NIV. ${result.level}`, 'reward');
      this.renderGarage();
    }

    selectGarageChassis() {
      const chassis = D.getChassis(this.garageChassisId);
      if (!this.store.selectChassis(chassis.id)) return;
      MO.Audio.sfx?.('purchase');
      this.toast(`${chassis.name.toUpperCase()} ÉQUIPÉ`, 'reward');
      this.renderGarage();
      this.renderMain();
    }

    renderSettings() {
      const settings = this.store.get().settings;
      this.elements.volume.value = String(settings.volume);
      this.elements.quality.value = settings.quality;
      this.elements.reducedMotion.checked = settings.reducedMotion;
      this.elements.highContrast.checked = settings.highContrast;
      this.elements.touchSetting.checked = settings.forceTouch;
    }

    saveSettings(patch) {
      this.store.updateSettings(patch);
      const settings = this.store.get().settings;
      MO.Audio.setVolume?.(settings.volume);
      MO.Events.emit('settings:changed', settings);
    }

    applySettings(settings) {
      document.body.classList.toggle('reduce-motion', !!settings.reducedMotion);
      document.body.classList.toggle('high-contrast', !!settings.highContrast);
      MO.Audio.setVolume?.(settings.volume);
      if (this.currentScreen === 'settings') this.renderSettings();
      if (this.game.active) this.updateTouchVisibility();
    }

    refreshPersistentUI() {
      const save = this.store.get();
      this.elements.credits.textContent = U.formatNumber(save.credits);
      this.elements.upgradeCredits.textContent = `${U.formatNumber(save.credits)} CR`;
      this.renderMain();
      if (this.currentScreen === 'mode') this.renderMode();
    }

    refreshAll() {
      this.refreshPersistentUI();
      this.renderSettings();
      if (this.currentScreen === 'garage') this.renderGarage();
    }

    onRaceStarted() {
      for (const screen of this.elements.screens) screen.classList.remove('active');
      this.currentScreen = 'race';
      this.elements.hud.classList.remove('hidden');
      this.elements.pauseOverlay.classList.add('hidden');
      this.elements.homeButton.classList.add('hidden');
      this.updateTouchVisibility();
      this.updateHUD();
    }

    updateTouchVisibility() {
      const settings = this.store.get().settings;
      const visible = this.game.active && (settings.forceTouch || MO.Input.isTouchDevice?.());
      this.elements.touchControls.classList.toggle('hidden', !visible);
      this.elements.touchControls.setAttribute('aria-hidden', String(!visible));
    }

    onCountdown(payload) {
      window.clearTimeout(this.countdownTimer);
      this.elements.countdown.textContent = payload.value;
      this.elements.countdown.classList.remove('hidden', 'go');
      if (payload.go) {
        this.elements.countdown.classList.add('go');
        this.countdownTimer = window.setTimeout(() => this.elements.countdown.classList.add('hidden'), 720);
      }
    }

    onPause(paused) {
      this.elements.pauseOverlay.classList.toggle('hidden', !paused);
      if (paused) this.elements.touchControls.classList.add('hidden');
      else this.updateTouchVisibility();
    }

    onRaceQuit() {
      this.elements.hud.classList.add('hidden');
      this.elements.touchControls.classList.add('hidden');
      this.elements.pauseOverlay.classList.add('hidden');
      this.elements.countdown.classList.add('hidden');
      this.show('main');
    }

    updateHUD() {
      const player = this.game.player;
      if (!this.game.active || !player) return;
      const armorPercent = U.clamp(player.armor / Math.max(1, player.maxArmor) * 100, 0, 100);
      const item = D.getItem(player.item);
      this.elements.hudPosition.textContent = String(player.position);
      this.elements.hudPositionSuffix.textContent = U.ordinalSuffix(player.position);
      this.elements.hudRacers.textContent = String(this.game.racers.length);
      this.elements.hudLap.textContent = String(player.lap);
      this.elements.hudLaps.textContent = String(this.game.laps);
      this.elements.hudSpeed.textContent = String(U.clamp(this.game.speedKmh, 0, 999)).padStart(3, '0');
      this.elements.hudItem.textContent = item ? `${item.icon} ${item.short}` : '—';
      this.elements.itemSlot.classList.toggle('ready', !!item);
      this.elements.armorBar.style.width = `${armorPercent}%`;
      this.elements.armorValue.textContent = String(Math.round(player.armor));
      this.elements.heatBar.style.width = `${U.clamp(player.heat, 0, 100)}%`;
      this.elements.heatValue.textContent = `${Math.round(player.heat)}%`;

      let message = '';
      if (this.game.paused) message = 'COURSE SUSPENDUE';
      else if (player.overheated) message = 'RÉACTEUR VERROUILLÉ';
      else if (player.respawnTimer > 0) message = 'RECONSTRUCTION DE L’UNITÉ';
      else if (player.drifting) message = `DÉRIVE ${Math.round(player.driftCharge * 100)}%`;
      else if (player.boostActive) message = 'SURCHARGE RÉACTEUR';
      else if (player.overdriveTimer > 0) message = 'OVERDRIVE ACTIF';
      else if (player.offroad) message = 'HORS-PISTE';
      this.elements.raceMessage.textContent = message;

      const best = this.store.get().bestTimes[this.game.track.id];
      this.elements.bestTimeHud.classList.toggle('hidden', !best);
      this.elements.bestTimeValue.textContent = U.formatTime(best);
    }

    showResults(result) {
      this.lastResult = result;
      this.elements.hud.classList.add('hidden');
      this.elements.touchControls.classList.add('hidden');
      this.elements.pauseOverlay.classList.add('hidden');
      this.elements.countdown.classList.add('hidden');
      this.renderResults(result);
      this.show('results');
    }

    renderResults(result) {
      const championship = result.championship;
      let rows = result.rows;
      if (championship?.final) {
        rows = championship.standings.map((entry, index) => ({
          ...entry,
          position: index + 1,
          time: null,
          points: entry.points,
        }));
        this.elements.resultsEyebrow.textContent = championship.won ? 'CHAMPION DU CIRCUIT ZERO' : 'GRAND PRIX TERMINÉ';
        this.elements.resultsTitle.textContent = championship.won ? 'VICTOIRE' : 'CLASSEMENT FINAL';
        this.elements.resultsSubtitle.textContent = championship.won
          ? `Le pilote ${this.store.get().pilotName} remporte le championnat des architectures.`
          : `Champion : ${championship.standings[0]?.callsign || championship.standings[0]?.name}. Votre place : ${rows.find((row) => row.isPlayer)?.position || '—'}e.`;
      } else if (championship) {
        this.elements.resultsEyebrow.textContent = `MANCHE ${championship.round}/${championship.totalRounds}`;
        this.elements.resultsTitle.textContent = result.position === 1 ? 'VICTOIRE' : `${result.position}${U.ordinalSuffix(result.position)} PLACE`;
        const next = D.getTrack(championship.nextTrackId);
        this.elements.resultsSubtitle.textContent = `Meilleur tour ${U.formatTime(result.bestLap)} · prochaine manche : ${next.name}.`;
      } else {
        this.elements.resultsEyebrow.textContent = this.mode === 'time-trial' ? 'CHRONO VALIDÉ' : 'COURSE TERMINÉE';
        this.elements.resultsTitle.textContent = result.position === 1 ? 'VICTOIRE' : `${result.position}${U.ordinalSuffix(result.position)} PLACE`;
        this.elements.resultsSubtitle.textContent = `${result.track.name} · ${U.formatTime(result.raceTime)} · meilleur tour ${U.formatTime(result.bestLap)}${result.newBest ? ' · NOUVEAU RECORD' : ''}.`;
      }

      this.elements.resultsTable.replaceChildren();
      for (const row of rows) {
        const entry = document.createElement('div');
        entry.className = `result-row${row.isPlayer ? ' player' : ''}`;
        const timeLabel = row.time == null ? row.chassisName : U.formatTime(row.time);
        const pointLabel = championship?.final ? `${row.points} PTS` : row.points != null ? `+${row.points} PTS` : U.formatTime(row.bestLap);
        entry.innerHTML = `
          <div class="result-rank">${row.position}</div>
          <div class="result-name"><strong>${escapeHTML(row.callsign || row.name)}</strong><small>${escapeHTML(row.chassisName || D.getChassis(row.chassisId).name)}</small></div>
          <div class="result-time">${escapeHTML(timeLabel || '—')}</div>
          <div class="result-points">${escapeHTML(pointLabel || '')}</div>`;
        this.elements.resultsTable.appendChild(entry);
      }

      const breakdown = result.rewardBreakdown;
      this.elements.rewardSummary.innerHTML = `
        <div><span>RÉCOMPENSE</span><strong>+${U.formatNumber(result.reward)} CR</strong></div>
        <div><span>MEILLEUR TOUR</span><strong>${U.formatTime(result.bestLap)}</strong></div>
        <div><span>MAÎTRISE</span><strong>${result.cleanRace ? 'PROPRE' : `${this.game.player?.stats.impacts || 0} IMPACTS`}</strong></div>
        ${result.newBest ? '<div><span>BONUS</span><strong>NOUVEAU RECORD</strong></div>' : ''}
        ${breakdown.championnat ? `<div><span>CHAMPIONNAT</span><strong>+${U.formatNumber(breakdown.championnat)} CR</strong></div>` : ''}`;

      if (championship && !championship.final) this.elements.resultsPrimary.textContent = 'MANCHE SUIVANTE';
      else if (championship?.final) this.elements.resultsPrimary.textContent = 'NOUVEAU GRAND PRIX';
      else this.elements.resultsPrimary.textContent = this.mode === 'time-trial' ? 'RELANCER LE CHRONO' : 'REJOUER';
    }

    handleResultsPrimary() {
      if (!this.lastResult) return;
      const championship = this.lastResult.championship;
      if (championship && !championship.final) this.game.startNextChampionshipRound();
      else if (championship?.final) this.game.startNewChampionship();
      else this.game.replayLast();
    }

    toast(text, type = '') {
      if (!text) return;
      const node = document.createElement('div');
      node.className = `toast${type ? ` ${type}` : ''}`;
      node.textContent = text;
      $('toastStack').appendChild(node);
      window.setTimeout(() => node.remove(), 2800);
    }

    animate(timeSeconds) {
      const save = this.store.get();
      const selected = D.getChassis(save.selectedChassis);
      this.renderer.renderGarage(this.featuredCanvas, selected, save.paints[selected.id] || selected.paint, timeSeconds, true);
      if (this.currentScreen === 'garage') {
        const chassis = D.getChassis(this.garageChassisId);
        this.renderer.renderGarage(this.elements.garageCanvas, chassis, save.paints[chassis.id] || chassis.paint, timeSeconds, false);
      }
    }
  }

  MO.UI = UI;
})(window.MO = window.MO || {});
