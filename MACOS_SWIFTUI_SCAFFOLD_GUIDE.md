# FX Rate Dashboard macOS SwiftUI Scaffold Guide

## Purpose

This file is the practical scaffold guide for building the macOS version.

Use it together with:

- [MACOS_PORT_EXECUTION_PLAN.md](/C:/Users/vampi/source/FX Rate Dashboard/MACOS_PORT_EXECUTION_PLAN.md)

The execution plan explains behavior and product rules.  
This scaffold guide explains what files to create first and what each file should own.

---

## Recommended Project Setup

## Xcode project

- Project name: `FXRateDashboard`
- Language: `Swift`
- UI: `SwiftUI`
- Testing: `XCTest`
- Deployment target:
  - preferred: `macOS 15.0+`
  - acceptable fallback: `macOS 14.0+`

## Scene model

Use these scenes:

1. `WindowGroup(id: "main-widget")`
2. `Settings` or a dedicated singleton settings window
3. `MenuBarExtra`

Recommended result:

- app launches main widget window
- menu bar extra stays available at all times
- settings is a separate window, not embedded in widget UI

---

## Recommended Folder Structure

```text
FXRateDashboard/
  App/
    FXRateDashboardApp.swift
    AppBootstrap.swift
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
    LaunchAtLoginService.swift
    WidgetWindowPlacementService.swift
  ViewModels/
    MainWidgetViewModel.swift
    SettingsViewModel.swift
    MenuBarViewModel.swift
  Views/
    MainWidgetWindowView.swift
    FullWidgetView.swift
    CompactWidgetView.swift
    WidgetTopBarView.swift
    WidgetValueSectionView.swift
    WidgetFooterView.swift
    SparklineChartView.swift
    SettingsView.swift
    MenuBarMenuView.swift
  Support/
    AppPaths.swift
    ColorPalette.swift
    RateMath.swift
    CurrencyCodeCatalog.swift
    WindowPlacementHelper.swift
    WidgetMetrics.swift
  Tests/
    RateMathTests.swift
    RateQueryMapperTests.swift
    WindowPlacementHelperTests.swift
    SettingsStoreTests.swift
    WiseRateClientTests.swift
```

---

## File-by-File Responsibilities

## App layer

### `App/FXRateDashboardApp.swift`

Owns:

- app entry point
- scene declarations
- root dependency injection wiring

Should create:

- one shared `AppBootstrap`
- one shared `MainWidgetViewModel`
- one shared `MenuBarViewModel`

Should declare:

- `WindowGroup(id: "main-widget")`
- `Settings`
- `MenuBarExtra`

### `App/AppBootstrap.swift`

Owns:

- long-lived service creation
- composition root

Should construct:

- `SettingsStore`
- `CacheStore`
- `KeychainTokenStore`
- `WiseRateClient`
- `RateQueryMapper`
- `LaunchAtLoginService`
- `MainWidgetViewModel`

This replaces the Windows `Host.CreateDefaultBuilder()` composition.

### `App/AppDelegate.swift`

Use only if needed for:

- activation policy tweaks
- menu bar behavior tuning
- AppKit fallback hooks

Keep this minimal.

---

## Models

### `Models/AppSettings.swift`

Mirror Windows `AppSettings`.

Properties:

- `baseCurrency: String`
- `quoteCurrency: String`
- `baseAmount: Decimal`
- `activeRange: TimeRangePreset`
- `refreshSeconds: Int`
- `isCompactMode: Bool`
- `windowOriginX: Double?`
- `windowOriginY: Double?`
- `lockPosition: Bool`
- `launchAtStartup: Bool`
- `hasStoredToken: Bool`

Important:

- do not store the token itself here
- token lives in Keychain

Methods:

- `normalized() -> AppSettings`

### `Models/RatePoint.swift`

Same as Windows:

- `timestampUTC: Date`
- `rate: Decimal`

### `Models/RateSeriesSnapshot.swift`

Same logical fields as Windows:

- `pair`
- `range`
- `points`
- `currentRate`
- `changeAbsolute`
- `changePercent`
- `asOfUTC`
- `isStale`

### `Models/TimeRangePreset.swift`

Enum:

- `.day`
- `.week`
- `.month`
- `.year`

### `Models/RateHistoryQuery.swift`

Fields:

- `range`
- `fromUTC`
- `toUTC`
- `group`

---

## Stores

### `Stores/SettingsStore.swift`

Owns:

- JSON persistence for settings

Path:

- `~/Library/Application Support/FXRateDashboard/settings.json`

Methods:

- `load() async throws -> AppSettings`
- `save(_ settings: AppSettings) async throws`

Rules:

- if file missing, return defaults
- if file invalid, return defaults

### `Stores/CacheStore.swift`

Owns:

- cached snapshots by pair + range

Path:

- `~/Library/Application Support/FXRateDashboard/cache/`

Methods:

- `loadSnapshot(pair:range:) async -> RateSeriesSnapshot?`
- `saveSnapshot(_ snapshot:) async`

Filename rule:

- `JPY_CNY_Day.json` style, with non-alphanumeric characters normalized

### `Stores/KeychainTokenStore.swift`

Owns:

- secure Wise token storage

Methods:

- `loadToken() -> String?`
- `saveToken(_ token: String)`
- `deleteToken()`
- `hasToken() -> Bool`

Do not write token to plain JSON.

---

## Services

### `Services/WiseRateClient.swift`

Direct port target from Windows `WiseRateClient`.

Methods:

- `getCurrentRate(source:target:token:)`
- `getHistoricalRates(source:target:token:from:to:group:)`

Rules to preserve:

- base URL: `https://api.wise.com/`
- authorization header: `Bearer <token>`
- parse Wise timestamps including `+0000`
- friendly errors for:
  - invalid token
  - rate limit
  - generic failure

Implementation note:

- use `URLSession`
- prefer direct connection behavior

### `Services/RateQueryMapper.swift`

Same mapping as Windows:

- `.day` -> `-1 day`, `minute`
- `.week` -> `-7 days`, `hour`
- `.month` -> `-30 days`, `day`
- `.year` -> `-365 days`, `day`

### `Services/LaunchAtLoginService.swift`

Owns:

- launch-at-login toggle

Recommended implementation:

- `SMAppService` if target and signing conditions allow it
- otherwise leave a documented fallback

### `Services/WidgetWindowPlacementService.swift`

Owns:

- restoring saved window position
- handling compact/full expansion safely near screen edges

This should wrap the current placement rules so they are not buried inside UI code.

---

## Support

### `Support/RateMath.swift`

Direct logic port from Windows.

Functions to include:

- `createSnapshot(...)`
- `appendOrReplaceLatest(...)`
- `downsample(...)`
- `scalePoints(...)`
- `formatDisplayAmount(...)`
- `formatSignedAmount(...)`
- `formatBaseAmount(...)`
- `determineAxisDecimalPlaces(...)`
- `formatAxisValue(...)`

### `Support/CurrencyCodeCatalog.swift`

Owns:

- ISO 4217 validation list

### `Support/AppPaths.swift`

Owns:

- Application Support root path
- settings path
- cache directory path

### `Support/ColorPalette.swift`

Owns:

- all semantic colors

Do not hardcode these across many views.

Include semantic entries like:

- `panelBackgroundOnline`
- `panelBackgroundOffline`
- `surfaceAltOnline`
- `surfaceAltOffline`
- `accentOnline`
- `accentOffline`
- `primaryTextOnline`
- `primaryTextOffline`
- `mutedTextOnline`
- `mutedTextOffline`
- `positive`
- `negative`
- `warning`
- `offlineTrend`

### `Support/WidgetMetrics.swift`

Owns:

- all sizes, radii, paddings, and font constants

This is important to reduce layout drift.

Suggested structure:

- `WidgetMetrics.full`
- `WidgetMetrics.compact`

### `Support/WindowPlacementHelper.swift`

Owns:

- compact/full target position calculations
- screen-edge-aware expansion rules

Keep this pure and testable.

---

## View Models

### `ViewModels/MainWidgetViewModel.swift`

This is the most important file.

It should own:

- widget state
- polling state
- offline/online state
- compact/full mode state
- selected time range
- all formatted display strings
- semantic colors or palette state

Recommended published properties:

- `pairLabel`
- `currentRateDisplay`
- `quoteCurrencyCode`
- `changeDisplay`
- `changePercentDisplay`
- `statusText`
- `footerSourceText`
- `chartPoints`
- `activeRange`
- `isOffline`
- `isCompactMode`
- `isWindowVisible`
- `settings`

Actions:

- `initialize()`
- `applySettings(...)`
- `toggleCompactMode()`
- `selectRange(_:)`
- `setWindowVisible(_:)`
- `updateWindowPosition(...)`
- `shutdown(...)`

Polling helpers:

- current-rate loop
- historical refresh loop
- startup bootstrap

### `ViewModels/SettingsViewModel.swift`

Owns:

- editable settings values as strings / toggles
- validation
- token masking
- token clear behavior

Methods:

- `load(from settings:, hasToken:, maskedToken:)`
- `buildSettings() throws -> AppSettings`
- `save() async`

### `ViewModels/MenuBarViewModel.swift`

Small helper view model for:

- show/hide label
- compact/full label
- settings action
- quit action

This can either wrap `MainWidgetViewModel` or just read from it.

---

## Views

## `Views/MainWidgetWindowView.swift`

Top-level widget surface.

Responsibilities:

- choose full vs compact mode
- own background card and border
- attach drag region
- attach right-click menu if needed

Should not directly own business logic.

## `Views/FullWidgetView.swift`

Contains:

- top bar
- value section
- chart card
- footer range row

## `Views/CompactWidgetView.swift`

Contains:

- top bar
- value section
- compact bottom line

## `Views/WidgetTopBarView.swift`

Contains:

- pair badge
- updated-at chip

## `Views/WidgetValueSectionView.swift`

Contains:

- main numeric value
- quote currency
- change amount
- change percent
- compact-mode `Wise`

## `Views/WidgetFooterView.swift`

Contains:

- `1D`
- `1W`
- `1M`
- `1Y`
- `Wise`

## `Views/SparklineChartView.swift`

Custom chart drawing view.

Use:

- `Canvas`
- custom path building
- custom grid lines
- custom marker drawing

Do not use Swift Charts for first parity pass.

## `Views/SettingsView.swift`

Contains:

- title
- five cards
- validation banner
- cancel/save button row

## `Views/MenuBarMenuView.swift`

Contains:

- show/hide
- compact/full
- settings
- quit

Use simple native menu first unless exact custom dark floating popup is required.

---

## Suggested Semantic Constants

## Widget sizes

### Full mode

- size: `404 x 410`
- outer margin: `10`
- content padding: `18`
- corner radius: `28`

### Compact mode

- size: `236 x 122`
- outer margin: `7`
- content padding: `9,9,9,8`
- corner radius: `24`

## Typography

### Full

- pair label: `12`
- status chip: `11`
- current value: `42`
- quote currency: `13`
- change line: `15`

### Compact

- pair label: `10`
- status chip: `9`
- current value: `27`
- quote currency: `10`
- change line: `11`

## Key colors

- bright green: `#9FE870`
- deep green: `#163300`
- online panel: `#FBFCF8`
- offline panel: `#D2D9CA`
- online secondary surface: `#F2F7EA`
- offline secondary surface: `#E1E5DE`
- positive: `#6C9A54`
- negative: `#D97A68`
- muted online: `#6A745F`
- muted offline: `#7D8479`

## Animation timing

- online/offline palette transition: `500ms`
- mode-size transition: about `280ms`
- compact/full content fade:
  - out: `180-220ms`
  - in: `260ms`

---

## Recommended First Implementation Sequence

## Step 1

Create:

- `Models`
- `Stores`
- `Services`
- `Support`

Do not build any polished UI yet.

## Step 2

Create:

- `MainWidgetViewModel`

Verify:

- settings load
- cache load
- Wise fetch
- offline fallback

## Step 3

Create:

- `MainWidgetWindowView`
- `FullWidgetView`
- `CompactWidgetView`

Use placeholder chart first if needed.

## Step 4

Create:

- `SparklineChartView`

Match the current chart spacing and value formatting.

## Step 5

Create:

- `SettingsViewModel`
- `SettingsView`

## Step 6

Create:

- `MenuBarExtra`
- menu actions

## Step 7

Implement:

- window restore
- edge-aware compact/full expansion
- launch at login

---

## Suggested macOS Codex Prompt

```text
Read MACOS_PORT_EXECUTION_PLAN.md and MACOS_SWIFTUI_SCAFFOLD_GUIDE.md first.

Then create the macOS SwiftUI project scaffold exactly following the file structure in the scaffold guide.

Constraints:
- Preserve behavior parity with the Windows app.
- Use SwiftUI first.
- Use AppKit only where window/menu-bar behavior needs it.
- Do not redesign the app before parity is reached.
- Store the Wise token in Keychain.
- Put settings/cache in Application Support.

Execution order:
1. create models, stores, services, and support files
2. create MainWidgetViewModel
3. create main widget views
4. create custom chart
5. create settings view
6. create menu bar integration
7. finish window placement and startup behavior
```

---

## What To Avoid

- Do not start with one giant Swift file.
- Do not hardcode colors in every view.
- Do not put token text into JSON settings.
- Do not use Swift Charts first if visual parity matters.
- Do not redesign compact/full layout before matching current behavior.
- Do not bury window-placement rules directly inside unrelated UI views.
