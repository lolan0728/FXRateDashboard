using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public sealed class RateQueryMapper : IRateQueryMapper
{
    public RateHistoryQuery MapHistoryQuery(TimeRangePreset range, DateTimeOffset? nowUtc = null)
    {
        var anchor = (nowUtc ?? DateTimeOffset.UtcNow).ToUniversalTime();

        return range switch
        {
            TimeRangePreset.Day => new RateHistoryQuery(range, anchor.AddDays(-1), anchor, "minute"),
            TimeRangePreset.Week => new RateHistoryQuery(range, anchor.AddDays(-7), anchor, "hour"),
            TimeRangePreset.Month => new RateHistoryQuery(range, anchor.AddDays(-30), anchor, "day"),
            TimeRangePreset.Year => new RateHistoryQuery(range, anchor.AddDays(-365), anchor, "day"),
            _ => throw new ArgumentOutOfRangeException(nameof(range), range, null)
        };
    }
}
