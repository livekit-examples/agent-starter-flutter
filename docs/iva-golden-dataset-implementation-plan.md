# Implementation Plan — `IVA_Test.csv` Golden Dataset → LiveKit Benchmark (agent-starter-flutter)

---

## 1. Context & Objective

Our infrastructure has three pieces today:

1. The **client's SIP calling AI model** — referenced as **M2**, the system under evaluation.
2. The **benchmark system** - a τ²-bench-style, outcome-first evaluation harness (stateful environment, layered grading, multiplicative reward).
3. The **M1 user-simulator model** — an LLM that plays the human caller, with a goal, persona, knowledge limits, and its own tools. It must **not** know the success criteria.

For the development phase we want the **LiveKit stack** (this repo + a LiveKit agent server hosting M2) to stand in for the client's production SIP agent. This plan describes how to ingest the **`IVA_Test.csv` golden data set** (1,000 German-language banking/insurance intent scenarios) and make it directly runnable as the **task suite** of that stack.

---

## 2. Dataset Analysis


### 2.1 Column schema

| # | Column | Purpose in the benchmark |
|---|---|---|
| 0–2 | `diab_IvaCallId`, `diab_ConversationSummary`, `diab_ConversationOutput` | Unpopulated production metrics — **dropped** |
| 3 | `callernbr` | Origin phone number → maps to LiveKit SIP egress `from` / call metadata |
| 4 | `intent_name` | CamelCase intent ID, e.g. `RequestProofOfFunds` — **task key** |
| 5 | `expected_output` | Machine intent code, e.g. `REQUEST_PROOF_OF_FUNDS` — **ground-truth label** |
| 6 | `real_output` | Unpopulated production field — **dropped** |
| 7 | `description` | English task definition — **user-simulator goal prompt** |
| 8 | `scenario` | German opening utterance — **task opener** |
| 9 | `caller_name` | Persona name, e.g. `Ahmed Hassan` |
| 10 | `gender` | `männlich` / `weiblich` — persona |
| 11 | `anrede` | `Sie` / `Du` — politeness register for the persona prompt |
| 12 | `ID des Kontakts` | Contact id — metadata |
| 13 | `Datum der Erstellung` | Creation timestamp — metadata |
| 14–15 | `Ausgeschlossen`, `Ausgeschlossenes Detail` | Excluded flag/details (production call outcomes) — **exclusion filter** |
| 16 | `Priorität` | Priority `10`/`11` — optional stratification |
| 17–25 | Attempts / call history / follow-up columns | Production operations — **dropped** |
| 26–28 | `Wrap-up-ID`, `Wrap-up-Typ`, `Wrap-up-Pfad` | Production wrap-up (`arguedpositive`) — metadata |

### 2.2 Statistics

- 1,000 rows, **199 unique intents** (verified programmatically).
- Mostly **5 prompt-variants per intent** (some have 4) → built-in **consistency test** material.
- Persona names vary per variation; ~50/50 gender split; `anrede` is `Sie` in sampled rows (confirm distribution at import).

### 2.3 Quirks to handle at import

1. **BOM + CRLF** — strip BOM, normalise line endings.
2. **Quoting** — `csv.QUOTE_ALL`; the `;` delimiter is quoted-safe, but run the import with a proper CSV parser, **never** `split(';')`.
3. **Umlauts / umlaut vowels** — `ä ö ü ß` throughout; keep UTF-8 end-to-end (Dart strings, JSON writes, file handles).
4. **Name/gender mismatch risk** — some names are culturally mismatched to `gender`; the persona builder must trust `gender` over the name for pronoun selection.
5. **Duplicate scenarios** — verify `scenario` uniqueness before hashing; collisions break run-key integrity (§4.4).

---

## 3. Target Architecture

### 3.1 Physical deployment for the dev phase

