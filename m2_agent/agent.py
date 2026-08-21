"""M2 Agent Server Demo for LiveKit Voice AI Architecture.

Supports:
  1. Pipeline (STT -> custom LLM endpoint -> TTS)
  2. Realtime (Multimodal Realtime model endpoint)

Plug-and-play via M2_MODEL_ENDPOINT + M2_MODEL_API_KEY in .env.
"""

from __future__ import annotations

import logging
import os

from dotenv import load_dotenv
from livekit.agents import JobContext, JobProcess, WorkerOptions, cli
from livekit.agents.voice import Agent, AgentSession
from livekit.plugins import cartesia, deepgram, openai, silero

load_dotenv()

logger = logging.getLogger("m2-agent")


def _env(key: str, default: str = "") -> str:
    return os.environ.get(key, default).strip().strip('"').strip("'")


def _build_pipeline_session() -> AgentSession:
    endpoint = _env("M2_MODEL_ENDPOINT") or None
    api_key = _env("M2_MODEL_API_KEY") or _env("OPENAI_API_KEY")
    model = _env("M2_MODEL_NAME", "gpt-4o-mini")
    try:
        temp = float(_env("M2_TEMPERATURE", "0.7"))
    except ValueError:
        temp = 0.7

    logger.info("Pipeline LLM: model=%s endpoint=%s", model, endpoint or "default")

    llm = openai.LLM(
        base_url=endpoint,
        api_key=api_key or "placeholder",
        model=model,
        temperature=temp,
    )

    stt_provider = _env("M2_STT_PROVIDER", "deepgram").lower()
    stt_endpoint = _env("M2_STT_ENDPOINT") or None
    stt_key = _env("M2_STT_API_KEY") or _env("DEEPGRAM_API_KEY") or api_key
    stt_model = _env("M2_STT_MODEL", "nova-2-general")

    if stt_provider == "openai" or stt_endpoint:
        stt = openai.STT(
            base_url=stt_endpoint,
            api_key=stt_key or "placeholder",
            model=stt_model if stt_model != "nova-2-general" else "whisper-1",
        )
    else:
        stt = deepgram.STT(model=stt_model, api_key=stt_key or None)

    tts_provider = _env("M2_TTS_PROVIDER", "cartesia").lower()
    tts_endpoint = _env("M2_TTS_ENDPOINT") or None
    tts_key = _env("M2_TTS_API_KEY") or _env("CARTESIA_API_KEY") or api_key
    tts_model = _env("M2_TTS_MODEL", "sonic-english")
    voice = _env("M2_VOICE", "79a125e8-cd45-4c13-8a67-188112f4dd22")

    if tts_provider == "openai" or tts_endpoint:
        tts = openai.TTS(
            base_url=tts_endpoint,
            api_key=tts_key or "placeholder",
            model=tts_model if tts_model != "sonic-english" else "tts-1",
            voice=voice if len(voice) < 20 else "alloy",
        )
    else:
        tts = cartesia.TTS(model=tts_model, voice=voice, api_key=tts_key or None)

    return AgentSession(stt=stt, llm=llm, tts=tts, vad=silero.VAD.load())


def _build_realtime_session(instructions: str) -> AgentSession:
    endpoint = _env("M2_MODEL_ENDPOINT") or None
    api_key = _env("M2_MODEL_API_KEY") or _env("OPENAI_API_KEY")
    model = _env("M2_MODEL_NAME", "gpt-4o-realtime-preview")
    voice = _env("M2_VOICE", "alloy")
    try:
        temp = float(_env("M2_TEMPERATURE", "0.7"))
    except ValueError:
        temp = 0.7

    logger.info("Realtime model: %s endpoint=%s", model, endpoint or "default")

    rt_model = openai.realtime.RealtimeModel(
        base_url=endpoint,
        api_key=api_key or "placeholder",
        model=model,
        instructions=instructions,
        voice=voice if len(voice) < 20 else "alloy",
        temperature=temp,
    )
    return AgentSession(llm=rt_model)


def prewarm(proc: JobProcess) -> None:
    proc.userdata["vad"] = silero.VAD.load()


async def entrypoint(ctx: JobContext) -> None:
    instructions = _env(
        "M2_INSTRUCTIONS",
        "You are a helpful and professional customer service voice assistant. Keep answers concise and natural.",
    )
    greeting = _env("M2_GREETING", "Hello! How can I help you today?")
    workflow = _env("M2_WORKFLOW", "pipeline").lower()

    logger.info("M2 connecting to %s workflow=%s", ctx.room.name, workflow)
    await ctx.connect()

    session = (
        _build_realtime_session(instructions) if workflow == "realtime" else _build_pipeline_session()
    )
    agent = Agent(instructions=instructions)

    await session.start(room=ctx.room, agent=agent)

    if greeting and workflow != "realtime":
        await session.say(greeting, allow_interruptions=True)


if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint, prewarm_fnc=prewarm))
