# NekoAlarm AI Music API

This server completes the AI-music flow for the iOS app. It accepts the app's JSON request, calls Stability AI Stable Audio 2.5 through its text-to-audio API, and returns the generated MP3 bytes. The iPhone converts the MP3 to WAV for AlarmKit and offers preview/share.

## API contract

- `GET /health` — health and provider configuration status (does not reveal the API key).
- `POST /api/generate` — JSON body:

```json
{
  "date": "2026-11-20",
  "prompt": "明るくて元気が出る、猫っぽい電子音楽",
  "format": "mp3",
  "mode": "custom"
}
```

Successful response: raw `audio/mpeg` MP3 bytes. The app already expects this format.

## Run locally

Requires Python 3.12+ and a Stability AI API key.

```bash
cd server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export STABILITY_API_KEY="your-private-key"
uvicorn main:app --host 0.0.0.0 --port 8080
```

The iOS app requires a publicly reachable HTTPS URL, so a local `http://localhost` address will not work on a normal installed iPhone build.

## Deploy with Render

1. Push this repository to GitHub.
2. In Render, create a new Blueprint from this repository and select the root `render.yaml`.
3. Set `STABILITY_API_KEY` as a private environment variable in the Render dashboard. Never commit it.
4. Wait for the service to deploy. Check `https://YOUR-SERVICE.onrender.com/health`.
5. Copy `https://YOUR-SERVICE.onrender.com/api/generate`.
6. In NekoAlarm, paste that HTTPS URL into **AI server URL**. The app stores the URL on the device; no rebuild is needed.

Free hosting availability, sleep behavior, limits, and provider credits can change. The first request may take longer if the host has been sleeping. Stable Audio API calls consume credits; have an adult account owner review the current pricing and usage limits before enabling paid generation.

## Cost and safety

- Stable Audio API usage consumes provider credits. Check current pricing and remaining credits before enabling generation. The free starter balance may not cover every model call; this is not a guaranteed free unlimited service.
- Keep the API key server-side. Do not put it in Swift, Info.plist, GitHub, screenshots, or chat.
- The server applies per-process request limits (5/hour and 10/day by default), validates prompts and caps audio at 20 MB. In-memory limits reset on restart and are not a substitute for a production billing quota or account authentication. When deployed behind a reverse proxy, verify that client IP forwarding is configured correctly.
- Use only original prompts. Do not request imitation of a specific artist, band, song, or recording.
- For public production use, add durable rate limiting, authentication, monitoring, and a hard provider spending cap before sharing the endpoint widely.
