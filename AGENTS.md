# AGENTS.md

Flutter voice-assistant starter app built on the LiveKit Agents framework (`livekit_client` + `livekit_components`). State is driven by a single global controller. Targets iOS, macOS, Android, web.

## Commands

Verify before finishing a change — this matches CI (`.github/workflows/test.yaml`):

```bash
flutter pub get
dart format --set-exit-if-changed -l 120 .
flutter analyze --no-fatal-infos
flutter test
```

CI additionally builds the Android `apk` and `appbundle`. Run `flutter analyze` fully (warnings allowed) — don't treat `--no-fatal-infos` as "ignore infos".

## Env & token sourcing

- App loads `assets/.env` via `flutter_dotenv` in `lib/main.dart:8` — the file is **optional**. A root `.env` (0 bytes) does nothing; config lives under `assets/`. Copy `.env.example` → `assets/.env` and set `LIVEKIT_SANDBOX_ID`.
- Token selection lives in `lib/controllers/app_ctrl.dart:51-57` (`_createSession`): if `LIVEKIT_SANDBOX_ID` is unset/empty/placeholder, it falls back to the public LiveKit homepage token endpoint. No credential config → app still runs against a demo agent.
- To use a custom backend, replace the `EndpointTokenSource`/`SandboxTokenSource` here (also supports dev-only hardcoded `serverUrl`/`token` literals in the same function).

## Architecture

- `lib/app.dart:12` declares the **global singleton** `final appCtrl = AppCtrl()` and registers it (plus its `session`/`roomContext`) via `MultiProvider`. Screens/widgets read it through `provider` `Selector`s.
- `AppCtrl` (`ChangeNotifier`) owns the `Room` (via `livekit_components.RoomContext`) and the `Session`, and exposes `appScreenState`/`agentScreenState` plus micro/camera/screenshare toggles. Any state changed by public methods must call `notifyListeners()`.
- `Session` handles connection + message history (`session.messages`, `session.sendText`). App-level navigation (welcome ↔ agent) is driven by `session.connectionState` via `_handleSessionChange`; `appCtrl.connect()`/`disconnect()` switch explicitly.
- Main entry `lib/main.dart` loads dotenv before `runApp`.
- Shared UI colors in `lib/ui/color_pallette.dart` (light/dark `LKColorPalette`), not hardcoded hex — reuse these for new UI instead of inventing colors.

## Lints & format (analysis_options.yaml)

- Enforced: `prefer_single_quotes`, `prefer_final_locals`, `unawaited_futures`, `discarded_futures` (mark outstanding futures with `unawaited`). Formatter `page_width: 120`.
- Platform dirs are analyzer-excluded — keep `build/**` and `ios/**` excluded: `livekit_client` ships a `Package.swift` and SPM checkouts under `build/` otherwise get swept into analysis.

## Tests

- `test/widget_test.dart` builds the whole app, unmounts it, then calls `appCtrl.cleanUp()` inside `tester.runAsync` to stop the global controller's room/session and avoid pending-timer failures. Preserve that cleanup pattern when adding widget tests — don't create additional `AppCtrl` instances.
- Requires the `flutter_dotenv` load with a fake sandbox ID (`mergeWith`) before pumping the app.