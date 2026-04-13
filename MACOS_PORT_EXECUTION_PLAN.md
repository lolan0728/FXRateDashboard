# FX Rate Dashboard macOS Port Execution Plan

## Purpose

This document is the handoff spec for porting the current Windows WPF app to a
native macOS app with minimal trial-and-error. It captures:

- the current product behavior
- the data and state logic that must be preserved
- the exact UI sizes, colors, spacing, and interaction rules
- a recommended macOS architecture
- a step-by-step implementation plan that another Codex session on macOS can execute

The intent is to reduce re-discovery work and avoid repeatedly re-debugging
logic that already exists in the Windows version.

---

## Recommended macOS Target

### Primary recommendation

- Language: `Swift`
- UI: `SwiftUI`
- Minimum OS: `macOS 15+` preferred
- Interop: use `AppKit` only for:
  - status bar item / menu bar icon integration details
  - utility-window level behavior if SwiftUI scene APIs are insufficient
  - secure storage integration fallback details

### Why this target

- The app is a desktop utility widget, not a cross-platform content app.
- The UI is custom and window-behavior-heavy, which maps well to `SwiftUI + targeted AppKit`.
- `macOS 15+` gives the best native window APIs and easier scene/window management.

### Fallback note

If the target Mac must support `macOS 14`, keep the same architecture but expect
to use slightly more AppKit for window placement and window chrome.

---

## Product Summary

The app is a small desktop exchange-rate widget using Wise rate data. It has:

- a full mode with chart
- a compact mode without chart
- a settings window
- a tray/menu-bar menu
- offline cache fallback
- animated online/offline visual state changes

The current product style is:

- desktop utility / widget
- soft light palette with Wise-inspired green
- custom rounded surfaces
- compact dense layout
- Apple-stocks-widget-inspired information hierarchy

---

## Current Windows Behavior To Preserve

## Core product behavior

- Data source: Wise `GET /v1/rates`
- Currency pair is user-configurable
- Base amount is user-configurable
- Current value shown is `currentRate * baseAmount`
- Chart values are also multiplied by `baseAmount`
- Time ranges:
  - `1D`
  - `1W`
  - `1M`
  - `1Y`
- Cached data is used when network is unavailable
- Offline state changes the whole widget from “color photo” to “desaturated / grayscale”
- Online/offline palette transition is animated over `500ms`

## Window behavior

- Single main widget window
- Separate settings window
- Separate tray-style popup menu
- Main widget is borderless and custom-drawn
- Main widget is movable unless `Lock position` is enabled
- Window remembers last position between launches
- Window is not always on top
- Main widget has two modes:
  - `Full`
  - `Compact`

## Compact mode behavior

- Hide chart
- Hide range buttons
- Keep:
  - pair label
  - current value
  - quote currency
  - change amount
  - change percent
  - update time chip
  - `Wise`
- Compact update-time chip only shows `HH:mm`, not `Updated at:`

## Visibility/menu behavior

- Widget can be hidden and shown from tray/menu-bar menu
- Main widget right-click menu and tray menu should expose the same actions
- Mode toggle text changes dynamically:
  - `Compact Mode`
  - `Restore Full Mode`
- Visibility text changes dynamically:
  - `Hide Window`
  - `Show Window`

## Mode-switch edge behavior

This is the desired rule to preserve for the macOS port:

- If compact window is near the right edge, moving to full mode should move left first, then expand.
- If compact window is near the bottom edge, moving to full mode should move up first, then expand.
- Do not allow expansion to spill off-screen.
- The current Windows implementation uses an edge-aware pre-adjustment strategy, not a post-expand clamp.

Important: the macOS implementation should implement this behavior explicitly and
should not rely on the host windowing system to “fix it later.”

---

## Current Data / State Logic

## Settings model

Current logical settings from `AppSettings`:

- `BaseCurrency`
- `QuoteCurrency`
- `BaseAmount`
- `ActiveRange`
- `RefreshSeconds`
- `IsCompactMode`
- `WindowLeft`
- `WindowTop`
- `LockPosition`
- `LaunchAtStartup`
- `EncryptedWiseToken`

