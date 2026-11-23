# RE:MEMORY AI server

This folder contains a small Node.js server for the game's real AI conversations.

## What it does
- Serves the game page and the `/api/chat` endpoint from one origin.
- Calls the OpenAI Responses API from the server, never from browser code.
- Keeps the API key in the server environment only.
- Gives N.O.V.A., each merchant, and each companion a separate role/personality prompt.
- Sends only a short recent conversation history; API-side response storage is disabled.
- Limits each IP to 12 chat requests per minute and caps request/output size.

## Run locally
Requires Node.js 20 or newer.

1. Copy `.env.example` to `.env` in this folder.
2. Set `OPENAI_API_KEY` in that private file. Never commit it.
3. Run `npm start` from this folder.
4. Open `http://localhost:3000`.

The API key is not included in this repository. Requests cannot reach the model until a valid key is configured.

## Deployment
A Render Blueprint file is provided at `../render.yaml`. Deploy the `RE-MEMORY` folder as the project root. Add `OPENAI_API_KEY` as a private environment secret in the hosting dashboard. Do not put it in GitHub, the browser, or a public environment variable.

The hosting free tier may sleep or have limits. Model API usage is billed separately by OpenAI. Set a small usage budget and usage alerts before enabling public access. Do not enable paid usage without the account owner's / guardian's approval.

## Configuration
- `OPENAI_MODEL`: defaults to `gpt-6-luna`; change only to a model enabled for the API account.
- `PORT`: hosting platform port, defaults to 3000.
- `ALLOWED_ORIGIN`: optional exact origin restriction.

## Notes
- Conversation history remains in the game's browser save data and is sent in a short window for each reply.
- The server does not store player chat logs.
- Rate limiting is in-memory and resets when the server restarts; production-scale public use should add persistent rate limiting and authentication.