```
┌───────────────────────────────┐        ┌──────────────────────────────────┐
│  M1 USER SIMULATOR (LLM)      │        │  M2 AGENT SERVER  (LiveKit)       │
│  persona prompt from task     │        │  hosted calling model            │
│  German, anrede-aware         │        │  STT → LLM(M2) → TTS + tools     │
└───────────────┬───────────────┘        └──────────────┬───────────────────┘
                │  text turns / audio (WebRTC)          │
                ▼                                       ▼
        ┌────────────────────────────────────────────────────┐
        │  THIS REPO (agent-starter-flutter)                  │
        │  · Scenario runner (benchmark-drive mode)           │
        │  · livekit_client.Session  → sendText / messages    │
        │  · pluggable MessageReceiver → timing + transcript  │
        └───┬────────────────────────────────────────────────┘
            │  JSON artifacts per call (results.json)
            ▼
        ┌────────────────────────────────────────────────────┐
        │  OFFLINE GRADER  (AI-eval-testing benchmark-tier)   │
        │  L1 deterministic intent match → expected_output     │
        │  L2 structured extraction                          │
        │  L3 LLM judge (helpfulness / guidance quality)      │
        │  L4 TAB tone vectors                                │
        └────────────────────────────────────────────────────┘
```

**Key rule:** this repo is the media/session layer and the *single-scenario debugger*, **not** the batch loader. Batch execution of thousands of runs belongs in a headless driver (could reuse the same Dart `Session` API in a CLI, or the Python runner from `AI-eval-testing`). This keeps UI widgets out of the measurement path.

**Prerequisite (out of scope here):** a LiveKit agent server that hosts M2. If M2 is strictly a SIP model, bridge it via the LiveKit **SIP gateway ingress/egress**; `callernbr` feeds the egress `from` number.

### 3.2 Role mapping from the CSV

| Benchmark actor | Source in `IVA_Test.csv` | Notes |
|---|---|---|
| Task | One row | Keyed by `intent_name` + variation |
| Goal | `description` | Handed to the M1 user-simulator prompt |
| Persona | `caller_name`, `gender`, `anrede` | Never expose `expected_output` to M1 |
| Opener | `scenario` | The user simulator's first utterance |
| Success criterion | `expected_output` (intent code) | Graded against the agent's detected/acted intent |
| Stratification | `Priorität`, `Ausgeschlossen` | Optional filtering |

> Because the CSV carries **no tool actions or environment state**, the dev-phase ground truth is **intent recognition + communication quality**. Environment-state grading (`R_DB`) is deferred until we attach mock tool/backend specs per intent (see §4.6 and §9).

---

## 4. Data Pipeline — CSV → Normalised Task Catalog

### 4.1 Artifacts produced (checked into the repo under `assets/benchmark/`)

```
assets/benchmark/
├── tasks_v1.json          # 1,000 normalized task specs
├── intents_v1.json        # 199-intent catalog (unique intent → metadata)
├── personas_v1.json       # persona table (name → gender/anrede clusters)
├── manifest.json          # schema version, source hash, generation timestamp
├── IVA_Test.csv           # frozen original (with SHA-256 recorded in manifest)
```

### 4.2 Canonical task schema

```json
{
  "schema_version": "1.0",
  "task_id": "RequestProofOfFunds#0001",
  "source_row": 1,
  "intent": {
    "name": "RequestProofOfFunds",
    "expected_output": "REQUEST_PROOF_OF_FUNDS"
  },
  "goal": "Caller needs an official letter or document confirming the funds available in their account.",
  "opener": "Mein Notar braucht einen Finanzierungsnachweis von meiner Bank",
  "persona": {
    "caller_name": "Ahmed Hassan",
    "gender": "männlich",
    "anrede": "Sie",
    "pronouns_de": ["er", "ihm"]
  },
  "metadata": {
    "callernbr": "496980884615",
    "priority": 11,
    "wrap_up_type": "arguedpositive",
    "contact_id": 1
  },
  "filters": {
    "excluded": false,
    "excluded_detail": null
  }
}
```

### 4.3 Loader / normaliser implementation

A single conversion tool (Dart script under `tool/`, or a Python generator that also feeds `AI-eval-testing`) with these steps:

1. Read CSV with a proper parser: strip BOM, `encoding: utf-8`, `delimiter: ';'`, honour quoting.
2. Validate required fields: `intent_name`, `expected_output`, `description`, `scenario`, `caller_name`, `gender`, `anrede`.
3. Reject/drop rows where `Ausgeschlossen == 'Ja'` (excluded) — record into `manifest.json#dropped`.
4. Enforce uniqueness of generated `task_id` (`intent_name` + zero-padded variation index).
5. Derive German pronouns from `gender` (`männlich → er/ihm`, `weiblich → sie/ihr`) — **never** infer from name.
6. Emit the four JSON artifacts + computed `SHA-256` of the frozen CSV into `manifest.json`.
7. Idempotent + deterministic output (sort keys, stable ordering) so git diffs are reviewable.