On macOS, keep the same logical model, but map storage/security differently.

## Polling logic

### Startup flow

1. Load settings
2. Apply window position
3. Load cached snapshot for current pair/range and present as offline
4. If no token:
   - remain offline
   - prompt settings
5. If token exists:
   - fetch history
   - fetch current rate
   - publish fresh online snapshot
   - start polling loops

### Ongoing polling

- Current rate refresh: every `RefreshSeconds`
- Historical data refresh: every `15 minutes`

### Time range mapping

From `RateQueryMapper`:

- `Day` -> from `now - 1 day`, group `minute`
- `Week` -> from `now - 7 days`, group `hour`
- `Month` -> from `now - 30 days`, group `day`
- `Year` -> from `now - 365 days`, group `day`

### Snapshot logic

From `RateMath.CreateSnapshot`:

- `CurrentRate` = latest known point or explicit override
- `ChangeAbsolute` = `currentRate - firstPointRate`
- `ChangePercent` = `(changeAbsolute / firstPointRate) * 100`
- `AsOfUtc` = latest point time or explicit override
- `IsStale` = whether the data is cached/offline

### Chart scaling

- Raw Wise rates are scaled by `BaseAmount` before chart display
- Main numeric display is scaled by `BaseAmount`
- Change amount is scaled by `BaseAmount`
- Percent change is not scaled

### Axis precision logic

From `RateMath.DetermineAxisDecimalPlaces`:

- Start at `2` decimals
- If any two tick labels are identical at that precision, increase precision
- Continue up to `8` decimals

This rule must be preserved on macOS for chart labels.

### Downsampling

- Chart point list is downsampled to at most `240` points

Preserve this to avoid unnecessary rendering overhead.

## Network behavior

### Wise API

- Base URL: `https://api.wise.com/`
- Current rate:
  - `v1/rates?source=USD&target=CNY`
- Historical rate:
  - `v1/rates?source=...&target=...&from=...&to=...&group=...`

### Auth

- HTTP header:
  - `Authorization: Bearer <token>`

### Timestamp parsing

Wise can return timezone offsets in `+0000` format. The client normalizes them
to `+00:00` before parsing. Preserve that logic on macOS.

### Error rules

- `401/403`: token invalid / insufficient permission
- `429`: rate limited
- other failure: generic request failure

### Proxy rule

Windows version explicitly bypasses system proxy for Wise requests because of
local proxy tools like Clash leaving stale proxy settings.

On macOS:

- Default to direct `URLSession`
- do not inherit ad hoc proxy behavior unless explicitly needed

---

## Persistence / Security Logic To Preserve

## Windows implementation

- Settings JSON path:
  - `%AppData%/FXRateDashboard/settings.json`
- Cache JSON path:
  - `%LocalAppData%/FXRateDashboard/cache`
- Token encryption:
  - Windows DPAPI, current user scope

## macOS equivalent

### Recommended storage mapping

- Settings file:
  - `~/Library/Application Support/FXRateDashboard/settings.json`
- Cache files:
  - `~/Library/Application Support/FXRateDashboard/cache/*.json`
- Token storage:
  - macOS Keychain

### Important rule

Do not write the raw Wise token into the JSON settings file.

Recommended pattern:

- `settings.json` stores a boolean like `hasToken` or a keychain lookup key
- actual token lives in Keychain only

This is better than trying to imitate DPAPI on macOS.

---

## Current Main Widget UI Specification

## Full mode size

From current app:

- Window size: `404 x 410`
- Outer margin: `10`
- Content padding: `18`
- Main corner radius: `28`

## Compact mode size

From current app:

- Window size: `236 x 122`
- Outer margin: `7`
- Content padding: `9,9,9,8`
- Main corner radius: `24`

## Typography and spacing

### Full mode

