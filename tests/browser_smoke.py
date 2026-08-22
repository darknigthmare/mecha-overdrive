#!/usr/bin/env python3
"""Test navigateur de bout en bout pour MECHA OVERDRIVE.

Dépendance facultative: pip install playwright, avec Chromium disponible.
Le test injecte les fichiers locaux dans une page afin de rester autonome.
"""
from __future__ import annotations

import asyncio
import json
import re
import shutil
import sys
from pathlib import Path

from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]
ORDER = [
    "core.js", "data.js", "storage.js", "audio.js", "input.js",
    "track.js", "renderer.js", "game.js", "ui.js", "main.js",
]


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


async def main() -> None:
    errors: list[str] = []
    warnings: list[str] = []
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    html = re.sub(r'<link[^>]+rel="stylesheet"[^>]*>', "", html)
    html = re.sub(r'<script[^>]+src="[^"]+"[^>]*></script>', "", html)
    html = re.sub(r'<link[^>]+rel="manifest"[^>]*>', "", html)
    html = re.sub(r'<link[^>]+rel="icon"[^>]*>', "", html)

    async with async_playwright() as playwright:
        launch_options = {
            "headless": True,
            "args": ["--no-sandbox", "--disable-gpu", "--mute-audio"],
        }
        system_chromium = Path("/usr/bin/chromium")
        if system_chromium.exists():
            launch_options["executable_path"] = str(system_chromium)
        browser = await playwright.chromium.launch(**launch_options)
        page = await browser.new_page(
            viewport={"width": 1440, "height": 900},
            device_scale_factor=1,
        )
        page.set_default_timeout(8_000)
        page.on("pageerror", lambda error: errors.append(f"PAGEERROR: {error}"))

        def on_console(message) -> None:
            if message.type == "error":
                errors.append(f"CONSOLE ERROR: {message.text}")
            elif message.type == "warning":
                warnings.append(f"CONSOLE WARNING: {message.text}")

        page.on("console", on_console)

        try:
            await page.set_content(html, wait_until="domcontentloaded")
            await page.add_style_tag(path=str(ROOT / "styles.css"))
            for name in ORDER:
                await page.add_script_tag(path=str(ROOT / "js" / name))
            await page.wait_for_function("window.MO && MO.app && MO.app.game && MO.app.ui")

            boot = await page.evaluate(
                "({version:MO.app.version,screen:MO.app.ui.currentScreen,"
                "chassis:MO.Data.CHASSIS.length,tracks:MO.Data.TRACKS.length,"
                "items:MO.Data.ITEMS.length})"
            )
            check(boot["screen"] == "main", "Le menu principal ne s'affiche pas.")
            check(boot["chassis"] == 8, "Le jeu doit contenir huit architectures.")
            check(boot["tracks"] == 4, "Le jeu doit contenir quatre circuits.")
            check(boot["items"] == 8, "Le jeu doit contenir huit objets.")
            print("BOOT", json.dumps(boot, ensure_ascii=False))
            await page.wait_for_timeout(300)
            await page.screenshot(path=str(ROOT / "media" / "preview-menu.png"))

            await page.click('[data-action="garage"]')
            await page.wait_for_timeout(250)
            garage = await page.evaluate(
                "({screen:MO.app.ui.currentScreen,"
                "cards:document.querySelectorAll('.chassis-card').length,"
                "upgrades:document.querySelectorAll('.upgrade-row').length,"
                "swatches:document.querySelectorAll('.paint-swatch').length})"
            )
            check(garage == {"screen": "garage", "cards": 8, "upgrades": 4, "swatches": 8},
                  "Le garage est incomplet.")
            print("GARAGE", json.dumps(garage, ensure_ascii=False))
            await page.click(".chassis-card:nth-child(8)")
            await page.wait_for_timeout(180)
            await page.screenshot(path=str(ROOT / "media" / "preview-garage.png"))
            await page.locator('.screen.active [data-action="back-main"]').click()

            await page.click('[data-action="quick-race"]')
            await page.wait_for_timeout(180)
            mode = await page.evaluate(
                "({screen:MO.app.ui.currentScreen,cards:document.querySelectorAll('.track-card').length})"
            )
            check(mode["screen"] == "mode" and mode["cards"] == 4, "La configuration de course est incomplète.")
            print("MODE", json.dumps(mode, ensure_ascii=False))
            await page.click(".track-card:nth-child(2)")
            await page.select_option("#difficultySelect", "pilot")
            await page.select_option("#lapsSelect", "1")
            await page.screenshot(path=str(ROOT / "media" / "preview-mode.png"))
            await page.click("#launchRaceButton")
            await page.keyboard.down("ArrowUp")
            await page.wait_for_timeout(3_850)

            racing = await page.evaluate(
                "({screen:MO.app.ui.currentScreen,state:MO.app.game.state,"
                "racers:MO.app.game.racers.length,track:MO.app.game.track.spec.id,"
                "speed:Math.round(MO.app.game.player.speed),"
                "distance:Math.round(MO.app.game.player.distance)})"
            )
            check(racing["screen"] == "race", "L'écran de course n'est pas actif.")
            check(racing["state"] == "racing", "La course n'a pas quitté le compte à rebours.")
            check(racing["racers"] == 8, "La course rapide doit avoir huit concurrents.")
            check(racing["speed"] > 0 and racing["distance"] > -1295, "Le véhicule n'avance pas.")
            print("RACING", json.dumps(racing, ensure_ascii=False))

            await page.evaluate("MO.app.game.player.item='overdrive'")
            await page.keyboard.press("Space")
            await page.wait_for_timeout(120)
            item = await page.evaluate(
                "({item:MO.app.game.player.item,overdrive:MO.app.game.player.overdriveTimer,"
                "used:MO.app.game.player.stats.itemsUsed})"
            )
            check(item["item"] is None and item["overdrive"] > 0 and item["used"] >= 1,
                  "L'utilisation des objets ne fonctionne pas.")
            print("ITEM", json.dumps(item, ensure_ascii=False))

            await page.keyboard.press("Escape")
            await page.wait_for_timeout(120)
            pause = await page.evaluate(
                "({paused:MO.app.game.paused,overlay:!document.querySelector('#pauseOverlay').classList.contains('hidden')})"
            )
            check(pause["paused"] and pause["overlay"], "La pause ne s'affiche pas.")
            await page.click("#resumeButton")
            await page.wait_for_timeout(120)
            resume = await page.evaluate(
                "({paused:MO.app.game.paused,overlay:!document.querySelector('#pauseOverlay').classList.contains('hidden')})"
            )
            check(not resume["paused"] and not resume["overlay"], "La reprise ne fonctionne pas.")
            print("PAUSE_RESUME", json.dumps({"pause": pause, "resume": resume}, ensure_ascii=False))
            await page.screenshot(path=str(ROOT / "media" / "preview-race.png"))

            # Place le joueur au-delà de l'arrivée, puis laisse la boucle normale conclure la course.
            await page.evaluate(
                """() => {
                  const g = MO.app.game;
                  g.raceTime = 74.382;
                  g.player.lapStartTime = 0;
                  g.player.distance = g.finishDistance + 20;
                  g.player.speed = Math.max(2500, g.player.topSpeed * 0.72);
                  g.player.x = 0;
                }"""
            )
            await page.wait_for_timeout(320)
            await page.keyboard.up("ArrowUp")
            await page.wait_for_timeout(200)
            result = await page.evaluate(
                "({active:MO.app.game.active,state:MO.app.game.state,"
                "screen:MO.app.ui.currentScreen,hasResult:!!MO.app.game.lastResult,"
                "position:MO.app.game.lastResult?.position,reward:MO.app.game.lastResult?.reward})"
            )
            check(not result["active"] and result["state"] == "finished", "La course ne se termine pas.")
            check(result["screen"] == "results" and result["hasResult"], "L'écran de résultats ne s'affiche pas.")
            check(isinstance(result["reward"], (int, float)) and result["reward"] >= 0,
                  "La récompense de course est invalide.")
            print("RESULT", json.dumps(result, ensure_ascii=False))
            await page.wait_for_timeout(2_650)
            await page.screenshot(path=str(ROOT / "media" / "preview-results.png"))

            await page.locator('.screen.active [data-action="back-main"]').click()
            await page.click('[data-action="time-trial"]')
            await page.select_option("#lapsSelect", "1")
            await page.click("#launchRaceButton")
            await page.wait_for_timeout(160)
            trial = await page.evaluate(
                "({mode:MO.app.game.mode,racers:MO.app.game.racers.length,state:MO.app.game.state})"
            )
            check(trial["mode"] == "time-trial" and trial["racers"] == 1,
                  "Le contre-la-montre doit être solo.")
            print("TIME_TRIAL", json.dumps(trial, ensure_ascii=False))
            await page.evaluate("MO.app.game.quit()")

            grand_prix = await page.evaluate(
                """() => {
                  const g = MO.app.game;
                  g.start({mode:'grand-prix',trackId:'foundry',difficulty:'pilot',laps:1,newChampionship:true});
                  return {
                    mode:g.mode,
                    racers:g.racers.length,
                    rounds:g.championship.tracks.length,
                    round:g.championship.round,
                  };
                }"""
            )
            check(grand_prix == {"mode": "grand-prix", "racers": 8, "rounds": 4, "round": 0},
                  "Le Grand Prix n'est pas correctement initialisé.")
            print("GRAND_PRIX", json.dumps(grand_prix, ensure_ascii=False))

            check(not errors, "Des erreurs JavaScript ont été détectées.")
        finally:
            await browser.close()

    print("WARNINGS", json.dumps(warnings, ensure_ascii=False))
    print("ERRORS", json.dumps(errors, ensure_ascii=False))


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as error:  # pragma: no cover - retour CLI lisible
        print(f"ÉCHEC QA: {error}", file=sys.stderr)
        sys.exit(1)
