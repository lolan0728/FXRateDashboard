using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public interface IWiseRateClient
{
    Task<RatePoint> GetCurrentRateAsync(string sourceCurrency, string targetCurrency, string bearerToken, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RatePoint>> GetHistoricalRatesAsync(
        string sourceCurrency,
        string targetCurrency,
        string bearerToken,
        DateTimeOffset fromUtc,
        DateTimeOffset toUtc,
        string group,
        CancellationToken cancellationToken = default);
}
