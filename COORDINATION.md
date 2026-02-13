# Coordination

## UI Phase 2 Screen Structure
ChatScreen (`lib/app.dart`) now hosts the Mission Control layout driven by the design system.

Primary sections
- Header row with mission summary and connection status pill.
- Session setup card with operator name, gateway URL, connect/disconnect actions, and Rust greeting.
- Chat stream panel with `ChatBubble` entries rendered by `ListView.builder`.
- Composer bar for sending outbound messages.

State management
- Riverpod providers live in `lib/app.dart`.
- `gatewayServiceProvider` injects `GatewayService` via `ProviderScope` overrides.
- `chatControllerProvider` manages `ChatState` (connection status and chat messages).

## Localization Rule (CN-only Phase)
- All user-facing UI strings MUST be Chinese.
- Do not introduce English placeholders, labels, helper text, empty states, or status text.
- Exception: keep non-translatable protocol literals/keys/command tokens in their required original form only when technically impossible to localize.
