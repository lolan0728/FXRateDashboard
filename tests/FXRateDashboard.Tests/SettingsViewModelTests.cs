using FXRateDashboard.Models;
using FXRateDashboard.Services;
using FXRateDashboard.ViewModels;

namespace FXRateDashboard.Tests;

public sealed class SettingsViewModelTests
{
    [Fact]
    public void Load_WithSavedToken_ShowsMaskedValueAndKeepsExistingTokenWhenUnchanged()
    {
        var protector = new TokenProtector();
        var token = "abcd1234efgh5678";
        var encryptedToken = protector.Protect(token);
        var viewModel = new SettingsViewModel(protector);

        viewModel.Load(new AppSettings
        {
            BaseCurrency = "JPY",
            QuoteCurrency = "CNY",
            BaseAmount = 10_000m,
            RefreshSeconds = 60,
            EncryptedWiseToken = encryptedToken
        });

        Assert.NotEqual(string.Empty, viewModel.ApiTokenText);
        Assert.NotEqual(token, viewModel.ApiTokenText);

        var success = viewModel.TryBuildSettings(out var settings, out var error);

        Assert.True(success);
        Assert.Equal(string.Empty, error);
        Assert.Equal(encryptedToken, settings.EncryptedWiseToken);
    }

    [Fact]
    public void TryBuildSettings_WithClearedToken_RemovesExistingToken()
    {
        var protector = new TokenProtector();
        var viewModel = new SettingsViewModel(protector);
        viewModel.Load(new AppSettings
        {
            EncryptedWiseToken = protector.Protect("abcd1234efgh5678")
        });

        viewModel.ApiTokenText = string.Empty;

        var success = viewModel.TryBuildSettings(out var settings, out var error);

        Assert.True(success);
        Assert.Equal(string.Empty, error);
        Assert.Null(settings.EncryptedWiseToken);
    }

    [Fact]
    public void TryBuildSettings_WithUnknownCurrencyCode_FailsValidation()
    {
        var viewModel = new SettingsViewModel(new TokenProtector())
        {
            BaseCurrency = "AAA",
            QuoteCurrency = "CNY",
            BaseAmountText = "100",
            RefreshSecondsText = "60"
        };

        var success = viewModel.TryBuildSettings(out _, out var error);

        Assert.False(success);
        Assert.Contains("valid ISO 4217", error);
    }

    [Fact]
    public void TryBuildSettings_WithKnownCurrencyCodes_Succeeds()
    {
        var viewModel = new SettingsViewModel(new TokenProtector())
        {
            BaseCurrency = "JPY",
            QuoteCurrency = "CNY",
            BaseAmountText = "100",
            RefreshSecondsText = "60"
        };

        var success = viewModel.TryBuildSettings(out var settings, out var error);

        Assert.True(success);
        Assert.Equal(string.Empty, error);
        Assert.Equal("JPY", settings.BaseCurrency);
        Assert.Equal("CNY", settings.QuoteCurrency);
    }

    [Fact]
    public void TryBuildSettings_WithRefreshIntervalBelowMinimum_FailsValidation()
    {
        var viewModel = new SettingsViewModel(new TokenProtector())
        {
            BaseCurrency = "USD",
            QuoteCurrency = "CNY",
            BaseAmountText = "1",
            RefreshSecondsText = "1"
        };

        var success = viewModel.TryBuildSettings(out _, out var error);

        Assert.False(success);
        Assert.Contains("between 15 and 3600", error);
    }

    [Fact]
    public void TryBuildSettings_PreservesLoadedPlacementAndRange()
    {
        var viewModel = new SettingsViewModel(new TokenProtector());
        viewModel.Load(new AppSettings
        {
            BaseCurrency = "JPY",
            QuoteCurrency = "CNY",
            BaseAmount = 100m,
            RefreshSeconds = 60,
            ActiveRange = TimeRangePreset.Month,
            WindowLeft = 123,
            WindowTop = 456
        });

        viewModel.BaseAmountText = "200";

        var success = viewModel.TryBuildSettings(out var settings, out var error);

        Assert.True(success);
        Assert.Equal(string.Empty, error);
        Assert.Equal(TimeRangePreset.Month, settings.ActiveRange);
        Assert.Equal(123, settings.WindowLeft);
        Assert.Equal(456, settings.WindowTop);
    }
}