- Pair label font: `12`
- Pair label padding: `10,5`
- Status chip font: `11`
- Status chip padding: `8,4`
- Current value font: `42`
- Quote currency font: `13`
- Change font: `15`

### Compact mode

- Pair label font: `10`
- Pair label padding: `7,4`
- Status chip font: `9`
- Status chip padding: `7,3`
- Status chip minimum width: `40`
- Current value font: `27`
- Quote currency font: `10`
- Change font: `11`

## Layout structure

### Top row

Left:

- pair badge

Right:

- rounded status/update chip

### Middle

- big current value
- smaller quote currency code aligned to its upper-right area
- second line with:
  - change amount
  - change percent
  - `Wise` on the right in compact mode

### Full mode lower area

- rounded chart card
- bottom row with:
  - `1D`, `1W`, `1M`, `1Y`
  - `Wise` aligned right

### Compact mode lower area

- chart removed
- range row removed

---

## Color Specification

These colors are directly derived from the current implementation and should be
preserved unless intentionally redesigned.

## Brand / core colors

- Brand bright green: `#9FE870`
- Brand forest green / primary text: `#163300`

## Online palette

- Panel background: `#FBFCF8`
- Secondary surface / chart card: `#F2F7EA`
- Accent badge: `#9FE870`
- Primary text: `#163300`
- Muted text: `#6A745F`
- Positive: `#6C9A54`
- Negative: `#D97A68`
- Warning: `#C69200`
- Edge/border: `#1F163300`

## Offline palette

- Panel background: `#D2D9CA`
- Secondary surface: `#E1E5DE`
- Accent badge: `#B7BEB2`
- Primary text: `#52584F`
- Muted text: `#7D8479`
- Offline line color: `#8E9689`
- Status chip background: `#66FFFFFF`

## Status chip

- Online chip background: `#14FFFFFF`
- Offline chip background: `#66FFFFFF`

## Transition

- Online <-> offline palette transition duration: `500ms`

This should remain smooth on macOS. Recommended implementation:

- animate semantic colors at the view-model / state layer
- avoid abrupt full-window redraws with no interpolation

---

## Chart Specification

## Visual shape

- Rounded rectangle chart card
- No title inside chart in the current version
- Filled area below the line
- Last point marker with soft halo
- Horizontal and vertical grid lines
- Left-side numeric labels
- Bottom time labels

## Chart card geometry

Current chart rendering constants:

- Left plot margin: `46`
- Top plot margin: `10`
- Right plot margin: `10`
- Bottom plot margin: `66`
- Inner plot padding: `8`
- Axis label safe inset: `6`
- Edge tick lift: `8`

## Line rendering

- Stroke width: `2.2`
- Rounded line caps and joins
- Area fill uses vertical alpha gradient from stroke color

## Marker rendering

- Halo radius: `8`
- Solid marker radius: `4.5`

## Time label formatting

Based on chart span:

- <= 2 days: `HH:mm`
- <= 45 days: `MM-dd`
- <= 400 days: `yy-MM`
- > 400 days: `yyyy-MM`

## macOS recommendation

Implement chart using `Canvas` in SwiftUI, not `Charts`.

Reason:

- The Windows version uses highly custom geometry and precise margins.
- Matching the current appearance will be easier with custom drawing.

---

## Settings Window Specification

## Current size and behavior

- Width: `392`
- Height: content-driven
- Borderless custom window
- White surface
- Rounded outer corner radius: `24`
- Close button in the top-right corner

## Layout

Title:

- centered `Settings`

Form cards:

1. `Currency Pair`
2. `Base Amount`
3. `Refresh Interval`
4. `Wise API Token`
5. `Options`

Bottom:

- validation banner
- `Cancel`
- `Save`

## Settings card style

- Card background:
  - gradient from `#F8FBFE` to `#F3F7FB`
- Card corner radius: `16`
- Card padding: `10`
- Card border: `#E3EAF2`

## Settings palette