### 4.4 Versioning & integrity

- `intents_v1.json` is versioned as part of the repo; **never** mutate a released version — bump to `v2` on schema/intent changes.
- `manifest.json` stores source CSV hash so we can prove *task set == golden set* at evaluation time (a quiet but critical reproducibility control).

### 4.5 Persona prompts for M1

The M1 user-simulator prompt is generated per task from the persona fields:

```
You are {caller_name}, a {gender} bank customer from Germany.
Register: formality {anrede} ("Sie" = formal, "Du" = informal).
Your goal: {description}
You have no special knowledge beyond what a normal customer would have.
Do not reveal your goal unprompted; act naturally, ask follow-ups as a real customer would.
Do not volunteer the final confirmation — wait for the agent to earn it.
```

> Anti-cheating guardrail (from `AI-eval-testing`): `expected_output` is **never** included in this prompt.

### 4.6 Intent→tool/backend specs (deferred)

For the dev phase, scoring stops at intent + communication. Later, each unique intent gets a hand- or LLM-written mock spec (tool schema + desired state), enabling `R_DB`. `intents_v1.json` is the natural anchor for appending `tool_spec`/`desired_state` per intent without touching the task rows.

---

## 5. Repository Integration Points

### 5.1 LiveKit `Session` plumbing (already suitable)

`livekit_client.Session` is pluggable and measurement-ready:

- `Session(messages)` — ordered, role-typed transcript (`lib/controllers/app_ctrl.dart` reads it via `session.messages`).
- `Session.sendText(text)` — scripted / text-mode turn injection.
- `Session.connectionState` — call lifecycle (`disconnected → connecting → connected → disconnected`) already drives `appScreenState` in `AppCtrl._handleSessionChange` (`app_ctrl.dart:170`); reuse it as the per-call state machine.
- **Pluggable `MessageSender` / `MessageReceiver`** (`Session` factory `senders:` / `receivers:` params, `session_options`/`session.dart`) — inject a custom receiver that stamps per-message timestamps without touching widgets.
- `TranscriptionStreamReceiver` — agent + user transcripts for audio-mode capture.

### 5.2 New module: the benchmark-drive session

Add a self-contained module (e.g. `lib/benchmark/`) **alongside**, not inside, the UI path:

```
lib/benchmark/
├── task_loader.dart        # loads assets/benchmark/*.json
├── scenario_runner.dart    # orchestrates ONE task → session → artifact
├── call_recorder.dart      # custom MessageReceiver: timestamps, transcript, audio refs
└── report.dart             # writes results.json per run
```

`scenario_runner` flow for one task:

1. Construct a fresh `Session` (own `Room` + token source) with `call_recorder` as receiver.
2. `session.start()` → wait for `connected`.
3. `session.sendText(task.opener)` (text-mode) **or** start local audio capture (audio-mode).
4. Record turns via `call_recorder` until the agent signals task completion / turn budget / `max_turns` / timeout.
5. `session.end()`, flush recorder, write `results.json`.

### 5.3 Custom M1 + M2 testing session

The **M1 user-simulator** and **M2 LiveKit agent** testing session is the concrete
realisation of the benchmark-drive session described in §5.2. It is a headless
 Dart script (no `runApp`/widgets) that wires the `livekit_client.Session` to
 an M1-driven turn-exchange loop. Two execution modes are supported:

**Text‑mode (Phase 1)** — recommended for rapid iteration and CI:

1. **Session creation** (`benchmark/task_loader.dart` → `scenario_runner.dart`):
   - Read one task from `tasks_v1.json`.
   - Build a `sdk.Session` using the sandbox/endpoint token source (same logic as
     `AppCtrl._createSession` but with a per‑run `SandboxTokenSource` or a
     hardcoded dev token).
   - Attach a custom `MessageReceiver` - a built in livekit sdk feature (`call_recorder.dart`) that records:
     - `receivedText` + timestamp per turn
     - `sentText` + timestamp per turn
     - `connectionState` transitions
   - Store the `Session` reference for cleanup.

