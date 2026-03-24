# Frontend Error Handling

MedSim iOS now routes user-visible failures through `Networking/AppErrorPresenter.swift` instead of showing raw Swift or `NSError` text.

## User-facing messages

- `APIClientError` exposes user-safe default copy for invalid requests, invalid responses, auth expiry, decoding failures, and HTTP status fallbacks.
- `AppErrorPresenter` maps arbitrary `Error` values into `PresentableAppError`.
- Backend `detail` is only shown to users for safe, short, actionable `4xx` responses other than `401`.
- `5xx` responses, unsafe backend detail, and unknown errors fall back to generic copy.
- Cancellation errors are silent.

## Debug details

- UI surfaces render `title` and `message` only by default.
- `PresentableAppError` keeps `debugMessage`, `statusCode`, and `correlationID` for logs and debug-only UI.
- `InlineAppErrorView` exposes a debug disclosure in `DEBUG` builds so developers can inspect and copy those values without leaking them in release UX.

## Correlation IDs

- The client sends `X-Correlation-ID` on API requests.
- `APIClient` preserves correlation IDs from backend error payloads and falls back to the response header when available.
- Non-2xx responses are logged with method, path, status code, correlation ID, and backend detail through `OSLog`.
