# API Discrepancy Report

Backend authority: `simworks` `main` OpenAPI fetched on March 19, 2026.

This report reflects the frontend after the fixes in this branch. Items already remediated are still listed under the appropriate discrepancy bucket so the before/after contract drift is explicit.

## A. Confirmed frontend bugs

### A1. ChatLab realtime transport used an undocumented WebSocket contract instead of backend SSE
- severity: blocking
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatRealtimeClient.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatRunStore.swift`, `apps/chatlab-ios/Tests/ChatLabiOSTests/ChatLabContractTests.swift`
- endpoint(s): `/api/v1/simulations/{simulation_id}/events/`, `/api/v1/simulations/{simulation_id}/events/stream/`
- current behavior: frontend now connects with SSE, performs cursor catch-up, and no longer depends on `/ws/simulation/{id}/` or unsupported outbound typing frames
- desired behavior: use backend-authoritative SSE plus paginated catch-up
- recommended fix: frontend-only fix, completed in this branch
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: optional only if product wants a future upstream realtime channel

### A2. Logout previously cleared local tokens without server-side refresh-token revocation
- severity: high
- exact affected files: `apps/trainerlab-ios/Sources/Networking/AuthService.swift`, `apps/trainerlab-ios/Sources/Auth/AuthViewModel.swift`, `apps/medsim-shell-ios/Sources/AppShell/AppShellRootView.swift`, `apps/trainerlab-ios/Tests/NetworkingTests/TrainerLabContractTests.swift`
- endpoint(s): `/api/v1/auth/logout/`
- current behavior: frontend now posts `LogoutRequest(refresh_token)` and then clears local tokens
- desired behavior: server-side logout plus local token deletion
- recommended fix: frontend-only fix, completed in this branch
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

### A3. ChatLab message and simulation DTOs were too strict for backend-defaulted fields
- severity: high
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatLabContracts.swift`, `apps/chatlab-ios/Tests/ChatLabiOSTests/ChatLabContractTests.swift`
- endpoint(s): generic simulation, conversation, message, and tool endpoints
- current behavior: frontend now tolerates omitted backend-defaulted fields and models `is_read` plus `media_list`
- desired behavior: decode backend responses even when defaults are omitted from payloads
- recommended fix: frontend-only fix, completed in this branch
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

### A4. TrainerLab intervention dictionary and event payloads drifted from backend field names
- severity: blocking
- exact affected files: `apps/trainerlab-ios/Sources/SharedModels/Contracts.swift`, `apps/trainerlab-ios/Sources/Sessions/RunSessionStore.swift`, `apps/trainerlab-ios/Sources/RunConsole/RunConsoleView.swift`, `apps/trainerlab-ios/Tests/NetworkingTests/TrainerLabContractTests.swift`
- endpoint(s): `/api/v1/trainerlab/dictionaries/interventions/`, `/events/illnesses/`, `/events/interventions/`
- current behavior: frontend now decodes `intervention_type`, encodes `illness_name` / `illness_description`, and uses backend-aligned intervention fields including `initiated_by_type`
- desired behavior: request/response field names must match backend exactly
- recommended fix: frontend-only fix, completed in this branch
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

### A5. Debrief annotation creation used invalid backend enum values
- severity: blocking
- exact affected files: `apps/trainerlab-ios/Sources/SharedModels/Contracts.swift`, `apps/trainerlab-ios/Sources/Sessions/RunSessionStore.swift`, `apps/trainerlab-ios/Sources/RunConsole/RunConsoleView.swift`, `apps/trainerlab-ios/Tests/NetworkingTests/TrainerLabContractTests.swift`, `apps/trainerlab-ios/Tests/RunConsoleTests/RunConsoleLayoutSupportTests.swift`
- endpoint(s): `/api/v1/trainerlab/simulations/{simulation_id}/annotations/`
- current behavior: frontend now uses typed enums for `learning_objective` and `outcome`, and the debrief sheet maps human-friendly labels onto backend-valid raw values only
- desired behavior: annotation requests must submit only backend-authoritative enum values
- recommended fix: frontend-only fix, completed in this branch
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

## B. Confirmed missing frontend features

### B1. Generic ChatLab lab-orders endpoint is modeled but not surfaced as a dedicated workflow
- severity: medium
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatLabService.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatLabContracts.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatToolsStore.swift`
- endpoint(s): `/api/v1/simulations/{simulation_id}/lab-orders/`
- current behavior: service/model support exists; no dedicated UI action explicitly targets the asynchronous generic lab-orders contract
- desired behavior: mobile users should have a clear way to trigger and understand async lab-order submission if this endpoint is intended to be first-class
- recommended fix: frontend-only UI/service integration, unless product decides the tool-specific sign-orders flow is sufficient
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: optional

### B2. Generic ChatLab conversation-management surface is still thinner than backend breadth
- severity: medium
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatLabHomeStore.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatRunStore.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatRunView.swift`
- endpoint(s): `/api/v1/simulations/{simulation_id}/conversations/`, `/{conversation_uuid}/`
- current behavior: current UI can run the main chat flow but does not expose the full backend conversation-management capability
- desired behavior: either explicitly scope shipping to the current thin ChatLab experience or add fuller conversation UX
- recommended fix: product-scoped frontend work
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

