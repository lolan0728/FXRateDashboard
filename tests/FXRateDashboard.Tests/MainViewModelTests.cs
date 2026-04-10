using FXRateDashboard.Models;
using FXRateDashboard.Services;
using FXRateDashboard.Tests.Fakes;
using FXRateDashboard.ViewModels;

namespace FXRateDashboard.Tests;

public sealed class MainViewModelTests
{
    [Fact]
    public async Task InitializeAsync_WithoutToken_RequestsConfiguration()
    {
        var settingsStore = new InMemorySettingsStore
        {
            CurrentSettings = new AppSettings
            {
                BaseCurrency = "USD",
                QuoteCurrency = "CNY",
                RefreshSeconds = 60
            }
        };
        var cacheStore = new InMemoryCacheStore();
        var wiseRateClient = new StubWiseRateClient();
        var startupService = new StubStartupLaunchService();
        var viewModel = new MainViewModel(
            settingsStore,
            cacheStore,
            wiseRateClient,
            new RateQueryMapper(),
            new TokenProtector(),
            new ImmediateUiDispatcher(),
            startupService);

        var requested = 0;
        viewModel.RequestOpenSettings += (_, _) => requested++;

        await viewModel.InitializeAsync();

        Assert.Equal("Updated at: --", viewModel.StatusMessage);
        Assert.Equal("1 USD/CNY", viewModel.PairLabel);
        Assert.Equal(1, requested);
    }

    [Fact]
    public async Task ApplySettingsAsync_EncryptsTokenAndLoadsSnapshot()
    {
        var settingsStore = new InMemorySettingsStore();
        var cacheStore = new InMemoryCacheStore();
        var wiseRateClient = new StubWiseRateClient
        {
            CurrentRateHandler = (_, _, _, _) => Task.FromResult(new RatePoint
            {
                TimestampUtc = new DateTimeOffset(2026, 4, 10, 8, 0, 0, TimeSpan.Zero),
                Rate = 1.12m
            }),
            HistoricalRateHandler = (_, _, _, fromUtc, _, _, _) => Task.FromResult<IReadOnlyList<RatePoint>>(
            [
                new RatePoint { TimestampUtc = fromUtc, Rate = 1.08m },
                new RatePoint { TimestampUtc = fromUtc.AddDays(10), Rate = 1.10m }
            ])
        };
        var startupService = new StubStartupLaunchService();
        var viewModel = new MainViewModel(
            settingsStore,
            cacheStore,
            wiseRateClient,
            new RateQueryMapper(),
            new TokenProtector(),
            new ImmediateUiDispatcher(),
            startupService);

        var result = await viewModel.ApplySettingsAsync(new AppSettings
        {
            BaseCurrency = "EUR",
            QuoteCurrency = "USD",
            BaseAmount = 10_000m,
            RefreshSeconds = 60,
            EncryptedWiseToken = "plain-token",
            LaunchAtStartup = true
        });

        Assert.True(result.Success);
        Assert.Equal("10000 EUR/USD", viewModel.PairLabel);
        Assert.Equal("USD", viewModel.QuoteCurrencyCode);
        Assert.Equal("11,200", viewModel.CurrentRateDisplay);
        Assert.NotEmpty(viewModel.ChartPoints);
        Assert.Equal(10_800m, viewModel.ChartPoints.First().Rate);
        Assert.Equal(11_200m, viewModel.ChartPoints.Last().Rate);
        Assert.NotEqual("plain-token", settingsStore.CurrentSettings.EncryptedWiseToken);
        Assert.True(startupService.Enabled);

        await viewModel.ShutdownAsync(0, 0);
    }

    [Fact]
    public async Task EnsureSettingsLoadedAsync_LoadsSavedWindowPlacement()
    {
        var settingsStore = new InMemorySettingsStore
        {
            CurrentSettings = new AppSettings
            {
                WindowLeft = 321,
                WindowTop = 654
            }
        };
        var viewModel = new MainViewModel(
            settingsStore,
            new InMemoryCacheStore(),
            new StubWiseRateClient(),
            new RateQueryMapper(),
            new TokenProtector(),
            new ImmediateUiDispatcher(),
            new StubStartupLaunchService());

        await viewModel.EnsureSettingsLoadedAsync();

        var placement = viewModel.GetSavedWindowPlacement();
        Assert.Equal(321, placement.Left);
        Assert.Equal(654, placement.Top);
    }
}
