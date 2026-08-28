# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A browser rhythm-game collection. The entire app — HTML, CSS, and JS — lives in a single
`index.html` file with no build step, no bundler, and no dependencies. It's published as-is
to GitHub Pages: https://masa0980-sudo.github.io/Rhythm_game/

## Commands

There is no package.json, build step, linter, or test framework — this is intentional; keep it
that way rather than introducing tooling.

- **Run locally**: serve the repo root and open `index.html`, e.g. `python3 -m http.server 8000`.
- **Verify UI changes**: use Playwright to drive a real browser against the local server
  (there is no automated test suite). The browser is pre-installed — launch with
  `executablePath: "/opt/pw-browsers/chromium"` and do **not** run `playwright install`.
  On first visit, `#startBtn` leads to a calibration screen (`#calib`); click the button with
  text `スキップ` to skip straight past it when testing later screens.
- **Deploy**: push to the `claude/browser-game-ai-weueub` branch. GitHub Actions
  (`.github/workflows/deploy-pages.yml`) rebuilds and republishes GitHub Pages automatically —
  there is no separate deploy command.
  When checking the run, note that the Actions API can return **job state that is several minutes
  stale** — a step can look stuck for ten-plus minutes when it actually finished in one. Don't
  cancel or re-run on that basis; wait and re-fetch, and treat `get_job_logs` (look for
  `Evaluated environment url: ...`) as the authoritative answer. This sandbox cannot reach
  `*.github.io`, so the live page can never be confirmed from here — say so rather than implying
  it was checked.

## Architecture

Everything is one `<script>` inside `index.html`, organized as numbered, comment-delimited
IIFE modules (search for `const X = (function(){ ... })()`), in dependency order:

1. **Sfx** — generates sound via the Web Audio API (no audio files).
2. **Engine** — generic rhythm/beat scheduler; knows nothing about the DOM or any specific game.
3. **Input** — unifies keyboard/click/tap input and prevents double-firing.
4. **Settings** — stores the user's audio-offset (latency) calibration.
   - 4b. **Scores** — per-device best score, stored locally.
   - 4c. **Leaderboard** — the shared TOP10, backed by Firestore (see below).
   - 4d. **RankUI** — renders the TOP10 list and the initials-entry form on the result screen.
5. **Calibration** — auto-measures audio/input latency on first run.
6–8. **RingGame / EchoGame / TimeGame** — the three playable mini-games, each owning its own
   screen's logic and rendering.
9. **Game list & screen navigation** — the `GAMES` array (id/name/desc/start per game) and the
   screen-switching glue (see below).

**Screen switching**: only one `.screen` element is visible at a time, controlled by
`const SCREENS = [...]` + `function show(id)`. **Any new screen must be added to `SCREENS`**,
or `show()` won't hide/reveal it correctly.

**Background art pattern**: screens that use the key art repeat the same three-layer markup —
`.keyartLayer > .keyartImg (art/keyart.jpg) + .keyartScrim`. JS hides the image automatically if
it fails to load, so the game still works without `art/keyart.jpg` present.

### Leaderboard (Firestore)

No Firebase SDK is loaded — `Leaderboard` calls the Firestore REST API directly via `fetch()`,
to keep the single-file constraint. Project ID `rythm-game-mo`; the API key is meant to be
public in client code. The real access control is Firestore's **security rules**, not the API
key: rules validate field shape and cap `score` at 100000, and disallow updates/deletes entirely.
Because of that last point, bad or test entries (`leaderboard/{gameId}/scores/{docId}`) can only
be removed by hand in the Firebase console — see README.md for the exact steps. Don't try to
build an in-app delete path; it's blocked by design.

The rules also mean a sandboxed/offline dev environment may not be able to reach
`firestore.googleapis.com` at all — `fetch()` will hang until it times out rather than fail
fast. Treat a stuck "読み込み中…" during local testing as an environment/network limitation, not
necessarily a code bug; confirm the actual leaderboard behavior in a real browser with network
access.
