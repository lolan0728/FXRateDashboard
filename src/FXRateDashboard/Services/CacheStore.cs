using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public sealed class CacheStore : ICacheStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly IAppPathProvider _appPathProvider;

    public CacheStore(IAppPathProvider appPathProvider)
    {
        _appPathProvider = appPathProvider;
    }

    public async Task<RateSeriesSnapshot?> LoadSnapshotAsync(string pair, TimeRangePreset range, CancellationToken cancellationToken = default)
    {
        var cachePath = BuildCachePath(pair, range);
        if (!File.Exists(cachePath))
        {
            return null;
        }

        try
        {
            await using var stream = File.OpenRead(cachePath);
            return await JsonSerializer.DeserializeAsync<RateSeriesSnapshot>(stream, JsonOptions, cancellationToken);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    public async Task SaveSnapshotAsync(RateSeriesSnapshot snapshot, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(_appPathProvider.CacheDirectoryPath);

        var cachePath = BuildCachePath(snapshot.Pair, snapshot.Range);
        await using var stream = File.Create(cachePath);
        await JsonSerializer.SerializeAsync(stream, snapshot, JsonOptions, cancellationToken);
    }

    private string BuildCachePath(string pair, TimeRangePreset range)
    {
        var safePair = Regex.Replace(pair, "[^A-Za-z0-9]+", "_");
        return Path.Combine(_appPathProvider.CacheDirectoryPath, $"{safePair}_{range}.json");
    }
}
