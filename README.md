# FX Rate Dashboard

A lightweight Windows desktop widget for tracking live Wise exchange rates with a compact chart, tray controls, and an Apple-stocks-inspired panel layout.

## Features

- Live Wise rate polling for a selected currency pair
- Compact floating desktop widget for Windows
- Trend chart with `1D`, `1W`, `1M`, and `1Y` ranges
- Configurable base amount, such as `10000 JPY/CNY`
- Tray-based settings and exit controls
- Cached offline view when the network is unavailable
- Smooth visual transition between online and offline states

## Stack

- WPF on `.NET 10`
- `CommunityToolkit.Mvvm`
- `Microsoft.Extensions.Hosting`
- Wise Rate API

## Requirements

- Windows 10 or Windows 11
- A Wise personal API token with at least read access

Wise API docs:

- [Wise Rate API](https://docs.wise.com/api-reference/rate)
- [Wise personal tokens](https://docs.wise.com/api-docs/guides/personal-tokens)

## Running Locally

```powershell
dotnet run --project .\src\FXRateDashboard\FXRateDashboard.csproj
```

On first launch, open the tray menu, open `Settings`, and paste your Wise token.

## Building

```powershell
dotnet build .\FXRateDashboard.sln -v minimal
dotnet test .\FXRateDashboard.sln -v minimal
```

## Publishing A Single EXE

```powershell
dotnet publish .\src\FXRateDashboard\FXRateDashboard.csproj -c Release
```

The single-file release output is generated under:

```text
src\FXRateDashboard\bin\Release\net10.0-windows\win-x64\publish\
```

## Configuration

The settings window supports:

- Base currency
- Quote currency
- Base amount
- Refresh interval
- Wise API token
- Lock widget position
- Launch at startup

## Token Safety

This repository does not store your Wise token.

- The app saves settings outside the repository
- The token is encrypted locally with Windows DPAPI
- The settings file is stored under `%AppData%\FXRateDashboard\settings.json`

That means publishing this repository to GitHub does not upload your token unless you manually copy local settings into the repo.

## Project Structure

```text
src/FXRateDashboard
tests/FXRateDashboard.Tests
```

## GitHub About Text (Recommended)

`Live Wise FX desktop widget for Windows with real-time rates, trend charts, tray controls, compact mode, and offline cache.`

## Suggested GitHub Topics

`windows` `wpf` `dotnet` `foreign-exchange` `exchange-rates` `wise-api` `desktop-widget`
