# livekit_voice_assistant — Repository Guide

A Flutter voice‑assistant starter app built on the **LiveKit Agents** framework
(`livekit_client` + `livekit_components`). Targets iOS, macOS, Android, and web.

---

## 1. Project Overview

The app lets a user connect to a LiveKit room, toggle camera/screenshare, send
text messages, and switch between a visualizer and transcription view of the
agent's audio/video. State is driven by a single global controller (`AppCtrl`),
and the UI reacts to the connection state automatically.

### Core Philosophy
- **Singleton controller** – `AppCtrl` is instantiated once in `lib/app.dart:12`
  and provided via `ChangeNotifierProvider.value` so every widget can read the
  same state.
- **Session‑driven UI** – screen navigation (`welcome` ↔ `agent`) is determined
  by `session.connectionState` through `_handleSessionChange` (`app_ctrl.dart:170`).
- **Provider‑based state** – UI reads `AppCtrl` fields through `Selector` widgets;
  any public method that changes state must call `notifyListeners()`.
- **Token‑source flexibility** – the app prefers a sandbox token (`LIVEKIT_SANDBOX_ID`)
  but falls back to a public homepage agent token when the env var is unset or a
  placeholder.
- **Optional env config** – the `assets/.env` file is **not required**; the app
  runs against a demo agent without it.

---

## 2. Directory Structure (root)

```
android/           # native Gradle files
ios/               # native CocoaPods files
macos/             # native macOS files
web/               # web deployment assets
assets/            # project assets (terminal.png) + optional assets/.env
.env               # local env override (0‑byte root .env does nothing)
.env.example       # template: LIVEKIT_SANDBOX_ID=<your-sandbox-id>
analysis_options.yaml  # lint/analysis configuration
pubspec.yaml       # Flutter dependencies
.taskfile.yaml     # task automation
.github/workflows/test.yaml  # CI workflow
lib/               # Dart source code
  main.dart        — app entry point
  controllers/     — AppCtrl (global session/controller)
  app.dart         — root widget + theming
  screens/         — WelcomeScreen, AgentScreen
  ui/              — color palettes (light/dark)
  widgets/         — reusable UI pieces
  support/         — helper widgets
test/              — widget tests
```

---

## 3. Core Files

### `lib/main.dart` (lines 1‑11)

```dart
void main() async {
  await dotenv.load(fileName: 'assets/.env', isOptional: true);
  runApp(const VoiceAssistantApp());
}
```

- Loads **optional** environment variables from `assets/.env` using
  `flutter_dotenv`.
- If the file is missing or `LIVEKIT_SANDBOX_ID` is absent, the app still
  starts — it will connect to the default LiveKit homepage agent token.
- Calls `runApp(const VoiceAssistantApp())` to launch the widget tree.

### `lib/app.dart` (lines 1‑97)

```dart
final appCtrl = AppCtrl();   // singleton

class VoiceAssistantApp extends StatelessWidget {
  // builds light/dark themes using LKColorPaletteLight/Dark
  // wraps widget tree in MultiProvider + components.SessionContext
  // home: Stack with AppLayoutSwitcher that shows WelcomeScreen or AgentScreen
}
```

- Declares the **global singleton** `final appCtrl = AppCtrl()` at line 12.
- `MultiProvider` registers three providers:
  - `ChangeNotifierProvider.value(value: appCtrl)` — the controller itself
  - `ChangeNotifierProvider.value(value: appCtrl.session)` — the LiveKit session
  - `ChangeNotifierProvider.value(value: appCtrl.roomContext)` — the room context
- `components.SessionContext` wraps the entire tree, providing LiveKit‑specific
  context (participant selectors, media device contexts, etc.).
- `VoiceAssistantApp` uses `AppLayoutSwitcher` to animate between
  `WelcomeScreen` (front) and `AgentScreen` (back) based on
  `appCtrl.appScreenState`.
- Theme is built from `LKColorPaletteLight` / `LKColorPaletteDark`.

### `lib/controllers/app_ctrl.dart` (lines 1‑191)

The heart of the app. `AppCtrl` extends `ChangeNotifier` and owns:

| Feature | Description |
|---|---|
| **States** | `appScreenState` (`welcome`/`agent`), `agentScreenState` (`visualizer`/`transcription`), plus booleans for camera, screenshare, send‑button enablement, session‑starting flag. |
| **Room & Session** | `late final sdk.Room room` (with `enableVisualizer: true`), `late final sdk.Session session`. |
| **Token sourcing** (`_createSession`, lines 36‑63) | 1. If hardcoded server+token are set → `Session.fromFixedTokenSource`.<br>2. Read `LIVEKIT_SANDBOX_ID` from dotenv.<br>   - If null/empty/placeholder → `EndpointTokenSource` pointing at `https://livekit.com/api/homepage-agent/token`.<br>   - Otherwise → `SandboxTokenSource(sandboxId: ...)`.<br>3. `Session.fromConfigurableTokenSource`. |
| **Connection** | `connect()` (`134`) — checks `isSessionStarting`, then `session.start()`. On `connected`, switches `appScreenState = AppScreenState.agent`.<br>`disconnect()` (`162`) — ends session, restores empty message history, resets screens to welcome/visualizer. |
| **Session listener** (`_handleSessionChange`, `170`) | Called whenever `session.connectionState` changes. Switches screen based on `ConnectionState.connected` → `agent`, `disconnected` → `welcome`, `connecting` → `null` (stay current). |
| **Cleanup** | `cleanUp()` (`88`) — removes listener, disposes `session`, `room`, `roomContext`, `messageCtrl`, `messageFocusNode`. Called from test and from `dispose()`. |
| **Listeners** | On construction (`85`) `session.addListener(_handleSessionChange)`. `messageCtrl.addListener` updates send‑button enablement. |
| **Utility actions** | `sendMessage()`, `toggleUserCamera()`, `toggleScreenShare()`, `toggleAgentScreenMode()`. All call `notifyListeners()` after mutating state. |

### `analysis_options.yaml` (lines 1‑50)

- Enforces lints: `prefer_single_quotes`, `prefer_final_locals`, `unawaited_futures`,
  `discarded_futures` (strict — forces marking outstanding futures with `unawaited`).
- Formatter `page_width: 120`, `trailing_commas: preserve`.
- Excludes platform directories (`build/**`, `ios/**`, `android/`, `web/` etc.) from
  analysis to avoid false positives from shipped dependencies.

### `pubspec.yaml` (lines 1‑104)

**Dependencies** (key ones):
- `livekit_components: ^1.3.1` — UI widgets (`VideoTrackWidget`,
  `AudioVisualizerWidget`, `ChatScrollView`, `ParticipantSelector`, …).
- `livekit_client: ^2.11.0` — SDK (`sdk.Session`, `sdk.Room`, token sources,
  connection state enums).
- `flutter_dotenv: ^6.0.0` — loads `assets/.env`.
- `provider: ^6.1.2` — `ChangeNotifierProvider`, `Selector`.
- `http`, `uuid`, `chat_bubbles`, `logging`, `intl`, etc.

**Assets**:
- `assets/` directory is declared; the optional `assets/.env` is read at runtime.
- `assets/terminal.png` is the image shown on `WelcomeScreen`.

### `test/widget_test.dart` (lines 1‑31)

```dart
void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await dotenv.load(
      fileName: 'assets/.env',
      isOptional: true,
      mergeWith: {'LIVEKIT_SANDBOX_ID': 'test'},
    );
    await tester.pumpWidget(const VoiceAssistantApp());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await appCtrl.cleanUp();   // disposes the global controller
    });
  });
}
```

- Loads dotenv with a **fake** `LIVEKIT_SANDBOX_ID: 'test'` so the app can
  build without a real sandbox ID.
- Pumps the app, then immediately calls `appCtrl.cleanUp()` inside
  `tester.runAsync` to avoid pending‑timer failures after the test unmounts the
  widget.

---

## 4. Screen Widgets

### `lib/screens/welcome_screen.dart`

- Displays the app logo (`assets/terminal.png`), a descriptive text with a link
  to the LiveKit voice‑AI quickstart docs, and an **AgentStatusIndicator**.
- Bottom button: `Consumer2<AppCtrl, Session>` builds a `Button` labelled
  `"Connecting"` or `"Start call"` depending on session state.
- On press → `appCtrl.connect()`.

### `lib/screens/agent_screen.dart`

The main agent interface. Key parts:

