import asyncio
import os
import time
from collections import defaultdict, deque
from typing import Deque

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field

STABILITY_URL = "https://api.stability.ai/v2beta/audio/stable-audio/text-to-audio"
MODEL = os.getenv("STABILITY_MODEL", "stable-audio-2.5")
DURATION_SECONDS = int(os.getenv("AUDIO_DURATION_SECONDS", "20"))
MAX_PROMPT_CHARS = 500
MAX_AUDIO_BYTES = 20 * 1024 * 1024
RATE_PER_HOUR = int(os.getenv("RATE_PER_HOUR", "5"))
RATE_PER_DAY = int(os.getenv("RATE_PER_DAY", "10"))

app = FastAPI(title="NekoAlarm AI Music API", version="1.0.0")
_requests: dict[str, Deque[float]] = defaultdict(deque)
_rate_lock = asyncio.Lock()


class GenerateRequest(BaseModel):
    date: str = Field(min_length=10, max_length=10)
    prompt: str = Field(min_length=1, max_length=MAX_PROMPT_CHARS)
    format: str = Field(default="mp3")
    mode: str = Field(default="custom")


async def enforce_rate_limit(client_ip: str) -> None:
    now = time.monotonic()
    one_hour_ago = now - 3600
    one_day_ago = now - 86400
    async with _rate_lock:
        history = _requests[client_ip]
        while history and history[0] < one_day_ago:
            history.popleft()
        hourly = sum(ts >= one_hour_ago for ts in history)
        if hourly >= RATE_PER_HOUR or len(history) >= RATE_PER_DAY:
            raise HTTPException(status_code=429, detail="この接続元からの作曲回数が上限に達しました。時間をおいて再試行してください。")
        history.append(now)


@app.get("/health")
async def health():
    return {"ok": True, "provider": "Stability AI", "configured": bool(os.getenv("STABILITY_API_KEY"))}


@app.post("/api/generate")
async def generate(body: GenerateRequest, request: Request):
    api_key = os.getenv("STABILITY_API_KEY")
    if not api_key:
        raise HTTPException(status_code=503, detail="サーバーに作曲AIのAPIキーが設定されていません。")
    if body.format.lower() != "mp3":
        raise HTTPException(status_code=400, detail="format は mp3 のみ対応しています。")
    if body.mode not in ("daily", "custom"):
        raise HTTPException(status_code=400, detail="mode が正しくありません。")
    prompt = body.prompt.strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="作曲リクエストを入力してください。")
    if len(prompt) > MAX_PROMPT_CHARS:
        raise HTTPException(status_code=413, detail="作曲リクエストは500文字以内にしてください。")

    client_ip = request.client.host if request.client else "unknown"
    await enforce_rate_limit(client_ip)

    # Ask for original music; do not request imitation of a named artist or existing song.
    safe_prompt = (
        prompt
        + ". Create original music only. Do not imitate any specific artist, band, "
          "copyrighted song, or existing recording. Instrumental, no spoken words."
    )
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "audio/*",
    }
    form = {
        "model": MODEL,
        "prompt": safe_prompt,
        "duration": str(DURATION_SECONDS),
        "output_format": "mp3",
    }

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(220.0, connect=15.0)) as client:
            upstream = await client.post(STABILITY_URL, headers=headers, data=form)
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="作曲AIの応答がタイムアウトしました。")
    except httpx.HTTPError:
        raise HTTPException(status_code=502, detail="作曲AIに接続できませんでした。")

    if upstream.status_code != 200:
        if upstream.status_code == 402:
            raise HTTPException(status_code=402, detail="作曲AIの利用クレジットが不足しています。")
        if upstream.status_code == 429:
            raise HTTPException(status_code=429, detail="作曲AI側の利用上限に達しました。")
        if upstream.status_code in (400, 403, 422):
            raise HTTPException(status_code=422, detail="この作曲リクエストはAI側で受け付けられませんでした。表現を変えてください。")
        raise HTTPException(status_code=502, detail="作曲AIでエラーが発生しました。")

    audio = upstream.content
    if len(audio) < 8_000:
        raise HTTPException(status_code=502, detail="作曲AIから有効な音源が返されませんでした。")
    if len(audio) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=502, detail="生成された音源がサイズ上限を超えました。")

    return Response(
        content=audio,
        media_type="audio/mpeg",
        headers={
            "Content-Disposition": 'attachment; filename="nekoalarm-generated.mp3"',
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        },
    )