- Window background: `White`
- Window border: `#E8EDF4`
- Input background: `#FCFDFE`
- Input border: `#D7E0EA`
- Primary text: `#192332`
- Muted text: `#708093`
- Accent green: `#59C64A`
- Accent green dark: `#46B03A`

## Input style

- Height: `36`
- Corner radius: `16`
- Font size: `13`
- Font weight: semi-bold

## Buttons

### Secondary

- Size: `102 x 36`
- Radius: `18`

### Primary

- same size as secondary
- green gradient background:
  - top `#62D255`
  - bottom `#49B73F`

## Validation banner

- Background: `#FFF6EDEE`
- Border: `#F3C8CD`
- Text color: `#9C2E34`

## Token field behavior

- If token exists, show masked token
- If field is focused and has content, show clear `x` button
- Empty field on save means remove token
- Token validation happens when token changes

## macOS recommendation

Use a dedicated `Settings` scene or singleton settings window.

Do not embed settings inside the main widget view.

---

## Tray / Menu Bar Menu Specification

## Current items

- `Show Window` / `Hide Window`
- `Compact Mode` / `Restore Full Mode`
- `Settings`
- divider
- `Quit`

## Visual style

- Dark popup surface: `#1F2228`
- Border: `#343A44`
- Text: `#F5F7FA`
- Hover: `#2C313A`
- Pressed: `#353B46`
- Divider: `#343943`
- Corner radius: `16`
- Padding: `6`
- Shadow blur: `24`

## Interaction rules

- Menu hides on deactivation
- Tray/menu-bar actions and widget right-click actions must remain in sync

## macOS recommendation

Use:

- `MenuBarExtra` for the status item
- a standard menu-bar menu for simplicity first

If the exact dark floating custom popup is required later:

- add AppKit-backed custom status item popover

Do not start by reimplementing a custom popup menu unless necessary.

---

## Recommended macOS Architecture

## Scenes

### 1. Main widget window

- `WindowGroup(id: "main-widget")`
- borderless utility-style window
- custom drag region
- remembers position
- does not appear in Dock as a second document-style window

### 2. Settings window

- singleton `Window(id: "settings")` or dedicated settings scene

### 3. Menu bar extra

- `MenuBarExtra("FX Rate Dashboard", systemImage: ...)`

## Recommended file structure

```text
MacFXRateDashboard/
  App/
    FXRateDashboardApp.swift
    AppDelegate.swift
  Models/
    AppSettings.swift
    RatePoint.swift
    RateSeriesSnapshot.swift
    TimeRangePreset.swift
    RateHistoryQuery.swift
  Stores/
    SettingsStore.swift
    CacheStore.swift
    KeychainTokenStore.swift
  Services/
    WiseRateClient.swift
    RateQueryMapper.swift
    StartupLaunchService.swift
    WidgetWindowPlacementService.swift
  ViewModels/
    MainWidgetViewModel.swift
    SettingsViewModel.swift
  Views/
    MainWidgetWindowView.swift
    CompactWidgetView.swift
    FullWidgetView.swift
    SparklineChartView.swift
    SettingsView.swift
    StatusMenuContent.swift
  Support/
    RateMath.swift
    AppPaths.swift
    ColorPalette.swift
    WindowPlacementHelper.swift
    CurrencyCodeCatalog.swift
```

## State ownership

- `MainWidgetViewModel`: app-wide widget state
- `SettingsViewModel`: settings window only
- `AppSettings`: persistent value object
- `RateSeriesSnapshot`: current loaded snapshot

---

## macOS Implementation Mapping

## Windows -> macOS mapping

- `WPF Window` -> `SwiftUI window scene + AppKit tuning if needed`
- `NotifyIcon` -> `MenuBarExtra` / `NSStatusItem`
- `DPAPI token protection` -> `Keychain`
- `ApplicationData/LocalApplicationData` -> `Application Support`
- `Dependency Injection via Host` -> either:
  - `Factory container in App`, or
  - lightweight DI composition root in `FXRateDashboardApp`

## Services to preserve almost 1:1

