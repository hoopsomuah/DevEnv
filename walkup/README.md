# Boom Squad Walk-Up Player

A static web app that plays each Boom Squad player's walk-up song from a configured cue point at the tap of a button. v1 scope per the PRD: PKCE auth + Spotify Connect playback + localStorage roster, no build step.

## How v1 works

- **You authenticate once** via Spotify on this device (PKCE; tokens live in `localStorage`).
- **Audio plays through your existing Spotify session** (the app on your phone routed to the dugout speaker). The web app is a remote control — it never plays audio itself in v1.
- **Roster lives in `localStorage`.** Edit it as JSON in Settings → Roster. No cue-point scrubber yet (that's v1.x).

Modes:
- **Walk-up:** plays from the cue point until you tap stop or another card.
- **Sample:** auto-pauses 10s after the cue point.

## One-time setup

### 1. Register a Spotify Developer app

1. Go to <https://developer.spotify.com/dashboard> and sign in.
2. Click **Create app**.
3. Name it (e.g. "Boom Squad Walk-Up"), give it any description, accept the terms, and create.
4. Open the app's **Settings**.
5. Under **Redirect URIs**, add the exact URL where you'll host this page. Examples:
   - Local testing: `http://127.0.0.1:5173/walkup/` (use 127.0.0.1, not `localhost`, for Spotify)
   - Hosted: `https://your-domain.example/walkup/`
   The trailing slash matters. Add every URL you'll actually use.
6. Save.
7. Under **User Management**, add the Spotify accounts (email or username) of anyone who'll use the app. Dev mode is capped at 25 users — plenty for one team.
8. Copy the **Client ID** from the app overview.

### 2. Plug the Client ID into the app

Edit `walkup/src/config.js`:

```js
export const CLIENT_ID = "your-client-id-here";
```

The redirect URI is derived from the page URL automatically — no other config needed.

### 3. Serve the page

This is a static site; it needs to be served over HTTP (not opened as `file://`) because of the OAuth redirect and the `crypto.subtle` PKCE hash. Any static server works. From the repo root:

```sh
# Python:
python3 -m http.server 5173
# Then open http://127.0.0.1:5173/walkup/
```

```sh
# Node (npx):
npx serve -l 5173 .
# Then open http://127.0.0.1:5173/walkup/
```

Hosting options for game day: Cloudflare Pages, Vercel, GitHub Pages — anything that serves static files. Whatever URL you pick must match the Redirect URI you registered.

### 4. Premium account on the streaming device

Whichever device actually streams audio (the dugout phone running Spotify) needs Spotify Premium. The web app itself doesn't — it's just a remote.

## Game-day usage

1. On the dugout phone, open Spotify and start any track briefly (this wakes the Connect device).
2. Connect the phone to the Bluetooth speaker.
3. Open the walk-up player URL in a browser. Sign in once.
4. The "Routing to: …" banner confirms the speaker is the target. If it shows the wrong device, open Settings and pick the right one.
5. Tap a player's card → song plays from the cue point. Tap again to pause; tap a different card to switch.

If the banner says no device is found: open Spotify on the phone, play any song for a second to wake it, then tap the page anywhere (or pull down to refresh) — the app re-checks for devices on focus.

## Editing the roster (v1)

Settings → Roster shows the current JSON. Schema:

```json
{
  "team": "The Boom Squad",
  "players": [
    {
      "id": "lucy",
      "jersey": "00",
      "name": "Lucy",
      "trackUri": "spotify:track:7yMR75YQqK1PzBxGLE5HNW",
      "trackName": "Also Sprach Zarathustra",
      "artist": "Phish",
      "startMs": 469000,
      "sampleDurationMs": 10000
    }
  ]
}
```

Required per player: `id` (unique), `name`, `startMs` (≥ 0). To get a track URI, in the Spotify app: right-click → Share → Copy Spotify URI. `startMs` is the cue point in milliseconds (7:49 = 469000).

## Files

```
walkup/
├── index.html
├── styles.css
├── README.md
└── src/
    ├── app.js        # entry; DOM wiring
    ├── auth.js       # PKCE flow + token refresh
    ├── config.js     # CLIENT_ID, scopes, URLs
    ├── playback.js   # play/pause + mode + sample timer
    ├── roster.js     # localStorage CRUD + ordering
    └── spotify.js    # Web API wrapper
```

## What's not in v1

Per the locked scope, these are deliberately out:
- In-app cue-point scrubber (edit JSON directly for now).
- Web Playback SDK fallback for desktop.
- Public share link with 30-second previews.
- Cross-device roster sync.

See the PRD for the full roadmap.