| Section | What it does |
|---|---|
| **AgentTrackView** (`15`) | Uses `AgentParticipantSelector` + `ParticipantContext` to pick the first video track or fallback audio track, then renders either `VideoTrackWidget` or `AudioVisualizerWidget` (5 bars). |
| **FrontView** (`64`) | `MediaDeviceContextBuilder` that provides `mediaDeviceCtx`. Layout consists of the track view (left, width 2/3) and, **only in transcription mode with camera opened**, a `ParticipantSelector` showing the local camera feed (right, 1/3). |
| **AgentScreen** (`108`) | `Selector<AppCtrl, AgentLayoutState>` that builds a `Stack` with `AgentLayoutSwitcher`. Shows `AgentStatusIndicator` (hidden when connected) in non‑transcription mode. |
| **Layout switching** | `AgentLayoutSwitcher` (`136`) handles four builders: `buildAgentView`, `buildCameraView`, `buildScreenShareView`, `transcriptionsBuilder`. |
| **Transcription area** (`173`) | When in transcription mode, shows `ChatScrollView` with message bubbles (`_MessageBubble`), and at the bottom a `MessageBar` for sending new messages. |
| **Camera toggle** (`157`) | `CameraToggleButton` inside the camera view lets the user flip front/back camera. |
| **Message input** (`200`) | `MessageBar` uses `AppCtrl.messageCtrl`, `messageFocusNode`, and `isSendButtonEnabled` to enable/disable the send button. Tapping send calls `AppCtrl.sendMessage()` which sends the text via `session.sendText()`. |

---

## 5. Widget Catalog

| Widget | File | Purpose |
|---|---|---|
| `ControlBar` | `lib/widgets/control_bar.dart` | Floating buttons for mic, camera, screenshare, end‑call. |
| `MessageBar` | `lib/widgets/message_bar.dart` | Input field + send button; disabled when `isSendButtonEnabled` is false. |
| `AgentStatusIndicator` | `lib/widgets/agent_status_indicator.dart` | Shows `"Waiting for agent"` / `"Agent is listening"`). |
| `AgentLayoutSwitcher` | `lib/widgets/agent_layout_switcher.dart` | Animated switcher between agent view, camera, screenshare, transcription. |
| `AppLayoutSwitcher` | `lib/widgets/app_layout_switcher.dart` | Front/back screen transition (welcome ↔ agent) with fade/slide. |
| `FloatingGlassButton` | `lib/widgets/floating_glass.dart` | Rounded transparent button with SF icons (used elsewhere). |
| `CameraToggleButton` | `lib/widgets/camera_toggle_button.dart` | Toggles front/back camera position. |
| `SessionErrorBanner` | `lib/widgets/session_error_banner.dart` | Display session‑ or agent‑related errors at the bottom of the stack. |
| `Button` (custom) | `lib/widgets/button.dart` | Simple raised/text button used on `WelcomeScreen`. |
| `AgentSelector` | `lib/support/agent_selector.dart` | Helper for selecting a participant (used in `AgentScreen`). |

All widgets reuse colors from `lib/ui/color_pallette.dart` (`LKColorPaletteLight/Dark`)
instead of hard‑coding hex values.

---

## 6. UI Color Palette

`lib/ui/color_pallette.dart` defines an abstract `AppColorPalette` and two
implementations:

- **`LKColorPaletteLight`** – light‑mode colors (e.g. `bg1: #DBDBD8`, `bg2: #F3F3F1`,
  `fg0: #FFFFFFFF`, `fg4: #707070`, `fgAccent: #002CF2`, …).
- **`LKColorPaletteDark`** – dark‑mode colors (e.g. `bg1: #070707`, `bg2: #131313`,
  `fg0: #000000`, `fg4: #666666`, `fgAccent: #002CF2`, …).

`VoiceAssistantApp.buildTheme()` in `lib/app.dart:17` picks the palette based on
the current `ThemeMode` and passes the colors to `ThemeData`.

---

## 7. How Modules Connect — Flow Diagram

