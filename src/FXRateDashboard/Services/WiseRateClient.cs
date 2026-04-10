using System.Globalization;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.RegularExpressions;
using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public sealed class WiseRateClient : IWiseRateClient
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private readonly HttpClient _httpClient;

    public WiseRateClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<RatePoint> GetCurrentRateAsync(
        string sourceCurrency,
        string targetCurrency,
        string bearerToken,
        CancellationToken cancellationToken = default)
    {
        var responseItems = await SendAsync(
            $"v1/rates?source={sourceCurrency}&target={targetCurrency}",
            bearerToken,
            cancellationToken);

        var rate = responseItems.FirstOrDefault()
                   ?? throw new WiseApiException("Wise did not return a current rate.");

        return new RatePoint
        {
            TimestampUtc = ParseWiseTimestamp(rate.Time),
            Rate = rate.Rate
        };
    }

    public async Task<IReadOnlyList<RatePoint>> GetHistoricalRatesAsync(
        string sourceCurrency,
        string targetCurrency,
        string bearerToken,
        DateTimeOffset fromUtc,
        DateTimeOffset toUtc,
        string group,
        CancellationToken cancellationToken = default)
    {
        var query =
            $"v1/rates?source={sourceCurrency}&target={targetCurrency}&from={FormatTimestamp(fromUtc)}&to={FormatTimestamp(toUtc)}&group={group}";
        var responseItems = await SendAsync(query, bearerToken, cancellationToken);

        return responseItems
            .OrderBy(item => ParseWiseTimestamp(item.Time))
            .Select(item => new RatePoint
            {
                TimestampUtc = ParseWiseTimestamp(item.Time),
                Rate = item.Rate
            })
            .ToList();
    }

    private async Task<List<WiseRateResponse>> SendAsync(string relativeUri, string bearerToken, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, relativeUri);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new WiseApiException(BuildErrorMessage(response.StatusCode), response.StatusCode);
        }

        return JsonSerializer.Deserialize<List<WiseRateResponse>>(payload, JsonOptions) ?? [];
    }

    private static string FormatTimestamp(DateTimeOffset value)
    {
        return Uri.EscapeDataString(value.UtcDateTime.ToString("yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture));
    }

    private static string BuildErrorMessage(HttpStatusCode statusCode)
    {
        return statusCode switch
        {
            HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden =>
                "The Wise token is invalid or does not have enough permission. Please update it in Settings with a new read-only token.",
            HttpStatusCode.TooManyRequests =>
                "Wise rate limits were hit. Please try again in a moment.",
            _ => "Wise request failed. Please check your connection and try again."
        };
    }

    private static DateTimeOffset ParseWiseTimestamp(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new WiseApiException("Wise returned an empty timestamp.");
        }

        var normalized = value.Trim();
        if (Regex.IsMatch(normalized, @"[+-]\d{4}$"))
        {
            normalized = $"{normalized[..^5]}{normalized[^5..^2]}:{normalized[^2..]}";
        }

        if (DateTimeOffset.TryParse(
                normalized,
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                out var timestamp))
        {
            return timestamp.ToUniversalTime();
        }

        throw new WiseApiException("Wise returned an unrecognized timestamp format.");
    }

    private sealed class WiseRateResponse
    {
        public decimal Rate { get; set; }

        public string Source { get; set; } = string.Empty;

        public string Target { get; set; } = string.Empty;

        public string Time { get; set; } = string.Empty;
    }
}
