using System.Globalization;
using FXRateDashboard.Models;

namespace FXRateDashboard.Utilities;

public static class RateMath
{
    public static RateSeriesSnapshot CreateSnapshot(
        string pair,
        TimeRangePreset range,
        IReadOnlyList<RatePoint> points,
        decimal? currentRateOverride = null,
        DateTimeOffset? asOfUtc = null,
        bool isStale = false)
    {
        var orderedPoints = points
            .OrderBy(point => point.TimestampUtc)
            .Select(point => new RatePoint
            {
                TimestampUtc = point.TimestampUtc,
                Rate = point.Rate
            })
            .ToList();

        var currentRate = currentRateOverride ?? orderedPoints.LastOrDefault()?.Rate ?? 0m;
        var anchorRate = orderedPoints.FirstOrDefault()?.Rate ?? currentRate;
        var changeAbsolute = currentRate - anchorRate;
        var changePercent = anchorRate == 0m ? 0m : changeAbsolute / anchorRate * 100m;

        return new RateSeriesSnapshot
        {
            Pair = pair,
            Range = range,
            Points = orderedPoints,
            CurrentRate = currentRate,
            ChangeAbsolute = changeAbsolute,
            ChangePercent = changePercent,
            AsOfUtc = (asOfUtc ?? orderedPoints.LastOrDefault()?.TimestampUtc ?? DateTimeOffset.UtcNow).ToUniversalTime(),
            IsStale = isStale
        };
    }

    public static IReadOnlyList<RatePoint> AppendOrReplaceLatest(IReadOnlyList<RatePoint> points, RatePoint latestPoint)
    {
        var merged = points
            .OrderBy(point => point.TimestampUtc)
            .Select(point => new RatePoint
            {
                TimestampUtc = point.TimestampUtc,
                Rate = point.Rate
            })
            .ToList();

        if (merged.Count == 0)
        {
            merged.Add(new RatePoint
            {
                TimestampUtc = latestPoint.TimestampUtc,
                Rate = latestPoint.Rate
            });
            return merged;
        }

        var lastPoint = merged[^1];
        if (latestPoint.TimestampUtc <= lastPoint.TimestampUtc)
        {
            merged[^1] = new RatePoint
            {
                TimestampUtc = latestPoint.TimestampUtc,
                Rate = latestPoint.Rate
            };
        }
        else
        {
            merged.Add(new RatePoint
            {
                TimestampUtc = latestPoint.TimestampUtc,
                Rate = latestPoint.Rate
            });
        }

        return merged;
    }

    public static IReadOnlyList<RatePoint> Downsample(IReadOnlyList<RatePoint> points, int maxPoints)
    {
        if (points.Count <= maxPoints || maxPoints <= 1)
        {
            return points
                .Select(point => new RatePoint
                {
                    TimestampUtc = point.TimestampUtc,
                    Rate = point.Rate
                })
                .ToList();
        }

        var sampled = new List<RatePoint>(capacity: maxPoints);
        var step = (double)(points.Count - 1) / (maxPoints - 1);

        for (var i = 0; i < maxPoints; i++)
        {
            var index = (int)Math.Round(i * step, MidpointRounding.AwayFromZero);
            index = Math.Min(index, points.Count - 1);
            var point = points[index];
            sampled.Add(new RatePoint
            {
                TimestampUtc = point.TimestampUtc,
                Rate = point.Rate
            });
        }

        return sampled;
    }

    public static IReadOnlyList<RatePoint> ScalePoints(IReadOnlyList<RatePoint> points, decimal multiplier)
    {
        return points
            .Select(point => new RatePoint
            {
                TimestampUtc = point.TimestampUtc,
                Rate = point.Rate * multiplier
            })
            .ToList();
    }

    public static string FormatRate(decimal value)
    {
        var absolute = Math.Abs(value);
        var format = absolute switch
        {
            >= 100m => "0.####",
            >= 1m => "0.#####",
            _ => "0.######"
        };

        return value.ToString(format, CultureInfo.InvariantCulture);
    }

    public static string FormatSignedRate(decimal value)
    {
        var prefix = value > 0 ? "+" : string.Empty;
        return $"{prefix}{FormatRate(value)}";
    }

    public static string FormatDisplayAmount(decimal value)
    {
        var absolute = Math.Abs(value);
        var format = absolute switch
        {
            >= 1000m => "#,##0.##",
            >= 1m => "#,##0.####",
            _ => "0.######"
        };

        return value.ToString(format, CultureInfo.InvariantCulture);
    }

    public static string FormatSignedAmount(decimal value)
    {
        var prefix = value > 0 ? "+" : string.Empty;
        return $"{prefix}{FormatDisplayAmount(value)}";
    }

    public static string FormatBaseAmount(decimal value)
    {
        var absolute = Math.Abs(value);
        var format = absolute switch
        {
            >= 1000m => "#,##0.##",
            >= 1m => "#,##0.####",
            _ => "0.####"
        };

        return value.ToString(format, CultureInfo.InvariantCulture);
    }

    public static int DetermineAxisDecimalPlaces(IReadOnlyList<decimal> values, int minimumDecimals = 2, int maximumDecimals = 8)
    {
        if (values.Count <= 1)
        {
            return minimumDecimals;
        }

        for (var decimals = minimumDecimals; decimals <= maximumDecimals; decimals++)
        {
            var formatted = values
                .Select(value => value.ToString($"F{decimals}", CultureInfo.InvariantCulture))
                .ToList();

            if (formatted.Distinct(StringComparer.Ordinal).Count() == formatted.Count)
            {
                return decimals;
            }
        }

        return maximumDecimals;
    }

    public static string FormatAxisValue(decimal value, int decimals)
    {
        return value.ToString($"F{decimals}", CultureInfo.InvariantCulture);
    }
}
