namespace FXRateDashboard.Models;

public sealed class AppSettings
{
    public string BaseCurrency { get; set; } = "USD";

    public string QuoteCurrency { get; set; } = "CNY";

    public decimal BaseAmount { get; set; } = 1m;

    public TimeRangePreset ActiveRange { get; set; } = TimeRangePreset.Day;

    public int RefreshSeconds { get; set; } = 60;

    public double? WindowLeft { get; set; }

    public double? WindowTop { get; set; }

    public bool AlwaysOnTop { get; set; }

    public bool LockPosition { get; set; }

    public bool LaunchAtStartup { get; set; }

    public double Opacity { get; set; } = 1.0;

    public string? EncryptedWiseToken { get; set; }

    public string Pair => $"{BaseCurrency}/{QuoteCurrency}";

    public AppSettings Clone()
    {
        return new AppSettings
        {
            BaseCurrency = BaseCurrency,
            QuoteCurrency = QuoteCurrency,
            BaseAmount = BaseAmount,
            ActiveRange = ActiveRange,
            RefreshSeconds = RefreshSeconds,
            WindowLeft = WindowLeft,
            WindowTop = WindowTop,
            AlwaysOnTop = AlwaysOnTop,
            LockPosition = LockPosition,
            LaunchAtStartup = LaunchAtStartup,
            Opacity = Opacity,
            EncryptedWiseToken = EncryptedWiseToken
        };
    }

    public void Normalize()
    {
        BaseCurrency = NormalizeCurrency(BaseCurrency, "USD");
        QuoteCurrency = NormalizeCurrency(QuoteCurrency, "CNY");
        BaseAmount = BaseAmount <= 0 ? 1m : decimal.Round(BaseAmount, 4);
        RefreshSeconds = Math.Clamp(RefreshSeconds, 15, 3600);
        AlwaysOnTop = false;
        Opacity = 1.0;
        EncryptedWiseToken = string.IsNullOrWhiteSpace(EncryptedWiseToken) ? null : EncryptedWiseToken.Trim();
    }

    private static string NormalizeCurrency(string? currency, string fallback)
    {
        if (string.IsNullOrWhiteSpace(currency))
        {
            return fallback;
        }

        var cleaned = new string(currency.Trim().ToUpperInvariant().Where(char.IsLetter).ToArray());
        return cleaned.Length == 3 ? cleaned : fallback;
    }
}
