namespace FXRateDashboard.Services;

public interface IAppPathProvider
{
    string SettingsFilePath { get; }

    string CacheDirectoryPath { get; }
}
