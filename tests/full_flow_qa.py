#!/usr/bin/env python3
"""QA approfondie de MECHA OVERDRIVE — Circuit Zero.

Ce scénario facultatif nécessite Playwright pour Python et un navigateur Chromium.
Il valide les trois modes, les quatre manches du Grand Prix, le garage,
les paramètres, les objets, la pause et les commandes tactiles.
"""
from __future__ import annotations

import asyncio
import json
import re
import sys
from pathlib import Path
from typing import Any

from playwright.async_api import Browser, Page, async_playwright

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = [
    "core.js",
    "data.js",
    "storage.js",
    "audio.js",
    "input.js",
    "track.js",
    "renderer.js",
    "game.js",
    "ui.js",
    "main.js",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


async def inject_application(page: Page) -> None:
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    html = re.sub(r'<link[^>]+rel="stylesheet"[^>]*>', "", html)
    html = re.sub(r'<script[^>]+src="[^"]+"[^>]*></script>', "", html)
    html = re.sub(r'<link[^>]+rel="manifest"[^>]*>', "", html)
    html = re.sub(r'<link[^>]+rel="icon"[^>]*>', "", html)
    await page.set_content(html, wait_until="domcontentloaded")
    await page.add_style_tag(path=str(ROOT / "styles.css"))
    for script in SCRIPTS:
        await page.add_script_tag(path=str(ROOT / "js" / script))
    await page.wait_for_function("() => !!window.MO?.app?.game && !!window.MO?.app?.ui")
    await page.wait_for_timeout(180)


async def finish_current_race(page: Page, seconds: float) -> None:
    await page.evaluate(
        """(seconds) => {
          const game = MO.app.game;
          const player = game.player;
          game.state = 'racing';
          game.countdown = 0;
          game.raceTime = seconds;
          player.distance = game.finishDistance + 10;
          player.progress = Math.max(player.progress, game.finishDistance + 10);
          player.speed = player.topSpeed;
          player.completedLaps = game.laps;
          player.lap = game.laps;
          player.lapTimes = Array.from(
            { length: game.laps },
            (_, index) => seconds / game.laps + index * 0.02,
          );
          player.bestLap = Math.min(...player.lapTimes);
          player.finished = true;
          player.finishTime = seconds;
          game.completeRace();
        }""",
        seconds,
    )
    await page.wait_for_function("() => MO.app.ui.currentScreen === 'results'")


async def desktop_suite(browser: Browser) -> dict[str, Any]:
    context = await browser.new_context(viewport={"width": 1440, "height": 900})
    page = await context.new_page()
    page_errors: list[str] = []
    console_errors: list[str] = []
    page.on("pageerror", lambda error: page_errors.append(str(error)))
    page.on(
        "console",
        lambda message: console_errors.append(message.text)
        if message.type == "error"
        else None,
    )
    await inject_application(page)

    report: dict[str, Any] = {
        "boot": await page.evaluate(
            "({screen:MO.app.ui.currentScreen,version:MO.app.version,"
            "chassis:MO.Data.CHASSIS.length,tracks:MO.Data.TRACKS.length,"
            "items:MO.Data.ITEMS.length})"
        )
    }
    require(report["boot"]["screen"] == "main", "Le menu principal ne s'affiche pas.")
    require(report["boot"]["chassis"] == 8, "Le catalogue des châssis est incomplet.")

    # Garage et persistance.
    await page.click('[data-action="garage"]')
    require(await page.locator("#chassisList button").count() == 8, "Le garage doit contenir huit châssis.")
    await page.locator("#chassisList button").nth(3).click()
    garage_name = await page.locator("#garageName").inner_text()
    await page.click("#selectChassisButton")
    selected_id = await page.evaluate("MO.Storage.get().selectedChassis")
    require(selected_id == "hexapod", "Le châssis choisi n'a pas été sauvegardé.")
    report["garage"] = {"name": garage_name, "selected": selected_id}

    # Paramètres et application immédiate.
    await page.locator('.screen.active [data-action="back-main"]').click()
    await page.click('[data-action="settings"]')
    await page.check("#highContrastCheck")
    await page.check("#touchControlsCheck")
    await page.select_option("#qualitySelect", "high")
    await page.locator("#volumeRange").evaluate(
        "element => { element.value='0.35'; element.dispatchEvent(new Event('input',{bubbles:true})); }"
    )
    settings = await page.evaluate("MO.Storage.get().settings")
    require(settings["highContrast"] is True, "Le contraste renforcé n'est pas sauvegardé.")
    require(
        await page.evaluate("document.body.classList.contains('high-contrast')"),
        "Le contraste renforcé n'est pas appliqué.",
    )
    report["settings"] = settings

    # Course rapide.
    await page.locator('.screen.active [data-action="back-main"]').click()
    await page.click('[data-action="quick-race"]')
    await page.select_option("#difficultySelect", "ace")
    await page.select_option("#lapsSelect", "1")
    await page.click("#launchRaceButton")
    await page.wait_for_function("() => MO.app.game.active && MO.app.game.racers.length === 8")
    await page.evaluate(
        "MO.app.game.state='racing'; MO.app.game.countdown=0; "
        "MO.app.game.player.item='overdrive'; MO.app.game.useItem(MO.app.game.player)"
    )
    object_state = await page.evaluate(
        "({used:MO.app.game.player.stats.itemsUsed,overdrive:MO.app.game.player.overdriveTimer})"
    )
    require(object_state["used"] == 1 and object_state["overdrive"] > 0, "L'Overdrive ne fonctionne pas.")
    await page.keyboard.press("Escape")
    await page.wait_for_timeout(80)
    require(await page.evaluate("MO.app.game.paused"), "La pause n'est pas active.")
    require(
        not await page.locator("#pauseOverlay").evaluate("node => node.classList.contains('hidden')"),
        "Le panneau de pause reste caché.",
    )
    await page.click("#resumeButton")
    require(not await page.evaluate("MO.app.game.paused"), "La reprise ne fonctionne pas.")
    await finish_current_race(page, 78)
    quick_result = await page.evaluate(
        "({position:MO.app.game.lastResult.position,reward:MO.app.game.lastResult.reward,"
        "rows:document.querySelectorAll('#resultsTable .result-row').length})"
    )
    require(quick_result["rows"] == 8, "Le classement de course rapide est incomplet.")
    report["quick_race"] = {"object": object_state, "result": quick_result}

    # Contre-la-montre.
    await page.locator('.screen.active [data-action="back-main"]').click()
    await page.click('[data-action="time-trial"]')
    await page.select_option("#lapsSelect", "2")
    await page.click("#launchRaceButton")
    await page.wait_for_function("() => MO.app.game.active")
    trial = await page.evaluate(
        "({racers:MO.app.game.racers.length,laps:MO.app.game.laps,"
        "difficultyDisabled:document.querySelector('#difficultySelect').disabled})"
    )
    require(trial == {"racers": 1, "laps": 2, "difficultyDisabled": True}, "Le contre-la-montre est invalide.")
    await finish_current_race(page, 91)
    trial["bestLap"] = await page.evaluate("MO.app.game.lastResult.bestLap")
    report["time_trial"] = trial

    # Grand Prix complet.
    await page.locator('.screen.active [data-action="back-main"]').click()
    await page.click('[data-action="grand-prix"]')
    await page.select_option("#lapsSelect", "1")
    await page.click("#launchRaceButton")
    rounds: list[dict[str, Any]] = []
    expected_tracks = ["foundry", "dunes", "glacier", "orbital"]
    for round_index, track_id in enumerate(expected_tracks):
        await page.wait_for_function("() => MO.app.game.active")
        current = await page.evaluate(
            "({round:MO.app.game.championship.round,track:MO.app.game.track.id})"
        )
        require(current == {"round": round_index, "track": track_id}, "Ordre de Grand Prix incorrect.")
        await finish_current_race(page, 70 + round_index * 3)
        current.update(
            await page.evaluate(
                "({resultRound:MO.app.game.lastResult.championship.round,"
                "final:MO.app.game.lastResult.championship.final,"
                "standings:MO.app.game.lastResult.championship.standings.length,"
                "button:document.querySelector('#resultsPrimaryButton').textContent})"
            )
        )
        require(current["standings"] == 8, "Le classement du Grand Prix est incomplet.")
        require(current["final"] is (round_index == 3), "L'état final du Grand Prix est incorrect.")
        rounds.append(current)
        if round_index < 3:
            await page.click("#resultsPrimaryButton")

    points = await page.evaluate(
        "MO.app.game.lastResult.championship.standings.map(entry => entry.points)"
    )
    require(len(points) == 8 and max(points) > 0, "Les points du championnat sont invalides.")
    await page.click("#resultsPrimaryButton")
    await page.wait_for_function("() => MO.app.game.active")
    restart = await page.evaluate(
        "({round:MO.app.game.championship.round,mode:MO.app.game.mode})"
    )
    require(restart == {"round": 0, "mode": "grand-prix"}, "Le nouveau Grand Prix ne redémarre pas.")
    await page.evaluate("MO.app.game.quit()")
    report["grand_prix"] = {"rounds": rounds, "points": points, "restart": restart}

    report["errors"] = {"page": page_errors, "console": console_errors}
    require(not page_errors and not console_errors, "Des erreurs JavaScript ont été détectées.")
    await context.close()
    return report


async def mobile_suite(browser: Browser) -> dict[str, Any]:
    context = await browser.new_context(
        viewport={"width": 844, "height": 390},
        is_mobile=True,
        has_touch=True,
        device_scale_factor=1,
    )
    page = await context.new_page()
    errors: list[str] = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    await inject_application(page)
    await page.click('[data-action="quick-race"]')
    await page.select_option("#lapsSelect", "1")
    await page.click("#launchRaceButton")
    await page.wait_for_function("() => MO.app.game.active")
    await page.wait_for_timeout(120)
    visible = not await page.locator("#touchControls").evaluate(
        "node => node.classList.contains('hidden')"
    )
    buttons = await page.locator("#touchControls [data-touch]").count()
    await page.evaluate(
        "MO.app.game.state='racing'; MO.app.game.countdown=0; MO.app.game.player.item='shield'"
    )
    await page.locator('[data-touch="item"]').dispatch_event("pointerdown")
    await page.locator('[data-touch="item"]').dispatch_event("pointerup")
    await page.wait_for_timeout(80)
    used = await page.evaluate("MO.app.game.player.stats.itemsUsed")
    require(visible and buttons == 6, "Les commandes tactiles sont incomplètes.")
    require(used == 1, "Le bouton tactile d'objet ne fonctionne pas.")
    require(not errors, "Une erreur est survenue en mode mobile.")
    await context.close()
    return {"visible": visible, "buttons": buttons, "itemUsed": used, "errors": errors}


async def main() -> None:
    async with async_playwright() as playwright:
        options: dict[str, Any] = {
            "headless": True,
            "args": ["--no-sandbox", "--disable-gpu", "--mute-audio"],
        }
        system_chromium = Path("/usr/bin/chromium")
        if system_chromium.exists():
            options["executable_path"] = str(system_chromium)
        browser = await playwright.chromium.launch(**options)
        try:
            report = {
                "desktop": await desktop_suite(browser),
                "mobile": await mobile_suite(browser),
            }
        finally:
            await browser.close()
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print("QA approfondie réussie.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as error:  # pragma: no cover
        print(f"ÉCHEC QA APPROFONDIE: {error}", file=sys.stderr)
        sys.exit(1)