2. **M1 turn injection** (driver code, not inside the Flutter widget tree):
   - The external M1 process (Python/CLI/another Dart isolate) sends a turn to
     M2 via `session.sendText(text)`. In the headless test this is mocked or
     driven by a pre‑recorded script, but in the full loop M1 is an LLM that
     receives the agent's last message (`session.messages`) and returns the next
     utterance.
   - After `session.sendText`, await a short `await Future.delayed(Duration(milliseconds: 500))`
     to let the agent process the turn, then read `session.messages` to get the
     agent's response.

3. **Turn loop** (repeat until stop condition):
   - M1 sends `session.sendText(opener)` → wait → read `session.messages[-1].content`.
   - M1 formulates next turn (goal‑aware, persona‑constrained, no `expected_output`).
   - `session.sendText(nextTurn)` → wait → read response.
   - Terminate when:
     - Agent sends a `confirmation` or `goodbye` marker (detected via keyword or
       LLM‑based intent detection).
     - `max_turns` reached (configurable, default 10).
     - Timeout elapsed (configurable, default 60 s per turn).
   - All turns are timestamped by `call_recorder`; the final transcript is
     exported to `results/<task_id>/<run>.json`.

4. **Cleanup** (`scenario_runner.dart`):
   - `session.removeListener(customListener)`.
   - `await session.dispose()`.
   - `await room.dispose()`.
   - This mirrors `AppCtrl.cleanUp()` and satisfies the `unawaited_futures`
     lint rule.

**Audio‑mode (Phase 4)** — separate CI job; same runner but with TTS/ASR
intermediaries:

1. Same session setup, but `session.sendText` is **not** used for user turns.
2. M1’s turn is produced by a TTS service (e.g. Google Cloud Text‑to‑Speech) from
   the generated utterance text; the audio is fed into the LiveKit room via the
   local microphone track.
3. M2’s response audio arrives via the remote audio track; a
   `TranscriptionStreamReceiver` (already available in `livekit_components`)
   captures the STT text, which is appended to `session.messages`.
4. The same turn‑loop logic (M1→TTS→room→M2 ASR→text→M1) applies, with
   per‑turn latency measurements.
5. Results include both the raw transcript and the latency/quality metrics; the
   audio run is tagged `mode: audio` in `results.json` and scored **separately**
   from the text‑mode run (per benchmark rules §6).

**Shared plumbing** (both modes):

- **`call_recorder.dart`** implements `components.MessageReceiver` (or the
  lower‑level `sdk.MessageReceiver`) and stores:
  ```dart
  class CallRecorder implements sdk.MessageReceiver {
    final List<Turn> turns = [];
    void onReceivedMessage(sdk.ReceivedMessage msg) {
      turns.add(Turn(
        text: msg.content.text,
        direction: Direction.received,
        timestamp: DateTime.now(),
        connectionState: session.connectionState,
      ));
    }
    void onSessionStarted() => turns.add(Turn(
      text: 'session_started',
      direction: Direction.system,
      timestamp: DateTime.now(),
    ));
    // onSessionEnded, onError, etc. as needed
  }
  ```
- **`report.dart`** writes a JSON artifact per run:
  ```json
  {
    "task_id": "RequestProofOfFunds#0001",
    "run": 1,
    "mode": "text", // or "audio"
    "turns": [...],
    "final_transcript": "...",
    "intent_match": true/false,
    "duration_ms": 4230,
    "model_version": "m1-claude-3.5-sonnet",
    "temperature": 0.0,
    "judge_model": null
  }
  ```
- **Entry point** (`lib/main_benchmark.dart`, see §5.3 of the original plan):
  ```bash
  flutter run -t lib/main_benchmark.dart --dart-define=TASK_ID=RequestProofOfFunds#0001
  ```
  This script boots the `scenario_runner`, runs the M1↔M2 loop, and exits.
  Because it does not call `runApp`, the UI widgets, `MultiProvider`, and
  timers are completely absent from the measurement path, keeping `flutter test`
  and `flutter analyze` green.

### 5.4 No changes required in the UI

The golden set does **not** require modifying the existing screens, `AppCtrl`, or
token sourcing. `AppCtrl` remains the interactive single‑scenario debugger; the
benchmark module is fully additive and lives under `lib/benchmark/`.

---

Add a self-contained module (e.g. `lib/benchmark/`) **alongside**, not inside, the UI path:

