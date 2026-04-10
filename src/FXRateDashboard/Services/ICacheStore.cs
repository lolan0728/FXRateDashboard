using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public interface ICacheStore
{
    Task<RateSeriesSnapshot?> LoadSnapshotAsync(string pair, TimeRangePreset range, CancellationToken cancellationToken = default);

    Task SaveSnapshotAsync(RateSeriesSnapshot snapshot, CancellationToken cancellationToken = default);
}
