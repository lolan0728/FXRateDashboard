using FXRateDashboard.Models;
using FXRateDashboard.Services;

namespace FXRateDashboard.Tests;

public sealed class RateQueryMapperTests
{
    [Theory]
    [InlineData(TimeRangePreset.Day, "minute", -1)]
    [InlineData(TimeRangePreset.Week, "hour", -7)]
    [InlineData(TimeRangePreset.Month, "day", -30)]
    [InlineData(TimeRangePreset.Year, "day", -365)]
    public void MapHistoryQuery_ReturnsExpectedWindow(TimeRangePreset range, string expectedGroup, int dayDelta)
    {
        var mapper = new RateQueryMapper();
        var anchor = new DateTimeOffset(2026, 4, 10, 8, 30, 0, TimeSpan.Zero);

        var query = mapper.MapHistoryQuery(range, anchor);

        Assert.Equal(expectedGroup, query.Group);
        Assert.Equal(anchor, query.ToUtc);
        Assert.Equal(anchor.AddDays(dayDelta), query.FromUtc);
    }
}
