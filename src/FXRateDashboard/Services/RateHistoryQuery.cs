using FXRateDashboard.Models;

namespace FXRateDashboard.Services;

public sealed record RateHistoryQuery(TimeRangePreset Range, DateTimeOffset FromUtc, DateTimeOffset ToUtc, string Group);
