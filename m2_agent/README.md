# M2 Agent Server Demo

This directory contains the **M2 Agent Server** demo for our LiveKit Voice AI architecture.

In our evaluation architecture:
- **M1**: The user-simulator model playing the human caller.
- **M2**: The hosted calling AI model under evaluation.
- **Flutter Client (`agent-starter-flutter`)**: The client application interfacing with LiveKit rooms for visualizer, audio, and transcriptions.

---

## 1. Supported Workflows

M2 supports two workflows out of the box:

### A. STT-LLM-TTS Pipeline Workflow (`M2_WORKFLOW=pipeline`)
- **Speech-to-Text (STT)**: Deepgram / Whisper / custom STT endpoint.
- **LLM**: Any OpenAI-compatible model endpoint (`M2_MODEL_ENDPOINT` + `M2_MODEL_API_KEY`).
- **Text-to-Speech (TTS)**: Cartesia / ElevenLabs / OpenAI TTS / custom TTS endpoint.
- **Turn Detection**: Silero Voice Activity Detection (VAD).

### B. Real-time Model Workflow (`M2_WORKFLOW=realtime`)
- **Realtime Model**: Direct stream to an OpenAI-compatible Realtime API / WebSocket model endpoint (`M2_MODEL_ENDPOINT` + `M2_MODEL_API_KEY`).

---

## 2. Plug and Play Setup

To plug in any custom model, copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Edit `.env` with your endpoint and API key:

```env
# LiveKit Server Connection
LIVEKIT_URL=wss://your-livekit-server.com
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret

# Select Workflow: "pipeline" or "realtime"
M2_WORKFLOW=pipeline

# Custom Model (Plug & Play)
M2_MODEL_ENDPOINT=https://your-custom-model-endpoint.com/v1
M2_MODEL_API_KEY=your_api_key
M2_MODEL_NAME=your-model-name
```

---

## 3. Quick Verification & Testing

### Test the Custom Model Endpoint directly
Verify endpoint connectivity and response latency before running the full agent:

```bash
python test_model.py
# Or with explicit arguments:
python test_model.py --endpoint https://api.openai.com/v1 --api-key sk-... --model gpt-4o-mini
# Or mock test:
python test_model.py --mock
```

### Run the M2 LiveKit Agent Worker

Install dependencies:
```bash
pip install -r requirements.txt
```

Launch the agent in development mode:
```bash
python agent.py dev
```

When a user or simulator connects to a LiveKit room, M2 will join automatically as the `AGENT` participant, run dialogue inference through your configured model endpoint, and return audio and transcriptions.
