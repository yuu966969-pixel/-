# RE:MEMORY AI server

## Free local AI (recommended)
The default provider is **Ollama**, which runs the language model on the same PC. No API key, subscription, or per-message API fee is needed. The PC must have enough memory and processing power, and the model download uses disk space and internet bandwidth.

1. Install Ollama from https://ollama.com/download
2. Open a terminal and run:
   `ollama pull qwen3:4b`
3. Keep Ollama running.
4. In this folder, run `npm start`.
5. Open `http://localhost:3000` in your browser.

Ollama normally exposes its local API at `http://127.0.0.1:11434`. The game server sends chat prompts to that local endpoint. Conversation text does not need to be sent to OpenAI or another cloud AI provider in this mode.

If your PC is low on memory, use a smaller model such as `qwen3:1.7b` by setting `OLLAMA_MODEL=qwen3:1.7b` and pulling that model first. Smaller models may give less detailed Japanese replies.

## Configuration
- `AI_PROVIDER`: defaults to `ollama`. Set to `openai` only if you deliberately want the optional cloud provider.
- `OLLAMA_BASE_URL`: defaults to `http://127.0.0.1:11434`.
- `OLLAMA_MODEL`: defaults to `qwen3:4b`.
- `PORT`: defaults to 3000.
- `ALLOWED_ORIGIN`: optional exact origin restriction.

## Optional cloud mode
The server retains an optional OpenAI Responses API mode. Set `AI_PROVIDER=openai` and configure `OPENAI_API_KEY` as a private server environment variable. This mode may incur separate API charges. Do not enable it without the account owner's / guardian's approval. Never put an API key in GitHub, the browser, or the game.

## Important limitations
- Ollama is local software: this free setup works when the game server and Ollama are running on the same PC. A remote Render server cannot reach Ollama on your own PC through `127.0.0.1`; a public online game needs a separately hosted model or a suitable managed inference service.
- The first reply can take longer while the model loads.
- Model quality and speed depend on PC hardware.
- The game server limits each IP to 12 chat requests per minute and caps request/output size.
- Conversation history remains in the game's browser save data and is sent to the local Ollama process for each reply. The server does not save chat logs.
