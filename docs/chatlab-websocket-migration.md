# ChatLab WebSocket Migration

ChatLab realtime is now WebSocket-only.

## What changed

- Removed ChatLab SSE transport code, SSE reconnection logic, stale-cursor handling, and SSE parser coverage.
- Added a dedicated `URLSessionWebSocketTask`-based ChatLab realtime client targeting `/ws/v1/chatlab/`.
- ChatLab bootstrap now comes from `getSimulation` plus `latest_event_id`, followed by conversation/message REST load, then websocket connect.
- Normal reconnect now uses `session.resume` with durable `last_event_id`.
- Hard resync now follows `session.resync_required`, performs a full REST bootstrap, resets replay state, and reconnects with `session.hello`.

## Handshake and replay

- Initial connect:
  - fetch simulation bootstrap
  - capture `latest_event_id`
  - open websocket
  - send `session.hello` with `simulation_id` and optional `last_event_id`
- Reconnect:
  - reopen websocket
  - send `session.resume` with `simulation_id` and current `last_event_id`
- Replay anchor rules:
  - `last_event_id` advances only after a durable event is successfully applied locally
  - transient websocket lifecycle events never become the replay anchor
  - duplicate durable events are ignored by `event_id`

## Remaining follow-up

- Monitor production logs for replay-window issues and close code `4409` frequency.
- If backend lifecycle payloads expand, keep the typed websocket payload models aligned with the backend contract first.
