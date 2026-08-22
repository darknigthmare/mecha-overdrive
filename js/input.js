(function (MO) {
  'use strict';

  const { clamp } = MO.Util;

  class Input {
    constructor() {
      this.keys = new Set();
      this.pressed = new Set();
      this.touch = {};
      this.previousGamepadButtons = [];
      this.gamepadPressed = new Set();
      addEventListener('keydown', (event) => {
        if (!this.keys.has(event.code)) this.pressed.add(event.code);
        this.keys.add(event.code);
        if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(event.code)) event.preventDefault();
      }, { passive: false });
      addEventListener('keyup', (event) => this.keys.delete(event.code));
      addEventListener('blur', () => this.reset());
      document.querySelectorAll('[data-touch]').forEach((button) => {
        const action = button.dataset.touch;
        const set = (value) => {
          this.touch[action] = value;
          button.classList.toggle('active', value);
        };
        button.addEventListener('pointerdown', (event) => {
          event.preventDefault();
          button.setPointerCapture?.(event.pointerId);
          if (!this.touch[action]) this.pressed.add(`touch:${action}`);
          set(true);
        });
        const release = (event) => {
          if (event?.pointerId != null && button.hasPointerCapture?.(event.pointerId)) button.releasePointerCapture(event.pointerId);
          set(false);
        };
        button.addEventListener('pointerup', release);
        button.addEventListener('pointercancel', release);
        button.addEventListener('lostpointercapture', () => set(false));
      });
    }

    reset() {
      this.keys.clear();
      this.pressed.clear();
      this.gamepadPressed.clear();
      for (const key in this.touch) this.touch[key] = false;
    }

    down(...codes) { return codes.some((code) => this.keys.has(code)); }

    consume(...codes) {
      for (const code of codes) {
        if (this.pressed.has(code)) {
          this.pressed.delete(code);
          return true;
        }
      }
      return false;
    }

    pollGamepad() {
      const gamepad = Array.from(navigator.getGamepads?.() || []).find(Boolean);
      this.gamepadPressed.clear();
      if (!gamepad) {
        this.previousGamepadButtons = [];
        return null;
      }
      gamepad.buttons.forEach((button, index) => {
        const down = button.pressed || button.value > 0.55;
        if (down && !this.previousGamepadButtons[index]) this.gamepadPressed.add(index);
        this.previousGamepadButtons[index] = down;
      });
      return gamepad;
    }

    frame() {
      const gamepad = this.pollGamepad();
      const keyboardSteer = (this.down('ArrowRight', 'KeyD') || this.touch.right ? 1 : 0)
        - (this.down('ArrowLeft', 'KeyA', 'KeyQ') || this.touch.left ? 1 : 0);
      const padSteer = gamepad && Math.abs(gamepad.axes[0]) > 0.12 ? gamepad.axes[0] : 0;
      return {
        steer: clamp(Math.abs(padSteer) > Math.abs(keyboardSteer) ? padSteer : keyboardSteer, -1, 1),
        accelerate: this.down('ArrowUp', 'KeyW', 'KeyZ') || !!this.touch.accelerate || !!(gamepad && gamepad.buttons[7]?.value > 0.16),
        brake: this.down('ArrowDown', 'KeyS') || !!this.touch.brake || !!(gamepad && gamepad.buttons[6]?.value > 0.16),
        boost: this.down('ShiftLeft', 'ShiftRight', 'KeyX') || !!this.touch.boost || !!(gamepad && gamepad.buttons[2]?.pressed),
        drift: this.down('ControlLeft', 'ControlRight', 'KeyC') || !!this.touch.drift || !!(gamepad && gamepad.buttons[1]?.pressed),
        itemPressed: this.consume('Space', 'KeyE', 'Enter', 'touch:item') || this.gamepadPressed.has(0),
        pausePressed: this.consume('Escape', 'KeyP', 'touch:pause') || this.gamepadPressed.has(9),
        resetPressed: this.consume('KeyR', 'touch:reset') || this.gamepadPressed.has(8),
      };
    }

    endFrame() { this.pressed.clear(); }
    isTouchDevice() { return matchMedia?.('(pointer: coarse)').matches || navigator.maxTouchPoints > 0; }
  }

  MO.Input = new Input();
})(window.MO = window.MO || {});
