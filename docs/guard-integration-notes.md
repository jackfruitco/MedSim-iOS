# Guard Framework Integration Notes

Integrates backend guard framework (simworks PR #437) into the iOS frontend.

## Heartbeat

- **Started** in `RunSessionStore.startConsole()` — a background `Task` sends `POST /api/v1/simulations/{id}/heartbeat/` every 15 seconds.
- **Stopped** in `RunSessionStore.stopConsole()` — the heartbeat task is cancelled.
- Failures are silently tolerated (fire-and-forget), matching the existing vitals task pattern.
- Only TrainerLab sends heartbeats. ChatLab does not (no live run console).

## TrainerLab: Paused / Runtime-Cap States

- `RunSessionStore.guardState` holds the latest `SimulationGuardState` from the backend.
- Guard state is fetched on: bootstrap, session refresh, transport reconnect, and after every run command.
- `canRunCommands` gates engine-progression controls (`start`, `pause`, `resume`, `stop`, `triggerRunTick`, `triggerVitalsTick`, `steerPrompt`) on `guardState.isEngineRunnable`.
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
  - A **denial banner** (via `InlineAppErrorView`) when `guardDenialMessage` is non-nil.

## API Endpoints

| Endpoint | Method | Used By |
|----------|--------|---------|
| `/api/v1/simulations/{id}/guard-state/` | GET | Both |
| `/api/v1/simulations/{id}/heartbeat/` | POST | TrainerLab |

## Shared Models

- `GuardContracts.swift` in `SharedModels` — `GuardState`, `PauseReason`, `DenialReason`, `GuardWarning` enums + `SimulationGuardState` DTO.
- All enums decode unknown values to `.unknown` without crashing.
- `SimulationGuardAPI` route enum in `Networking/APIClient.swift`.
- `APIClientError.isGuardDenied` helper for detecting 403 responses.

## Token Limits

Backend token-limit enforcement exists but hard caps may not be configured. The frontend does not assume a numeric token meter is always present. `warnings` may be empty, and `runtimeCapMinutes` may be nil.
