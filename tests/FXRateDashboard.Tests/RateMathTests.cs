using FXRateDashboard.Models;
using FXRateDashboard.Utilities;

namespace FXRateDashboard.Tests;

public sealed class RateMathTests
{
    [Fact]
    public void CreateSnapshot_ComputesChangeFields()
    {
        var points = new[]
        {
            new RatePoint { TimestampUtc = new DateTimeOffset(2026, 4, 9, 0, 0, 0, TimeSpan.Zero), Rate = 7.10m },
            new RatePoint { TimestampUtc = new DateTimeOffset(2026, 4, 10, 0, 0, 0, TimeSpan.Zero), Rate = 7.35m }
        };

        var snapshot = RateMath.CreateSnapshot("USD/CNY", TimeRangePreset.Day, points);

        Assert.Equal(0.25m, snapshot.ChangeAbsolute);
        Assert.Equal(7.35m, snapshot.CurrentRate);
        Assert.Equal(decimal.Round(0.25m / 7.10m * 100m, 27), decimal.Round(snapshot.ChangePercent, 27));
    }

    [Fact]
    public void Downsample_KeepsFirstAndLastPoint()
    {
        var points = Enumerable.Range(0, 20)
            .Select(index => new RatePoint
            {
                TimestampUtc = DateTimeOffset.UtcNow.AddMinutes(index),
                Rate = index
            })
            .ToList();

        var sampled = RateMath.Downsample(points, 5);

        Assert.Equal(5, sampled.Count);
        Assert.Equal(points.First().Rate, sampled.First().Rate);
        Assert.Equal(points.Last().Rate, sampled.Last().Rate);
    }

    [Fact]
    public void ScalePoints_MultipliesRatesAndPreservesTimestamps()
    {
        var timestamp = new DateTimeOffset(2026, 4, 10, 0, 0, 0, TimeSpan.Zero);
        var points = new[]
        {
            new RatePoint { TimestampUtc = timestamp, Rate = 0.0429157m },
            new RatePoint { TimestampUtc = timestamp.AddHours(1), Rate = 0.0430284m }
        };

        var scaled = RateMath.ScalePoints(points, 10_000m);

        Assert.Equal(429.1570m, scaled[0].Rate);
        Assert.Equal(430.2840m, scaled[1].Rate);
        Assert.Equal(points[0].TimestampUtc, scaled[0].TimestampUtc);
    }

    [Fact]
    public void DetermineAxisDecimalPlaces_IncreasesUntilLabelsAreDistinct()
    {
        var values = new[] { 429.151m, 429.154m, 429.159m };

        var decimals = RateMath.DetermineAxisDecimalPlaces(values);

        Assert.Equal(3, decimals);
    }
}
