using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public interface IRateQueryMapper
{
    RateHistoryQuery MapHistoryQuery(TimeRangePreset range, DateTimeOffset? nowUtc = null);
}
