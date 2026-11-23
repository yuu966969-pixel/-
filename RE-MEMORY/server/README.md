# RE:MEMORY AI server

## Online AI (recommended deployment)
The server supports **Cloudflare Workers AI** through an OpenAI-compatible chat-completions endpoint. The model runs in Cloudflare's hosted infrastructure, so players can use the game from a browser without installing Ollama.

Default model: `@cf/meta/llama-3.3-70b-instruct-fp8-fast`.

Cloudflare Workers AI currently includes 10,000 Neurons per day on the Free plan. This is a daily compute allowance, not unlimited usage; actual conversation count depends on prompt and response length. When the daily allowance or a provider rate limit is reached, chat requests stop until the allowance resets. Model prices and free allowances can change. See https://developers.cloudflare.com/workers-ai/platform/pricing/.

### Required server secrets
Set these as private environment variables in the hosting dashboard (never in GitHub or browser code):
- `AI_PROVIDER=cloudflare`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN` — create a restricted token with Workers AI permissions only.
- `CLOUDFLARE_MODEL=@cf/meta/llama-3.3-70b-instruct-fp8-fast`

An account owner / guardian should create and manage the hosting and Cloudflare accounts, review service terms, and keep the token private. Do not paste tokens into chat, source files, or GitHub.

### Deploy with Render
1. Connect this GitHub repository to Render.
2. Create a Blueprint using `RE-MEMORY/render.yaml`.
3. Choose the Free web-service instance.
4. Add the Cloudflare Account ID and API token as secret environment variables in Render.
5. Deploy. Once healthy, open the Render-provided HTTPS URL.

Render Free web services may spin down after inactivity and have monthly instance-hour limits, so the first visit after a quiet period can be slow. See https://render.com/docs/free.

## Local-only alternative
To run on one PC without cloud AI usage, install Ollama from https://ollama.com/download, run `ollama pull qwen3:4b`, set `AI_PROVIDER=ollama`, and start this server with `npm start`. Open `http://localhost:3000`.

## Optional OpenAI mode
The server retains an optional OpenAI Responses API mode. Set `AI_PROVIDER=openai` and configure `OPENAI_API_KEY` privately. This can incur separate API charges.

## Technical notes
- `GET /api/health` reports provider configuration; `POST /api/chat` handles NPC dialogue.
- Character-specific instructions and canonical game lore are added server-side.
- The server sends only the recent chat history needed for the current reply and does not write chat logs to disk.
- A basic per-IP rate limit and request-size/output caps are enabled. These are prototype safeguards, not full production abuse protection.
