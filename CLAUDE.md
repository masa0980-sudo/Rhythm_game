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

### PlayCounts (Firestore)

Same no-SDK, `fetch()`-only approach as `Leaderboard`, but a separate collection
(`playCounts/{gameId}`, one doc per game, single `count` field) so its rules don't interact with
the leaderboard's. `increment()` fires a `:commit` request with a `fieldTransforms[].increment`
transform — atomic +1, no read-modify-write — from `startGame()` (the shared helper both the
game-select cards and the "もういちど" retry button call through). `fetchCounts()` batches all
four docs into one `:batchGet` call to populate the small play-count line on each game card.

Both calls are fire-and-forget / non-blocking by design — the game must never wait on this
network round trip before starting. `increment()` tries the +1 transform first (the steady-state
case, one request); if that fails because the doc doesn't exist yet, it falls back to creating the
doc with `count: 1` (one extra request, only on a gameId's very first play ever). The rules mirror
this: `allow update` only ever accepts exactly +1, and `allow create` only accepts a brand-new doc
whose only field is `count: 1` — no manual Firebase-console seeding needed for a new gameId.

This Firestore project (`rythm-game-mo`) is intentionally **shared across several separate public
games** (tennis-game, neon-void, typing_quotes, etc.), not just this repo — each game's own
`playCounts/{gameId}` document lives in the same `playCounts` collection, keyed by an id unique to
that game (`ring`/`endless`/`echo`/`timeg` here; `tennis`, `neon-void`, etc. elsewhere). If you're
choosing a new gameId, check it doesn't collide with another game's.

## Mini mode (`?mini=1`, called from mini-medley)

The hub in `C:\claude\repos\mini-medley` opens this page in an iframe with `?mini=1&sec=20&mute=0|1`.
**The protocol is specified in mini-medley's CLAUDE.md**; this section only records Rhythm_game's side.
Without `mini=1` everything behaves exactly as before.

- It plays **ぴったりリング (normal) only**. A one-line `<head>` script adds `<html class="mini">` before first paint; CSS hides
  every screen except `#play`. `miniBoot()` calls `show("play")` and posts `mini-ready`; the hub's `mini-go` runs `miniGo()`,
  which calls `RingGame.begin("normal")` **directly** (not `startGame(g)`, so `PlayCounts` is not incremented).
- `COUNT_BEATS` is 4 instead of 8 in mini mode (the hub already shows its own 3-2-1; the count-in is only for feeling the tempo).
  The whole run takes about 18 s, so the `sec` safety cut (`Engine.finish()` after `sec` seconds, which emits `sessionEnd`) normally
  never fires with the hub's `sec=20`. **If you change `PHRASES`/`COUNT_BEATS`, re-check the run still fits in `sec`.**
- `onSessionEnd()` has a `MINI` branch at the top that returns before `Scores.submit`, `RankUI` (Firestore TOP10) and the result
  screen. `RingGame.miniStats()` exposes the internal `stats` for `endMini()`.
- Score: judgement points (PERFECT 100 / GOOD 50) ÷ 2400 × 100. Measured with a bot: all-perfect → 92–100, all-GOOD (taps 90 ms
  off) → 50, no input → 0. Taps are judged against the **saved audio-offset setting** (`rhythm-ring-offset`, from the calibration
  done in the normal game on the same origin); mini mode never runs or writes the calibration.
- `mute=1` sets `Sfx`'s `master` gain to 0 (`master` is not rewritten elsewhere). Nothing is written to localStorage in mini mode.
- Verification: add `&debug=1` to expose `window.__engine`; a bot can press Space when `__engine.perceived(__engine.peekHits(1)[0].time)`
  equals `__engine.now()`. Standalone check: `?mini=1&sec=30` auto-starts after 300 ms (`window.parent === window`).
- Deploys from the branch `claude/browser-game-ai-weueub` (not `main`).