```
lib/benchmark/
├── task_loader.dart        # loads assets/benchmark/*.json
├── scenario_runner.dart    # orchestrates ONE task → session → artifact
├── call_recorder.dart      # custom MessageReceiver: timestamps, transcript, audio refs
└── report.dart             # writes results.json per run
```

`scenario_runner` flow for one task:

1. Construct a fresh `Session` (own `Room` + token source) with `call_recorder` as receiver.
2. `session.start()` → wait for `connected`.
3. `session.sendText(task.opener)` (text-mode) **or** start local audio capture (audio-mode).
4. Record turns via `call_recorder` until the agent signals task completion / turn budget / `max_turns` / timeout.
5. `session.end()`, flush recorder, write `results.json`.

### 5.3 App entry point hooks

Add a **headless entry** (e.g. `lib/main_benchmark.dart`) that bypasses `runApp`/widgets entirely:

```
flutter run -t lib/main_benchmark.dart --dart-define=TASK_ID=RequestProofOfFunds#0001
```

This keeps the measurement path free of `MaterialApp`/`MultiProvider`/timers, and keeps `lib/main.dart` + widget tests untouched (`.github/workflows/test.yaml` stays green).

### 5.4 No changes required in the UI

The golden set does **not** require modifying the existing screens, `AppCtrl`, or token sourcing. `AppCtrl` remains the interactive single-scenario debugger; the benchmark module is additive.

---

## 6. Running a Benchmark Pass

```
choose task subset   →  for each task, N runs (N=3–5 for LLM variance per benchmark rules):
                          run task co-op (text-mode) or native audio (audio-mode)
                          write results/<task_id>/<run>.json
aggregate            →  intent-match stats, per-intent & per-tier breakdowns
grade (offline)      →  L1 deterministic | L2 structured | L3 LLM-judge | L4 TAB
publish              →  leaderboard table + variance/CI
```

- **Text-mode (Phase 1):** M1 user-simulator LLM exchanges text turns with M2 directly via `sendText`/`messages`. Fast, cheap, isolates dialogue policy.
- **Audio-mode (Phase 4):** M1 → TTS → room → M2 ASR → response. Report **separately** from text-mode (per benchmark rules — avoids conflating M2 failures with ASR/TTS failures).

---

## 7. Grading & Scoring (Offline)

Grading reuses the `AI-eval-testing` layered pipeline, with the CSV-derived ground truth:

```
L1  Deterministic  intent match   agent's detected/acted intent == task.expected_output
                   → also normalised-string match on transcript markers (confirmations)
L2  Structured     extraction     required fields/confirmations present in transcript
L3  LLM judge      rubric         guidance quality, helpfulness, no-confabulation
    (multi-sample, temp=0, discrete labels)
L4  TAB vectors    tone           cosine/subspace vs target tone ("warm, professional, reassuring")
```

**Composite (multiplicative):** `R = R_INTENT × R_COMM × R_POLICY(× R_TONE later)` — a missing confirmation zeroes the run, matching the benchmark's stance that a *helpful but task-incomplete* agent scores 0.

Per-run records carry the required audit tags: `model version`, `temperature`, `run count`, `judge model`, `task-suite version` (from `manifest.json`).

---

## 8. Phases & Verification Gates

| Phase | Deliverable | Gate |
|---|---|---|
| **P0 — Ingest** | Loader + normaliser (`tool/` or Python) emits `assets/benchmark/*.json`, `manifest.json` with CSV SHA-256 | 1,000 rows in, 0 dropped-unexpectedly, deterministic re-run yields identical artifacts |
| **P1 — Single-run harness** | `lib/benchmark/` + `main_benchmark.dart` runs 1 text-mode task, writes `results.json` | `flutter run -t lib/main_benchmark.dart --dart-define=TASK_ID=…` produces a valid artifact |
| **P2 — Intents catalog** | `intents_v1.json` reviewed; intents group-stratified (by category, difficulty proxy, `Priorität`, `Anzahl an Versuchen`) | 199 unique intents confirmed, 5-variation sets verified |
| **P3 — Grading** | Offline grader (Python, in `AI-eval-testing`) scores artifacts through L1–L3 | Pass/wrong/no-result/incomplete classification on a small manual-labelled subset is correct |
| **P4 — Batch run** | Headless batch driver runs the 1,000-task suite × 3–5 | CI-compatible: `flutter test` + lint stay green; batch completes without room/idle-timer leaks |
| **P5 — Audio mode + extensions** | TTS/ASR path, tone vectors, and per-intent tool/backend specs | Audio-mode scores reported separately; `R_DB` enabled for a pilot intent cluster |

