using FXRateDashboard.Models;
using FXRateDashboard.Services;

namespace FXRateDashboard.Tests.Fakes;

internal sealed class InMemorySettingsStore : ISettingsStore
{
    public AppSettings CurrentSettings { get; set; } = new();

    public Task<AppSettings> LoadAsync(CancellationToken cancellationToken = default)
    {
        return Task.FromResult(CurrentSettings.Clone());
    }

    public Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        CurrentSettings = settings.Clone();
        return Task.CompletedTask;
    }
}

internal sealed class InMemoryCacheStore : ICacheStore
{
    private readonly Dictionary<string, RateSeriesSnapshot> _snapshots = new(StringComparer.OrdinalIgnoreCase);

    public Task<RateSeriesSnapshot?> LoadSnapshotAsync(string pair, TimeRangePreset range, CancellationToken cancellationToken = default)
    {
        _snapshots.TryGetValue($"{pair}:{range}", out var snapshot);
        return Task.FromResult(snapshot?.Clone());
    }

    public Task SaveSnapshotAsync(RateSeriesSnapshot snapshot, CancellationToken cancellationToken = default)
    {
        _snapshots[$"{snapshot.Pair}:{snapshot.Range}"] = snapshot.Clone();
        return Task.CompletedTask;
    }
}

internal sealed class ImmediateUiDispatcher : IUiDispatcher
{
    public Task InvokeAsync(Action action)
    {
        action();
        return Task.CompletedTask;
    }
}

internal sealed class StubStartupLaunchService : IStartupLaunchService
{
    public bool Enabled { get; private set; }

    public Task SetEnabledAsync(bool enabled, CancellationToken cancellationToken = default)
    {
        Enabled = enabled;
        return Task.CompletedTask;
    }
}

internal sealed class StubWiseRateClient : IWiseRateClient
{
    public Func<string, string, string, CancellationToken, Task<RatePoint>> CurrentRateHandler { get; set; } =
        (_, _, _, _) => Task.FromResult(new RatePoint
        {
            TimestampUtc = DateTimeOffset.UtcNow,
            Rate = 7.23m
        });

    public Func<string, string, string, DateTimeOffset, DateTimeOffset, string, CancellationToken, Task<IReadOnlyList<RatePoint>>> HistoricalRateHandler { get; set; } =
        (_, _, _, fromUtc, _, _, _) => Task.FromResult<IReadOnlyList<RatePoint>>(
            [
                new RatePoint { TimestampUtc = fromUtc, Rate = 7.20m },
                new RatePoint { TimestampUtc = fromUtc.AddHours(12), Rate = 7.21m }
            ]);

    public Task<RatePoint> GetCurrentRateAsync(string sourceCurrency, string targetCurrency, string bearerToken, CancellationToken cancellationToken = default)
    {
        return CurrentRateHandler(sourceCurrency, targetCurrency, bearerToken, cancellationToken);
    }

    public Task<IReadOnlyList<RatePoint>> GetHistoricalRatesAsync(
        string sourceCurrency,
        string targetCurrency,
        string bearerToken,
        DateTimeOffset fromUtc,
        DateTimeOffset toUtc,
        string group,
        CancellationToken cancellationToken = default)
    {
        return HistoricalRateHandler(sourceCurrency, targetCurrency, bearerToken, fromUtc, toUtc, group, cancellationToken);
    }
}

internal sealed class TempPathProvider : IAppPathProvider, IDisposable
{
    public TempPathProvider()
    {
        var root = Path.Combine(Path.GetTempPath(), "FXRateDashboardTests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        Directory.CreateDirectory(Path.Combine(root, "cache"));

        Root = root;
        SettingsFilePath = Path.Combine(root, "settings.json");
        CacheDirectoryPath = Path.Combine(root, "cache");
    }

    public string Root { get; }

    public string SettingsFilePath { get; }

    public string CacheDirectoryPath { get; }

    public void Dispose()
    {
        if (Directory.Exists(Root))
        {
            Directory.Delete(Root, recursive: true);
        }
    }
}