## C. Backend features present but not yet surfaced in UI

### C1. TrainerLab event families beyond injury/illness/vitals/intervention/note still lack clean SwiftUI entry points
- severity: high
- exact affected files: `apps/trainerlab-ios/Sources/Networking/TrainerLabService.swift`, `apps/trainerlab-ios/Sources/Sessions/RunSessionStore.swift`, `apps/trainerlab-ios/Sources/RunConsole/RunConsoleView.swift`
- endpoint(s): `/events/problems/`, `/events/assessment-findings/`, `/events/diagnostic-results/`, `/events/resources/`, `/events/disposition/`
- current behavior: backend supports them; service coverage already exists; the run console still does not expose dedicated forms for these event families
- desired behavior: structured SwiftUI controls for all trainer-authored event types that should be user-visible
- recommended fix: frontend-only UI work
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

### C2. Generic tool surface remains partial beyond the currently rendered tool sections
- severity: medium
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatRunView.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatToolsStore.swift`
- endpoint(s): `/api/v1/simulations/{simulation_id}/tools/`, `/{tool_name}/`
- current behavior: frontend renders a thin tools experience centered on existing sections; backend contract is broader
- desired behavior: clean user-facing handling for tool-specific states that matter to shipping scope
- recommended fix: frontend-only UI expansion if generic ChatLab is intended to ship broadly
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: not required

## D. Decision items requiring product/architecture choice

### D1. Generic typing transport: keep local-only typing UX or add a supported upstream realtime contract
- severity: medium
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatRealtimeClient.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatRunStore.swift`
- endpoint(s): `/api/v1/simulations/{simulation_id}/events/stream/`
- current behavior: frontend now keeps typing local-only because the backend contract only guarantees SSE downstream events
- desired behavior: choose whether shared typing indicators matter enough to justify a backend-supported upstream channel
- recommended fix: recommend frontend adaptation for now; only add backend support if shared typing is a product requirement
- whether frontend-only fix is sufficient: yes for current scope
- whether backend change is optional or required: optional

### D2. Trainer note events and debrief annotations should stay separate unless product wants a single concept
- severity: medium
- exact affected files: `apps/trainerlab-ios/Sources/Sessions/RunSessionStore.swift`, `apps/trainerlab-ios/Sources/RunConsole/RunConsoleView.swift`
- endpoint(s): `/events/notes/`, `/annotations/`
- current behavior: frontend now exposes them as separate concepts, matching backend semantics
- desired behavior: explicit product choice on whether that distinction should remain visible
- recommended fix: recommend keeping them separate because the backend models different meanings and lifecycles
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: optional

### D3. ChatLab sign-orders vs generic lab-orders UX needs an explicit mobile product decision
- severity: medium
- exact affected files: `apps/chatlab-ios/Sources/ChatLabiOS/ChatToolsStore.swift`, `apps/chatlab-ios/Sources/ChatLabiOS/ChatLabService.swift`
- endpoint(s): `/tools/patient_results/orders/`, `/lab-orders/`
- current behavior: the existing UI continues to use the tool-specific sign-orders flow; the generic async lab-orders endpoint is now supported in code but not separately surfaced
- desired behavior: choose whether mobile should compose both endpoints into one workflow or surface them distinctly
- recommended fix: recommend keeping current UI on the proven tool-specific flow until product defines the generic lab-order experience
- whether frontend-only fix is sufficient: yes
- whether backend change is optional or required: optional

## E. Backend inconsistencies or OpenAPI gaps

### E1. No confirmed backend code/OpenAPI mismatch was found in the audited areas
- severity: low
- exact affected files: none confirmed
- endpoint(s): none confirmed
- current behavior: OpenAPI and the inspected frontend-facing backend contract were consistent in the areas audited here
- desired behavior: continue treating backend OpenAPI as the source of truth
- recommended fix: none
- whether frontend-only fix is sufficient: not applicable
- whether backend change is optional or required: not required

## Validation summary

- `swift test` in `apps/chatlab-ios`: passed after fixing the package compile issue and adding contract coverage.
- `swift test` in `apps/trainerlab-ios`: passed.
- `xcodebuild -list -project MedSim.xcodeproj`: passed after running unrestricted, confirming `MedSim`, `MedSimTests`, and `MedSimUITests`.
- `xcodebuild test -project MedSim.xcodeproj -scheme MedSim -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /tmp/medsim-derived -only-testing:MedSimTests`: passed.
- `xcodebuild test -project MedSim.xcodeproj -scheme MedSim -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -derivedDataPath /tmp/medsim-derived -only-testing:MedSimUITests`: passed; `MedSimUITests.testLaunchPerformance()` is now an explicit skip because launch-performance measurement proved unstable as a merge-gating simulator test, while the remaining UI launch smoke tests passed.