Repo verification commands (mirror CI) run at every phase: `flutter pub get && dart format --set-exit-if-changed -l 120 . && flutter analyze --no-fatal-infos && flutter test`.

---

## 9. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| CSV is intent-label-only (no env/tool state) | Dev phase grades intent + communication; append tool specs per intent in `intents_v1.json` before enabling `R_DB` (P5) |
| German-only data + German M1 prompts | Keep UTF-8 end-to-end; choose German-strong judge models; spot-check salutations/pronouns in persona builder |
| Name≠gender mismatches in source | Derive pronouns from `gender` field only; never from name |
| This repo is a phone client, not a batch runner | UI module is additive; batch execution forks to a headless CLI using the same `Session` API (P4) |
| Non-determinism (2 stochastic LLMs) | Mandate N=3–5 runs/task, report CIs; single-run scores never published |
| Golden-set drift vs `AI-eval-testing` source | `manifest.json` hash + versioned intents; import tool is idempotent |
| LiveKit idle-timers/rooms leaking across thousands of runs | Run artifacts on fresh `Session`/`Room` per task; reuse the `appCtrl.cleanUp()`-style dispose pattern |

---

## 10. Post‑Development Handoff & Plug‑and‑Play Model Integration

After the development phase the repository can remain as the client’s production‑ready voice‑assistant app.  
The only thing the client may need to swap is the **M2 model** that lives behind the LiveKit room.  
The app’s token‑source layer (`AppCtrl._createSession`, `app_ctrl.dart:36‑63`) was designed exactly for this: changing the back‑end model does **not** require touching any UI widget, screen, or the `Session`‑driven flow.

Below are the two concrete scenarios the client may encounter and the minimal steps to switch between them.

### 10.1 Case A – “Raw” model (binary / compiled artefact the client hosts)

The client receives a raw model file (e.g. a TensorFlow‑Lite `.tflite`, an ONNX `.onnx`, or a small Go/Python binary) that they want to run **inside** a LiveKit agent process.

**What changes**

| Area | Action |
|------|--------|
| **LiveKit agent** | Package the raw model into a new LiveKit worker (Go, Node, or Python). The agent exposes an RPC method – e.g. `agent.chat(text)` – that runs inference and returns the transcript/intent. |
| **Token source** | The existing `if/else` chain in `app_ctrl.dart:_createSession` can be extended with a new branch that uses a **LiteralTokenSource** pointing at the client’s own LiveKit instance: <br>`const hardcodedServerUrl = 'wss://client‑livekit‑host.com'; const hardcodedToken = 'eyJ...';` <br>or, if the client prefers a sandbox, create a new sandbox ID and add it to `assets/.env`. |
| **UI / app code** | **No changes** – `AppCtrl.connect()`, `session.sendText()`, `session.messages`, and all screens continue to work exactly as before. The only visible difference is that the agent’s responses now come from the client‑provided model. |
| **Deployment** | Deploy the new agent Docker image (or binary) to the client’s infrastructure (self‑hosted LiveKit server or LiveKit Cloud). Update the `LIVEKIT_SANDBOX_ID` or token literal in the Flutter build config and rebuild. |
| **Benchmark continuity** | The `lib/benchmark/` module from the development phase can be reused; simply point its token source at the client’s new room/agent. The same `scenario_runner.dart` will drive the 1,000‑task suite against the new M2. |

**Minimal code tweak example** (add to `app_ctrl.dart:_createSession`):

```dart
// After the existing sandbox/endpoint blocks, add:
if (hardcodedServerUrl != null && hardcodedToken != null) {
  return sdk.Session.fromFixedTokenSource(
    sdk.LiteralTokenSource(
      serverUrl: hardcodedServerUrl,
      participantToken: hardcodedToken,
    ),
    options: sdk.SessionOptions(room: room),
  );
}
```

If the client supplies a sandbox ID, just add it to `assets/.env`; the existing `if (sandboxId == null …)` branch will automatically pick up `SandboxTokenSource`.

### 10.2 Case B – “Model endpoint” (REST / gRPC / HTTP service the client already runs)