```
main.dart
  └─► loads assets/.env (optional)
      └─► provides LIVEKIT_SANDBOX_ID to app_ctrl.dart

app.dart
  ├─► declares final appCtrl = AppCtrl()
  ├─► MultiProvider registers:
  │     • ChangeNotifierProvider.value(appCtrl)
  │     • ChangeNotifierProvider.value(appCtrl.session)
  │     • ChangeNotifierProvider.value(appCtrl.roomContext)
  ├─► components.SessionContext wraps the tree
  └─► VoiceAssistantApp.build() returns a MaterialApp whose home is a Stack:
       • AppLayoutSwitcher shows WelcomeScreen (front) / AgentScreen (back)
         based on appCtrl.appScreenState
       • SessionErrorBanner always present

AppCtrl (controller)
  ├─► _createSession() reads LIVEKIT_SANDBOX_ID → picks token source
  │     • SandboxTokenSource if ID set and not placeholder
  │     • EndpointTokenSource (public homepage) otherwise
  ├─► session.addListener(_handleSessionChange) on construction
  │     • _handleSessionChange switches appScreenState
  │       → connected → welcome becomes agent
  │       → disconnected → agent becomes welcome
  ├─► connect()
  │     • session.start()
  │     • on connected → appScreenState = agent → notifyListeners()
  │       UI (AppLayoutSwitcher) swaps to AgentScreen
  ├─► disconnect()
  │     • session.end()
  │     • message history reset
  │     • appScreenState = welcome, agentScreenState = visualizer
  │     • notifyListeners() → UI reverts to WelcomeScreen
  └─► user actions (sendMessage, toggleCamera, toggleScreenMode, …)
        → mutate state → notifyListeners()
        → UI updates via Selector widgets

Screens
  • WelcomeScreen: reads appCtrl.appScreenState + session.connectionState
    → shows Connecting/Start-call button → onPress → appCtrl.connect()
  • AgentScreen: reads appCtrl.agentScreenState, isUserCameEnabled,
    isScreenshareEnabled → renders AgentLayoutSwitcher with appropriate
    builder (agent view / camera / screenshare / transcription).
    • Consumer<AppCtrl> + Selector widgets drive dynamic UI.

Widgets
  • MessageBar → reads AppCtrl.messageCtrl, isSendButtonEnabled → enables/disables send.
  • AgentStatusIndicator → can be driven by session state.
  • All UI colors come from LKColorPaletteLight/Dark.
```

---

## 8. Architecture Patterns (summary)

| Pattern | Where it appears |
|---|---|
| **Singleton controller** | `lib/app.dart:12` (`final appCtrl = AppCtrl()`) + `ChangeNotifierProvider.value` |
| **Session‑driven UI** | `app_ctrl.dart:170` `_handleSessionChange` → `AppLayoutSwitcher` front/back |
| **Provider‑based state** | `Selector<AppCtrl, AppScreenState>`, `Selector<AppCtrl, AgentLayoutState>` throughout screens & widgets |
| **Token‑source flexibility** | `app_ctrl.dart:36‑63` `_createSession` — sandbox ID → SandboxTokenSource, else EndpointTokenSource |
| **Optional env config** | `main.dart:8` `dotenv.load(fileName: 'assets/.env', isOptional: true)` — app runs without it |
| **Cleanup discipline** | `cleanUp()` (`app_ctrl.dart:88`) called from test (`widget_test.dart:28`) and from `dispose()` (`app_ctrl.dart:101`) |
| **lints strict** | `analysis_options.yaml` enforces `unawaited_futures: true`, `discarded_futures: true`; code must mark outstanding futures with `unawaited` |

---

## 9. Adding New Features

1. **New state** – extend `AppCtrl` in `lib/controllers/app_ctrl.dart`, add a new enum value or bool, and be sure to call `notifyListeners()` in the setter.
2. **New screen** – create a widget under `lib/screens/`, then add its builder to `AppLayoutSwitcher` in `lib/app.dart` (front/back) or to `AgentLayoutSwitcher` in `lib/screens/agent_screen.dart`.
3. **New widget** – place it in `lib/widgets/`, reuse colors from `LKColorPaletteLight/Dark`, and read `AppCtrl` state via `Selector` or `Provider.of()`.
4. **New env var** – add `LIVEKIT_SANDBOX_ID=<your‑id>` to `assets/.env`; the token‑source logic in `_createSession` will automatically pick up a `SandboxTokenSource`.
5. **Tests** – follow `test/widget_test.dart`: load dotenv with `mergeWith: {'LIVEKIT_SANDBOX_ID': 'test'}`, pump the app, and call `appCtrl.cleanUp()` inside `tester.runAsync`.

---

## 10. Running the App

```bash
# from the repo root
flutter pub get          # install dependencies
flutter run              # launch (defaults to debug; env .env optional)
```

- Without `assets/.env` the app connects to the **public LiveKit homepage agent**.
- With `assets/.env` containing `LIVEKIT_SANDBOX_ID=your-sandbox-id`, it will use
  the sandbox token source.
- Lint/check: `flutter analyze` (excludes `build/`, `ios/`, `android/`, `web/` etc.).
- Format: `flutter format --set-exit-if-changed -l 120 .`
- Tests: `flutter test`

---