- `WiseRateClient`
- `RateQueryMapper`
- `RateMath`
- `CacheStore`
- `SettingsStore`

These should be ported with behavior parity before UI polish.

---

## Implementation Order For macOS Codex

## Phase 1: Scaffold and data layer

Build first:

- app shell
- settings model
- paths
- cache store
- keychain token store
- Wise client
- range mapper
- rate math

Acceptance:

- fetch current and history rates from Wise
- save/load settings
- save/load cached snapshots
- token reads from Keychain

## Phase 2: Main widget state

Build:

- `MainWidgetViewModel`
- startup sequence
- current polling loop
- history polling loop
- offline/online palette state
- compact/full mode state

Acceptance:

- startup shows cached state first
- online refresh replaces cached state
- switching range refreshes correctly
- removing token keeps cached view and offline palette

## Phase 3: Full widget UI

Build:

- borderless main widget window
- full widget layout
- chart card
- custom chart canvas
- range buttons

Acceptance:

- full mode matches current layout hierarchy
- chart values and axis precision rules match Windows behavior
- online/offline palette transition animates smoothly

## Phase 4: Compact mode

Build:

- compact layout
- compact time chip
- compact mode animation
- right-click/context actions

Acceptance:

- compact mode matches current content set
- full -> compact -> full mode transitions preserve state

## Phase 5: Settings and menu bar

Build:

- settings window
- menu bar extra
- menu actions
- launch at login

Acceptance:

- settings edits update live widget state
- show/hide and mode toggle stay in sync
- menu bar behavior is stable

## Phase 6: Window placement edge behavior

Build:

- last window position restore
- edge-aware expansion
- drag handling

Acceptance:

- compact near right edge expands safely
- compact near bottom edge expands safely
- last position restore works after relaunch

---

## Recommended Acceptance Checklist

Before considering the macOS port complete, verify:

- Wise token can be entered, replaced, and cleared
- Current rate fetch works with the same Wise token
- History fetch works in all four ranges
- Base amount scales both value and chart labels
- Offline state preserves the last successful timestamp
- Offline palette is visibly desaturated
- Online/offline palette transition is smooth
- Compact mode removes chart and range controls
- Main widget remembers last position
- Edge-aware expansion behaves correctly
- Settings window does not block widget interaction incorrectly
- Menu bar actions match widget state
- Launch at login works

---

## Non-Goals For First macOS Port

Do not add these during the first port:

- multi-widget support
- notifications / alerts
- cloud sync
- iCloud settings
- cross-platform shared UI framework
- redesign of the visual language
- replacing custom chart with a different product style

The first goal is parity, not redesign.

---

## Direct Prompt For Codex On macOS

Use the following prompt in the macOS Codex session:

```text
Read MACOS_PORT_EXECUTION_PLAN.md first and implement the macOS version of FX Rate Dashboard with behavior parity to the Windows app.

Constraints:
- Preserve the current logic and UI hierarchy before redesigning anything.
- Use SwiftUI as the primary UI framework.
- Use AppKit only where SwiftUI scene/window/menu-bar APIs are insufficient.
- Store the Wise token in macOS Keychain, not in plain JSON.
- Persist settings and cache under Application Support.
- Implement full mode first, then compact mode, then settings/menu bar integration.
- Preserve:
  - base amount scaling
  - chart axis precision rules
  - offline cache fallback
  - online/offline palette transition
  - compact/full mode behavior
  - edge-aware window expansion

Execution order:
1. scaffold app and models/services
2. port data and polling logic
3. build full widget UI
4. build compact mode
5. build settings window
6. build menu bar integration
7. finish window positioning and launch-at-login

When uncertain, prefer parity with the Windows logic described in the plan over inventing a new macOS-only behavior.
```

---

## Notes For The macOS Session

- The current Windows codebase is the source of truth for behavior.
- If any behavior seems odd but user-visible, preserve it first.
- If a macOS API makes exact parity hard, implement the closest stable desktop-native version and document the difference clearly.
