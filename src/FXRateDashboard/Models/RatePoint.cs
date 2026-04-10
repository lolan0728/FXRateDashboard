namespace FXRateDashboard.Models;

public sealed class RatePoint
{
    public DateTimeOffset TimestampUtc { get; set; }

    public decimal Rate { get; set; }
}
