namespace FXRateDashboard.Services;

public sealed class AppPathProvider : IAppPathProvider
{
    public AppPathProvider()
    {
        var roamingRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "FXRateDashboard");
        var localRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FXRateDashboard");

        Directory.CreateDirectory(roamingRoot);
        Directory.CreateDirectory(localRoot);
        Directory.CreateDirectory(Path.Combine(localRoot, "cache"));

        SettingsFilePath = Path.Combine(roamingRoot, "settings.json");
        CacheDirectoryPath = Path.Combine(localRoot, "cache");
    }

    public string SettingsFilePath { get; }

    public string CacheDirectoryPath { get; }
}
