using System.Text.Json;
using System.Text.Json.Serialization;
using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public sealed class SettingsStore : ISettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly IAppPathProvider _appPathProvider;

    public SettingsStore(IAppPathProvider appPathProvider)
    {
        _appPathProvider = appPathProvider;
    }

    public async Task<AppSettings> LoadAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(_appPathProvider.SettingsFilePath))
        {
            return new AppSettings();
        }

        try
        {
            await using var stream = File.OpenRead(_appPathProvider.SettingsFilePath);
            var settings = await JsonSerializer.DeserializeAsync<AppSettings>(stream, JsonOptions, cancellationToken);
            settings ??= new AppSettings();
            settings.Normalize();
            return settings;
        }
        catch (JsonException)
        {
            return new AppSettings();
        }
    }

    public async Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default)
    {
        settings.Normalize();
        Directory.CreateDirectory(Path.GetDirectoryName(_appPathProvider.SettingsFilePath)!);

        await using var stream = File.Create(_appPathProvider.SettingsFilePath);
        await JsonSerializer.SerializeAsync(stream, settings, JsonOptions, cancellationToken);
    }
}