The client already runs a model as an external service (e.g. a SageMaker endpoint, a FastAPI service, or an OpenAI‑compatible API). They want the LiveKit room to forward messages to that endpoint and get back the result.

**What changes**

| Area | Action |
|------|--------|
| **LiveKit worker (tiny proxy)** | Add a small LiveKit agent/worker that listens for incoming `session.sendText` messages, forwards the payload to the client’s endpoint (POST JSON), and returns the model’s reply via `session.sendText`. This worker can be a few lines of code (see the Node worker example in the “Custom M2” section of the plan). |
| **Token source** | Same as Case A – use a `LiteralTokenSource` or sandbox ID that points at the client’s LiveKit room where the proxy worker runs. No changes to the Flutter token logic are needed. |
| **UI / app code** | **No changes** – the flow `session.sendText → worker → endpoint → worker → session.messages → UI` is invisible to the widget tree. The conversation view displays the endpoint‑generated text exactly like any other turn. |
| **Deployment** | Deploy the proxy worker to the same LiveKit deployment the client uses for other agents. Update the room URL / token in the Flutter build config (again via `assets/.env` or a hard‑coded literal). |
| **Benchmark continuity** | The `scenario_runner.dart` already records every turn in `CallRecorder`; the extra hop through the endpoint is captured in the transcript, so the existing grading pipeline (L1‑L4) works unchanged. |

**Example minimal worker (Node.js)** – copied from the plan and adapted:

```js
// worker.js
const { Worker } = require('livekit-sdk');
const fetch = require('node-fetch');

worker.on('message', async (msg, from) => {
  if (msg.type !== 'model_request') return;
  const resp = await fetch('https://client-model-endpoint.com/translate', {
    method: 'POST',
    body: JSON.stringify(msg.payload),
    headers: { 'Content-Type': 'application/json' }
  });
  const data = await resp.json();
  worker.sendMessage({ type: 'model_response', text: data.translated }, from);
});

worker.start();
```

The Flutter side simply does `await session.sendText('{"type":"model_request","payload":"Hello"}')` and reads the reply from `session.messages`.

### 10.3 Quick checklist for the client

1. **Decide which case** (raw model vs. endpoint) the client prefers.  
2. **If raw model** – package it into a LiveKit agent, optionally containerise, and decide on token method (sandbox ID or literal token). Add the branch to `app_ctrl.dart:_createSession` if a new literal token is needed.  
3. **If endpoint** – spin up a tiny proxy worker (the snippet above) inside the same LiveKit room, point the token to that room, and ensure the worker’s endpoint URL is correct.  
4. **Update configuration** – either add `LIVEKIT_SANDBOX_ID=<new‑id>` to `assets/.env` **or** edit `app_ctrl.dart` to add the new `hardcodedServerUrl / hardcodedToken` literal.  
5. **Rebuild & test** – `flutter pub get && flutter run`. Verify that a simple `session.sendText('test')` appears in the conversation screen.  
6. **Run the benchmark suite** – use `lib/benchmark/scenario_runner.dart` (or the headless `main_benchmark.dart`) with the new token; the same 1,000‑task CSV will be processed against the client‑provided M2.  

Because the **UI, `AppCtrl`, and all screen widgets are model‑agnostic**, the handoff takes only a few configuration steps and a minimal amount of back‑end code (agent or worker). The bulk of the repository – the LiveKit session management, the `AppCtrl` state machine, the `Selector`-driven UI, and the benchmark runner – stays exactly the same, delivering a smooth plug‑and‑play experience for the client’s post‑development benchmarking needs.

---
 
## 11. Open Questions

1. M2 hosting: will we run the LiveKit agent server + SIP gateway ourselves, or does the client's model expose a WebSocket/HTTP endpoint we wrap in a LiveKit agent worker?
2. Should `assets/benchmark/` artifacts be generated at build time (from the CSV in `AI-eval-testing`) or committed frozen for reproducibility?
3. Which judge model for L3 (German Q&A helpfulness) — a Claude-family model per the benchmark docs, or a candidate also being evaluated?
4. Do we keep `anrede` per-row (Sie/Du) or normalise to `Sie` for the dev phase?
5. Target tier for dev: focus on the 199 unique intents once (coverage), or the 5-variation sets first (consistency)?