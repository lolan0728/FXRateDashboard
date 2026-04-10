using System.Globalization;
using System.Windows;
using System.Windows.Media;
using FXRateDashboard.Models;
using FXRateDashboard.Utilities;
using Brush = System.Windows.Media.Brush;
using BrushConverter = System.Windows.Media.BrushConverter;
using Color = System.Windows.Media.Color;
using Pen = System.Windows.Media.Pen;
using Point = System.Windows.Point;
using SolidColorBrush = System.Windows.Media.SolidColorBrush;
using Vector = System.Windows.Vector;

namespace FXRateDashboard.Controls;

public sealed class SparklineChart : FrameworkElement
{
    private const double PlotLeftMargin = 46;
    private const double PlotTopMargin = 10;
    private const double PlotRightMargin = 10;
    private const double PlotBottomMargin = 66;
    private const double PlotInnerPadding = 8;
    private const double AxisLabelSafeInset = 6;
    private const double EdgeTickLift = 8;

    private static readonly Brush GridBrush = CreateBrush("#22163300");
    private static readonly Brush AxisLabelBrush = CreateBrush("#6A745F");
    private static readonly Brush EmptyStateBrush = CreateBrush("#8A9380");
    private static readonly Typeface AxisTypeface = new("Segoe UI");

    public static readonly DependencyProperty ItemsSourceProperty =
        DependencyProperty.Register(
            nameof(ItemsSource),
            typeof(IReadOnlyList<RatePoint>),
            typeof(SparklineChart),
            new FrameworkPropertyMetadata(Array.Empty<RatePoint>(), FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty StrokeBrushProperty =
        DependencyProperty.Register(
            nameof(StrokeBrush),
            typeof(Brush),
            typeof(SparklineChart),
            new FrameworkPropertyMetadata(DefaultStrokeBrush(), FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty AxisDecimalsProperty =
        DependencyProperty.Register(
            nameof(AxisDecimals),
            typeof(int),
            typeof(SparklineChart),
            new FrameworkPropertyMetadata(2, FrameworkPropertyMetadataOptions.AffectsRender));

    public IReadOnlyList<RatePoint> ItemsSource
    {
        get => (IReadOnlyList<RatePoint>)GetValue(ItemsSourceProperty);
        set => SetValue(ItemsSourceProperty, value);
    }

    public Brush StrokeBrush
    {
        get => (Brush)GetValue(StrokeBrushProperty);
        set => SetValue(StrokeBrushProperty, value);
    }

    public int AxisDecimals
    {
        get => (int)GetValue(AxisDecimalsProperty);
        set => SetValue(AxisDecimalsProperty, value);
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);

        if (ActualWidth <= 0 || ActualHeight <= 0)
        {
            return;
        }

        var points = ItemsSource ?? Array.Empty<RatePoint>();
        var plotRect = new Rect(
            PlotLeftMargin,
            PlotTopMargin,
            Math.Max(ActualWidth - PlotLeftMargin - PlotRightMargin, 1),
            Math.Max(ActualHeight - PlotTopMargin - PlotBottomMargin, 1));

        if (plotRect.Width <= 0 || plotRect.Height <= 0)
        {
            return;
        }

        if (points.Count == 0)
        {
            DrawEmptyState(drawingContext, plotRect);
            return;
        }

        var (minValue, maxValue) = GetValueRange(points);
        DrawAxes(drawingContext, plotRect, points, minValue, maxValue);

        var chartPoints = BuildChartPoints(points, plotRect, minValue, maxValue);
        if (chartPoints.Count == 0)
        {
            return;
        }

        var lineGeometry = BuildLineGeometry(chartPoints, plotRect);
        var fillGeometry = BuildFillGeometry(chartPoints, plotRect);

        var strokeBrush = SnapshotBrush(StrokeBrush);
        var fillBrush = CreateAreaBrush(strokeBrush);
        var pen = new Pen(strokeBrush, 2.2)
        {
            StartLineCap = PenLineCap.Round,
            EndLineCap = PenLineCap.Round,
            LineJoin = PenLineJoin.Round
        };
        pen.Freeze();

        var clipRect = new Rect(
            plotRect.Left - 2,
            plotRect.Top - 2,
            plotRect.Width + 4,
            plotRect.Height + 4);
        drawingContext.PushClip(new RectangleGeometry(clipRect));
        drawingContext.DrawGeometry(fillBrush, null, fillGeometry);
        drawingContext.DrawGeometry(null, pen, lineGeometry);

        var lastPoint = chartPoints[^1];
        var haloBrush = CreateMarkerHaloBrush(strokeBrush);
        drawingContext.DrawEllipse(haloBrush, null, lastPoint, 8, 8);
        drawingContext.DrawEllipse(strokeBrush, null, lastPoint, 4.5, 4.5);
        drawingContext.Pop();
    }

    private void DrawEmptyState(DrawingContext drawingContext, Rect plotRect)
    {
        DrawEmptyGrid(drawingContext, plotRect);

        var message = CreateText("Waiting for rate data", 10, EmptyStateBrush);
        var center = new Point(
            plotRect.Left + (plotRect.Width - message.Width) / 2,
            plotRect.Top + (plotRect.Height - message.Height) / 2);

        drawingContext.DrawText(message, center);
    }

    private void DrawAxes(
        DrawingContext drawingContext,
        Rect plotRect,
        IReadOnlyList<RatePoint> points,
        decimal minValue,
        decimal maxValue)
    {
        var horizontalPen = new Pen(GridBrush, 1);
        horizontalPen.Freeze();

        var verticalPen = new Pen(new SolidColorBrush(Color.FromArgb(24, 22, 51, 0)), 1);
        verticalPen.Freeze();

        var axisDecimals = RateMath.DetermineAxisDecimalPlaces(BuildValueTicks(minValue, maxValue, 4), Math.Max(AxisDecimals, 0));

        var valueTicks = BuildValueTicks(minValue, maxValue, 4);

        for (var index = 0; index < valueTicks.Count; index++)
        {
            var tick = valueTicks[index];
            var normalized = (double)((tick - minValue) / (maxValue - minValue));
            var y = GetPlotY(plotRect, normalized);
            if (index == 0)
            {
                y += EdgeTickLift;
            }
            else if (index == valueTicks.Count - 1)
            {
                y -= EdgeTickLift;
            }

            drawingContext.DrawLine(horizontalPen, new Point(plotRect.Left, y), new Point(plotRect.Right, y));

            var label = CreateText(RateMath.FormatAxisValue(tick, axisDecimals), 9, AxisLabelBrush);
            var yPosition = Math.Clamp(
                y - (label.Height / 2),
                AxisLabelSafeInset,
                Math.Max(ActualHeight - label.Height - AxisLabelSafeInset, AxisLabelSafeInset));
            drawingContext.DrawText(
                label,
                new Point(Math.Max(plotRect.Left - label.Width - 8, 0), yPosition));
        }

        foreach (var tick in BuildTimeTicks(points, 4))
        {
            var ratio = tick.Ratio;
            var x = GetPlotX(plotRect, ratio);

            drawingContext.DrawLine(verticalPen, new Point(x, plotRect.Top), new Point(x, plotRect.Bottom));

            var label = CreateText(FormatTimestamp(tick.Point.TimestampUtc, points[0].TimestampUtc, points[^1].TimestampUtc), 9, AxisLabelBrush);
            var xPosition = ratio switch
            {
                <= 0.05 => x,
                >= 0.95 => x - label.Width,
                _ => x - (label.Width / 2)
            };

            xPosition = Math.Clamp(xPosition, 0, Math.Max(ActualWidth - label.Width, 0));
            var yPosition = Math.Clamp(
                plotRect.Bottom + 2,
                AxisLabelSafeInset,
                Math.Max(ActualHeight - label.Height - AxisLabelSafeInset, AxisLabelSafeInset));
            drawingContext.DrawText(label, new Point(xPosition, yPosition));
        }
    }

    private void DrawEmptyGrid(DrawingContext drawingContext, Rect plotRect)
    {
        var horizontalPen = new Pen(GridBrush, 1);
        horizontalPen.Freeze();

        for (var i = 0; i < 4; i++)
        {
            var ratio = i / 3d;
            var y = plotRect.Top + PlotInnerPadding + ((plotRect.Height - (PlotInnerPadding * 2)) * ratio);
            drawingContext.DrawLine(horizontalPen, new Point(plotRect.Left, y), new Point(plotRect.Right, y));
        }

        for (var i = 0; i < 4; i++)
        {
            var ratio = i / 3d;
            var x = plotRect.Left + PlotInnerPadding + ((plotRect.Width - (PlotInnerPadding * 2)) * ratio);
            drawingContext.DrawLine(horizontalPen, new Point(x, plotRect.Top), new Point(x, plotRect.Bottom));
        }
    }

    private static (decimal MinValue, decimal MaxValue) GetValueRange(IReadOnlyList<RatePoint> points)
    {
        var minValue = points.Min(point => point.Rate);
        var maxValue = points.Max(point => point.Rate);

        if (minValue == maxValue)
        {
            minValue -= 0.5m;
            maxValue += 0.5m;
        }

        var span = maxValue - minValue;
        var padding = Math.Max(span * 0.08m, 0.0001m);
        return (minValue - padding, maxValue + padding);
    }

    private static List<Point> BuildChartPoints(
        IReadOnlyList<RatePoint> points,
        Rect plotRect,
        decimal minValue,
        decimal maxValue)
    {
        var chartPoints = new List<Point>(points.Count);
        var lastIndex = points.Count - 1;

        for (var index = 0; index < points.Count; index++)
        {
            var widthFactor = lastIndex == 0 ? 0d : (double)index / lastIndex;
            var normalized = (double)((points[index].Rate - minValue) / (maxValue - minValue));
            normalized = Math.Clamp(normalized, 0d, 1d);

            var x = GetPlotX(plotRect, widthFactor);
            var y = GetPlotY(plotRect, normalized);
            chartPoints.Add(new Point(x, y));
        }

        return chartPoints;
    }

    private static StreamGeometry BuildLineGeometry(IReadOnlyList<Point> points, Rect plotRect)
    {
        var geometry = new StreamGeometry();

        using var context = geometry.Open();
        context.BeginFigure(points[0], isFilled: false, isClosed: false);

        if (points.Count == 1)
        {
            context.LineTo(points[0], isStroked: true, isSmoothJoin: false);
        }
        else
        {
            for (var index = 0; index < points.Count - 1; index++)
            {
                var (controlPoint1, controlPoint2, endPoint) = GetBezierSegment(points, index, plotRect);
                context.BezierTo(controlPoint1, controlPoint2, endPoint, isStroked: true, isSmoothJoin: true);
            }
        }

        geometry.Freeze();
        return geometry;
    }

    private static StreamGeometry BuildFillGeometry(IReadOnlyList<Point> points, Rect plotRect)
    {
        var geometry = new StreamGeometry();

        using var context = geometry.Open();
        context.BeginFigure(new Point(points[0].X, plotRect.Bottom), isFilled: true, isClosed: true);
        context.LineTo(points[0], isStroked: true, isSmoothJoin: false);

        if (points.Count == 1)
        {
            context.LineTo(points[0], isStroked: true, isSmoothJoin: false);
        }
        else
        {
            for (var index = 0; index < points.Count - 1; index++)
            {
                var (controlPoint1, controlPoint2, endPoint) = GetBezierSegment(points, index, plotRect);
                context.BezierTo(controlPoint1, controlPoint2, endPoint, isStroked: true, isSmoothJoin: true);
            }
        }

        context.LineTo(new Point(points[^1].X, plotRect.Bottom), isStroked: true, isSmoothJoin: false);
        geometry.Freeze();
        return geometry;
    }

    private static (Point ControlPoint1, Point ControlPoint2, Point EndPoint) GetBezierSegment(
        IReadOnlyList<Point> points,
        int index,
        Rect plotRect)
    {
        var point0 = index > 0 ? points[index - 1] : points[index];
        var point1 = points[index];
        var point2 = points[index + 1];
        var point3 = index < points.Count - 2 ? points[index + 2] : point2;

        var controlPoint1 = ClampToRect(point1 + (Vector)(point2 - point0) / 6, plotRect);
        var controlPoint2 = ClampToRect(point2 - (Vector)(point3 - point1) / 6, plotRect);
        var endPoint = ClampToRect(point2, plotRect);
        return (controlPoint1, controlPoint2, endPoint);
    }

    private static Point ClampToRect(Point point, Rect rect)
    {
        return new Point(
            Math.Clamp(point.X, rect.Left + PlotInnerPadding, rect.Right - PlotInnerPadding),
            Math.Clamp(point.Y, rect.Top + PlotInnerPadding, rect.Bottom - PlotInnerPadding));
    }

    private static IReadOnlyList<decimal> BuildValueTicks(decimal minValue, decimal maxValue, int count)
    {
        if (count <= 1)
        {
            return [maxValue];
        }

        var ticks = new List<decimal>(count);
        var step = (maxValue - minValue) / (count - 1);

        for (var index = 0; index < count; index++)
        {
            ticks.Add(maxValue - (step * index));
        }

        return ticks;
    }

    private static IReadOnlyList<TimeTick> BuildTimeTicks(IReadOnlyList<RatePoint> points, int count)
    {
        if (points.Count == 1 || count <= 1)
        {
            return [new TimeTick(points[0], 0)];
        }

        var ticks = new List<TimeTick>(count);
        var indexes = new HashSet<int>();

        for (var step = 0; step < count; step++)
        {
            var ratio = step / (double)(count - 1);
            var index = (int)Math.Round(ratio * (points.Count - 1), MidpointRounding.AwayFromZero);
            if (!indexes.Add(index))
            {
                continue;
            }

            var point = points[index];
            var actualRatio = index / (double)(points.Count - 1);
            ticks.Add(new TimeTick(point, actualRatio));
        }

        return ticks;
    }

    private FormattedText CreateText(string text, double fontSize, Brush brush)
    {
        return new FormattedText(
            text,
            CultureInfo.InvariantCulture,
            System.Windows.FlowDirection.LeftToRight,
            AxisTypeface,
            fontSize,
            brush,
            VisualTreeHelper.GetDpi(this).PixelsPerDip);
    }

    private static string FormatTimestamp(DateTimeOffset value, DateTimeOffset min, DateTimeOffset max)
    {
        var span = max - min;
        return span.TotalDays switch
        {
            <= 2 => value.ToLocalTime().ToString("HH:mm", CultureInfo.InvariantCulture),
            <= 45 => value.ToLocalTime().ToString("MM-dd", CultureInfo.InvariantCulture),
            <= 400 => value.ToLocalTime().ToString("yy-MM", CultureInfo.InvariantCulture),
            _ => value.ToLocalTime().ToString("yyyy-MM", CultureInfo.InvariantCulture)
        };
    }

    private static Brush DefaultStrokeBrush()
    {
        return CreateBrush("#6C9A54");
    }

    private static Brush CreateAreaBrush(Brush strokeBrush)
    {
        var color = strokeBrush is SolidColorBrush solidBrush ? solidBrush.Color : Color.FromRgb(108, 154, 84);
        var brush = new LinearGradientBrush
        {
            StartPoint = new Point(0, 0),
            EndPoint = new Point(0, 1)
        };
        brush.GradientStops.Add(new GradientStop(Color.FromArgb(88, color.R, color.G, color.B), 0));
        brush.GradientStops.Add(new GradientStop(Color.FromArgb(12, color.R, color.G, color.B), 1));
        brush.Freeze();
        return brush;
    }

    private static Brush CreateMarkerHaloBrush(Brush strokeBrush)
    {
        var color = strokeBrush is SolidColorBrush solidBrush ? solidBrush.Color : Color.FromRgb(108, 154, 84);
        var brush = new SolidColorBrush(Color.FromArgb(58, color.R, color.G, color.B));
        brush.Freeze();
        return brush;
    }

    private static Brush SnapshotBrush(Brush brush)
    {
        var color = brush is SolidColorBrush solidBrush ? solidBrush.Color : Color.FromRgb(108, 154, 84);
        var snapshot = new SolidColorBrush(color);
        snapshot.Freeze();
        return snapshot;
    }

    private static Brush CreateBrush(string hex)
    {
        var brush = (SolidColorBrush)new BrushConverter().ConvertFrom(hex)!;
        brush.Freeze();
        return brush;
    }

    private static double GetPlotX(Rect plotRect, double ratio)
    {
        var drawableWidth = Math.Max(plotRect.Width - (PlotInnerPadding * 2), 1);
        return plotRect.Left + PlotInnerPadding + (drawableWidth * ratio);
    }

    private static double GetPlotY(Rect plotRect, double normalized)
    {
        var drawableHeight = Math.Max(plotRect.Height - (PlotInnerPadding * 2), 1);
        return plotRect.Bottom - PlotInnerPadding - (drawableHeight * normalized);
    }

    private readonly record struct TimeTick(RatePoint Point, double Ratio);
}
