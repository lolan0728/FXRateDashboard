using Microsoft.Win32;

namespace FXRateDashboard.Services;

public sealed class StartupLaunchService : IStartupLaunchService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "FXRateDashboard";

    public Task SetEnabledAsync(bool enabled, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        using var runKey = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true)
                           ?? Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);

        if (runKey is null)
        {
            return Task.CompletedTask;
        }

        if (enabled)
        {
            var executablePath = Environment.ProcessPath;
            if (!string.IsNullOrWhiteSpace(executablePath))
            {
                runKey.SetValue(AppName, $"\"{executablePath}\"");
            }
        }
        else if (runKey.GetValue(AppName) is not null)
        {
            runKey.DeleteValue(AppName, throwOnMissingValue: false);
        }

        return Task.CompletedTask;
    }
}
