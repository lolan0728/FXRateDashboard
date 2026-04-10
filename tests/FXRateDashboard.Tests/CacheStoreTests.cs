using FXRateDashboard.Models;
using FXRateDashboard.Services;
using FXRateDashboard.Tests.Fakes;

namespace FXRateDashboard.Tests;

public sealed class CacheStoreTests
{
    [Fact]
    public async Task SaveAndLoadSnapshot_RoundTripsJson()
    {
        using var pathProvider = new TempPathProvider();
        var cacheStore = new CacheStore(pathProvider);
        var snapshot = new RateSeriesSnapshot
        {
            Pair = "USD/CNY",
            Range = TimeRangePreset.Week,
            CurrentRate = 7.22m,
            ChangeAbsolute = 0.12m,
            ChangePercent = 1.6m,
            AsOfUtc = DateTimeOffset.UtcNow,
            Points =
            [
                new RatePoint { TimestampUtc = DateTimeOffset.UtcNow.AddHours(-1), Rate = 7.10m },
                new RatePoint { TimestampUtc = DateTimeOffset.UtcNow, Rate = 7.22m }
            ]
        };

        await cacheStore.SaveSnapshotAsync(snapshot);
        var reloaded = await cacheStore.LoadSnapshotAsync("USD/CNY", TimeRangePreset.Week);

        Assert.NotNull(reloaded);
        Assert.Equal(snapshot.Pair, reloaded!.Pair);
        Assert.Equal(snapshot.Points.Count, reloaded.Points.Count);
        Assert.Equal(snapshot.CurrentRate, reloaded.CurrentRate);
    }
}
