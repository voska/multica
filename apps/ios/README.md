# @multica/ios

Native SwiftUI client for Multica. Companion app for triaging issues, watching agents, and overseeing autopilots from iOS.

## Stack

- SwiftUI + Swift 6 (strict concurrency)
- `@Observable` state, `NavigationStack` with value-typed paths per tab
- async/await `URLSession` networking, Keychain token storage
- XcodeGen for reproducible project generation
- No third-party runtime dependencies
- iOS 18.0 deployment target, builds against the iOS 26 SDK

## Position in the monorepo

```
apps/
  web/         Next.js — primary client
  desktop/     Electron — reuses packages/* directly
  docs/        Mintlify
  ios/         <— this app
packages/
  core/        Cross-platform business logic (types, queries, stores, WS client)
  ui/          shadcn primitives (web-only)
  views/      Page-level React DOM views (web-only)
```

Why native Swift instead of React Native or Capacitor: `packages/views` and `packages/ui` are React DOM, so they don't carry over to RN or to native. What we share with the rest of the monorepo is the **data contract**, which we keep aligned via codegen from `packages/core/types` (see "Type codegen" below).

## Run

```bash
pnpm --filter @multica/ios codegen      # regenerate Swift types from packages/core/types
pnpm --filter @multica/ios generate     # xcodegen
pnpm --filter @multica/ios build        # compile for generic iOS
pnpm --filter @multica/ios test         # XCTest on iPhone 17 Pro Simulator
pnpm --filter @multica/ios build:device # signed Debug build for Matt's physical iPhone
```

Or open `apps/ios/Multica.xcodeproj` in Xcode after `pnpm --filter @multica/ios generate`.

## Type codegen

`scripts/codegen-types.mjs` parses TypeScript interfaces in `packages/core/types/` and emits Swift `Codable` structs under the `Generated` namespace in `Multica/Models/Generated.swift`. Dependency-free regex walker — no `tsc`, no `quicktype`.

Today this is a parallel namespace next to the hand-written `Models.swift` types — meant to detect drift, not yet the source of truth at call sites. Migration plan: switch one consumer at a time over to `Generated.*`, then delete the matching hand-written type.

## Server target

The first launch picks a server URL: `https://app.multica.ai`, your self-hosted Multica, or a custom HTTPS host. Tokens are stored in Keychain scoped to the host. Auth is email OTP or a bearer/PAT.

## Five tabs

1. **Inbox** — primary timeline, time-bucketed feed, live-agents strip. Workspace switcher in the principal toolbar slot.
2. **Issues** — grouped by status, scope filter (Open / Mine / Agents / All), swipe to act.
3. **Agents** — segmented Agents | Squads, live/online/offline groupings.
4. **Autopilots** — active / paused sections, swipe Run / Pause / Activate, detail with triggers + runs.
5. **You** — profile, workspace, server, account, about.

## Debug helpers

Two `#if DEBUG`-only env vars on launch:

```bash
SIMCTL_CHILD_MULTICA_MOCK=1 \
SIMCTL_CHILD_MULTICA_TAB=issues \
  xcrun simctl launch booted ai.multica.mobile
```

- `MULTICA_MOCK=1` — seeds the store with mock data; skips network bootstrap.
- `MULTICA_TAB=issues|agents|autopilots|you` — sets the initial tab.

Neither ships to release builds.

## Code signing

Default team is `T2D59CP243` (Matthew Voska, personal). Override in `project.yml` if building for a different team. Bundle ID is `ai.multica.mobile`.

## Prior art on mobile in this repo

- `multica-ai/multica#360` — closed native SwiftUI MVP PR.
- `multica-ai/multica#966` — open Expo MVP PR.
- `multica-ai/multica#2337` — open Expo/React Native iOS first-version PR.

This `apps/ios` directory is the canonical native iOS client going forward.
