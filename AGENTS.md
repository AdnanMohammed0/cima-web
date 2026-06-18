# Architecture

**Playwright-backed streaming proxy** — uses a headless Chromium browser to bypass Cloudflare and IP-bound auth tokens.

```
User visits /watch/movie/550
  → Watch.jsx → fetchStream(550) → GET /api/stream?tmdb_id=550

Backend:
  → findStream() launches Playwright headless Chrome
  → Navigates to vidlink.pro/movie/550
  → Intercepts .m3u8 network response
  → Fetches playlist body via page.evaluate(fetch(url)) (browser JS context = Cloudflare clearance)
  → Rewrites all segment/playlist URLs to /api/proxy/playlist?url=...&domain=...
  → Caches rewritten playlist with session ID
  → Returns { playlistUrl: "/api/proxy/playlist/SESSION_ID", ... }

Frontend:
  → Passes playlistUrl as source to VideoPlayer
  → HLS.js loads /api/proxy/playlist/SESSION_ID → gets rewritten master playlist

HLS.js fetches sub-playlist:
  → /api/proxy/playlist?url=SUB_PLAYLIST_URL&domain=CDN_ORIGIN
  → Backend uses pagePool[domain] → page.evaluate(fetch(url)) → fetches via browser
  → Rewrites .ts/.m4s segment URLs → /api/proxy/segment?url=...&domain=...
  → Returns rewritten sub-playlist

HLS.js fetches segments:
  → /api/proxy/segment?url=SEGMENT_URL&domain=CDN_ORIGIN
  → Backend uses pagePool[domain] → page.evaluate(fetch(url)) base64 → decodes → returns binary
```

# Key Files

| File | Purpose |
|------|---------|
| `backend/services/scraper.js` | Playwright-based embed scraper. Navigates to source, intercepts ALL .m3u8 responses, picks the master playlist (has `#EXT-X-STREAM-INF`), returns it with CDN domain. |
| `backend/services/sessionStore.js` | In-memory TTL cache (1h) for rewritten playlists, keyed by session ID. |
| `backend/services/streamProxy.js` | *(deprecated)* Old Axios-based proxy. Not used — Playwright-backed approach in routes/proxy.js replaces it. |
| `backend/routes/stream.js` | `/api/stream?tmdb_id=X` → scrapes, rewrites playlist, caches, returns `playlistUrl`. Accepts `type`, `season`, `episode` params. Previously supported `provider` param (removed dead providers). |
| `backend/routes/proxy.js` | `/api/proxy/playlist/:sessionId` → serves cached playlist. `/api/proxy/playlist` → fetches sub-playlist via Playwright, rewrites segments. `/api/proxy/segment` → fetches segment via Playwright browser JS context. Maintains a pagePool (domain → Playwright page, 10min TTL) for zero-overhead repeat requests. |
| `frontend/src/services/stream.js` | Calls `/api/stream`, returns `{ playlistUrl, source }`. |
| `frontend/src/pages/Watch.jsx` | Fetches stream on mount, passes `playlistUrl` as `source` to VideoPlayer. Falls back to Vidlink iframe on error. |
| `backend/services/subtitleScraper.js` | Playwright-based scraper for opensubtitles.org. Bypasses Anubis PoW, extracts subtitle rows from `#search_results`, downloads ZIP via `page.evaluate(fetch())`, unzips with adm-zip, converts SRT/ASS to VTT. Uses `LANG_MAP` for two-letter → three-letter ISO 639-2 language codes. |
| `frontend/src/components/VideoPlayer.jsx` | HLS.js-based video player with forward/backward 10s (desktop + mobile double-tap), quality selector, subtitle support (HLS embedded + external + Arabic auto-load), subtitle settings (size, background, offset), keyboard shortcuts (space/arrows/f/m), continue watching progress saving (every 5s), sync mode for watch parties. |
| `frontend/src/store/store.js` | Zustand store with stream caching (preload + cache), continue watching (localStorage, 20 items max), watch party state management. |
| `frontend/src/pages/Home.jsx` | Hero carousel with auto-rotation, continue watching section with progress bars, watch party CTA (navigates to `/party` hub), trending/popular/top-rated horizontal scrolls. Preloads first featured media stream. |
| `frontend/src/pages/Detail.jsx` | Media detail page with backdrop hero, poster, meta info, cast, seasons/episodes, recommendations. Preloads stream on mount (movie + first TV episode). CreateRoom button for watch parties. |
| `frontend/src/pages/PartyHub.jsx` | Watch party hub — create new room or join existing by code. Accessible from homepage CTA, bottom nav, and desktop nav. |
| `frontend/src/pages/Room.jsx` | Room page with host media search (TMDB dropdown), synced video player, chat sidebar, participant list. Host can search and change media on the fly. |
| `backend/server.js` | Express server, Socket.io, CORS, `/api/rooms` POST/GET routes, listens on `0.0.0.0`. |

# Dependencies

- `backend`: express, socket.io, cors, uuid, dotenv, playwright (Chromium ~300MB cached in ms-playwright)
- `frontend`: react, react-router-dom, plyr, hls.js (CDN), zustand, react-icons

# Theme

- **Red accent**: On all interactive buttons, progress bars, active states
- **Mobile-first**: VideoPlayer is fullscreen on mobile (`h-dvh`), controls adapted for touch
- **Network access**: `host: '0.0.0.0'` in Vite config + Express `listen` for LAN access

# Known Issues

- Playwright + Chromium adds ~400MB to installation
- Every new CDN domain triggers a Cloudflare challenge on first request (2-3s delay)
- Page pool TTL (10min) means stale sessions re-trigger Cloudflare
- Segment proxy uses base64 encoding (FileReader in browser context) which adds CPU overhead per segment
- No multi-user isolation currently — all segment requests share the same Playwright page per domain
- Opensubtitles.org uses three-letter ISO 639-2 language codes (`ara`), not two-letter codes (`ar`) — scraper has `LANG_MAP` to translate
- Anubis PoW at opensubtitles.org takes 3-10s on first request per browser context; subsequent requests leverage established session cookie
- `AbortSignal.timeout` (used in `preloadStream` store action) is Node 17+ — backend runs Node 16, will throw if preload triggered server-side
- Subtitle custom rendering (VTT parsed into cues, tracked at 100ms, rendered in overlay div with custom styles) respects size/background/offset settings
