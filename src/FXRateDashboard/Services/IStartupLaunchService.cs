namespace FXRateDashboard.Services;

public interface IStartupLaunchService
{
    Task SetEnabledAsync(bool enabled, CancellationToken cancellationToken = default);
}
