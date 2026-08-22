(function (MO) {
  'use strict';

  function boot() {
    const canvas = document.getElementById('gameCanvas');
    const minimap = document.getElementById('minimapCanvas');
    if (!canvas || !minimap) throw new Error('Canvas principal introuvable.');

    const renderer = new MO.GameRenderer(canvas, minimap);
    const game = new MO.Game({ input: MO.Input, audio: MO.Audio, store: MO.Storage });
    const ui = new MO.UI(renderer, game);
    let previous = performance.now();

    function frame(now) {
      const dt = MO.Util.clamp((now - previous) / 1000, 0, 0.05);
      previous = now;

      game.update(dt);
      if (game.active && game.player && game.track) {
        renderer.render(game, game.paused ? 0 : dt);
        ui.updateHUD();
        const player = game.player;
        MO.Audio.updateEngine?.(
          player.speed / Math.max(1, player.topSpeed),
          player.boostActive || player.overdriveTimer > 0 || player.padBoostTimer > 0 ? 1 : 0,
          1 - player.armor / Math.max(1, player.maxArmor),
          !game.paused,
        );
      } else {
        renderer.renderIdle(dt);
        MO.Audio.updateEngine?.(0, 0, 0, false);
      }
      ui.animate(now / 1000);
      requestAnimationFrame(frame);
    }

    document.addEventListener('visibilitychange', () => {
      if (document.hidden && game.active && !game.paused) game.togglePause();
    });

    window.addEventListener('contextmenu', (event) => {
      if (event.target.closest('#gameCanvas, .touch-controls')) event.preventDefault();
    });

    window.addEventListener('error', (event) => {
      console.error('[MECHA OVERDRIVE] Erreur non interceptée', event.error || event.message);
      MO.Events.emit('ui:toast', { text: 'ANOMALIE SYSTÈME — CONSULTEZ LA CONSOLE', type: 'warning' });
    });

    window.addEventListener('unhandledrejection', (event) => {
      console.error('[MECHA OVERDRIVE] Promesse rejetée', event.reason);
      MO.Events.emit('ui:toast', { text: 'ANOMALIE SYSTÈME — CONSULTEZ LA CONSOLE', type: 'warning' });
    });

    MO.app = { renderer, game, ui, version: MO.VERSION };
    requestAnimationFrame(frame);

    if ('serviceWorker' in navigator && /^https?:$/.test(location.protocol)) {
      navigator.serviceWorker.register('./service-worker.js').catch((error) => {
        console.warn('[MECHA OVERDRIVE] Service worker non disponible', error);
      });
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
  else boot();
})(window.MO = window.MO || {});
