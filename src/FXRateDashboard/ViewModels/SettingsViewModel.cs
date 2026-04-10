using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using FXRateDashboard.Models;
using FXRateDashboard.Services;
using FXRateDashboard.Utilities;

namespace FXRateDashboard.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly ITokenProtector _tokenProtector;
    private AppSettings _loadedSettings = new();
    private string? _existingEncryptedToken;
    private string? _existingTokenMask;

    public SettingsViewModel(ITokenProtector tokenProtector)
    {
        _tokenProtector = tokenProtector;
    }

    [ObservableProperty]
    private string _baseCurrency = "USD";

    [ObservableProperty]
    private string _quoteCurrency = "CNY";

    [ObservableProperty]
    private string _baseAmountText = "1";

    [ObservableProperty]
    private string _refreshSecondsText = "60";

    [ObservableProperty]
    private bool _lockPosition;

    [ObservableProperty]
    private bool _launchAtStartup;

    [ObservableProperty]
    private string _apiTokenText = string.Empty;

    [ObservableProperty]
    private string _tokenHelpText = "Paste token or clear it.";

    public void Load(AppSettings settings)
    {
        _loadedSettings = settings.Clone();
        _existingEncryptedToken = settings.EncryptedWiseToken;
        BaseCurrency = settings.BaseCurrency;
        QuoteCurrency = settings.QuoteCurrency;
        BaseAmountText = RateMath.FormatBaseAmount(settings.BaseAmount);
        RefreshSecondsText = settings.RefreshSeconds.ToString(CultureInfo.InvariantCulture);
        LockPosition = settings.LockPosition;
        LaunchAtStartup = settings.LaunchAtStartup;

        var savedToken = NormalizeTokenInput(_tokenProtector.Unprotect(settings.EncryptedWiseToken) ?? settings.EncryptedWiseToken);
        _existingTokenMask = string.IsNullOrWhiteSpace(savedToken) ? null : MaskToken(savedToken);
        ApiTokenText = _existingTokenMask ?? string.Empty;
        TokenHelpText = _existingTokenMask is null
            ? "Paste token."
            : "Replace or clear it.";
    }

    public bool TryBuildSettings(out AppSettings settings, out string validationError)
    {
        settings = new AppSettings();
        validationError = string.Empty;

        var baseCurrency = NormalizeCurrency(BaseCurrency);
        var quoteCurrency = NormalizeCurrency(QuoteCurrency);
        if (baseCurrency is null || quoteCurrency is null)
        {
            validationError = "Base and quote currency must be valid ISO 4217 codes, for example USD and CNY.";
            return false;
        }

        if (!TryParsePositiveDecimal(BaseAmountText, out var baseAmount))
        {
            validationError = "Base amount must be a positive number.";
            return false;
        }

        if (!int.TryParse(RefreshSecondsText, NumberStyles.Integer, CultureInfo.InvariantCulture, out var refreshSeconds))
        {
            validationError = "Refresh interval must be a whole number of seconds.";
            return false;
        }

        if (refreshSeconds < 15 || refreshSeconds > 3600)
        {
            validationError = "Refresh interval must be between 15 and 3600 seconds.";
            return false;
        }

        settings = _loadedSettings.Clone();
        settings.BaseCurrency = baseCurrency;
        settings.QuoteCurrency = quoteCurrency;
        settings.BaseAmount = baseAmount;
        settings.RefreshSeconds = refreshSeconds;
        settings.LockPosition = LockPosition;
        settings.LaunchAtStartup = LaunchAtStartup;
        settings.EncryptedWiseToken = ResolveTokenForSave();
        settings.Normalize();
        return true;
    }

    private string? ResolveTokenForSave()
    {
        if (string.IsNullOrWhiteSpace(ApiTokenText))
        {
            return null;
        }

        var normalized = NormalizeTokenInput(ApiTokenText);
        if (normalized == _existingTokenMask)
        {
            return _existingEncryptedToken;
        }

        return normalized;
    }

    private static bool TryParsePositiveDecimal(string input, out decimal value)
    {
        if (decimal.TryParse(input, NumberStyles.Number, CultureInfo.InvariantCulture, out value) && value > 0)
        {
            return true;
        }

        if (decimal.TryParse(input, NumberStyles.Number, CultureInfo.CurrentCulture, out value) && value > 0)
        {
            return true;
        }

        value = 0m;
        return false;
    }

    private static string? NormalizeCurrency(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return null;
        }

        var cleaned = new string(input.Trim().ToUpperInvariant().Where(char.IsLetter).ToArray());
        return cleaned.Length == 3 && CurrencyCodeCatalog.IsKnownCode(cleaned) ? cleaned : null;
    }

    private static string? NormalizeTokenInput(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var token = value.Trim();

        if (token.StartsWith("Authorization:", StringComparison.OrdinalIgnoreCase))
        {
            token = token["Authorization:".Length..].Trim();
        }

        if (token.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            token = token["Bearer ".Length..].Trim();
        }

        token = token.Trim().Trim('"');
        return string.IsNullOrWhiteSpace(token) ? null : token;
    }

    private static string MaskToken(string token)
    {
        var visibleLead = Math.Min(4, Math.Max(2, token.Length / 4));
        var visibleTail = Math.Min(4, Math.Max(2, token.Length / 4));
        var hiddenLength = Math.Max(token.Length - visibleLead - visibleTail, 0);

        if (hiddenLength == 0)
        {
            return token;
        }

        return $"{token[..visibleLead]}{new string('*', hiddenLength)}{token[^visibleTail..]}";
    }
}
