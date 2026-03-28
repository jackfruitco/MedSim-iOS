# Guard Framework Integration Notes

Integrates backend guard framework (simworks PR #437) into the iOS frontend.

## Backend Contract

The frontend `SimulationGuardState` DTO maps 1:1 to the backend `GuardStateOut` schema:

| Backend field | Swift property | Type |
|---|---|---|
| `guard_state` | `guardState` | `GuardState` enum |
| `pause_reason` | `pauseReason` | `PauseReason?` enum |
| `engine_runnable` | `engineRunnable` | `Bool` |
| `active_elapsed_seconds` | `activeElapsedSeconds` | `Int` |
| `runtime_cap_seconds` | `runtimeCapSeconds` | `Int?` |
| `wall_clock_expires_at` | `wallClockExpiresAt` | `String?` |
| `warnings` | `warnings` | `[GuardWarning]` |
| `denial_reason` | `denialReason` | `DenialReason?` enum |
| `denial_message` | `denialMessage` | `String?` |

Both `GET /guard-state/` and `POST /heartbeat/` return `GuardStateOut`.

## Heartbeat

- **Started** in `RunSessionStore.startConsole()` — a background `Task` sends `POST /api/v1/simulations/{id}/heartbeat/` every 15 seconds with `{ "client_visibility": "unknown" }`.
- **Stopped** in `RunSessionStore.stopConsole()` — the heartbeat task is cancelled.
- The heartbeat response returns the full guard state, which is applied to the store immediately.
- Only TrainerLab sends heartbeats. ChatLab does not (no live run console).

## TrainerLab: Paused / Runtime-Cap States

- `RunSessionStore.guardState` holds the latest `SimulationGuardState` from the backend.
- Guard state is fetched on: bootstrap, session refresh, transport reconnect, and after every run command.
- `canRunCommands` gates engine-progression controls (`start`, `pause`, `resume`, `stop`, `triggerRunTick`, `triggerVitalsTick`, `steerPrompt`) on `guardState.engineRunnable` (uses the backend flag directly).
- `canMutateCommands` / `canInterventionCommands` remain independent — manual record actions (interventions, annotations, notes) stay available while the engine is guard-paused.
- `RunConsoleView` shows:
  - A **warning banner** when `guardState.warnings` includes `APPROACHING_RUNTIME_CAP`.
  - A **pause overlay** for resumable pauses (`pausedInactivity`, `pausedManual`) with a Resume button.
  - A **terminal card** for `pausedRuntimeCap` and `ended` states via the existing terminal card overlay.

## ChatLab: Send Locks

- `ChatRunStore.guardState` is fetched on bootstrap and foreground resume.
- When `create_message` or `retry_message` returns HTTP 403, `ChatRunStore` fetches guard state immediately.
- `isConversationLocked()` additionally checks `guardState.shouldLockChatSending`, locking the composer.
- The transcript remains fully readable — only the composer input and send/retry controls are disabled.
- `ChatRunView` shows:
  - A **guard warning banner** when `guardState.warningMessage` is non-nil.
  - A **denial banner** (via `InlineAppErrorView`) when `guardDenialMessage` is non-nil — prefers backend-provided `denial_message`, falls back to per-reason defaults.

## API Endpoints

| Endpoint | Method | Request Body | Response | Used By |
|----------|--------|-------------|----------|---------|
| `/api/v1/simulations/{id}/guard-state/` | GET | — | `GuardStateOut` | Both |
| `/api/v1/simulations/{id}/heartbeat/` | POST | `{ "client_visibility": "..." }` | `GuardStateOut` | TrainerLab |

## Shared Models

- `GuardContracts.swift` in `SharedModels` — `GuardState`, `PauseReason`, `DenialReason`, `GuardWarning` enums + `SimulationGuardState` DTO + `HeartbeatRequest`.
- All enums decode unknown values to `.unknown` without crashing.
- `SimulationGuardAPI` route enum in `Networking/APIClient.swift`.
- `APIClientError.isGuardDenied` helper for detecting 403 responses.

## Token / Runtime Limits

Backend runtime caps vary by plan (Go: 20m, Plus: 30m, MedSim One Plus: 45m). The frontend does not assume caps are always present — `runtimeCapSeconds` may be nil, and `warnings` may be empty. The `remainingMinutes` computed property converts seconds to minutes for display.
