namespace FXRateDashboard.Models;

public sealed class RateSeriesSnapshot
{
    public string Pair { get; set; } = string.Empty;

    public TimeRangePreset Range { get; set; }

    public List<RatePoint> Points { get; set; } = [];

    public decimal CurrentRate { get; set; }

    public decimal ChangeAbsolute { get; set; }

    public decimal ChangePercent { get; set; }

    public DateTimeOffset AsOfUtc { get; set; }

    public bool IsStale { get; set; }

    public RateSeriesSnapshot Clone()
    {
        return new RateSeriesSnapshot
        {
            Pair = Pair,
            Range = Range,
            Points = Points.Select(point => new RatePoint
            {
                TimestampUtc = point.TimestampUtc,
                Rate = point.Rate
            }).ToList(),
            CurrentRate = CurrentRate,
            ChangeAbsolute = ChangeAbsolute,
            ChangePercent = ChangePercent,
            AsOfUtc = AsOfUtc,
            IsStale = IsStale
        };
    }
}
